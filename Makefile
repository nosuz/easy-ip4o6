include $(TOPDIR)/rules.mk

PKG_NAME:=easy-ip4o6
PKG_VERSION:=0.0
PKG_RELEASE:=1

PKG_LICENSE:=MIT
PKG_MAINTAINER:=Your Name <you@example.com>

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/luci.mk

define Package/$(PKG_NAME)
  SECTION:=net
  CATEGORY:=Network
  TITLE:=Easy IPv4 over IPv6 protocol support for LuCI
  DEPENDS:=+luci +netifd +kmod-ip6-tunnel
endef

define Package/$(PKG_NAME)/install
	$(INSTALL_DIR) $(1)/www/luci-static/resources/protocol
	$(INSTALL_DATA) ./files/ip4o6.js \
		$(1)/www/luci-static/resources/protocol/ip4o6.js

	$(INSTALL_DIR) $(1)/lib/netifd/proto
	$(INSTALL_BIN) ./files/ip4o6.sh \
		$(1)/lib/netifd/proto/ip4o6.sh
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
