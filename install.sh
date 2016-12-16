#!/bin/sh

set -e

AZURE_COM_ACCOUNT="$1"
AZURE_CN_ACCOUNT="$2"

cd `dirname $0`

# Make tr work under OSX
export LC_ALL=C
GROUP_NAME="gohop3"

# Generate passwords
GHPASS=`tr -dc A-Za-z0-9 < /dev/urandom | fold -w 16 | head -n 1`
SSPASS=`tr -dc A-Za-z0-9 < /dev/urandom | fold -w 16 | head -n 1`

# Generate ssh key
if [ ! -f $HOME/.ssh/id_rsa-gohop.pub ]; then
    ssh-keygen -f $HOME/.ssh/id_rsa-gohop -t rsa -N ''
fi
SSHKEY=`cat $HOME/.ssh/id_rsa-gohop.pub`

# Generate gohop server parameters
cat << EOF > server.param.json
{
  "\$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "adminUsername": {
      "value": "$USER"
    },
    "ghPassword": {
      "value": "$GHPASS"
    },
    "sshPublicKey": {
      "value": "$SSHKEY"
    }
  }
}
EOF

echo "Logging into azure.com..."
azure account set "$AZURE_COM_ACCOUNT"
echo "Deploying Gohop server..."
azure config mode arm
azure group create $GROUP_NAME eastasia
azure group deployment create $GROUP_NAME gohop-dep -f server/server.json -e server.param.json -v
GHSADDR=`azure network public-ip list $GROUP_NAME --json | grep "ipAddress" | cut -d'"' -f4`
echo "Gohop server is running at $GHSADDR:40000-41000"

# Generate gohop client parameters
cat << EOF > client.param.json
{
  "\$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "adminUsername": {
      "value": "$USER"
    },
    "sshPublicKey": {
      "value": "$SSHKEY"
    },
    "ghPassword": {
      "value": "$GHPASS"
    },
    "ssPassword": {
      "value": "$SSPASS"
    },
    "ghServer": {
        "value": "$GHSADDR"
    }
  }
}
EOF

echo "Logging into azure.cn..."
azure account set "$AZURE_CN_ACCOUNT"
echo "Deploying Gohop client and shadowsocks server..."
azure config mode arm
azure group create $GROUP_NAME chinaeast
azure group deployment create $GROUP_NAME gohop-dep -f client/client.json -e client.param.json -v
GHCADDR=`azure network public-ip list $GROUP_NAME --json | grep "ipAddress" | cut -d'"' -f4`
echo "Shadowsocks server is running at $GHCADDR:8388"

echo "Using following config file for shadowsocks client:"
cat << EOF
{
    "server":"$GHCADDR",
    "server_port":8388,
    "local_address":"local_address_to_bind",
    "local_port": local_port_to_bind,
    "password":"$SSPASS",
    "timeout":600,
    "method":"aes-256-cfb"
}
EOF
SSURL=`echo "aes-256-cfb:$SSPASS@$GHCADDR:8388" | base64`

echo
echo
echo "For iOS devices, install Shadowrocket at https://itunes.apple.com/cn/app/shadowrocket/id932747118?mt=8"
echo " and scan this QR Code"
echo "https://api.qrserver.com/v1/create-qr-code/?data=ss://$SSURL"
