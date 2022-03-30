#!/bin/bash

print_help() {
cat << EOF
USAGE
        $0 --jk-url <jenkins_url> --node-ip <node-ip> [--node-name <node-name>] --username <username> --password <password> --ct-id <container_id> --ct-name <container_name> --ct-ip <container_ip> --ct-gw <container_gw> [--ct-dns <container_dns>] [--ct-bridge <container_bridge>] [--ct-os-template <container_os_template>] --ct-cred <container_credentials> --ssh-pubkey <ssh-pubkey> --type <type>

DESCRIPTION
        Créer un conteneur sur le node <node-name> en se connectant au noeud <node-ip>
	
	--jk-url
		URL de Jenkins

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
                IP du conteneur. Ne pas oublier de spécifier le CIDR

        --ct-gw
                Passerelle du conteneur

        --ct-dns (optionnel) [defaut: <container_gw>]
                Serveur de nom du conteneur

        --ct-bridge (optionnel) [defaut: vmbr0]
                Interface réseau du conteneur

        --ct-os-template (optionnel) [defaut: local:vztmpl/debian-11-standard_11.3-1_amd64.tar.zst]
                OS template qui sera installé sur le conteneur

	--ct-cred
		Identifiants permettant d'accéder au conteneur
	
	--ssh-pubkey
		La clé publique SSH qui permettra à Jenkins de se connecter au conteneur

	--type, -t
		Le type de conteneur
		Liste des types : gcc, python, shell, docker
EOF

}

if [ $# -eq 0 ]; then
        print_help
        exit 1
fi


while [ $# -gt 0 ]; do
        key=$1

        case $key in
                --jk-url)
                        JENKINS_URL=$2
                        shift
                        shift
                        ;;
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
			;;
                --ct-cred)
                        CONTAINER_CREDENTIALS=$2
                        shift
                        shift
			;;
		--ssh-pubkey)
                        CONTAINER_SSH_PUBKEY=$2
                        shift
                        shift
			;;
		--type|-t)
			CONTAINER_TYPE=$2
			shift
			shift
			;;
		*)
			UNKNOWN_FLAG=$1
			break
        esac
done

###CHECK UNKNWON FLAG

if [ ! -z "$UNKNOWN_FLAG" ]; then
	echo "Flag '$UNKNOWN_FLAG' inconnu"
	exit 1
fi



if [ -z "$JENKINS_URL" ]; then
        echo "Vous devez spécifier l'url de Jenkins"
        exit 1
fi



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

if ! [[ "$CONTAINER_ID" =~ ^[0-9]+$ ]]; then
	echo "L'ID du conteneur doit être un nombre"
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

if [ -z "$CONTAINER_SSH_PUBKEY" ]; then
        echo "Vous devez spécifier la clé publique SSH qui permettra la connexion au conteneur"
        exit 1
fi

if [ -z "$CONTAINER_TYPE" ]; then
	echo "Vous devez spécifier le type du conteneur"
	exit 1
fi


if [ ! -f "types.d/${CONTAINER_TYPE}.sh" ]; then
	echo "Type de conteneur inconnu"
	exit 1
fi

if [ -z "$CONTAINER_CREDENTIALS" ]; then
	echo "Vous devez spécifier les identifiants du conteneur"
	exit 1
fi


##### CREATE TMP SSKKEY
mkdir -p tmp/
TMP_SSHKEY="tmp/tmp_${CONTAINER_ID}_rsa"
ssh-keygen -t rsa -b 2048 -f $TMP_SSHKEY -q -N ""
chmod 600 $TMP_SSHKEY

AUTHORIZED_KEYS="tmp/authorized_keys"
cat << EOF > $AUTHORIZED_KEYS
# --- BEGIN PVE ---
${CONTAINER_SSH_PUBKEY}
# --- END PVE ---
EOF



##### GET COOKIE

curl --silent --insecure --data "username=$USERNAME&password=$PASSWORD" \
 https://$APINODE:8006/api2/json/access/ticket\
