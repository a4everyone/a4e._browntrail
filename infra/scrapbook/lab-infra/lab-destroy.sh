#!/bin/bash

if [ -z "$A4E_PROJ_ROOT" ] || [ ! -d "$A4E_PROJ_ROOT" ]; then
    echo "error:Please define A4E_PROJ_ROOT to point at your project root directory (e.g. /home/user/a4e)!"
    exit 1
fi

if [ "$#" -lt 1 ]; then
    echo Usage: ./lab-destroy infrastructure-cfg-file.cfg
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

for account in "${LAB_ACCOUNTS[@]}"; do

    echo Entering account \"$account\"
    ${A4E_PROJ_ROOT}/infra/tools/azure-admin.sh login $account

    ACC_MACHINES_ARR="LAB_MACHINES_${account}[@]"
    ACC_MACHINES_ARR=( "${!ACC_MACHINES_ARR}" )
    for AZURE_LAB_VMNAME_STAR in "${ACC_MACHINES_ARR[@]}"; do
    
        AZURE_LAB_VMNAME=${AZURE_LAB_VMNAME_STAR/\#/}
        docker-machine rm -f $AZURE_LAB_VMNAME
    done
    
    # azure group delete -q ${AZURE_LAB_RESOURCE_GROUP}
done
