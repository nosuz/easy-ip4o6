#!/bin/sh

# logger -t ip4o6 "proto_ip4o6_setup() called with config=$1"

logger -t ip4o6 "arg0: $0"
logger -t ip4o6 "arg1: $1"
logger -t ip4o6 "arg2: $2"
logger -t ip4o6 "arg3: $3"
logger -t ip4o6 "arg4: $4"

# /lib/netifd/proto/ip4o6.sh zoot setup
[ -n "$INCLUDE_ONLY" ] || {
	. /lib/functions.sh
	. /lib/netifd/netifd-proto.sh
	init_proto "$@"
}

proto_ip4o6_setup() {
	logger -t ip4o6 "setup()"
	local config="$1"

	local ipv4addr iface_id peer_ipv6addr mtu
	json_get_vars ipv4addr iface_id peer_ipv6addr mtu

	logger -t ip4o6 "peer_ipv6addr: $peer_ipv6addr"
	logger -t ip4o6 "iface_id: $iface_id"
	logger -t ip4o6 "ipv4addr: $ipv4addr"
	logger -t ip4o6 "mtu: $mtu"

	# Create device name
	local ifname="ip4o6-${config}"

	# # uplink (IPv6) interface のデバイス名を取得
	# local wan_dev
	# wan_dev="$(ubus call network.interface.${peer_iface} status | jsonfilter -e '@["l3_device"]')"

	# # 仮のトンネルデバイス作成（例: sit トンネルを使う）
	# ip tunnel add "${ifname}" mode sit remote "${relay_server}" local "$(ip -6 addr show dev ${wan_dev} | grep -oP 'inet6 \K[^/]+')" ttl "${ttl:-64}" || true
	# ip link set "${ifname}" up

	# # IPv4 アドレスを設定
	# ip addr add "${ipv4addr}/32" dev "${ifname}"

	# Set MTU if specified
	[ -n "$mtu" ] && ip link set dev "${ifname}" mtu "$mtu"

	proto_init_update "$ifname" 1
	proto_send_update "$config"
}

proto_ip4o6_teardown() {
	logger -t ip4o6 "teardown()"
	local config="$1"
	local ifname="ip4o6-${config}"

	ip link delete "$ifname" || true
}

proto_ip4o6_init_config() {
	logger -t ip4o6 "init_config()"
	# cat /etc/config/network
	# /etc/init.d/network restart
	proto_config_add_string "peer_ipv6addr"
	proto_config_add_string "iface_id"
	proto_config_add_string "ipv4addr"
	proto_config_add_string "mtu"
	proto_config_add_string "isp"

	proto_config_add_optional "iface_id"
	proto_config_add_optional "mtu"

	proto_no_device=1
	proto_shell_init=1

	# mandatory to call setup()
	available=1
}

[ -n "$INCLUDE_ONLY" ] || {
	logger -t ip4o6 "add_protocol"
	add_protocol ip4o6
}
