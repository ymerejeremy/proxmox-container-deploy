#!/bin/bash

print_help() {
cat << EOF
USAGE
        $0 --node-ip <node-ip> [--node-name <node-name>] --username <username> --password <password> --ct-id <container_id> --ct-name <container_name> --ct-ip <container_ip> --ct-gw <container_gw> [--ct-dns <container_dns>] [--ct-bridge <container_bridge>] [--ct-os-template <container_os_template>]

DESCRIPTION
        Créer un conteneur sur le node <node-name> en se connectant au noeud <node-ip>

        --node-ip
                IP du noeud

        --node-name (optionnel) [defaut: proxmox]
                Nom du noeud

        --username, -u
                Nom de l'utilisateur qui sera pris pour créer le conteneur

        --password, -p
                Mot de passe de l'utilisateur qui sera pris pour créer le conteneur

        --ct-id
                ID du conteneur

        --ct-name
                Nom du conteneur

        --ct-ip
                IP du conteneur

        --ct-gw
                Passerelle du conteneur

        --ct-dns (optionnel) [defaut: <container_gw>]
                Serveur de nom du conteneur

        --ct-bridge (optionnel) [defaut: vmbr0]
                Interface réseau du conteneur

        --ct-os-template (optionnel) [defaut: local:vztmpl/debian-11-standard_11.3-1_amd64.tar.zst]
                OS template qui sera installé sur le conteneur
EOF

}

if [ $# -eq 0 ]; then
        print_help
        exit 1
fi


while [ $# -gt 0 ]; do
        key=$1

        case $key in
                --node-ip)
                        APINODE=$2
                        shift
                        shift
                        ;;
                --node-name)
                        TARGETNODE=$2
                        shift
                        shift
                        ;;
                --username|-u)
                        USERNAME=$2
                        shift
                        shift
                        ;;
                --password|-p)
                        PASSWORD=$2
                        shift
                        shift
                        ;;
                --ct-id)
                        CONTAINER_ID=$2
                        shift
                        shift
                        ;;
                --ct-name)
                        CONTAINER_NAME=$2
                        shift
                        shift
                        ;;
                --ct-ip)
                        CONTAINER_IP=$2
                        shift
                        shift
                        ;;
                --ct-gw)
                        CONTAINER_GW=$2
                        shift
                        shift
                        ;;
                --ct-dns)
                        CONTAINER_DNS=$2
                        shift
                        shift
                        ;;
                --ct-bridge)
                        CONTAINER_BRIDGE=$2
                        shift
                        shift
                        ;;
                --ct-os-template)
                        CONTAINER_OS_TEMPLATE=$2
                        shift
                        shift
        esac
done


### CHECK CONNECTION INFOS

if [ -z "$USERNAME" ]; then
        echo "Vous devez spécifier un utilisateur"
        exit 1
fi

if [ -z "$PASSWORD" ]; then
        echo "Vous devez spécifier un mot de passe"
        exit 1
fi

if [ -z "$APINODE" ]; then
        echo "Vous devez spécifier l'adresse du noeud au quel le programme se connectera"
        exit 1
fi

if [ -z "$TARGETNODE" ]; then
        TARGETNODE=proxmox
fi


### CHECK CONTAINER INFOS

if [ -z "$CONTAINER_ID" ]; then
        echo "Vous devez spécifier l'ID du conteneur"
        exit 1
fi

if [ -z "$CONTAINER_NAME" ]; then
        echo "Vous devez spécifier le nom du conteneur"
        exit 1
fi

if [ -z "$CONTAINER_IP" ]; then
        echo "Vous devez spécifier l'IP du conteneur"
        exit 1
fi

if [ -z "$CONTAINER_GW" ]; then
        echo "Vous devez spécifier la passerelle du conteneur"
        exit 1
fi

if [ -z "$CONTAINER_DNS" ]; then
        CONTAINER_DNS=$CONTAINER_GW
fi

if [ -z "$CONTAINER_BRIDGE" ]; then
        CONTAINER_BRIDGE="vmbr0"
fi

if [ -z "$CONTAINER_OS_TEMPLATE" ]; then
        CONTAINER_OS_TEMPLATE="local:vztmpl/debian-11-standard_11.3-1_amd64.tar.zst"
fi



##### GET COOKIE

curl --silent --insecure --data "username=$USERNAME&password=$PASSWORD" \
 https://$APINODE:8006/api2/json/access/ticket\
| jq --raw-output '.data.ticket' | sed 's/^/PVEAuthCookie=/' > cookie


##### GET CSRF TOKEN

curl --silent --insecure --data "username=$USERNAME&password=$PASSWORD" https://$APINODE:8006/api2/json/access/ticket | jq --raw-output '.data.CSRFPreventionToken' | sed 's/^/CSRFPreventionToken:/' > csrftoken


##### CREATE LXC

result=$(curl --silent --insecure --cookie "$(<cookie)" --header "$(<csrftoken)" -X POST --data-urlencode hostname="${CONTAINER_NAME}" --data-urlencode net0="name=eth0,bridge=${CONTAINER_BRIDGE},gw=${CONTAINER_GW},ip=${CONTAINER_IP}" --data-urlencode nameserver="${CONTAINER_DNS}" --data-urlencode ostemplate="${CONTAINER_OS_TEMPLATE}" --data vmid=${CONTAINER_ID} https://$APINODE:8006/api2/json/nodes/$TARGETNODE/lxc)

echo "$result"

rm -f csrftoken cookie &> /dev/null
