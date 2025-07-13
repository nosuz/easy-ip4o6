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

        let ispOpt = s.taboption('general', form.ListValue, "isp", _('ISP'));
        ispOpt.default = "interlink";
        ispOpt.value("interlink", _("ZOOT NATIVE"));
        ispOpt.value("other", _("Other ISP"));

        o = s.taboption('general', form.Value, 'peer_ipv6addr', _('Peer IPv6 Address'));
        o.datatype = 'ip6addr';
        o.optional = false;
        o.rmempty = false;

        /*
        // 解決策1: 単一フィールドでカスタムrender使用
        let ifaceOpt = s.taboption('general', form.Value, 'iface_id', _('Local IPv6 Interface'));
        ifaceOpt.optional = true;
        ifaceOpt.placeholder = "::feed"; // デフォルト

        // カスタムrender関数でplaceholderを動的に設定
        ifaceOpt.render = function(option_index, section_id, in_table) {
            // ISPの値を取得
            const ispField = this.map.lookupOption('isp', section_id);
            if (ispField && ispField[0]) {
                const ispValue = ispField[0].formvalue(section_id) || ispField[0].default;
                this.placeholder = (ispValue === 'interlink') ? "::feed" : "::1";
            }
            return form.Value.prototype.render.call(this, option_index, section_id, in_table);
        };
        */

        // 解決策2: 別の方法 - depends()を使う場合は異なるフィールド名を使用
        // ZOOT NATIVE用
        let ifaceOptInterlink = s.taboption('general', form.Value, 'iface_id_interlink', _('Local IPv6 Interface'));
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
        let ifaceOptOther = s.taboption('general', form.Value, 'iface_id_other', _('Local IPv6 Interface'));
        ifaceOptOther.optional = true;
        ifaceOptOther.placeholder = "::1";
        ifaceOptOther.depends('isp', 'other');
        ifaceOptOther.cfgvalue = function(section_id) {
            return this.map.data.get(this.map.config, section_id, 'iface_id');
        };
        ifaceOptOther.write = function(section_id, value) {
            return this.map.data.set(this.map.config, section_id, 'iface_id', value);
        };

        o = s.taboption('general', form.Value, 'ipv4addr', _('Fixed Local IPv4 Address'));
        o.datatype = 'ip4addr';
        o.optional = false;
        o.rmempty = false;

        o = s.taboption('general', form.Value, 'mtu', _('MTU'));
        o.datatype = 'uinteger';
        o.placeholder = '1480';
        o.optional = true;
    }
});
