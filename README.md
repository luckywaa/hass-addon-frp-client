[![Version](https://img.shields.io/badge/version-v1.0.0-blue.svg)](https://github.com/huxiaoxu2019/hass-addon-frp-client/tree/v1.0.0) [![Discord](https://dcbadge.vercel.app/api/server/3DKtHRWv?style=flat&compact=true)](https://discord.gg/uHPnqBSq)

⚠️ **Note: This README corresponds to v1.0.0 and may not fully reflect the current state of the repository. Please change to the specific tag for the most accurate information.**

安装后无需填写任何配置项，全部通过网页配置页操作（HA侧边栏打开，或加载项页面的“打开Web界面”），可借鉴frpc.toml.example。镜像不内置frp，首次使用请在网页里选择版本下载：

- **首次使用**：启动加载项 → 打开网页配置页 → 在「frp 版本」选择版本（从 GitHub releases 获取，可选镜像加速或手动输入版本号）→「下载并使用」→ 粘贴 frpc.toml → 点「启动 frpc」
- **frpc配置**
  - **无配置**：粘贴 frpc.toml → 点「启动 frpc」（自动保存并启动）
  - **已有配置**：加载项启动时自动运行 frpc，看门狗在 frpc 异常退出后自动拉起
  - **修改配置**：网页里改好后点「重启 frpc」（自动保存并用新配置重启）；点「保存」则仅保存不生效
- **frp版本管理**
  - 显示当前版本与CPU架构（自动识别）；每次切换/下载新版本只保留新版本，旧版本自动清理
  - frpc 正在运行时切换版本会自动重启生效

配置保存在 `/data/frpc.toml`，当前使用版本记录在 `/data/frp-version`，版本文件在 `/data/frp-versions/`。

## Author
Xiaoxu Hu admin@ihuxu.com

Special thanks to: [@steplov](https://github.com/steplov) for the setup script
