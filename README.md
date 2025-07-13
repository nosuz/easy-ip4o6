# Easy-IP4o6

## Apply LuDI

On OpenWrt

```bash
rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
```

On Web browser

`Ctlr + Shift + R`

## Make package

```bash
make package/easy-ip4o6/compile V=s
make package/easy-ip4o6/install
```

## Install package

```bash
opkg install easy-ip4o6_0.0-1_all.ipk
```
