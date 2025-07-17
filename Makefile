.PHONY: all build clean

all: build

build:
	(rm *.ipk || true) && \
	cd openwrt && \
	cp -r ../easy-ip4o6 package && \
	make menuconfig && \
	make package/easy-ip4o6/clean && \
	make package/easy-ip4o6/compile -j$$(nproc) && \
	# make package/easy-ip4o6/compile -j1 V=s && \
	cp $$(find bin/packages -name '*.ipk' -print | grep easy-ip4o6) ..

clean:
	cd openwrt && \
	make package/easy-ip4o6/clean
