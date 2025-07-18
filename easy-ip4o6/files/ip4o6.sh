#!/bin/sh
. /lib/functions/network.sh

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

# Function to get tunnel state file path
get_tunnel_state_file() {
    local config="$1"
    echo "/tmp/ip4o6_${config}.state"
}

# Function to save tunnel state
save_tunnel_state() {
    local config="$1"
    local tunnel_local_ipv6="$2"
    local wan_interface="$3"
    local wan_dev="$4"
    local state_file=$(get_tunnel_state_file "$config")

    cat > "$state_file" << EOF
tunnel_local_ipv6=$tunnel_local_ipv6
wan_interface=$wan_interface
wan_dev=$wan_dev
EOF
    logger -t ip4o6 "Saved tunnel state to $state_file: local=$tunnel_local_ipv6, wan_interface=$wan_interface, wan_dev=$wan_dev"
}

# Function to load tunnel state
load_tunnel_state() {
    local config="$1"
    local state_file=$(get_tunnel_state_file "$config")

    if [ -f "$state_file" ]; then
        . "$state_file"
        logger -t ip4o6 "Loaded tunnel state from $state_file: local=$tunnel_local_ipv6, wan_interface=$wan_interface, wan_dev=$wan_dev"
        return 0
    else
        logger -t ip4o6 "No tunnel state file found: $state_file"
        return 1
    fi
}

