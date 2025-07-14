# Makefile for installing ip4o6 protocol support files

LJS_SRC := ip4o6.js
LJS_DST := /www/luci-static/resources/protocol/

SH_SRC := ip4o6.sh
SH_DST := /lib/netifd/proto/

.PHONY: all install clean

all:
	@echo "Use 'make install' to copy files."

install:
	@echo "Installing protocol files..."
	install -d $(LJS_DST)
	install -m 0644 $(LJS_SRC) $(LJS_DST)
	install -d $(SH_DST)
	install -m 0755 $(SH_SRC) $(SH_DST)
	rm -rf /tmp/luci-indexcache /tmp/luci-modulecache
	@echo "Done."

clean:
	@echo "Nothing to clean."
