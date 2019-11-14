#!/bin/sh

set -e

AZURE_COM_SUB="$1"
AZURE_CN_SUB="$2"

cd `dirname $0`

# Make tr work under OSX
export LC_ALL=C
GROUP_NAME="hai"

# Generate passwords
GHPASS=`date |md5 | head -c8`
SSPASS=`date |md5 | head -c8`

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
az cloud set -n AzureCloud
az account set -s "$AZURE_COM_SUB"
echo "Deploying Gohop server..."
az group create -n $GROUP_NAME -l southeastasia
az group deployment create -g $GROUP_NAME --template-file server/server.json --parameters @server.param.json
GHSADDR=`az network public-ip list -g $GROUP_NAME | grep "ipAddress" | cut -d'"' -f4`
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
az cloud set -n AzureChinaCloud
az account set -s "$AZURE_CN_SUB"
echo "Deploying Gohop client and shadowsocks server..."
az group create -n $GROUP_NAME -l chinaeast2
az group deployment create -g $GROUP_NAME --template-file client/client.json --parameters @client.param.json
GHCADDR=`az network public-ip list -g $GROUP_NAME | grep "ipAddress" | cut -d'"' -f4`
echo "Shadowsocks server is running at $GHCADDR:9488"

echo "Using following config file for shadowsocks client:"
cat << EOF
{
    "server":"$GHCADDR",
    "server_port":9488,
    "local_address":"local_address_to_bind",
    "local_port": local_port_to_bind,
    "password":"$SSPASS",
    "timeout":600,
    "method":"aes-256-cfb"
}
EOF
SSURL=`echo "aes-256-cfb:$SSPASS@$GHCADDR:9488" | base64`

echo
echo
echo "For iOS devices, install Shadowrocket at https://itunes.apple.com/cn/app/shadowrocket/id932747118?mt=8"
echo " and scan this QR Code"
echo "https://api.qrserver.com/v1/create-qr-code/?data=ss://$SSURL"
