#!/bin/sh

GHSERVER="$1"
URL_BASE="$2"
GHPASSWD="$3"
SSPASSWD="$4"

# Install gohop
curl "$URL_BASE/gohop" -o /usr/local/bin/gohop
chmod +x /usr/local/bin/gohop

# Create gohop config file
mkdir -p /etc/gohop/scripts
curl "$URL_BASE/client/chnroute-up.sh" -o /etc/gohop/scripts/chnroute-up.sh
curl "$URL_BASE/client/chnroute-down.sh" -o /etc/gohop/scripts/chnroute-down.sh
chmod +x /etc/gohop/scripts/chnroute-up.sh /etc/gohop/scripts/chnroute-down.sh
cat << EOF > /etc/gohop/client.ini
[default]
mode = client
[client]
server = $GHSERVER
hopstart = 40000
hopend = 41000
mtu = 1400
key = $GHPASSWD
morphmethod = none
redirect-gateway = true
local = false
heartbeat-interval = 30
up = /etc/gohop/scripts/chnroute-up.sh
down = /etc/gohop/scripts/chnroute-down.sh
EOF

# Create gohop service configuration for systemd
cat << EOF > /etc/systemd/system/gohop-client.service
[Unit]
Description = GoHop personal VPN client
Requires = network.target
After = network.target
[Service]
ExecStart = /usr/local/bin/gohop /etc/gohop/client.ini
KillSignal = SIGTERM
[Install]
WantedBy = multi-user.target
EOF

# Install shadowsocks server
curl "$URL_BASE/ss-server" -o /usr/local/bin/ss-server
chmod +x /usr/local/bin/ss-server
mkdir /etc/shadowsocks-libev

# Create shadowsocks config file
cat << EOF > /etc/shadowsocks-libev/config.json
{
    "server":"10.1.0.4",
    "server_port":8388,
    "password":"$SSPASSWD",
    "timeout":300,
    "method":"aes-256-cfb",
    "fast_open": false,
    "workers": 10
}
EOF

# Create shadowsocks service configuration for systemd
cat << EOF > /etc/systemd/system/shadowsocks-libev.service
[Unit]
Description = Shadowsocks-libev server
After = network.target
[Service]
Type=simple
User=root
LimitNOFILE=32768
ExecStart=/usr/local/bin/ss-server -c /etc/shadowsocks-libev/config.json -u
[Install]
WantedBy = multi-user.target
EOF

# Regenerage /etc/resolv.conf
echo "DNS1=8.8.8.8" >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo "DNS2=8.8.4.4" >> /etc/sysconfig/network-scripts/ifcfg-eth0
systemctl restart network.service

# Manually start all services, no wait to next reboot
systemctl enable gohop-client.service
systemctl start gohop-client.service
systemctl enable shadowsocks-libev.service
systemctl start shadowsocks-libev.service
