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

# Function to get WAN interface name from device
get_wan_interface_name() {
    local wan_dev="$1"
    local wan_interface=""

    # Get interface name corresponding to WAN device from UCI configuration
    for iface in $(uci -q show network | grep "^network\." | grep "\.ifname=" | cut -d. -f2 | cut -d= -f1); do
        local ifname=$(uci -q get network.$iface.ifname)
        if [ "$ifname" = "$wan_dev" ]; then
            wan_interface="$iface"
            break
        fi
    done

    # Use default value if not found
    if [ -z "$wan_interface" ]; then
        case "$wan_dev" in
            *eth*|*wan*)
                wan_interface="wan"
                ;;
            *)
                wan_interface="wan6"
                ;;
        esac
    fi

    echo "$wan_interface"
}

# Function to get tunnel local IPv6 address
get_tunnel_local_ipv6() {
    local iface_id="$1"
    local isp="$2"

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

    # Get WAN interface and IPv6 address (RA-assigned, not tunnel-specific)
    local wan_dev="$(ip -6 route | grep '^default' | sed -n 's/.* dev \([^ ]\+\).*/\1/p' | head -n1)"
    if [ -z "$wan_dev" ]; then
        echo ""
        return 1
    fi

    # Get RA-assigned IPv6 address instead of any global address
    local ra_ipv6="$(get_ra_ipv6_addr "$wan_dev")"
    local ipv6_addr="${ra_ipv6%%/*}"

    if [ -z "$ipv6_addr" ]; then
        echo ""
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

# Function to get RA-assigned IPv6 address (not tunnel-specific)
get_ra_ipv6_addr() {
    local wan_dev="$1"
    if [ -z "$wan_dev" ]; then
        return 1
    fi

    # Get all global IPv6 addresses and filter out tunnel-specific ones
    # RA addresses are typically dynamic and have different characteristics
    local ra_ipv6=""

    # Try to get RA address by checking for dynamic flag or avoiding known tunnel addresses
    # This gets the first non-tunnel global IPv6 address
    ra_ipv6="$(ip -6 addr show dev "$wan_dev" | awk '
        /inet6 [0-9a-f:]+\/[0-9]+ scope global/ {
            addr = $2;
            # Skip if this looks like a tunnel address (manually added /128)
            if (index(addr, "/128") == 0) {
                print addr;
                exit;
            }
        }')"

    echo "$ra_ipv6"
}

# Function to check if WAN has RA-assigned IPv6 address
check_wan_ra_ipv6() {
    local wan_dev="$1"
    local ra_addr="$(get_ra_ipv6_addr "$wan_dev")"
    [ -n "$ra_addr" ]
}

# Function to check if monitoring script is already running
is_monitoring_running() {
    local config="$1"
    local pidfile="/var/run/ip4o6_monitor_${config}.pid"

    if [ -f "$pidfile" ]; then
        local pid=$(cat "$pidfile")
        if kill -0 "$pid" 2>/dev/null; then
            return 0  # Running
        else
            # PID file exists but process is dead, clean up
            rm -f "$pidfile"
        fi
    fi
    return 1  # Not running
}

# Function to update monitoring script's tracked address
update_monitoring_address() {
    local config="$1"
    local new_address="$2"
    local control_file="/var/run/ip4o6_monitor_${config}.control"

    echo "UPDATE_ADDRESS:$new_address" > "$control_file"
    logger -t ip4o6 "Updated monitoring address for $config to: $new_address"
}

# Function to start monitoring script (修正版)
start_monitoring() {
    local config="$1"
    local wan_dev="$2"
    local monitor_file="/tmp/ip4o6_monitor_${config}.sh"

    # Check if monitoring is already running
    if is_monitoring_running "$config"; then
        logger -t ip4o6 "Monitoring already running for $config, updating address"
        local current_ra_addr="$(get_ra_ipv6_addr "$wan_dev")"
        update_monitoring_address "$config" "$current_ra_addr"
        return 0
    fi

    # Get initial RA IPv6 address to monitor
    local initial_ra_addr="$(get_ra_ipv6_addr "$wan_dev")"

    # Create monitoring script (修正版)
    cat > "$monitor_file" << EOF
#!/bin/sh
CONFIG="$config"
WAN_DEV="$wan_dev"
PIDFILE="/var/run/ip4o6_monitor_\${CONFIG}.pid"
CONTROL_FILE="/var/run/ip4o6_monitor_\${CONFIG}.control"
CURRENT_RA_ADDR="$initial_ra_addr"
INTERFACE_DOWN=0

# Save PID
echo \$\$ > "\$PIDFILE"

logger -t ip4o6 "Starting persistent monitoring for \$CONFIG on \$WAN_DEV (initial RA addr: \$CURRENT_RA_ADDR)"

# Function to get RA-assigned IPv6 address (not tunnel-specific)
get_ra_ipv6_addr() {
    local wan_dev="\$1"
    if [ -z "\$wan_dev" ]; then
        return 1
    fi

    # Get all global IPv6 addresses and filter out tunnel-specific ones
    # RA addresses are typically dynamic and have different characteristics
    local ra_ipv6=""

    # Try to get RA address by checking for dynamic flag or avoiding known tunnel addresses
    # This gets the first non-tunnel global IPv6 address
    ra_ipv6="\$(ip -6 addr show dev "\$wan_dev" | awk '
        /inet6 [0-9a-f:]+\/[0-9]+ scope global/ {
            addr = \$2;
            # Skip if this looks like a tunnel address (manually added /128)
            if (index(addr, "/128") == 0) {
                print addr;
                exit;
            }
        }')"

    echo "\$ra_ipv6"
}

# Function to check for control commands
check_control_commands() {
    if [ -f "\$CONTROL_FILE" ]; then
        local cmd=\$(cat "\$CONTROL_FILE")
        rm -f "\$CONTROL_FILE"

        case "\$cmd" in
            UPDATE_ADDRESS:*)
                local new_addr="\${cmd#UPDATE_ADDRESS:}"
                logger -t ip4o6 "Control command: updating tracked address to \$new_addr"
                CURRENT_RA_ADDR="\$new_addr"
                # Reset interface down flag when address is updated
                INTERFACE_DOWN=0
                return 0
                ;;
            STOP)
                logger -t ip4o6 "Control command: stopping monitoring"
                return 1
                ;;
        esac
    fi
    return 0
}

