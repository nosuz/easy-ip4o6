'use strict';
'require form';
'require network';
'require ui';

network.registerErrorCode('MISSING_PEER_IPV6ADDRESS', _('Missing peer IPv6 address'));
network.registerErrorCode('MISSING_FIXED_IPV4ADDRESS', _('Missing fixed local IPv4 address'));
network.registerErrorCode('NO_IPIP_TUNNEL', _('IPv4 over IPv6 tunnel was stopped.'));


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
        let o;

        let ispOpt = s.taboption('general', form.ListValue, "isp", _('Tunneling Service'), _('Select your ISP tunneling service. "Other" will not work for now.'));
        ispOpt.default = "interlink";
        ispOpt.value("interlink", _("ZOOT NATIVE"));
        ispOpt.value("other", _("Other"));

        o = s.taboption('general', form.Value, 'peer_ipv6addr', _('Peer IPv6 Address'), _('IPv6 address on the other end of IPIP tunnel.'));
        o.datatype = 'ip6addr';
        o.optional = false;
        o.rmempty = false;

        // ZOOT NATIVE用
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

        // Other ISP用
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
