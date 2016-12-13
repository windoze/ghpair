#!/bin/sh

URL_BASE="$1"

# Install gohop
apt update
apt --yes install curl
apt --yes dist-upgrade
curl "$URL_BASE/gohop" -o /usr/local/bin/gohop
chmod +x /usr/local/bin/gohop

# Enable IP forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# Enable IP masquerade
cat << EOF > /etc/rc.local
iptables -t nat -A POSTROUTING -j MASQUERADE
exit 0
EOF

# Create gohop config file
mkdir /etc/gohop
cat << EOF > /etc/gohop/server.ini
[default]
mode = server
[server]
hopstart = 40000
hopend = 41000
addr = 10.1.1.1/24
mtu = 1400
key = dSQaVkDsU7PTt6pU
morphmethod = none
fixmss = true
peertimeout = 60
EOF

# Create gohop service configuration for systemd
cat << EOF > /etc/systemd/system/gohop-server.service
[Unit]
Description = GoHop personal VPN server
Requires = network.target
After = network.target
[Service]
ExecStart = /usr/local/bin/gohop /etc/gohop/server.ini
KillSignal = SIGTERM
[Install]
WantedBy = multi-user.target
EOF

# Manually start all services, no wait to next reboot
sysctl -p /etc/sysctl.conf
iptables -t nat -A POSTROUTING -j MASQUERADE
systemctl enable gohop-server.service
systemctl start gohop-server.service