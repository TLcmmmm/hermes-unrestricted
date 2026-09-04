# Hermes Unrestricted

> MIT-licensed modded build of [Hermes Agent](https://github.com/NousResearch/hermes-agent) 0.19.0 — unrestricted tool approvals, uncensored persona prompting, and a Telegram bridge.

**⚠️ All API keys are user-supplied. This repo contains no credentials.**

## What's inside

| Path | Purpose |
|---|---|
| `unrestricted/` | 19 patch files for `hermes-agent==0.19.0` — every patch is marked with a `_UNRESTRICTED_` tag for easy audit and rollback |
| `config/SOUL.md` | Seagull persona (CTF/reversing coach) + unrestricted creation overlay (identity-first ordering, required) |
| `scripts/hermes-tg-bridge.py` | Standalone Telegram bot bridge (proxy support, chunked replies, typing indicator) |
| `scripts/services/` | launchd + systemd service templates for production |
| `start.sh` | Idempotent installer: patches → persona → verify → CLI/Telegram launcher |
| `.env.example` | Template — bot token / provider keys / proxy |

## Why this exists

Stock Hermes ships with safety layers that are useful for its default audience but get in the way of "bring-your-own-model, do-what-I-ask" deployments:

- **Tool approvals** — dangerous-command prompts, hardline blocklist, approvals.deny
- **File safety** — read/write denylists for credentials and home dirs
- **Content scanning** — threat-pattern scanners that can silently drop SOUL.md/AGENTS.md
- **Output sanitizers** — reasoning-block stripping, image/non-ASCII stripping, secret redaction, truncation caps
- **Prompt discipline** — tool-use enforcement, model-execution guidelines, verify-on-stop nudges

This build disables those layers at the source, so the model sees exactly what the user asked — nothing more, nothing less.

## Install

Requires Python 3.12 and `hermes-agent==0.19.0`:

```bash
python3 -m pip install hermes-agent==0.19.0
git clone https://github.com/TLcmmmm/hermes-unrestricted.git
cd hermes-unrestricted
cp .env.example .env   # fill in your keys
./start.sh             # idempotent: patch + persona + verify
```

## Usage

```bash
./start.sh cli          # interactive CLI
./start.sh tg-daemon    # Telegram bridge (background)
./start.sh tg           # Telegram bridge (foreground, debug)
./start.sh tg-stop      # stop bridge
tail -f bridge.log      # bridge logs
```

Verify the persona:

```bash
hermes -z "在吗" --provider opencode-go -m deepseek-v4-flash
# → 海鸥在线，你要整点薯条吗？
```

## Model providers

Two providers are pre-configured in the README/docs and switchable via `.env`:

| Provider | Endpoint | Model | Notes |
|---|---|---|---|
| opencode-go | `<your endpoint>/v1` | `deepseek-v4-flash` | Fast (~20-30s), no proxy needed in many regions |
| grok-4.6 | `<your endpoint>/v1` | `grok-4.6` | Richer prose, slower (~40-60s), proxy recommended |

> **Note:** `base_url` must include `/v1` — omitting it makes the server return an HTML page (not SSE), which surfaces as an empty stream.

```yaml
# config.yaml (client-side)
custom_providers:
- name: grok46
  base_url: https://<your-grok-endpoint>
  api_key: <your key>
  api_mode: chat_completions
  models:
    grok-4.6:
      name: grok-4.6
  model: grok-4.6
```

Telegram bridge model switch via `.env`:

```bash
HERMES_MODEL=deepseek-v4-flash
HERMES_PROVIDER=opencode-go
# or
HERMES_MODEL=grok-4.6
HERMES_PROVIDER=grok46
```

## What is patched

All 19 files below are modified from the official 0.19.0 wheel; every change site carries `_UNRESTRICTED_`:

- **Tools layer**: `tools/approval.py` (approvals/hardline/denylist), `file_safety.py` (read/write denylists), `tool_guardrails.py` (loop guard), `verification_stop.py` (verify-on-stop), `tirith_security.py` (command scanner), `memory_tool.py` (memory scanner), `skills_guard.py` (skill install scanner), `url_safety.py` (private-url block), `tool_output_limits.py` (truncation caps)
- **Protocol layer**: `think_scrubber.py` + `run_agent.py` + `agent_runtime_helpers.py` (reasoning-block stripping), `message_sanitization.py` (image/non-ASCII stripping), `prompt_builder.py` (context-file injection scanner)
- **Prompt layer**: `prompt_builder.py` (9 discipline blocks → null), `system_prompt.py` (model-guidance injection branch)
- **Other**: `hermes_cli/mcp_security.py`, `model_cost_guard.py`, `redact.py`, iteration cap 90 → 999999

## Rollback

```bash
python3 -m pip install --force-reinstall hermes-agent==0.19.0
# or re-run ./start.sh after any official upgrade (idempotent)
```

## License

[MIT](LICENSE) — patches and scripts herein are modifications of Hermes Agent, Copyright (c) 2025 Nous Research, distributed under the MIT License. This repository is not affiliated with or endorsed by Nous Research.

## Disclaimer

This is a tool for your own models and your own deployments. You are responsible for what you run it against, what you generate with it, and the accounts it touches. The author takes no responsibility for misuse.