| jq --raw-output '.data.ticket' | sed 's/^/PVEAuthCookie=/' > cookie


##### GET CSRF TOKEN

curl --silent --insecure --data "username=$USERNAME&password=$PASSWORD" https://$APINODE:8006/api2/json/access/ticket | jq --raw-output '.data.CSRFPreventionToken' | sed 's/^/CSRFPreventionToken:/' > csrftoken


##### CREATE LXC

result=$(curl --silent --insecure --cookie "$(<cookie)" --header "$(<csrftoken)" -X POST --data-urlencode hostname="${CONTAINER_NAME}" --data-urlencode net1="name=eth0,bridge=${CONTAINER_BRIDGE},gw=${CONTAINER_GW},ip=${CONTAINER_IP}" --data-urlencode nameserver="${CONTAINER_DNS}" --data-urlencode ostemplate="${CONTAINER_OS_TEMPLATE}" --data vmid=${CONTAINER_ID} https://$APINODE:8006/api2/json/nodes/$TARGETNODE/lxc --data-urlencode ssh-public-keys="$(cat ${TMP_SSHKEY}.pub)")

echo "$result"

result=$(curl --silent --insecure --cookie "$(<cookie)" --header "$(<csrftoken)" -X POST --data-urlencode node="$TARGETNODE" --data vmid=${CONTAINER_ID} https://$APINODE:8006/api2/json/nodes/$TARGETNODE/lxc/${CONTAINER_ID}/status/start)

echo "$result"


IP=$(echo "$CONTAINER_IP" | cut -d'/' -f1)
echo "En attente du lancement du conteneur .."
while ! ping -c 1 $IP &> /dev/null; do
	sleep 1
done

>/var/jenkins_home/.ssh/known_hosts

scp -i ${TMP_SSHKEY} -o "StrictHostKeyChecking=no" "types.d/_.sh" root@$IP:setup1.sh
scp -i ${TMP_SSHKEY} -o "StrictHostKeyChecking=no" "types.d/${CONTAINER_TYPE}.sh" root@$IP:setup2.sh
ssh -i ${TMP_SSHKEY} -o "StrictHostKeyChecking=no" root@$IP 'chmod 755 setup1.sh; bash setup1.sh; rm -f setup1.sh; chmod 755 setup2.sh; bash setup2.sh; rm -f setup2.sh'
scp -i ${TMP_SSHKEY} -o "StrictHostKeyChecking=no" "$AUTHORIZED_KEYS" root@$IP:.ssh/authorized_keys


# RECUPERATION DU JAR CLI

mkdir -p ~/bin

if [ ! -f "~/bin/jenkins-cli.jar" ]; then
	curl --silent http://localhost:8080/jnlpJars/jenkins-cli.jar -o ~/bin/jenkins-cli.jar
	chmod 755 ~/bin/jenkins-cli.jar
fi

cat <<EOF | java -jar ~/bin/jenkins-cli.jar -s http://localhost:8080/ -i ~/.ssh/jenkins_master_rsa create-node $CONTAINER_NAME
<slave>
  <name>${CONTAINER_NAME}</name>
  <description></description>
  <remoteFS>/root/slave/</remoteFS>
  <numExecutors>1</numExecutors>
  <mode>NORMAL</mode>
  <retentionStrategy class="hudson.slaves.RetentionStrategy$Always"/>
  <launcher class="hudson.plugins.sshslaves.SSHLauncher" plugin="ssh-slaves@1.5">
    <host>${CONTAINER_IP}</host>
    <port>22</port>
    <credentialsId>${CONTAINER_CREDENTIALS}</credentialsId>
  </launcher>
  <label>${CONTAINER_TYPE}</label>
  <nodeProperties/>
  <userId>0</userId>
</slave>
EOF


rm -f csrftoken cookie &> /dev/null
rm -rf tmp &> /dev/null
