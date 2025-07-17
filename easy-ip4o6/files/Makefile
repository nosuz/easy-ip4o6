# Makefile for installing ip4o6 protocol support files

LJS_SRC := ip4o6.js
LJS_DST := /www/luci-static/resources/protocol/

SH_SRC := ip4o6.sh
SH_DST := /lib/netifd/proto/

HTP_SRC := 99-ip4o6-control
HTP_DST := /etc/hotplug.d/iface/


.PHONY: all install remove clean

all:
	@echo "Use 'make install' to copy files."

install:
	@echo "Installing protocol files..."
	install -d $(LJS_DST)
	install -m 0644 $(LJS_SRC) $(LJS_DST)
	install -d $(SH_DST)
	install -m 0755 $(SH_SRC) $(SH_DST)
	install -d $(HTP_DST)
	install -m 0644 $(HTP_SRC) $(HTP_DST)
	rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
	@echo "Done."
	@echo "Reboot is required at the first installation."

remove:
	@echo "Removing protocol files..."
	for iface in $$(uci -q show network | grep "proto='ip4o6'" | cut -d. -f2 | cut -d= -f1); do \
		echo "Removing ip4o6 interface: $$iface"; \
		uci delete network.$$iface; \
	done; \
	uci commit network; \
	/etc/init.d/network reload
	@echo "Wait 60 sec."
	sleep 60

	rm $(LJS_DST)/$(LJS_SRC)
	rm $(SH_DST)/$(SH_SRC)
	rm  $(HTP_DST)/$(HTP_SRC)
	@echo "Done."

clean:
	@echo "Nothing to clean."
