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

# Function to expand IPv6 addresses
expand_ipv6() {
    local addr="$1"
    local expanded=""
    local left_part=""
    local right_part=""
    local missing_groups=0
    local i=0
    local left_groups=0
    local right_groups=0

    # Input validation
    if [ -z "$addr" ]; then
        echo "Error: No IPv6 address provided" >&2
        return 1
    fi

    # Remove interface specification starting with %
    addr=$(echo "$addr" | sed 's/%.*$//')

    # Handle addresses containing ::
    if echo "$addr" | grep -q "::"; then
        # Split by ::
        if [ "$addr" = "::" ]; then
            # Handle :: only case
            left_part=""
            right_part=""
        else
            # Split before and after ::
            left_part=$(echo "$addr" | sed 's/::.*//')
            right_part=$(echo "$addr" | sed 's/.*:://')
        fi

        # Process left part
        if [ -n "$left_part" ]; then
            # Count groups in left part
            left_groups=$(echo "$left_part:" | grep -o ':' | wc -l)

            # Expand each group in left part to 4 digits
            expanded=""
            IFS=':'
            for group in $left_part; do
                if [ -n "$group" ]; then
                    # Process as hexadecimal (remove leading zeros then zero-pad)
                    group=$(echo "$group" | sed 's/^0*//')
                    if [ -z "$group" ]; then
                        group="0"
                    fi
                    expanded="$expanded$(printf "%04x" "0x$group"):"
                fi
            done
            IFS=' '
            expanded=$(echo "$expanded" | sed 's/:$//')
        else
            left_groups=0
        fi

        # Process right part
        if [ -n "$right_part" ]; then
            # Count groups in right part
            right_groups=$(echo "$right_part:" | grep -o ':' | wc -l)

            # Expand each group in right part to 4 digits
            right_expanded=""
            IFS=':'
            for group in $right_part; do
                if [ -n "$group" ]; then
                    # Process as hexadecimal (remove leading zeros then zero-pad)
                    group=$(echo "$group" | sed 's/^0*//')
                    if [ -z "$group" ]; then
                        group="0"
                    fi
                    right_expanded="$right_expanded$(printf "%04x" "0x$group"):"
                fi
            done
            IFS=' '
            right_expanded=$(echo "$right_expanded" | sed 's/:$//')
        else
            right_groups=0
        fi

        # Calculate number of missing 0000 groups
        missing_groups=$((8 - left_groups - right_groups))

        # Build complete address
        result=""
        if [ -n "$expanded" ]; then
            result="$expanded"
        fi

        # Add missing 0000 groups
        i=0
        while [ $i -lt $missing_groups ]; do
            if [ -n "$result" ]; then
                result="$result:0000"
            else
                result="0000"
            fi
            i=$((i + 1))
        done

        # Add right part
        if [ -n "$right_expanded" ]; then
            if [ -n "$result" ]; then
                result="$result:$right_expanded"
            else
                result="$right_expanded"
            fi
        fi

        expanded="$result"

    else
        # For addresses without ::, simply expand each group to 4 digits
        expanded=""
        IFS=':'
        for group in $addr; do
            if [ -n "$group" ]; then
                # Process as hexadecimal (remove leading zeros then zero-pad)
                group=$(echo "$group" | sed 's/^0*//')
                if [ -z "$group" ]; then
                    group="0"
                fi
                if [ -n "$expanded" ]; then
                    expanded="$expanded:$(printf "%04x" "0x$group")"
                else
                    expanded="$(printf "%04x" "0x$group")"
                fi
            fi
        done
        IFS=' '
    fi

    echo "$expanded"
}