# Function to remove tunnel state
remove_tunnel_state() {
    local config="$1"
    local state_file=$(get_tunnel_state_file "$config")

    if [ -f "$state_file" ]; then
        rm -f "$state_file"
        logger -t ip4o6 "Removed tunnel state file: $state_file"
    fi
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
		logger -t ip4o6 "Error: No IPv6 address provided to expand_ipv6()"
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
		logger -t ip4o6 "Error: No IPv6 address provided to compress_ipv6()"
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

# Function to get tunnel local IPv6 address using network.sh functions
get_tunnel_local_ipv6() {
    local iface_id="$1"
    local isp="$2"
    local wan_interface="$3"

    # Set default iface_id if not provided
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

    # Get WAN interface IPv6 address using network.sh functions
    local wan_dev=""
    local ipv6_addr=""

    # Get device name for the interface
    network_get_device wan_dev "$wan_interface"
    if [ -z "$wan_dev" ]; then
        logger -t ip4o6 "Failed to get device for interface: $wan_interface"
        return 1
    fi

    # Get IPv6 address using network.sh function
    if ! network_get_ipaddr6 ipv6_addr "$wan_interface"; then
        logger -t ip4o6 "Failed to get IPv6 address for interface: $wan_interface"
        return 1
    fi

    # Remove prefix length if present
    ipv6_addr="${ipv6_addr%%/*}"

    if [ -z "$ipv6_addr" ]; then
        logger -t ip4o6 "No IPv6 address found for interface: $wan_interface"
        return 1
    fi

    # Expand IPv6 address and get prefix
    local expanded_ipv6=$(expand_ipv6 "$ipv6_addr")
    local prefix64=$(echo "$expanded_ipv6" | cut -d: -f1-4)

    # Normalize iface_id to represent a suffix for ::xxxx
    local colon_count=$(echo "$iface_id" | awk -F':' '{print NF}')
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
    local local_ipv6=$(expand_ipv6 "${prefix64}:${suffix}")
    local tunnel_local_ipv6=$(compress_ipv6 "$local_ipv6")

    echo "$tunnel_local_ipv6"
}

# Function to check if interface has IPv6 address using network.sh functions
check_wan_ipv6() {
    local wan_interface="$1"
    local ipv6_addr=""

    # Check if interface is up
    if ! network_is_up "$wan_interface"; then
        logger -t ip4o6 "Interface $wan_interface is not up"
        return 1
    fi

    # Try to get IPv6 address
    if network_get_ipaddr6 ipv6_addr "$wan_interface"; then
        [ -n "$ipv6_addr" ] && return 0
    fi

    logger -t ip4o6 "No IPv6 address found for interface: $wan_interface"
    return 1
}

# Function to determine WAN interface - simplified to check only wan6 and wan
get_wan_interface() {
    local wan_interface=""

    # Check wan6 first (preferred for IPv6 tunnel)
    if network_is_up "wan6" && check_wan_ipv6 "wan6"; then
        wan_interface="wan6"
    # Fallback to wan
    elif network_is_up "wan" && check_wan_ipv6 "wan"; then
        wan_interface="wan"
    fi

    echo "$wan_interface"
}

proto_ip4o6_setup() {
	logger -t ip4o6 "setup()"
	local config="$1"

	local ipv4addr iface_id peer_ipv6addr mtu isp
	json_get_vars ipv4addr iface_id peer_ipv6addr mtu isp

	logger -t ip4o6 "peer_ipv6addr: $peer_ipv6addr"
	logger -t ip4o6 "iface_id: $iface_id"
	logger -t ip4o6 "ipv4addr: $ipv4addr"
	logger -t ip4o6 "mtu: $mtu"
	logger -t ip4o6 "isp: $isp"

	[ -z "$peer_ipv6addr" ] && {
        logger -t ip4o6 "No pear IPv6 address, skipping setup."
		proto_notify_error "$config" "MISSING_PEER_IPV6ADDRESS"
		proto_block_restart "$config"
		return
	}

	[ -z "$ipv4addr" ] && {
        logger -t ip4o6 "No fixed IPv4 address, skipping setup."
		proto_notify_error "$config" "MISSING_FIXED_IPV4ADDRESS"
		proto_block_restart "$config"
		return
	}

	# Create device name
	local ifname="ip4o6-${config}"
	logger -t ip4o6 "ifname: $ifname"

	# Determine WAN interface (wan6 or wan)
	local wan_interface=$(get_wan_interface)
	logger -t ip4o6 "wan_interface: $wan_interface"

	# Return error if WAN interface doesn't exist or is not up
	if [ -z "$wan_interface" ]; then
		logger -t ip4o6 "ERROR: No suitable WAN interface (wan6/wan) found with IPv6 address"
		return
	fi

	# Get WAN device name
	local wan_dev=""
	network_get_device wan_dev "$wan_interface"
	logger -t ip4o6 "wan_dev: $wan_dev"

	# Get tunnel local IPv6 address
	tunnel_local_ipv6=$(get_tunnel_local_ipv6 "$iface_id" "$isp" "$wan_interface")
	if [ -z "$tunnel_local_ipv6" ]; then
		logger -t ip4o6 "ERROR: Failed to create tunnel local IPv6 address"
		proto_notify_error "$config" "TUNNEL_LOCAL_IPV6_ERROR"
		proto_block_restart "$config"
		return
	fi
	logger -t ip4o6 "tunnel local_ipv6: $tunnel_local_ipv6"

	# Add the local IPv6 address to WAN device
	if [ -n "$wan_dev" ]; then
		ip -6 addr show dev "$wan_dev" | grep -q "$tunnel_local_ipv6/128" || \
			ip -6 addr add "$tunnel_local_ipv6/128" dev "$wan_dev"

        # Save tunnel state for teardown
        save_tunnel_state "$config" "$tunnel_local_ipv6" "$wan_interface" "$wan_dev"
	fi

	# Add dependency on WAN interface
    # use logical interface name
	proto_add_host_dependency "$config" "::" "$wan_interface"
    logger -t ip4o6 "Added dependency to $wan_interface"

	# Setup interface using netifd protocol handler
	proto_init_update "$ifname" 1

	# Set IPv4 address
	proto_add_ipv4_address "$ipv4addr" "32" "" ""

	# Set default route
	proto_add_ipv4_route "0.0.0.0" 0 "" ""

	# Add tunnel
	proto_add_tunnel
	json_add_string mode ipip6
	json_add_int mtu "${mtu:-1452}"
	json_add_int ttl "64"
	json_add_string local "$tunnel_local_ipv6"
	json_add_string remote "$peer_ipv6addr"
    # Don't add link parameter - let netifd handle it
	proto_close_tunnel

	# Send configuration
	proto_send_update "$config"

	logger -t ip4o6 "IPv4 over IPv6 tunnel setup completed with dependency on $wan_interface"
}

proto_ip4o6_teardown() {
	logger -t ip4o6 "teardown()"
	local config="$1"
	local ifname="ip4o6-${config}"

	logger -t ip4o6 "Tearing down tunnel interface: $ifname"

	# Load tunnel state from setup
	local tunnel_local_ipv6=""
	local wan_interface=""
	local wan_dev=""

	if load_tunnel_state "$config"; then
		logger -t ip4o6 "Using saved tunnel state: local=$tunnel_local_ipv6, wan_interface=$wan_interface, wan_dev=$wan_dev"

		# Remove the tunnel local IPv6 address from WAN device
		if [ -n "$tunnel_local_ipv6" ] && [ -n "$wan_dev" ]; then
			logger -t ip4o6 "Removing tunnel local IPv6: $tunnel_local_ipv6 from $wan_dev"
			ip -6 addr del "$tunnel_local_ipv6/128" dev "$wan_dev" 2>/dev/null || true
		fi

		# Remove tunnel state file
		remove_tunnel_state "$config"
	else
		logger -t ip4o6 "No saved tunnel state found"
	fi

	# Remove tunnel interface (netifd will handle the cleanup)

	logger -t ip4o6 "IPv4 over IPv6 tunnel teardown completed"
}

proto_ip4o6_init_config() {
	logger -t ip4o6 "init_config()"
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
