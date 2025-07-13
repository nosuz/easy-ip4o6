'use strict';
'require form';
'require network';
'require ui';

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

        o = s.taboption('general', form.ListValue, "isp", _('ISP'))
        o.default = "interlink"

        o.value("interlink", _("ZOOT NATIVE"))

        o = s.taboption('general', form.Value, 'peer_ipv6addr', _('Peer IPv6 Address'));
        o.datatype = 'ip6addr';
        o.optional = false;

        o = s.taboption('general', form.Value, 'iface_id', _('Local IPv6 Interface'));
        o.optional = false;

        o = s.taboption('general', form.Value, 'ipv4addr', _('Fixed Local IPv4 Address'));
        o.datatype = 'ip4addr';
        o.optional = false;

        o = s.taboption('general', form.Value, 'mtu', _('MTU'));
        o.datatype = 'uinteger';
        o.placeholder = '1480';
        o.optional = true;
    }
});
