# v2ray vpn配置

使用nftable配置相关脚本。代理模式是透明代理

## 初始化步骤

- 安装nftables相关命令
- 将nft命令加入sudo免密码列表
- 软链接nftables.d文件夹到/etc目录下
- 初始化ip白名单(不走代理的ip段)配置文件~/.config/.v2ray.ignore.ip
