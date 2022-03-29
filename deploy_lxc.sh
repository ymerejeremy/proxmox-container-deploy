#!/bin/bash

if [ $# -lt 4 ]; then
        echo "Usage: $0 <container_id> <container_name> <container_bridge> <container_os_template>"
        exit 1
fi

CONTAINER_ID="$1"
CONTAINER_NAME="$2"
CONTAINER_BRIDGE="$3"
CONTAINER_OS_TEMPLATE="$4"


USERNAME=jk-agent@pam
PASSWORD=password
APINODE=192.168.0.60
TARGETNODE=proxmox


##### GET COOKIE

curl --silent --insecure --data "username=$USERNAME&password=$PASSWORD" \
 https://$APINODE:8006/api2/json/access/ticket\
| jq --raw-output '.data.ticket' | sed 's/^/PVEAuthCookie=/' > cookie


##### GET CSRF TOKEN

curl --silent --insecure --data "username=$USERNAME&password=$PASSWORD" https://$APINODE:8006/api2/json/access/ticket | jq --raw-output '.data.CSRFPreventionToken' | sed 's/^/CSRFPreventionToken:/' > csrftoken


##### CREATE LXC

curl --silent \
        --insecure \
        --cookie "$(<cookie)" \
        --header "$(<csrftoken)" \
        -X POST \
        --data-urlencode net0="name=${CONTAINER_NAME},bridge=${CONTAINER_BRIDGE}" \
        --data-urlencode ostemplate="${CONTAINER_OS_TEMPLATE}" \
        --data vmid=${CONTAINER_ID} \
        https://$APINODE:8006/api2/json/nodes/$TARGETNODE/lxc
