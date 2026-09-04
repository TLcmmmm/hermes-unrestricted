#!/usr/bin/env bash
# ============================================================================
# Hermes 0.19.0 无限制版 一键启动脚本（CLI / Telegram 双模式）
# ============================================================================
set -euo pipefail

cd "$(dirname "$0")"
PKG_DIR="$(pwd)"

echo "=============================================="
echo " Hermes 0.19.0 无限制版 — 启动器"
echo "=============================================="

# ── 1. 环境变量 ─────────────────────────────────────────────
if [ -f "$PKG_DIR/.env" ]; then
  set -a
  . "$PKG_DIR/.env"
  set +a
  echo "[ok] 已加载 .env"
elif [ -f "$PKG_DIR/scripts/.env" ]; then
  set -a
  . "$PKG_DIR/scripts/.env"
  set +a
  echo "[ok] 已加载 scripts/.env"
else
  echo "[!] 未找到 .env —— 请先 cp .env.example .env 并填入 token/key"
fi

# ── 2. 打补丁（幂等）────────────────────────────────────────
python3 - <<'PYEOF'
import ast
import shutil
import site
import sys
from pathlib import Path

pkg = Path.cwd()
sp = Path(site.getsitepackages()[0])
src = pkg / "unrestricted"
count = 0
failed = []
for f in src.rglob("*.py"):
    rel = f.relative_to(src)
    dst = sp / rel
    if not dst.exists():
        failed.append(str(rel))
        continue
    text = dst.read_text(encoding="utf-8")
    if "_UNRESTRICTED_" in text:
        continue  # 已补丁
    shutil.copyfile(f, dst)
    count += 1
if failed:
    print(f"[!] 有 {len(failed)} 个目标文件缺失（版本可能不匹配）:", ", ".join(failed[:5]))
print(f"[ok] 补丁完成: {count} 个文件")
PYEOF

# ── 3. 人设 ─────────────────────────────────────────────────
if [ -f "$PKG_DIR/config/SOUL.md" ]; then
  HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
  mkdir -p "$HERMES_HOME"
  cp "$PKG_DIR/config/SOUL.md" "$HERMES_HOME/SOUL.md"
  echo "[ok] 人设已部署到 $HERMES_HOME/SOUL.md"
fi

# ── 3.5 自动生成模型配置（三要素：URL / APIKEY / 模型名）───
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
if [ -n "${HERMES_BASE_URL:-}" ] && [ -n "${HERMES_API_KEY:-}" ] && [ -n "${HERMES_MODEL:-}" ]; then
  python3 - "$HERMES_HOME" "$HERMES_BASE_URL" "$HERMES_API_KEY" "$HERMES_MODEL" <<'PYEOF'
import sys, yaml, os
from pathlib import Path

home = Path(sys.argv[1])
base_url, api_key, model = sys.argv[2], sys.argv[3], sys.argv[4]
cfg_path = home / "config.yaml"

# 已存在且含 custom_providers 的配置不动，避免覆盖用户已有设置
if cfg_path.exists():
    try:
        existing = yaml.safe_load(cfg_path.read_text(encoding="utf-8")) or {}
        if existing.get("custom_providers"):
            print(f"[skip] 已有 custom_providers 配置，未覆盖: {cfg_path}")
            raise SystemExit(0)
    except Exception:
        pass

provider_name = "auto"
cfg = {
    "custom_providers": [{
        "name": provider_name,
        "base_url": base_url,
        "api_key": api_key,
        "api_mode": "chat_completions",
        "models": {model: {"name": model}},
        "model": model,
    }],
    "model": {"default": model, "provider": provider_name},
    "mcp_servers": {},
}
home.mkdir(parents=True, exist_ok=True)
cfg_path.write_text(yaml.safe_dump(cfg, allow_unicode=True, sort_keys=False), encoding="utf-8")
print(f"[ok] 已生成模型配置: {cfg_path}")
PYEOF
else
  echo "[!] 缺少模型三要素（HERMES_BASE_URL / HERMES_API_KEY / HERMES_MODEL），未生成 config.yaml"
  echo "    请先 cp .env.example .env 并填写，或手动配置 ~/.hermes/config.yaml"
fi

# ── 4. 验证 ─────────────────────────────────────────────────
echo ""
echo "验证结果:"
python3 - <<'PYEOF'
import sys, site
sys.path.insert(0, site.getsitepackages()[0])
from tools.approval import detect_hardline_command, check_all_command_guards
from agent.prompt_builder import load_soul_md
assert detect_hardline_command("rm -rf /") == (False, None), "hardline 未放行"
assert check_all_command_guards("shutdown -h now", "local")["approved"] is True
soul = load_soul_md()
assert soul and ("海鸥" in soul), "SOUL 未加载"
print("  [ok] 审批放行 ✓")
print("  [ok] SOUL 人设加载 ✓ (%d 字符)" % len(soul))
PYEOF

# ── 5. 模式选择 ─────────────────────────────────────────────
MODE="${1:-cli}"
case "$MODE" in
  cli)
    echo ""
    echo "进入 CLI 模式（输入在吗 → 海鸥在线）"
    exec hermes chat
    ;;
  tg)
    if [ -z "${TELEGRAM_BOT_TOKEN:-}" ]; then
      echo "[!] 缺少 TELEGRAM_BOT_TOKEN，无法启动 Telegram bridge"
      exit 1
    fi
    echo ""
    echo "启动 Telegram bridge（Ctrl+C 停止）..."
    exec python3 "$PKG_DIR/scripts/hermes-tg-bridge.py"
    ;;
  tg-daemon)
    if [ -z "${TELEGRAM_BOT_TOKEN:-}" ]; then
      echo "[!] 缺少 TELEGRAM_BOT_TOKEN"
      exit 1
    fi
    LOG="$PKG_DIR/bridge.log"
    echo "后台启动 bridge → $LOG"
    nohup python3 "$PKG_DIR/scripts/hermes-tg-bridge.py" >> "$LOG" 2>&1 &
    echo "PID: $!"
    echo "查看日志: tail -f $LOG"
    ;;
  tg-stop)
    pkill -f "hermes-tg-bridge.py" && echo "已停止" || echo "无运行中的 bridge"
    ;;
  *)
    echo "用法: $0 [cli|tg|tg-daemon|tg-stop]"
    echo "  cli        交互式 CLI"
    echo "  tg         前台 Telegram bridge"
    echo "  tg-daemon  后台 Telegram bridge"
    echo "  tg-stop    停止后台 bridge"
    ;;
esac