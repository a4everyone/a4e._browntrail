AZURE_RESOURCE_GROUP=webprod
WEB_SITE_ACOCUNT=NIKOLOV
AZURE_DRIVER_VER=0.2.1

#Boilerplate code for loading azure keys
#source ../../tools/keytools.sh
#loadazurekeys $AZURE_USER
#cd $currpath

if [[ $1 == "prod" ]]; then
    WEB_KEY_PATH=${A4E_PROJ_ROOT}/infra/keys/keys-website/prod-rsa
else
    WEB_KEY_PATH=${A4E_PROJ_ROOT}/infra/keys/keys-website/stage-rsa
fi
export AZURE_SSH_KEY=$(cat ${WEB_KEY_PATH}.pub)

rm result.log
azure config mode arm
azure-admin l $WEB_SITE_ACOCUNT
azure group create -n webprod -l "North Europe"
#azure group template validate -f azuredeploy.json -p "{\"ParameterName\":{\"value\":\"ParameterValue\"}}" -g webprod
#azure group deployment create -f azuredeploy.json -g webprod -n deployment1 --json

#ssh-keygen -t rsa -q -f test-rsa -N ""

sed -e 's|^.*#.*$||' < azuredeploy.json.tmpl > azuredeploy.json
#cat azuredeploy.parameters.json.tmpl | envsubst '$AZURE_SSH_KEY' > azuredeploy.parameters.json
azure group deployment create -f azuredeploy.json -g webprod -n deployment1 -p "{\"sshKeyData\":{\"value\":\"${AZURE_SSH_KEY}\"}}" --json > result.log

PUBLIC_IP=$(cat result.log | grep ipAddress | grep -o '\([0-9]\{1,3\}\.\)\{1,3\}[0-9]\{1,3\}')

rm result.log azuredeploy.json

test -z PUBLIC_IP && exit 1

ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p 50001 -i ${WEB_KEY_PATH} a4everyone@${PUBLIC_IP} 'bash -s' < prepare-host.sh
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p 50002 -i ${WEB_KEY_PATH} a4everyone@${PUBLIC_IP} 'bash -s' < prepare-host.sh
envsubst < ../../tools/install-azure-storage-driver.sh | ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p 50001 -i ${WEB_KEY_PATH} a4everyone@${PUBLIC_IP} 'bash -s'
envsubst < ../../tools/install-azure-storage-driver.sh | ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p 50002 -i ${WEB_KEY_PATH} a4everyone@${PUBLIC_IP} 'bash -s'

docker-machine create --driver generic --generic-ssh-key=/home/pato/.ssh/azure_pato --generic-ip-address=${PUBLIC_IP} --generic-ssh-user="a4everyone" --generic-ssh-key="${WEB_KEY_PATH}" --generic-engine-port=2376 --generic-ssh-port=50001 a4eweb-0
docker-machine create --driver generic --generic-ssh-key=/home/pato/.ssh/azure_pato --generic-ip-address=${PUBLIC_IP} --generic-ssh-user="a4everyone" --generic-ssh-key="${WEB_KEY_PATH}" --generic-engine-port=2377 --generic-ssh-port=50002 a4eweb-1


eval $(docker-machine env a4eweb-0)
#docker-compose -f docker-compose.yml -f docker-compose.prod1 pull
docker-compose -f docker-compose.yml -f docker-compose.prod0 up-d

eval $(docker-machine env a4eweb-1)
#docker-compose -f docker-compose.yml -f docker-compose.prod2 pull
docker-compose -f docker-compose.yml -f docker-compose.prod1 up-d

#TODO
# In docker-compose yamls make IPs configurable - both external and internal
