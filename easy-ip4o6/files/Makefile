# Makefile for installing ip4o6 protocol support files

LJS_SRC := ip4o6.js
LJS_DST := /www/luci-static/resources/protocol/

SH_SRC := ip4o6.sh
SH_DST := /lib/netifd/proto/


.PHONY: all install remove clean

all:
	@echo "Use 'make install' to copy files."

install:
	@echo "Installing protocol files..."
	install -d $(LJS_DST)
	install -m 0644 $(LJS_SRC) $(LJS_DST)
	install -d $(SH_DST)
	install -m 0755 $(SH_SRC) $(SH_DST)
	rm -rf /tmp/luci-*
	@echo "Reloading network configurations."
	/etc/init.d/network reload
	@echo "Done."

remove:
	@echo "Removing protocol files..."
	for iface in $$(uci -q show network | grep "proto='ip4o6'" | cut -d. -f2 | cut -d= -f1); do \
		echo "Removing ip4o6 interface: $$iface"; \
		uci delete network.$$iface; \
	done; \
	uci commit network;

	rm $(LJS_DST)/$(LJS_SRC)
	rm $(SH_DST)/$(SH_SRC)

	@echo "Reloading network configurations."
	/etc/init.d/network reload
	@echo "Done."

clean:
	@echo "Nothing to clean."
