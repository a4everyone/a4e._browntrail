#! /bin/bash

CURRDIR=$(readlink -f ${BASH_SOURCE[0]})
CURRDIR=$(dirname $CURRDIR)

function loadazurekeys {
    source $CURRDIR/../keys/keys-azure

    LOOKUPVAR=AZURE_$1_SUBSCRIPTION_ID
    AZURE_SUBSCRIPTION_ID=${!LOOKUPVAR}

    LOOKUPVAR=AZURE_$1_USERNAME
    AZURE_USERNAME=${!LOOKUPVAR}
    
    LOOKUPVAR=AZURE_$1_TENANT
    AZURE_TENANT=${!LOOKUPVAR}
    
    LOOKUPVAR=AZURE_$1_SP_PASSWORD
    AZURE_SP_PASSWORD=${!LOOKUPVAR}
}

function loadstorageenv {
    source $CURRDIR/../keys/keys-azure

    LOOKUPVAR=AZURE_SA_$1_NAME
    AZURE_STORAGE_ACCOUNT=${!LOOKUPVAR}

    LOOKUPVAR=AZURE_SA_$1_KEY
    AZURE_STORAGE_ACCESS_KEY=${!LOOKUPVAR}
    
    LOOKUPVAR=AZURE_SA_$1_QUEUE_REST_URI
    AZURE_STORAGE_QUEUE_REST_URI=${!LOOKUPVAR}

    LOOKUPVAR=AZURE_SA_$1_QUEUE_REST_AUTHPARAMS
    AZURE_STORAGE_QUEUE_REST_AUTHPARAMS=${!LOOKUPVAR}
}

function loadmailingcredentials {
    source $CURRDIR/../keys/keys-mailing
    # Nothing for now - we have only one mailing credential and it's loaded from keys-mailing
}

function loadweatherkeys {
    source $CURRDIR/../keys/keys-weather
}
