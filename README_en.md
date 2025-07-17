# Easy-IP4o6

Easy-IP4o6 is a package that provides an interface for connecting with fixed IPv4 addresses using IPIP (IPv4 over IPv6), transferring IPv4 traffic over IPv6 networks, such as Interlink's [ZOOT NATIVE](https://www.interlink.or.jp/service/zootnative/). While there are already several packages that provide IPIP tunnels, this package is characterized by having fewer configuration items and being easy to use.

The connections of other companies' IPIP may also be configurable, but the default settings are unknown. It would be helpful if you could provide the default values.

## Features

- Creating fixed IPv4 interfaces using IPIP (IPv4 over IPv6) method
- Interface management according to WAN line status

## Required Dependencies

- `luci` - Web-based configuration functionality
- `netifd` - OpenWrt network management daemon
- `kmod-ip6-tunnel` - IPv6 tunnel kernel module

All of these are packages installed by default, so no additional packages are required.

However, for manual installation, the following packages must be pre-installed:

- `openssh-sftp-server` - For receiving files via `scp`
- `make` - For automatic execution of a series of commands

## Installation Methods

There are two ways to install `easy-ip4o6`: using a package or manual installation.

### Package Installation

1. Download the package from [Releases](https://github.com/nosuz/easy-ip4o6/releases).
2. Select Software from the System menu in the web management interface.
3. (Optional) Press the `Update Lists...` button to update the package list.
4. Press the `Upload Package...` button to upload and install the downloaded package.
5. Select Reboot from the System menu, and reboot the router.

#### Manual Package Installation

```bash
# Update package list to install dependency packages (optional)
opkg update

# Install the package
opkg install easy-ip4o6_*_all.ipk
reboot
```

### Manual Installation

1. All files required for installation are in the `easy-ip4o6/files` directory. Copy the entire `files` directory to the OpenWrt machine using `scp` or similar.

2. Log in to the OpenWrt machine using `ssh` or `slogin`, navigate to the copied `files` directory, and run `make install` to install the files. If the installed configuration is not recognized, restart the system.

```bash
# copy files. `openssh-sftp-server` package is required on OpenWrt machine.
scp -r easy-ip4o6/files root@<OpenWrt Address>:
```

```bash
# install files. `make` package is required on OpenWrt machine.
cd files
make install
# `make remove` to uninstall files.
reboot
```

To remove manually installed `easy-ip4o6`, run `make remove`.

## Usage

1. Select Interfaces from the Network menu in the web management interface.
2. Press the `Add new interface...` button and enter the interface name. For Protocol, select `Easy IPv4 over IPv6 (ip4o6)`.
3. Select your ISP's service name from the Tunneling Service. For services other than Interlink's ZOOT NATIVE, please select `Other`.
4. In Peer IPv6 Address, enter the IPv6 address of the terminating device (ISP side) provided by your ISP.
5. In Fixed global IPv4 Address, enter the fixed IPv4 address assigned by your ISP.
6. If necessary, enter values for Local IPv6 Interface (lower 64 bits of IPv6) and MTU.
7. Select an appropriate `firewall-zone` (e.g., `wan`) from `Firewall Settings`.
8. Press the `Save & Apply` button to save the configuration and restart the network.

The function to notify the update server of the local IPv6 address has been omitted in `easy-ip4o6`. Although it is explained that notifying the IPv6 address shortens reconnection time, I have never felt the need for it.

### Troubleshooting

- If `Easy IPv4 over IPv6 (ip4o6)` does not appear in Protocol, try restarting.
- If some sites are accessible while others are not, try reducing the MTU value.

## File Structure

```
Makefile                          # Makefile for package creation
easy-ip4o6/
├── Makefile                   # Makefile for OpenWrt build system
└── files/
    ├── Makefile               # Makefile for manual installation
    ├── ip4o6.js               # LuCI handler
    ├── ip4o6.sh               # netifd protocol handler
    └── 99-ip4o6-control       # Hotplug event handler
```

## Development Environment Setup

Package building uses the [Docker Image](https://hub.docker.com/r/openwrt/sdk) provided by OpenWrt.

Reference: [GitHub - openwrt/docker: Docker containers of the ImageBuilder and SDK](https://github.com/openwrt/docker)

### Using Dev Container

This project supports a development environment using OpenWrt's Docker container as a Dev Container. The steps to start the Dev Container are as follows:

1. Open this project in VSCode.
2. Open the command palette with `Ctrl + Shift + P`.
3. Select `Dev Containers: Rebuild and Reopen in Container`. **The first startup may take up to 30 minutes** as it fetches and installs the latest feeds.

#### Troubleshooting

If you encounter a `permission error` due to user ID issues, run `.devcontainer/generate_env.py` or `.devcontainer/generate_env.sh` to set your user ID and group ID in `.devcontainer/.env`, then rebuild the container.

## Package Building

```bash
# Run inside Dev Container
# Note: On first startup, the following commands will run and may take up to 30 minutes to complete
# if [ -d openwrt ]; then cd openwrt; else mkdir openwrt && cd openwrt && /builder/setup.sh; fi && ./scripts/feeds update -a && ./scripts/feeds install -a

# Create package management
# This container builds packages for x86_64
make build
```

When you run `make build`, `make menuconfig` is executed internally. Select (M mark) the `easy-ip4o6` package from Network so that it will be created. The build process will then start automatically.

The created package will be copied to the top directory.

## License

GPL-2.0

## Maintainer

[@nosuz123](https://x.com/nosuz123) on X

## Contributing

Bug reports and feature requests are accepted through GitHub Issues. Pull requests are also welcome.
