#!/bin/sh

GHSERVER=$1
URL_BASE="$2"

# Install gohop
apt --yes install curl shadowsocks-libev
curl "$URL_BASE/gohop" -o /usr/local/bin/gohop
chmod +x /usr/local/bin/gohop

# Create gohop config file
mkdir -p /etc/gohop/scripts
curl "$URL_BASE/client/chnroute-up.sh" -o /etc/gohop/scripts/chnroute-up.sh
curl "$URL_BASE/client/chnroute-down.sh" -o /etc/gohop/scripts/chnroute-down.sh
cat << EOF > /etc/gohop/client.ini
[default]
mode = client
[client]
server = $GHSERVER
hopstart = 40000
hopend = 41000
mtu = 1400
key = dSQaVkDsU7PTt6pU
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

# Create shadowsocks config file
cat << EOF > /etc/shadowsocks-libev/config.json
{
    "server":"10.1.0.6",
    "server_port":8388,
    "password":"4eeAa3sEW0qdk2cf",
    "timeout":300,
    "method":"aes-256-cfb",
    "fast_open": false,
    "workers": 10
}
EOF

# Manually start all services, no wait to next reboot
systemctl enable gohop-client.service
systemctl start gohop-client.service
systemctl enable shadowsocks-libev.service
systemctl start shadowsocks-libev.service
