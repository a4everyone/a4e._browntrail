#!/bin/bash

CURRDIR=$(readlink -f ${BASH_SOURCE[0]})
CURRDIR=$(dirname $CURRDIR)
source  $CURRDIR/keytools.sh

case $1 in
    l|login)
        loadazurekeys $2
        azure login -u ${AZURE_USERNAME} --service-principal --tenant ${AZURE_TENANT} -p ${AZURE_SP_PASSWORD}
        azure account set ${AZURE_SUBSCRIPTION_ID}
    ;;
    s|storage)
        loadstorageenv $2
        echo export AZURE_STORAGE_ACCOUNT=$AZURE_STORAGE_ACCOUNT
        echo export AZURE_STORAGE_ACCESS_KEY=$AZURE_STORAGE_ACCESS_KEY
        echo -e '#''\033[0;31m'' Use: eval $(azure-admin storage '$2')''\033[0m'
    ;;
    *)
        echo "Invalid argument $1. Use l|login or s|storage"
        exit 1
    ;;
esac
