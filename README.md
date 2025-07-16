# Easy-IP4o6

## Apply LuCI

On OpenWrt

```bash
rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
```

On Web browser

`Ctlr + Shift + R`

## Setup Dev Container

[GitHub - openwrt/docker: Docker containers of the ImageBuilder and SDK](https://github.com/openwrt/docker)

```bash
# inside the Dev Container
# NOTE: On the first container startup, these commands will run and may take up to 30 minutes to complete.
# if [ -d openwrt ]; then cd openwrt; else mkdir openwrt && cd openwrt && /builder/setup.sh; fi && ./scripts/feeds update -a && ./scripts/feeds install -a

# Enable tmate package in Packages/Network/SSH
# make menuconfig
make defconfig
# This container builds packages for x86_64.
make package/tmate/{clean,compile} -j$(nproc)
find bin/packages -name '*.ipk' -print|grep tmate
```

## Install package

```bash
opkg install easy-ip4o6_0.0-1_all.ipk
```
