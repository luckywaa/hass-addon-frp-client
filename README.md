[![Version](https://img.shields.io/badge/version-v1.0.0-blue.svg)](https://github.com/huxiaoxu2019/hass-addon-frp-client/tree/v1.0.0) [![Discord](https://dcbadge.vercel.app/api/server/3DKtHRWv?style=flat&compact=true)](https://discord.gg/uHPnqBSq)

⚠️ **Note: This README corresponds to v1.0.0 and may not fully reflect the current state of the repository. Please change to the specific tag for the most accurate information.**

安装后，在插件配置页面填写 frpc 配置并保存，可借鉴frpc.toml.example。

**注意：配置页面的输入框是单行的，直接粘贴多行TOML会丢失换行。** 推荐两种方式：

1. **frpc_config_base64（推荐）**：将frpc.toml整个文件base64编码后粘贴到该输入框（PowerShell：`[Convert]::ToBase64String([IO.File]::ReadAllBytes("frpc.toml"))`；Linux：`base64 -w0 frpc.toml`）。填写后优先生效。
2. **frpc_config**：将TOML内容压成一行，行与行之间用字面`\n`分隔（可在编辑器里把换行全部替换成`\n`再粘贴），插件会自动还原成多行。

## Author
Xiaoxu Hu admin@ihuxu.com

Special thanks to: [@steplov](https://github.com/steplov) for the setup script
