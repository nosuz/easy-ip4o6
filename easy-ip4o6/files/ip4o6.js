'use strict';
'require form';
'require network';
'require ui';

network.registerErrorCode('MISSING_PEER_IPV6ADDRESS', _('Missing peer IPv6 address'));
network.registerErrorCode('MISSING_FIXED_IPV4ADDRESS', _('Missing fixed local IPv4 address'));

network.registerPatternVirtual(/^ip4o6-.+$/);

return network.registerProtocol('ip4o6', {
    getI18n: function() {
        return _('Easy IPv4 over IPv6 (ip4o6)');
    },

    getIfname: function() {
        return this._ubus('l3_device') || 'ip4o6-' + this.sid;
    },

    isVirtual: function() {
        return true;
    },

    isFloating: function() {
        return true;
    },

    getDevices: function() {
        return null;
    },

    containsDevice: function(ifname) {
        return (ifname === this.getIfname());
    },

    renderFormOptions: function(s) {
        // Hide Advanced Settings and DHCP tabs
        setTimeout(() => {
            let style = document.getElementById('ip4o6-hide-tabs');
            if (!style) {
                style = document.createElement('style');
                style.id = 'ip4o6-hide-tabs';
                style.innerHTML = `
                    li[data-tab="advanced"] { display: none !important; }
                    li.cbi-tab-disabled[data-tab="advanced"] { display: none !important; }
                    li[data-tab="dhcp"] { display: none !important; }
                    li.cbi-tab-disabled[data-tab="dhcp"] { display: none !important; }
                `;
                document.head.appendChild(style);
            }

            // Direct DOM manipulation as fallback for Advanced Settings
            const advancedTab = document.querySelector('li[data-tab="advanced"]');
            if (advancedTab) {
                advancedTab.style.display = 'none';
                console.log('Advanced Settings tab hidden successfully');
            }

            // Direct DOM manipulation as fallback for DHCP
            const dhcpTab = document.querySelector('li[data-tab="dhcp"]');
            if (dhcpTab) {
                dhcpTab.style.display = 'none';
                console.log('DHCP tab hidden successfully');
            }
        }, 0);

        let o;

        let ispOpt = s.taboption('general', form.ListValue, "isp", _('Tunneling Service'), _('Select your ISP tunneling service. "Other" will not work for now.'));
        ispOpt.default = "interlink";
        ispOpt.value("interlink", _("ZOOT NATIVE"));
        ispOpt.value("other", _("Other"));

        o = s.taboption('general', form.Value, 'peer_ipv6addr', _('Peer IPv6 Address'), _('IPv6 address on the other end of IPIP tunnel.'));
        o.datatype = 'ip6addr';
        o.optional = false;
        o.rmempty = false;

        // For ZOOT NATIVE
        let ifaceOptInterlink = s.taboption('general', form.Value, 'iface_id_interlink', _('Local IPv6 Interface'), _('Interface ID for the local end of IPIP tunnel. The local IPv6 address is not required.'));
        ifaceOptInterlink.optional = true;
        ifaceOptInterlink.placeholder = "::feed";
        ifaceOptInterlink.depends('isp', 'interlink');
        ifaceOptInterlink.cfgvalue = function(section_id) {
            return this.map.data.get(this.map.config, section_id, 'iface_id');
        };
        ifaceOptInterlink.write = function(section_id, value) {
            return this.map.data.set(this.map.config, section_id, 'iface_id', value);
        };

        // For Other ISP
        let ifaceOptOther = s.taboption('general', form.Value, 'iface_id_other', _('Local IPv6 Interface'), _('Interface ID for the local end of IPIP tunnel. The local IPv6 address is not required.'));
        ifaceOptOther.optional = true;
        ifaceOptOther.placeholder = "::1";
        ifaceOptOther.depends('isp', 'other');
        ifaceOptOther.cfgvalue = function(section_id) {
            return this.map.data.get(this.map.config, section_id, 'iface_id');
        };
        ifaceOptOther.write = function(section_id, value) {
            return this.map.data.set(this.map.config, section_id, 'iface_id', value);
        };

        o = s.taboption('general', form.Value, 'ipv4addr', _('Fixed global IPv4 Address'), _('Your ISP will provide a global IPv4 address.'));
        o.datatype = 'ip4addr';
        o.optional = false;
        o.rmempty = false;

        o = s.taboption('general', form.Value, 'mtu', _('MTU'), _('Largest data size on IPIP tunnel. Reduce the size if not work well.'));
        o.datatype = 'uinteger';
        o.placeholder = '1452';
        o.optional = true;
    }
});