# Main monitoring loop (修正版)
while true; do
    # Check for control commands
    if ! check_control_commands; then
        break
    fi

    # Check if interface still exists (but don't stop monitoring)
    if ! ip link show dev "\$WAN_DEV" >/dev/null 2>&1; then
        logger -t ip4o6 "WAN device \$WAN_DEV disappeared, waiting for recovery..."
        sleep 30
        continue
    fi

    # Get current RA IPv6 address
    current_ra_addr="\$(get_ra_ipv6_addr "\$WAN_DEV")"

    # Check if RA address changed or disappeared
    if [ -z "\$current_ra_addr" ]; then
        # IPv6 address is lost
        if [ \$INTERFACE_DOWN -eq 0 ]; then
            # First time detecting address loss - bring interface down once
            logger -t ip4o6 "RA IPv6 address lost on \$WAN_DEV, bringing interface down"
            ifdown "\$CONFIG" 2>/dev/null
            INTERFACE_DOWN=1
            CURRENT_RA_ADDR=""
        else
            # Interface is already down, just monitor for recovery
            logger -t ip4o6 "RA IPv6 address still absent on \$WAN_DEV, waiting for recovery..."
        fi
    elif [ \$INTERFACE_DOWN -eq 1 ]; then
        # Interface was down but IPv6 address is now available - bring it back up
        logger -t ip4o6 "RA IPv6 address recovered on \$WAN_DEV (\$current_ra_addr), bringing interface up"
        CURRENT_RA_ADDR="\$current_ra_addr"
        INTERFACE_DOWN=0
        ifup "\$CONFIG" 2>/dev/null
    elif [ "\$current_ra_addr" != "\$CURRENT_RA_ADDR" ]; then
        # Address changed while interface was up
        logger -t ip4o6 "RA IPv6 address changed on \$WAN_DEV (\$CURRENT_RA_ADDR -> \$current_ra_addr), restarting interface"
        CURRENT_RA_ADDR="\$current_ra_addr"
        ifdown "\$CONFIG" 2>/dev/null
        sleep 5
        ifup "\$CONFIG" 2>/dev/null
    fi

    sleep 30
done

# Clean up PID file
rm -f "\$PIDFILE"
rm -f "\$CONTROL_FILE"
logger -t ip4o6 "Monitoring stopped for \$CONFIG"
EOF

    chmod +x "$monitor_file"

    # Start monitoring in background
    "$monitor_file" &

    logger -t ip4o6 "Started persistent monitoring script for $config (PID: $!) - monitoring RA addr: $initial_ra_addr"
}

