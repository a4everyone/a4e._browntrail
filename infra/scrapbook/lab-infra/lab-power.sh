#!/bin/bash

if [ -z "$A4E_PROJ_ROOT" ] || [ ! -d "$A4E_PROJ_ROOT" ]; then
    echo "error:Please define A4E_PROJ_ROOT to point at your project root directory (e.g. /home/user/a4e)!"
    exit 1
fi

#~ if [[ $2 != "on" ]] && [[ $2 != "off" ]] && [[ $2 != "onc" ]] && [[ $2 != "offc" ]]; then
    #~ echo Usage: lab-power.sh on/off infrastructure-cfg-file.cfg
    #~ exit 1
#~ fi

PWR_COMMAND=$2

source lab-common.cfg

if [ ! -r $1 ]; then
    echo "$1 doesn't exist or is not accessible"
    exit 1
fi
source $1

function control_machine {
    #~ azure vm $1 $2 $3
    
    
#~ Sub Id: ${MACHINE_CONF[0]}
#~ Ten_Id: ${MACHINE_CONF[1]}
#~ USRN  : ${MACHINE_CONF[2]}
#~ PASS  : ${MACHINE_CONF[3]}
#~ RGN   : ${MACHINE_CONF[4]}
#~ MACHIN: ${MACHINE_CONF[5]}"
        
        AZURE_LOGIN_RESPONSE=$(\
        curl -X POST https://login.windows.net/${AZURE_TENANT}/oauth2/token \
        --data "resource=https://management.core.windows.net/&client_id=${AZURE_USERNAME}&grant_type=client_credentials&client_secret=${AZURE_SP_PASSWORD}" )

        echo "Login response is ${AZURE_LOGIN_RESPONSE}"
        AZURE_ACCESS_TOKEN=$(jq -r ."access_token" <<< $AZURE_LOGIN_RESPONSE)
        echo "Acess token is ${AZURE_ACCESS_TOKEN}"

		echo URL is https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${1}/providers/Microsoft.Compute/virtualMachines/${2}/${3}?api-version=2015-05-01-preview
        #~ for machine_name in "${MACHINE_ARR[@]}"; do
            curl -X POST \
            -H "Content-Length: 0" \
            -H "Authorization: Bearer ${AZURE_ACCESS_TOKEN}" \
            https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${1}/providers/Microsoft.Compute/virtualMachines/${2}/${3}?api-version=2015-05-01-preview
        #~ done
}

FAIL=0
source ${A4E_PROJ_ROOT}/infra/tools/keytools.sh

for account in "${LAB_ACCOUNTS[@]}"; do

    loadazurekeys ${account}
    #~ echo Entering account \"$account\"
    #~ ${A4E_PROJ_ROOT}/infra/tools/azure-admin.sh login $account

	
    ACC_MACHINES_ARR="LAB_MACHINES_${account}[@]"
    ACC_MACHINES_ARR=( "${!ACC_MACHINES_ARR}" )
    for AZURE_LAB_VMNAME_STAR in "${ACC_MACHINES_ARR[@]}"; do

        AZURE_LAB_VMNAME=${AZURE_LAB_VMNAME_STAR/\#/}
		control_machine ${AZURE_LAB_RESOURCE_GROUP} ${AZURE_LAB_VMNAME} ${PWR_COMMAND}
	
        
        #~ # If the operation ends in c, it must affect only machines other than the main lab machine
        #~ if [[ $AZURE_LAB_VMNAME_STAR =~ .*#$ ]] && ( [[ $PWR_COMMAND == "onc" ]] || [[ $PWR_COMMAND == "offc" ]] ); then continue; fi
        
        #~ if [[ $PWR_COMMAND == "on" ]] || [[ $PWR_COMMAND == "onc" ]]; then
            #~ control_machine ${account} ${AZURE_LAB_RESOURCE_GROUP} ${AZURE_LAB_VMNAME} start
        #~ elif [[ $PWR_COMMAND == "off" ]] || [[ $PWR_COMMAND == "offc" ]]; then
            #~ control_machine ${account} ${AZURE_LAB_RESOURCE_GROUP} ${AZURE_LAB_VMNAME} deallocate 
        #~ fi
    done
    #~ for job in `jobs -p`; do
        #~ wait $job || let "FAIL+=1"
    #~ done
done
