#!/bin/bash

set -e

if [ "$#" -lt 2 ]; then
    echo Usage: ./lab-up infrastructure-cfg-file.cfg COMMAND...
    echo Valid commands are: pull up down scale stop start ps volumesrm danglingrm
    exit 1
fi

source lab-common.cfg

if [ ! -r $1 ]; then
    echo "$1 doesn't exist or is not accessible"
    false
fi
source $1
shift

export COMPOSE_HTTP_TIMEOUT=150

function composeit {
    local VM_NAME_STAR=$1
    local VM_CORE_CNT=$2
    export LAB_IDX=$3
    
    shift 3

    local VM_NAME=${VM_NAME_STAR/\#/}
    echo executing "$@" for $VM_NAME
    
    if [[ "${VM_NAME}" == "dev" ]]; then
        #make sure docker-machine isn't pointing to some weird remote machine
        unset DOCKER_TLS_VERIFY DOCKER_HOST DOCKER_CERT_PATH DOCKER_MACHINE_NAME
    else
        set +e
        for retries in `seq 1 3`; do
            # This strange syntax guarantees exit if docker-machine env fails - otherwise compose will be applied to your local docker o.O
            eval $(docker-machine env $VM_NAME || echo false) && break
            if [ $retries -eq 3 ]; then echo "docker-machine $VM_NAME failed permanently!"; exit 1; fi
            sleep 3
        done
        set -e
    fi

    while [ $# -ge 1 ]; do
        case $1 in
            pull|stop|start|down|ps)
                docker-compose ${COMPOSE_CONFIG_FILES} $1
                ;;
            up)
                docker-compose ${COMPOSE_CONFIG_FILES} up -d
                ;;
            scale)
                if [[ ! $VM_NAME_STAR =~ .*#$ ]]; then
                    # lab service is not on this machine for this lab
                    docker-compose ${COMPOSE_CONFIG_FILES} stop lab db weather
                fi
                docker-compose ${COMPOSE_CONFIG_FILES} scale compute=$VM_CORE_CNT
                ;;
            volumesrm)
                docker volume rm $(docker volume ls -q)
                ;;
            danglingrm)
                docker rmi $(docker images -q -f dangling=true)
                docker volume rm $(docker volume ls -q -f dangling=true)
                ;;
            images)
                docker images
                ;;
            checkmysql)
                #~ docker exec -it lab_lab_1 ls /uploads
                docker exec -it lab_lab_1 mysql -v -hmysql -P3306 -uroot -p1qazZAQ! -e "SELECT host FROM mysql.user WHERE User = 'root';"
                ;;
            *)
                echo "unrecognised command: $1" && false
                ;;
        esac
        shift
    done
}

LAB_COMPUTE_MACHINES=
for account in "${LAB_ACCOUNTS[@]}"; do

    source ${A4E_PROJ_ROOT}/infra/tools/keytools.sh
    loadazurekeys ${account}
    #loadstorageenv ${AZURE_STORAGE_NAME}

    ACC_MACHINES_ARR="LAB_MACHINES_${account}[@]"
    ACC_MACHINES_ARR=( "${!ACC_MACHINES_ARR}" )

    TEMPOR="${ACC_MACHINES_ARR[@]##*\#}"
    if [ -n "$TEMPOR" ]; then
        TEMPOR="${AZURE_SUBSCRIPTION_ID} ${AZURE_TENANT} ${AZURE_USERNAME} ${AZURE_SP_PASSWORD} ${AZURE_LAB_RESOURCE_GROUP} ${ACC_MACHINES_ARR[@]##*\#}"
        LAB_COMPUTE_MACHINES="${LAB_COMPUTE_MACHINES}${TEMPOR};"
    fi
done

## We need this in the Lab script that starts VMs: START
#~ MACHINE_CONF=( ${LAB_COMPUTE_MACHINES[1]} )
#~ MACHINE_ARR=( ${MACHINE_CONF[@]:3} )
#~ echo machine arr is: "${MACHINE_ARR[@]}"
#~ echo ${MACHINE_CONF[3]}
#exit 0
## We need this in the Lab script that starts VMs: END

FAIL=0
for account in "${LAB_ACCOUNTS[@]}"; do

    source ${A4E_PROJ_ROOT}/infra/tools/keytools.sh
    loadstorageenv ${AZURE_STORAGE_NAME}
    loadweatherkeys

    export LAB_COMPUTE_MACHINES
    export AZURE_STORAGE_ACCOUNT
    export AZURE_STORAGE_ACCESS_KEY
    export AZURE_STORAGE_QUEUE_REST_URI
    export AZURE_STORAGE_QUEUE_REST_AUTHPARAMS

    ACC_MACHINES_ARR="LAB_MACHINES_${account}[@]"
    ACC_MACHINES_ARR=( "${!ACC_MACHINES_ARR}" )
    for AZURE_LAB_VMNAME in "${ACC_MACHINES_ARR[@]}"; do
    
        MACHINE_SIZE="LAB_MACHINE_SIZES[${AZURE_LAB_VMNAME/\#/}]"
        MACHINE_SIZE="${!MACHINE_SIZE}"

        MACHINE_CORES="LAB_MACHINE_CORES[$MACHINE_SIZE]"
        MACHINE_CORES="${!MACHINE_CORES}"

        MACHINE_LAB_IDX="LAB_INDEXES[${AZURE_LAB_VMNAME/\#/}]"
        MACHINE_LAB_IDX="${!MACHINE_LAB_IDX}"

        composeit $AZURE_LAB_VMNAME $MACHINE_CORES $MACHINE_LAB_IDX "$@" &
    done
    for job in `jobs -p`; do
        wait $job || let "FAIL+=1"
    done
done


echo If this is zero then everything was fine: $FAIL