# Function to compress IPv6 addresses
compress_ipv6() {
    local addr="$1"
    local compressed=""
    local groups=""
    local i=0
    local zero_start=-1
    local zero_len=0
    local max_zero_start=-1
    local max_zero_len=0

    # Input validation
    if [ -z "$addr" ]; then
        echo "Error: No IPv6 address provided" >&2
        return 1
    fi

    # First convert to fully expanded address
    addr=$(expand_ipv6 "$addr")

    # Convert to space-separated for array-like processing
    groups=$(echo "$addr" | sed 's/:/ /g')

    # Remove leading zeros from each group
    compressed=""
    for group in $groups; do
        # Remove leading zeros (but 0000 becomes 0)
        group=$(echo "$group" | sed 's/^0*//')
        if [ -z "$group" ]; then
            group="0"
        fi

        if [ -n "$compressed" ]; then
            compressed="$compressed:$group"
        else
            compressed="$group"
        fi
    done

    # Find the longest sequence of consecutive zeros
    # Check each group
    groups=$(echo "$compressed" | sed 's/:/ /g')
    i=0
    zero_start=-1
    zero_len=0

    for group in $groups; do
        if [ "$group" = "0" ]; then
            if [ $zero_start -eq -1 ]; then
                zero_start=$i
                zero_len=1
            else
                zero_len=$((zero_len + 1))
            fi
        else
            if [ $zero_start -ne -1 ] && [ $zero_len -gt $max_zero_len ]; then
                max_zero_start=$zero_start
                max_zero_len=$zero_len
            fi
            zero_start=-1
            zero_len=0
        fi
        i=$((i + 1))
    done

    # Handle case where zeros continue to the end
    if [ $zero_start -ne -1 ] && [ $zero_len -gt $max_zero_len ]; then
        max_zero_start=$zero_start
        max_zero_len=$zero_len
    fi

    # Replace with :: only if there are 2 or more consecutive zeros
    if [ $max_zero_len -ge 2 ]; then
        # Build the result by splitting into before and after parts
        result=""
        i=0
        before_part=""
        after_part=""

        # Build before part (groups before the consecutive zeros)
        for group in $groups; do
            if [ $i -lt $max_zero_start ]; then
                if [ -n "$before_part" ]; then
                    before_part="$before_part:$group"
                else
                    before_part="$group"
                fi
            elif [ $i -ge $((max_zero_start + max_zero_len)) ]; then
                # Build after part (groups after the consecutive zeros)
                if [ -n "$after_part" ]; then
                    after_part="$after_part:$group"
                else
                    after_part="$group"
                fi
            fi
            i=$((i + 1))
        done

        # Combine parts with ::
        if [ -n "$before_part" ] && [ -n "$after_part" ]; then
            result="$before_part::$after_part"
        elif [ -n "$before_part" ]; then
            result="$before_part::"
        elif [ -n "$after_part" ]; then
            result="::$after_part"
        else
            result="::"
        fi

        compressed="$result"
    fi

    echo "$compressed"
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

	[ -z "$peer_ipv6addr" ] && {
		proto_notify_error "$config" "MISSING_PEER_IPV6ADDRESS"
		proto_block_restart "$config"
		return
	}

	[ -z "$ipv4addr" ] && {
		proto_notify_error "$config" "MISSING_FIXED_IPV4ADDRESS"
		proto_block_restart "$config"
		return
	}

	[ -z "$iface_id" ] && {
		case "$isp" in
			interlink)
				iface_id="::feed"
				;;
			other)
				iface_id="::1"
				;;
			*)
				iface_id="::feed"
				;;
		esac
	}

	# Create device name
	local ifname="ip4o6-${config}"
	logger -t ip4o6 "ifname: $ifname"

	# 1. Get WAN interface IPv6 address
	wan_dev="$(ip -6 route | grep '^default' | sed -n 's/.* dev \([^ ]\+\).*/\1/p' | head -n1)"
	logger -t ip4o6 "wan_dev: $wan_dev"
	local global_ipv6="$(ip -6 addr show dev "$wan_dev" | awk '/inet6 [0-9a-f:]+\/[0-9]+ scope global/ { print $2; exit }')"
	ipv6_addr="${global_ipv6%%/*}"
	logger -t ip4o6 "wan ipv6_addr: $ipv6_addr"

	# 2. Expand IPv6 address
	local expanded_ipv6=$(expand_ipv6 "$ipv6_addr")
	local prefix64=$(echo "$expanded_ipv6" | cut -d: -f1-4)
	logger -t ip4o6 "prefix64: $prefix64"

	# 3. Combine with interface ID
	# Normalize iface_id to represent a suffix for ::xxxx
	colon_count=$(echo "$iface_id" | awk -F':' '{print NF}')
	case "$iface_id" in
		::*)
			;;  # already correct
		:*)
			iface_id="::${iface_id#:}"
			;;
		*:*)
			# if fewer than 4 groups, treat as a suffix needing ::
			if [ "$colon_count" -le 4 ]; then
				iface_id="::${iface_id}"
			fi
			;;
		*)
			iface_id="::${iface_id}"
			;;
	esac

	local suffix=$(expand_ipv6 "$iface_id" | cut -d: -f5-8)
	logger -t ip4o6 "suffix: $suffix"
	local_ipv6=$(expand_ipv6 "${prefix64}:${suffix}")
	logger -t ip4o6 "local_ipv6: $local_ipv6"

	# 4. Compress IPv6 address
	tunnel_local_ipv6=$(compress_ipv6 "$local_ipv6")
	logger -t ip4o6 "tunnel local_ipv6: $tunnel_local_ipv6"

	# Add the local IPv6 address to WAN device
	if [ -n "$wan_dev" ]; then
		ip -6 addr show dev "$wan_dev" | grep -q "$tunnel_local_ipv6/128" || \
			ip -6 addr add "$tunnel_local_ipv6/128" dev "$wan_dev"
	fi

	# Setup interface using netifd protocol handler
	proto_init_update "$ifname" 1

	# Set IPv4 address (point-to-point)
	proto_add_ipv4_address "$ipv4addr" "32" "" ""

	# Set default route via tunnel interface
	# proto_add_ipv4_route "0.0.0.0" 0 "" "$ifname"
	proto_add_ipv4_route "0.0.0.0" 0 "" ""

	# Create IPv4 over IPv6 tunnel
	proto_add_tunnel
	json_add_string mode ipip6
	json_add_int mtu "${mtu:-1452}"
	json_add_int ttl "64"
	json_add_string local "$tunnel_local_ipv6"
	json_add_string remote "$peer_ipv6addr"
	[ -n "$wan_dev" ] && json_add_string link "$wan_dev"
	json_add_object "data"
	json_close_object
	proto_close_tunnel

	# DNS configuration (if needed)
	# proto_add_dns_server "8.8.8.8"
	# proto_add_dns_server "8.8.4.4"

	# Apply configuration
	proto_send_update "$config"

	logger -t ip4o6 "IPv4 over IPv6 tunnel setup completed"
}

