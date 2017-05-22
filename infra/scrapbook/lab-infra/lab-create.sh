#!/bin/bash

if [ -z "$A4E_PROJ_ROOT" ] || [ ! -d "$A4E_PROJ_ROOT" ]; then
    echo "error:Please define A4E_PROJ_ROOT to point at your project root directory (e.g. /home/user/a4e)!"
    exit 1
fi

if [ "$#" -lt 1 ]; then
    echo Usage: ./lab-create infrastructure-cfg-file.cfg
    exit 1
fi

source lab-common.cfg

for srcfile in "$@"; do
    if [ ! -r $srcfile ]; then
        echo "$srcfile doesn't exist or is not accessible"
        exit 1
    fi
    source $srcfile
done


function cleanup {
    rm -rf result-tmp.json
}

trap cleanup HUP INT QUIT KILL TERM EXIT


source ${A4E_PROJ_ROOT}/infra/tools/keytools.sh

loadstorageenv ${AZURE_STORAGE_NAME}

export AZURE_DRIVER_VER="v0.5.1"
export AZURE_STORAGE_ACCOUNT
export AZURE_STORAGE_ACCESS_KEY

for account in "${LAB_ACCOUNTS[@]}"; do

    echo Entering account \"$account\"
    loadazurekeys $account
    #~ ${A4E_PROJ_ROOT}/infra/tools/azure-admin.sh login $account


    ACC_MACHINES_ARR="LAB_MACHINES_${account}[@]"
    ACC_MACHINES_ARR=( "${!ACC_MACHINES_ARR}" )
    for AZURE_LAB_VMNAME_STAR in "${ACC_MACHINES_ARR[@]}"; do
    
        AZURE_LAB_VMNAME=${AZURE_LAB_VMNAME_STAR/\#/}
        MACHINE_SIZE="LAB_MACHINE_SIZES[$AZURE_LAB_VMNAME]"
        MACHINE_SIZE="${!MACHINE_SIZE}"
        
        VM_OS_SKU="canonical:ubuntuserver:16.04.0-LTS:latest"

        rm -rf result-tmp.json

        echo Provisioning machine ${AZURE_LAB_VMNAME}, in account ${account}, size ${MACHINE_SIZE}

        #~ azure vm quick-create -g ${AZURE_LAB_RESOURCE_GROUP} -n ${AZURE_LAB_VMNAME} -l "${AZURE_LAB_LOCATION}" -y Linux -Q ${VM_OS_SKU} -z ${MACHINE_SIZE} -u ${AZURE_VM_USERNAME} -M ~/.ssh/azure_pato.pub -p 1qazZAQ! --json > result-tmp.json
        #~ if [ $? -eq 0 ]; then
            #~ echo Provisioning successful
        #~ else
            #~ echo Provisioning failed! Try running azure cli with -v and without --json to see detailed output
            #~ exit 1
        #~ fi

        #~ NIC_ID=$(cat result-tmp.json | jq ."networkProfile"."networkInterfaces"[0]."id" | sed s/\"//g)
        #~ NIC_NAME=${NIC_ID##*\/}
        #~ NETWORK_NUM=$(echo $NIC_NAME | grep -o [0-9]* | tail -1)
        
        #~ AZURE_LAB_DNS_LOCATION=$(cat result-tmp.json | jq ."location" | sed s/\"//g)
        
        #~ AZURE_LAB_LOC_SHORT=${NIC_NAME#$AZURE_LAB_VMNAME\-}
        #~ AZURE_LAB_LOC_SHORT=${AZURE_LAB_LOC_SHORT%%\-*}
        
        #~ PUBLIP_NAME=${AZURE_LAB_VMNAME}-${AZURE_LAB_LOC_SHORT}-${NETWORK_NUM}-pip
        #~ PUBLIP_ID=/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_LAB_RESOURCE_GROUP}/providers/Microsoft.Network/publicIPAddresses/${PUBLIP_NAME}
        #~ VM_DNS_NAME=${PUBLIP_NAME}.${AZURE_LAB_DNS_LOCATION}.cloudapp.azure.com
        #~ AZURE_PUB_KEY=$(cat ${A4E_PROJ_ROOT}/infra/keys/keys-lab/stage-rsa.pub)

        #~ azure network nic set -i ${PUBLIP_ID} ${AZURE_LAB_RESOURCE_GROUP} ${NIC_NAME}

        # VM_PUBLIP=$(dig +short ${VM_DNS_NAME})

        #~ sshpass -p '1qazZAQ!' ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${AZURE_VM_USERNAME}@${VM_DNS_NAME} "echo $AZURE_PUB_KEY >> ~/.ssh/authorized_keys"

        #~ echo "Provisioning docker"
        #docker-machine create --driver generic --generic-ssh-key=../keys/keys-lab/stage-rsa --generic-ip-address=${VM_PUBLIP} --generic-ssh-user="${AZURE_VM_USERNAME}" ${AZURE_LAB_VMNAME}
        #~ docker-machine create --driver generic --generic-ssh-key=${A4E_PROJ_ROOT}/infra/keys/keys-lab/stage-rsa --generic-ip-address=${VM_DNS_NAME} --generic-ssh-user="${AZURE_VM_USERNAME}" ${AZURE_LAB_VMNAME}

        #~ export AZURE_AVAILABILITY_SET="compute"
        export AZURE_CLIENT_ID=${AZURE_USERNAME}
        export AZURE_CLIENT_SECRET=${AZURE_SP_PASSWORD}
        export AZURE_IMAGE=${VM_OS_SKU}
        export AZURE_LOCATION=${AZURE_LAB_LOCATION}
        export AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}
        export AZURE_SIZE=${MACHINE_SIZE}
        export AZURE_DNS_LABEL=${AZURE_LAB_VMNAME}
        export AZURE_SSH_USER=${AZURE_VM_USERNAME}
        export AZURE_RESOURCE_GROUP=${AZURE_LAB_RESOURCE_GROUP}
        #~ export AZURE_VNET="swarm-managers"
        #~ export AZURE_SUBNET_PREFIX="192.168.0.0/24"
        export MACHINE_DRIVER=azure

        docker-machine create ${AZURE_LAB_VMNAME}
        if [ $? -eq 0 ]; then
            echo Docker Provisioning successful
        else
            echo Provisioning failed! Check Docker output for info
            exit 1
        fi

        #~ envsubst < ${A4E_PROJ_ROOT}/infra/tools/install-azure-storage-driver.sh | ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ${A4E_PROJ_ROOT}/infra/keys/keys-lab/stage-rsa ${AZURE_VM_USERNAME}@${VM_DNS_NAME} 'bash -s'
        envsubst < ${A4E_PROJ_ROOT}/infra/tools/install-azure-storage-driver.sh | docker-machine ssh ${AZURE_LAB_VMNAME} 'bash -s'
        if [ $? -eq 0 ]; then
            echo Azure Storage Driver installation successful
        else
            echo Azure Storage Driver installation failed
            exit 1
        fi
    done

done

#docker-machine create --driver azure --azure-subscription-id $AZURE_SUBSCRIPTION_ID --azure-image "canonical:ubuntuserver:16.04.0-LTS:latest" --azure-location "North Europe" --azure-size Standard_DS1_V2 --azure-client-id $AZURE_USERNAME --azure-client-secret $AZURE_SP_PASSWORD efe8-1
# ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ~/a4e/infra/keys/keys-lab/stage-rsa a4e@tod1-north-489041947-pip.northeurope.cloudapp.azure.com
#envsubst < ../tools/install-azure-storage-driver.sh | ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ../keys/keys-lab/stage-rsa a4e@tod1-north-489041947-pip.northeurope.cloudapp.azure.com 'bash -s'
