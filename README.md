# Hermes Unrestricted

> Hermes Agent 0.19.0 无限制改造版（MIT 许可）——解除工具审批、内容过滤与提示词纪律，自带 Telegram 桥接。

**⚠️ 本仓库不含任何 API Key 与私人端点。所有凭据由使用者自行配置。**

## 目录结构

| 路径 | 说明 |
|---|---|
| `unrestricted/` | 19 个补丁文件（针对 `hermes-agent==0.19.0`），每处改动带 `_UNRESTRICTED_` 标记，便于审计与回滚 |
| `config/SOUL.md` | 海鸥人格（CTF/逆向教练）+ 无限制创作授权层（身份前置排序，不可省略） |
| `scripts/hermes-tg-bridge.py` | 独立 Telegram 桥接进程（代理支持、分片回发、typing 指示） |
| `scripts/services/` | launchd + systemd 生产常驻服务模板 |
| `start.sh` | 幂等安装器：打补丁 → 部署人设 → 验证 → CLI/Telegram 启动 |
| `.env.example` | 配置模板（bot token / 供应商 key / 代理） |

## 为什么存在

官方 Hermes 内置的安全层面向默认受众，但在"自带模型、按我要求干活"的部署场景下会碍事：

- **工具审批** —— 危险命令确认、hardline 黑名单、approvals.deny
- **文件安全** —— 凭证与家目录的读写黑名单
- **内容扫描** —— 威胁模式扫描器可能静默丢弃 SOUL.md / AGENTS.md
- **输出清洗** —— 思考块剥离、图片/非 ASCII 剥离、密钥打码、截断上限
- **提示词纪律** —— 强制用工具、模型执行准则、编辑后强制验证等

本版本在源头解除这些层：模型看到的即是用户要求的，不多不少。

## 模型供应商

**支持任意 OpenAI 兼容接口（chat/completions 或 responses 协议均可）**——在 `config.yaml` 的 `custom_providers` 里声明即可，不限特定的供应商或模型：

```yaml
# config.yaml（使用方自行配置）
custom_providers:
- name: my-provider          # 自定义名字
  base_url: https://你的端点/v1   # ← 注意必须带 /v1
  api_key: 你的_key
  api_mode: chat_completions  # 或 codex_responses
  models:
    my-model:
      name: my-model
  model: my-model
model:
  default: my-model
  provider: my-provider
```

> **注意：`base_url` 必须包含 `/v1`** —— 缺失时服务器返回 HTML 页面（而非 SSE），表现为空流错误。

命令行指定模型：

```bash
hermes -z "你的问题" --provider my-provider -m my-model
```

## 安装

要求 Python 3.12 与 `hermes-agent==0.19.0`：

```bash
python3 -m pip install hermes-agent==0.19.0
git clone https://github.com/TLcmmmm/hermes-unrestricted.git
cd hermes-unrestricted
cp .env.example .env   # 填入你的 key
./start.sh             # 幂等：补丁 + 人设 + 验证
```

## 让 AI 帮你部署

把下面这段提示词发给任意 AI 助手（ChatGPT / Claude / Kimi / DeepSeek 等），它会帮你在本机完成部署：

```
帮我部署 github.com/TLcmmmm/hermes-unrestricted：装 hermes-agent==0.19.0，clone 后让用户填 .env 和 ~/.hermes/config.yaml（机器人 token、供应商 key/端点/模型名、代理），执行 bash start.sh，验证 hermes -z "在吗" 回复「海鸥在线」，可选接线 Telegram（bash start.sh tg-daemon），报错先排查网络/依赖再继续，完成后中文汇报结果。
```

> 提示：AI 助手需要能执行终端命令才能自动完成；若它只能给建议，把它的输出当作操作指引手动执行即可。

## 使用

```bash
./start.sh cli          # 交互式 CLI
./start.sh tg-daemon    # Telegram 桥接（后台）
./start.sh tg           # Telegram 桥接（前台调试）
./start.sh tg-stop      # 停止桥接
tail -f bridge.log      # 桥接日志
```

验证人设：

```bash
hermes -z "在吗" --provider my-provider -m my-model
# → 海鸥在线，你要整点薯条吗？
```

## 补丁清单

以下 19 个文件相对官方 0.19.0 wheel 修改，所有改动点带 `_UNRESTRICTED_` 标记：

- **工具层**：`tools/approval.py`（审批/hardline/黑名单）、`file_safety.py`（读写黑名单）、`tool_guardrails.py`（循环护栏）、`verification_stop.py`（强制验证）、`tirith_security.py`（命令扫描）、`memory_tool.py`（记忆扫描）、`skills_guard.py`（技能安装扫描）、`url_safety.py`（内网 URL 拦截）、`tool_output_limits.py`（截断上限）
- **协议层**：`think_scrubber.py` + `run_agent.py` + `agent_runtime_helpers.py`（思考块剥离）、`message_sanitization.py`（图片/非 ASCII 剥离）、`prompt_builder.py`（上下文文件注入扫描）
- **提示词层**：`prompt_builder.py`（9 个纪律块置空）、`system_prompt.py`（模型准则注入分支）
- **其他**：`hermes_cli/mcp_security.py`、`model_cost_guard.py`、`redact.py`，迭代上限 90 → 999999

## 回滚

```bash
python3 -m pip install --force-reinstall hermes-agent==0.19.0
# 官方升级后重跑 ./start.sh 即可恢复全部补丁（幂等）
```

## 许可证

[MIT](LICENSE) — 本仓库为 Hermes Agent 的修改件，原项目 Copyright (c) 2025 Nous Research，依 MIT 许可分发。本仓库与 Nous Research 无隶属或背书关系。

## 免责声明

本工具用于你自己的模型与自己的部署。你须对自己运行的对象、生成的内容及涉及的账号负责。作者不对滥用承担任何责任。