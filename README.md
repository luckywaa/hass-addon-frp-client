[![Version](https://img.shields.io/badge/version-v1.0.0-blue.svg)](https://github.com/huxiaoxu2019/hass-addon-frp-client/tree/v1.0.0) [![Discord](https://dcbadge.vercel.app/api/server/3DKtHRWv?style=flat&compact=true)](https://discord.gg/uHPnqBSq)

⚠️ **Note: This README corresponds to v1.0.0 and may not fully reflect the current state of the repository. Please change to the specific tag for the most accurate information.**

安装后，在 HA 侧边栏打开本加载项的网页配置页（或加载项页面的“打开Web界面”），把 frpc.toml 内容直接粘贴进文本框，点“保存并生效”，frpc 会自动加载新配置。可借鉴frpc.toml.example。

**备用方式**（不使用网页配置页时）：插件配置页的两个选项，二选一：

1. **frpc_config_base64（推荐）**：将frpc.toml整个文件base64编码后粘贴（PowerShell：`[Convert]::ToBase64String([IO.File]::ReadAllBytes("frpc.toml"))`；Linux：`base64 -w0 frpc.toml`）。
2. **frpc_config**：TOML压成一行，行与行之间用字面`\n`分隔（编辑器里把换行替换成`\n`再粘贴）。

> 注意：加载项配置页的输入框是单行的，直接粘贴多行内容会丢失换行；网页配置页没有此限制。选项内容只在首次启动时作为初始配置导入，之后以网页编辑器保存的 `/data/frpc.toml` 为准。

## Author
Xiaoxu Hu admin@ihuxu.com

Special thanks to: [@steplov](https://github.com/steplov) for the setup script