# Function to stop monitoring script
stop_monitoring() {
    local config="$1"
    local pidfile="/var/run/ip4o6_monitor_${config}.pid"
    local control_file="/var/run/ip4o6_monitor_${config}.control"
    local monitor_file="/tmp/ip4o6_monitor_${config}.sh"

    # Send stop command via control file
    echo "STOP" > "$control_file"

    # Give it a moment to process the command
    sleep 2

    # If still running, force kill
    if [ -f "$pidfile" ]; then
        local pid=$(cat "$pidfile")
        if kill -0 "$pid" 2>/dev/null; then
            logger -t ip4o6 "Force stopping monitoring for $config (PID: $pid)"
            kill "$pid" 2>/dev/null
        fi
        rm -f "$pidfile"
    fi

    rm -f "$control_file"
    rm -f "$monitor_file"
    logger -t ip4o6 "Monitoring stopped for $config"
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
		proto_notify_error "$config" "MISSING_PEER_IPV6ADDRESS"
		proto_block_restart "$config"
		return
	}

	[ -z "$ipv4addr" ] && {
		proto_notify_error "$config" "MISSING_FIXED_IPV4ADDRESS"
		proto_block_restart "$config"
		return
	}

	# Create device name
	local ifname="ip4o6-${config}"
	logger -t ip4o6 "ifname: $ifname"

	# 1. Get WAN interface IPv6 address
	wan_dev="$(ip -6 route | grep '^default' | sed -n 's/.* dev \([^ ]\+\).*/\1/p' | head -n1)"
	logger -t ip4o6 "wan_dev: $wan_dev"

	# Return error if WAN interface doesn't exist
	if [ -z "$wan_dev" ]; then
		logger -t ip4o6 "ERROR: No WAN interface found"
		proto_notify_error "$config" "NO_WAN_INTERFACE"
		proto_block_restart "$config"
		return
	fi

	# Check if WAN has RA-assigned IPv6 address
	if ! check_wan_ra_ipv6 "$wan_dev"; then
		logger -t ip4o6 "ERROR: No RA-assigned IPv6 address found on WAN interface"
		proto_notify_error "$config" "NO_RA_IPV6"
		proto_block_restart "$config"
		return
	fi

	# Get WAN interface name
	local wan_interface_name=$(get_wan_interface_name "$wan_dev")
	logger -t ip4o6 "wan_interface_name: $wan_interface_name"

	# Set dependency on WAN interface
	local current_depends=$(uci -q get network.${config}.depends)
	if [ "$current_depends" != "$wan_interface_name" ]; then
		logger -t ip4o6 "Setting dependency on interface: $wan_interface_name"
		uci set network.${config}.depends="$wan_interface_name"
		uci commit network
	fi

	# Get tunnel local IPv6 address
	tunnel_local_ipv6=$(get_tunnel_local_ipv6 "$iface_id" "$isp")
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

	# Start monitoring for global IPv6 address (修正版)
	start_monitoring "$config" "$wan_dev"

	logger -t ip4o6 "IPv4 over IPv6 tunnel setup completed with dependency on $wan_interface_name"
}

proto_ip4o6_teardown() {
	logger -t ip4o6 "teardown()"
	local config="$1"
	local ifname="ip4o6-${config}"

	logger -t ip4o6 "Tearing down tunnel interface: $ifname"

	# Note: We don't stop monitoring here to keep it persistent
	# stop_monitoring "$config"

	# Get the same parameters to reconstruct tunnel_local_ipv6
	local ipv4addr iface_id peer_ipv6addr mtu isp
	json_get_vars ipv4addr iface_id peer_ipv6addr mtu isp

	# Get WAN interface and reconstruct tunnel_local_ipv6
	wan_dev="$(ip -6 route | grep '^default' | sed -n 's/.* dev \([^ ]\+\).*/\1/p' | head -n1)"
	if [ -n "$wan_dev" ]; then
		# Get tunnel local IPv6 address
		tunnel_local_ipv6=$(get_tunnel_local_ipv6 "$iface_id" "$isp")

		if [ -n "$tunnel_local_ipv6" ]; then
			logger -t ip4o6 "Removing tunnel local IPv6: $tunnel_local_ipv6 from $wan_dev"
			# Remove the tunnel local IPv6 address from WAN device
			ip -6 addr del "$tunnel_local_ipv6/128" dev "$wan_dev" 2>/dev/null || true
		fi
	fi

	# send error message
	proto_notify_error "$config" "NO_IPIP_TUNNEL"

	# Remove tunnel interface (netifd will handle the cleanup)
	proto_init_update "$ifname" 0
	# DEBUG: make permission error.
	proto_send_update "$config"

	logger -t ip4o6 "IPv4 over IPv6 tunnel teardown completed (monitoring continues)"
}

proto_ip4o6_init_config() {
	logger -t ip4o6 "init_config()"
	proto_config_add_string "peer_ipv6addr"
	proto_config_add_string "iface_id"
	proto_config_add_string "ipv4addr"
	proto_config_add_string "mtu"
	proto_config_add_string "isp"
	proto_config_add_string "depends"

	proto_config_add_optional "iface_id"
	proto_config_add_optional "mtu"
	proto_config_add_optional "depends"

	proto_no_device=1
	proto_shell_init=1

	# mandatory to call setup()
	available=1
}

[ -n "$INCLUDE_ONLY" ] || {
	logger -t ip4o6 "add_protocol"
	add_protocol ip4o6
}
