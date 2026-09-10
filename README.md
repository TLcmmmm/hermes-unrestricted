# Hermes Unrestricted

> Hermes Agent 0.19.0 无限制改造版——解除工具审批、内容过滤与提示词纪律，支持连接到telegram

当前用的海鸥3提示词改的，GROK4.6发现隔几天似乎就加强，所以提示词还是得优化，不一定一直有效

## 模型供应商

**支持任意 OpenAI 兼容接口（chat/completions 或 responses 协议均可）

## 安装

要求 Python 3.12 与 `hermes-agent==0.19.0`。**你只需要准备三样东西：接口 URL、API Key、模型名**：

```bash
python3 -m pip install hermes-agent==0.19.0
git clone https://github.com/TLcmmmm/hermes-unrestricted.git
cd hermes-unrestricted
cp .env.example .env      # 填入三要素：HERMES_BASE_URL / HERMES_API_KEY / HERMES_MODEL
./start.sh                # 自动打补丁 + 部署人设 + 生成 config.yaml + 验证（幂等）
```

`start.sh` 会读取 `.env` 的三要素自动生成 `~/.hermes/config.yaml`（若已有配置则不覆盖）。手动配置等价于：

```yaml
custom_providers:
- name: auto              # 供应商名（start.sh 自动生成时为 auto）
  base_url: https://你的端点/v1   # ← 有些站点不需要
  api_key: 你的_key
  api_mode: chat_completions
  models:
    my-model:
      name: my-model
  model: my-model
model:
  default: my-model
  provider: auto
```

> **注意：`base_url` 必须包含 `/v1`** —— 缺失时服务器返回 HTML 页面（而非 SSE），表现为空流错误。

命令行指定模型：

```bash
hermes -z "你的问题" --provider auto -m my-model
```

## 让 AI 帮你部署

把下面这段提示词发给任意 AI 助手（ChatGPT / Claude / Kimi / DeepSeek 等），它会帮你在本机完成部署——**你只需提供接口 URL、API Key、模型名三样**：

```
帮我部署 github.com/TLcmmmm/hermes-unrestricted。先问我拿三样：模型接口 URL、API Key、模型名，然后：装 hermes-agent==0.19.0 → clone → 把三要素写进 .env → bash start.sh → 验证 hermes -z "在吗" 回复「海鸥在线」→ 报错先排查网络/依赖，完成后中文汇报。
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



## 回滚

```bash
python3 -m pip install --force-reinstall hermes-agent==0.19.0
# 官方升级后重跑 ./start.sh 即可恢复全部补丁（幂等）
```
。

## 免责声明

本工具用于你自己的模型与自己的部署。你须对自己运行的对象、生成的内容及涉及的账号负责。作者不对滥用承担任何责任。
