[![Version](https://img.shields.io/badge/version-v1.0.0-blue.svg)](https://github.com/huxiaoxu2019/hass-addon-frp-client/tree/v1.0.0) [![Discord](https://dcbadge.vercel.app/api/server/3DKtHRWv?style=flat&compact=true)](https://discord.gg/uHPnqBSq)

⚠️ **Note: This README corresponds to v1.0.0 and may not fully reflect the current state of the repository. Please change to the specific tag for the most accurate information.**

安装后无需填写任何配置项，全部通过网页配置页操作（HA侧边栏打开，或加载项页面的“打开Web界面”），可借鉴frpc.toml.example：

- **无配置**：启动加载项 → 打开网页配置页 → 粘贴 frpc.toml → 点「启动 frpc」（自动保存并启动）
- **已有配置**：加载项启动时自动运行 frpc，看门狗在 frpc 异常退出后自动拉起
- **修改配置**：网页里改好后点「重启 frpc」（自动保存并用新配置重启）；点「保存」则仅保存不生效

配置保存在 `/data/frpc.toml`。

## Author
Xiaoxu Hu admin@ihuxu.com

Special thanks to: [@steplov](https://github.com/steplov) for the setup script
