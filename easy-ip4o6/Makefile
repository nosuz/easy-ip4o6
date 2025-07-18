# OpenWrt Makefile for easy-ip4o6 package

include $(TOPDIR)/rules.mk

PKG_NAME:=easy-ip4o6
PKG_VERSION:=1.1
PKG_RELEASE:=3

PKG_MAINTAINER:=Norio Suzuki <nosuzuki@postcard.st>
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	CATEGORY:=Network
	SECTION:=net
	TITLE:=Easy IPIP (IPv4 over IPv6) Tunnel Interface
	DEPENDS:=+luci +netifd +kmod-ip6-tunnel
	PKGARCH:=all
endef

define Package/$(PKG_NAME)/description
	This package provides IPIP (IPv4 over IPv6) tunnel interfaces.
	Includes netifd protocol support and hotplug event handling.
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/network
endef

define Build/Compile
	# Nothing to compile - this is a script-only package
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/lib/netifd/proto
	$(INSTALL_BIN) ./files/ip4o6.sh $(1)/lib/netifd/proto/

	$(INSTALL_DIR) $(1)/www/luci-static/resources/protocol
	$(INSTALL_DATA) ./files/ip4o6.js $(1)/www/luci-static/resources/protocol/ip4o6.js
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
# Restart netifd to register the new protocol
if [ -z "$${IPKG_INSTROOT}" ]; then
	/etc/init.d/network reload
fi
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
# Remove any ip4o6 interfaces before removing the package
if [ -z "$${IPKG_INSTROOT}" ]; then
	# Find and remove ip4o6 interfaces
	for iface in $$(uci -q show network | grep "proto='ip4o6'" | cut -d. -f2 | cut -d= -f1); do
		echo "Removing ip4o6 interface: $$iface"
		uci delete network.$$iface
	done
	uci commit network
	/etc/init.d/network reload
fi
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
