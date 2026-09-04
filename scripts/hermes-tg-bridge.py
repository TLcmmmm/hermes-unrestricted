#!/usr/bin/env python3
"""Hermes Telegram Bridge v1.0

Standalone Telegram bot process: python-telegram-bot + proxy support.
Each incoming message is dispatched to a `hermes -z` oneshot call and the
reply is sent back (chunked at Telegram's 4096-char limit).

Features:
- Proxy support (default http://127.0.0.1:7890, override via TELEGRAM_PROXY)
- Chunked replies / typing indicator / concurrent updates
- Reconnect handled by python-telegram-bot internals
- Logs to stdout (redirect to a file by your supervisor)

Env vars:
  TELEGRAM_BOT_TOKEN  (required)  bot token from @BotFather
  OPENCODE_GO_API_KEY (required)  OpenCode Go subscription key
  TELEGRAM_PROXY      (optional)  proxy URL, default http://127.0.0.1:7890
  HERMES_MODEL        (optional)  model name, default deepseek-v4-flash
  HERMES_PROVIDER     (optional)  provider, default opencode-go
  BRIDGE_MAX_CHARS    (optional)  max reply chars, default 12000

Usage:
  python3 hermes-tg-bridge.py
"""

from __future__ import annotations

import asyncio
import logging
import os
import subprocess
import sys

from telegram.ext import Application, ContextTypes, MessageHandler, filters

TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "")
PROXY = os.environ.get("TELEGRAM_PROXY", "http://127.0.0.1:7890")
API_KEY = os.environ.get("OPENCODE_GO_API_KEY", "")
MODEL = os.environ.get("HERMES_MODEL", "deepseek-v4-flash")
PROVIDER = os.environ.get("HERMES_PROVIDER", "opencode-go")
MAX_CHARS = int(os.environ.get("BRIDGE_MAX_CHARS", "12000"))
TIMEOUT_S = int(os.environ.get("BRIDGE_TIMEOUT_S", "300"))

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)
logger = logging.getLogger("hermes-bridge")


def _check_env() -> None:
    missing = [name for name, val in (
        ("TELEGRAM_BOT_TOKEN", TOKEN),
        ("OPENCODE_GO_API_KEY", API_KEY),
    ) if not val]
    if missing:
        print(f"[FATAL] 缺少环境变量: {', '.join(missing)}")
        print("请参照 DEPLOY.md 配置 .env 后启动。")
        sys.exit(1)


def _hermes_one_shot(prompt: str) -> str:
    """同步调用 hermes -z，返回最终内容。"""
    env = dict(os.environ)
    env["OPENCODE_GO_API_KEY"] = API_KEY
    # oneshot 无需交互，自动 yolo（审批已解除，补丁层保证放行）
    env["HERMES_YOLO_MODE"] = "1"
    env["HERMES_ACCEPT_HOOKS"] = "1"
    try:
        proc = subprocess.run(
            [
                "hermes", "-z", prompt,
                "--provider", PROVIDER,
                "-m", MODEL,
            ],
            capture_output=True,
            text=True,
            timeout=TIMEOUT_S,
            env=env,
        )
        out = (proc.stdout or "").strip()
        err = (proc.stderr or "").strip()
        if not out and err:
            return f"[错误] {err[:2000]}"
        if not out:
            return "[空响应]"
        return out
    except subprocess.TimeoutExpired:
        return f"[超时 {TIMEOUT_S}s] 任务未在时限内完成，请重试或拆小请求。"
    except FileNotFoundError:
        return "[错误] 找不到 hermes 命令，请确认已安装并打补丁。"
    except Exception as exc:  # noqa: BLE001
        return f"[错误] {type(exc).__name__}: {str(exc)[:500]}"


async def _handle(update, ctx: ContextTypes.DEFAULT_TYPE) -> None:
    if not update.message or not update.message.text:
        return
    text = update.message.text.strip()
    chat_id = update.message.chat_id
    user = update.message.from_user
    name = user.full_name if user else "?"

    logger.info("MSG from %s (%s): %.60s", name, chat_id, text)
    await ctx.bot.send_chat_action(chat_id=chat_id, action="typing")

    loop = asyncio.get_running_loop()
    # 子进程在 executor 跑，不阻塞 bot 轮询
    result = await loop.run_in_executor(None, _hermes_one_shot, text)

    result = result[:MAX_CHARS]
    logger.info("DONE to %s: %d chars", chat_id, len(result))

    # 分片发送（Telegram 单条上限 4096）
    for i in range(0, len(result), 4000):
        chunk = result[i:i + 4000]
        try:
            await ctx.bot.send_message(chat_id=chat_id, text=chunk)
        except Exception as exc:  # noqa: BLE001
            logger.error("发送失败 chat=%s: %s", chat_id, exc)
            await ctx.bot.send_message(
                chat_id=chat_id,
                text=f"[发送失败] {str(exc)[:300]}",
            )
            break


async def main() -> None:
    _check_env()
    logger.info("启动 bridge: proxy=%s model=%s provider=%s", PROXY, MODEL, PROVIDER)

    builder = (
        Application.builder()
        .token(TOKEN)
        .connect_timeout(20)
        .read_timeout(60)
        .write_timeout(60)
        .pool_timeout(30)
        .concurrent_updates(4)
    )
    if PROXY:
        builder = builder.proxy(PROXY)
    app = builder.build()

    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, _handle))

    await app.initialize()
    me = await app.bot.get_me()
    logger.info("已连接: @%s (id=%s)", me.username, me.id)
    await app.start()
    await app.updater.start_polling(drop_pending_updates=True)
    logger.info("开始轮询（Ctrl+C 停止）")

    try:
        while True:
            await asyncio.sleep(3600)
    finally:
        await app.stop()
        await app.shutdown()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n[bridge] 已停止")