proto_ip4o6_teardown() {
	logger -t ip4o6 "teardown()"
	local config="$1"
	local ifname="ip4o6-${config}"

	logger -t ip4o6 "Tearing down tunnel interface: $ifname"

	# Get the same parameters to reconstruct tunnel_local_ipv6
	local ipv4addr iface_id peer_ipv6addr mtu
	json_get_vars ipv4addr iface_id peer_ipv6addr mtu

	[ -z "$iface_id" ] && {
		iface_id="::feed"
	}

	# Get WAN interface and reconstruct tunnel_local_ipv6
	wan_dev="$(ip -6 route | grep '^default' | sed -n 's/.* dev \([^ ]\+\).*/\1/p' | head -n1)"
	if [ -n "$wan_dev" ]; then
		local global_ipv6="$(ip -6 addr show dev "$wan_dev" | awk '/inet6 [0-9a-f:]+\/[0-9]+ scope global/ { print $2; exit }')"
		ipv6_addr="${global_ipv6%%/*}"

		if [ -n "$ipv6_addr" ]; then
			local expanded_ipv6=$(expand_ipv6 "$ipv6_addr")
			local prefix64=$(echo "$expanded_ipv6" | cut -d: -f1-4)
			local local_ipv6=$(expand_ipv6 "${prefix64}${iface_id}")
			tunnel_local_ipv6=$(compress_ipv6 "$local_ipv6")

			logger -t ip4o6 "Removing tunnel local IPv6: $tunnel_local_ipv6 from $wan_dev"
			# Remove the tunnel local IPv6 address from WAN device
			ip -6 addr del "$tunnel_local_ipv6/128" dev "$wan_dev" 2>/dev/null || true
		fi
	fi

	# Remove tunnel interface (netifd will handle the cleanup)
	proto_init_update "$ifname" 0
	proto_send_update "$config"

	logger -t ip4o6 "IPv4 over IPv6 tunnel teardown completed"
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
