#! /bin/bash

source ${A4E_PROJ_ROOT}/infra/tools/keytools.sh
loadazurekeys TODD
loadstorageenv prod
loadmailingcredentials

export AZURE_DRIVER_VER="v0.5.1"
export AZURE_STORAGE_ACCOUNT
export AZURE_STORAGE_ACCESS_KEY

export VMNAME=swarmtodd2
export PRIVATE_STATIC_IP="192.168.0.11"
export AZURE_AVAILABILITY_SET="swarm-managers"
export AZURE_CLIENT_ID=$AZURE_USERNAME
export AZURE_CLIENT_SECRET=$AZURE_SP_PASSWORD
export AZURE_IMAGE="canonical:UbuntuServer:16.04.0-LTS:latest"
export AZURE_LOCATION="West Europe"
export AZURE_SUBSCRIPTION_ID=$AZURE_SUBSCRIPTION_ID
export AZURE_SIZE="Standard_DS1_V2"
#~ Azure disallows different machine series in the same Availability Set
#~ export AZURE_SIZE="Standard_A0"
export AZURE_DNS_LABEL=$VMNAME
export AZURE_SSH_USER="a4everyone"
export AZURE_RESOURCE_GROUP="a4eprod"
export AZURE_VNET="swarm-managers"
export AZURE_SUBNET_PREFIX="192.168.0.0/24"
export MACHINE_DRIVER=azure

docker-machine create --azure-private-ip-address $PRIVATE_STATIC_IP --azure-open-port 80 --azure-open-port 443 --engine-label com.a4everyone.role=webserver $VMNAME

envsubst < ${A4E_PROJ_ROOT}/infra/tools/install-azure-storage-driver.sh | docker-machine ssh $VMNAME 'bash -s'

docker swarm init
docker network create -d overlay --subnet 10.0.10.0/24 a4e-web
docker network create -d overlay --subnet 10.0.11.0/24 a4e-lab

## PROD
LAB_IDX=2
ENV_IDX=2
NG_WWW=www
NG_IF_BASIC_AUTH="#"
SRV_ENV=prod
WEB_REPLICAS=2
COMPUTE_REPLICAS=4

## STAGE
LAB_IDX=2
ENV_IDX=2
NG_WWW=stage2
NG_IF_BASIC_AUTH=""
SRV_ENV=stage
WEB_REPLICAS=1
COMPUTE_REPLICAS=4

## COMMON
COMMON_PREFIX="${SRV_ENV}${ENV_IDX}"
CERT_KEYFILE=${A4E_PROJ_ROOT}/infra/keys/cert/a4everyone.com.key
CERT_CHAINFILE=${A4E_PROJ_ROOT}/infra/keys/cert/STAR_a4everyone_com.chained.crt
INPUT_QUEUE=requests-${COMMON_PREFIX}
NG_PAGESPEED="#"
LAB_NAME="lab${LAB_IDX}"

source ${A4E_PROJ_ROOT}/infra/tools/keytools.sh && loadstorageenv ${SRV_ENV} && loadmailingcredentials


## TODO
# use --env-file and --secret in docker service create

docker service create --name app --replicas ${WEB_REPLICAS} --with-registry-auth --update-delay 5s \
--mount "type=volume,src=app-work,dst=/opt/tomcat8/apache-tomcat-8.5.3/work/,volume-driver=local" \
--mount "type=volume,src=app-logs,dst=/opt/tomcat8/apache-tomcat-8.5.3/logs/,volume-driver=local" \
--mount "type=volume,src=app-temp,dst=/opt/tomcat8/apache-tomcat-8.5.3/temp/,volume-driver=local" \
--mount "type=volume,src=uploads,dst=/app-uploads,volume-driver=azurefile,volume-opt=share=uploads,volume-opt=gid=1001,volume-opt=filemode=0660,volume-opt=dirmode=0770,readonly=false" \
--mount "type=volume,src=a4e-config,dst=/home/a4e-app/config,volume-driver=azurefile,volume-opt=share=a4e-config,volume-opt=gid=1001,volume-opt=filemode=0660,volume-opt=dirmode=0770,readonly=false" \
--network a4e-web --constraint "node.labels.com.a4everyone.role.webserver == yes" \
-e INPUT_QUEUE="${INPUT_QUEUE}" -e MAIL_USER_RESPONSE="${MAIL_USER_RESPONSE}" -e MAIL_PASS_RESPONSE="${MAIL_PASS_RESPONSE}" \
-e STORAGE_USER_NAME="${AZURE_STORAGE_ACCOUNT}" -e STORAGE_PASS="${AZURE_STORAGE_ACCESS_KEY}" -e SRV_ENV="${SRV_ENV}" \
a4everyone/app:release

docker service create --name web --replicas ${WEB_REPLICAS} --with-registry-auth --update-delay 2s \
--mount "type=volume,src=web-work,dst=/home/a4e-web/ngx-tmp-files/,volume-driver=local" \
--mount "type=volume,src=report-data,dst=/home/a4e-web/html/report/data,volume-driver=azurefile,volume-opt=share=web-reports,volume-opt=gid=1001,volume-opt=filemode=0660,volume-opt=dirmode=0770,readonly=false" \
--network a4e-web --constraint "node.labels.com.a4everyone.role.webserver == yes" \
--publish "80:8001" --publish "443:4443" \
-e NG_WEBHOSTNAME="a4everyone.com" -e NG_WWW="${NG_WWW}." -e NG_IF_BASIC_AUTH="${NG_IF_BASIC_AUTH}" -e NG_FWD_TO_WWW="" -e NG_PAGESPEED="#" \
-e CERT_KEY="$(cat ${CERT_KEYFILE})" \
-e CERT_CHAIN="$(cat ${CERT_CHAINFILE})" \
a4everyone/web:release

docker service create --name conf --replicas 1 --with-registry-auth \
--mount "type=volume,src=conf-log,dst=/home/a4e-conf/log/,volume-driver=local" \
--mount "type=volume,src=a4e-config,dst=/home/config/,volume-driver=azurefile,volume-opt=share=a4e-config,volume-opt=gid=1001,volume-opt=filemode=0660,volume-opt=dirmode=0770,readonly=false" \
--network a4e-web --constraint "node.labels.com.a4everyone.role.webserver == yes" \
-e SRV_ENV="${SRV_ENV}" -e GITHUB_ACCESS_KEY="$(cat ${A4E_PROJ_ROOT}/infra/keys/keys-config/github-a4e-conf-client-rsa)" \
a4everyone/conf:release

docker service create --name lab-db --replicas 1 --with-registry-auth --update-delay 2s --network a4e-lab \
-e MYSQL_ROOT_PASSWORD='1qazZAQ!' \
--mount "type=volume,src=lab-db-files,dst=/mysql-files,volume-driver=azurefile,volume-opt=share=lab-db-files,volume-opt=gid=1001,volume-opt=filemode=0660,volume-opt=dirmode=0770,readonly=false" \
--mount "type=volume,src=lab-db-data,dst=/var/lib/mysql,volume-driver=local" \
--constraint "node.labels.com.a4everyone.role.dbserver == yes" \
a4everyone/lab-db:release

docker service create --name weather --replicas 1 --with-registry-auth --update-delay 2s --network a4e-lab \
-e WEATHER_KEY_HISTORY="${WEATHER_KEY_HISTORY}" \
-e WEATHER_KEY_FORECAST="${WEATHER_KEY_FORECAST}" \
--mount "type=volume,src=weather-work,dst=/home/a4e-weather/work,volume-driver=local" \
--constraint "node.labels.com.a4everyone.role.lab == yes" \
a4everyone/weather:release

docker service create --name "lab-compute${LAB_IDX}" --replicas ${COMPUTE_REPLICAS} --with-registry-auth --update-delay 0s --network a4e-lab \
-e LAB_IDX=${LAB_NAME} \
-e COMMON_PREFIX=${COMMON_PREFIX} \
-e STORAGE_ACC_CONN_STRING="DefaultEndpointsProtocol=https;AccountName=${AZURE_STORAGE_ACCOUNT};AccountKey=${AZURE_STORAGE_ACCESS_KEY}" \
-e PARALLEL_QUEUE_IN=parallel-in-${COMMON_PREFIX}${LAB_NAME} \
-e PARALLEL_QUEUE_OUT=parallel-out-${COMMON_PREFIX}${LAB_NAME} \
-e PARALLEL_EXEC_PATH=/parallel/${COMMON_PREFIX}${LAB_NAME} \
--mount "type=volume,src=parallel,dst=/parallel,volume-driver=azurefile,volume-opt=share=a4elab-parallel,volume-opt=gid=1001,volume-opt=filemode=0660,volume-opt=dirmode=0770,readonly=false" \
--constraint "node.labels.com.a4everyone.role.lab == yes" \
a4everyone/lab-compute:release com.a4e.dataproc.parallel.Worker

docker service create --name "lab${LAB_IDX}" --replicas 1 --with-registry-auth --update-delay 0s --network a4e-lab \
-e LAB_IDX=${LAB_NAME} \
-e COMMON_PREFIX=${COMMON_PREFIX} \
-e STORAGE_ACC_CONN_STRING="DefaultEndpointsProtocol=https;AccountName=${AZURE_STORAGE_ACCOUNT};AccountKey=${AZURE_STORAGE_ACCESS_KEY}" \
-e QUEUE_REST_URI="${AZURE_STORAGE_QUEUE_REST_URI}" \
-e QUEUE_REST_AUTHPARAMS="${AZURE_STORAGE_QUEUE_REST_AUTHPARAMS}" \
-e INPUT_QUEUE=${INPUT_QUEUE} \
-e PARALLEL_QUEUE_IN=parallel-in-${COMMON_PREFIX}${LAB_NAME} \
-e PARALLEL_QUEUE_OUT=parallel-out-${COMMON_PREFIX}${LAB_NAME} \
-e PARALLEL_EXEC_PATH=/parallel/${COMMON_PREFIX}${LAB_NAME} \
-e MYSQL_FILES_PATH=/mysql-files/${COMMON_PREFIX}${LAB_NAME} \
-e MYSQL_SCRIPTS_PATH=/mysql-scripts \
-e EXT_DATA_PATH=/a4r-ext-data \
-e PDFCONVERTER_PATH=/pdfconv \
-e CONFIG_PATH=/a4e-config \
-e OUT_PREFIX=auto- \
-e UPLOADS_PATH=/uploads \
-e OUTPUT_PATH=/output/${COMMON_PREFIX}${LAB_NAME} \
-e INPUT_PATH=/input/${COMMON_PREFIX}${LAB_NAME} \
-e LOGS_PATH=/logs/${COMMON_PREFIX}${LAB_NAME} \
-e A4ECONF_PATH=/a4e-config \
-e REPORT_DATA_PATH=/report-data \
-e LAB_DB_ADDR=lab-db \
-e AGGREG_DB_ADDR=10.1.1.50
-e AGGREG_DB_USER=aggregator
-e AGGREG_DB_PASSWORD=aggregator2
--mount "type=volume,src=lab-db-files,dst=/mysql-files,volume-driver=azurefile,volume-opt=share=lab-db-files,volume-opt=gid=1001,volume-opt=filemode=0660,volume-opt=dirmode=0770,readonly=false" \
--mount "type=volume,src=mysql-scripts,dst=/mysql-scripts/,volume-driver=local" \
--mount "type=volume,src=output,dst=/output/,volume-driver=azurefile,volume-opt=share=a4elab-output,volume-opt=gid=1001,volume-opt=filemode=0660,volume-opt=dirmode=0770,readonly=false" \
--mount "type=volume,src=parallel,dst=/parallel/,volume-driver=azurefile,volume-opt=share=a4elab-parallel,volume-opt=gid=1001,volume-opt=filemode=0660,volume-opt=dirmode=0770,readonly=false" \
--mount "type=volume,src=uploads,dst=/uploads/,volume-driver=azurefile,volume-opt=share=uploads,volume-opt=gid=1001,volume-opt=filemode=0660,volume-opt=dirmode=0770,readonly=false" \
--mount "type=volume,src=input,dst=/input/,volume-driver=azurefile,volume-opt=share=a4elab-input,volume-opt=gid=1001,volume-opt=filemode=0660,volume-opt=dirmode=0770,readonly=false" \
--mount "type=volume,src=logs,dst=/logs/,volume-driver=azurefile,volume-opt=share=a4elab-logs,volume-opt=gid=1001,volume-opt=filemode=0660,volume-opt=dirmode=0770,readonly=false" \
--mount "type=volume,src=extdata,dst=/a4r-ext-data,volume-driver=azurefile,volume-opt=share=external-data,volume-opt=gid=1001,volume-opt=filemode=0660,volume-opt=dirmode=0770,readonly=false" \
--mount "type=volume,src=pdfconv,dst=/pdfconv,volume-driver=azurefile,volume-opt=share=pdfconverterbucket,volume-opt=gid=1001,volume-opt=filemode=0660,volume-opt=dirmode=0770,readonly=false" \
--mount "type=volume,src=report-data,dst=/report-data/,volume-driver=azurefile,volume-opt=share=web-reports,volume-opt=gid=1001,volume-opt=filemode=0660,volume-opt=dirmode=0770,readonly=false" \
--mount "type=volume,src=a4e-config,dst=/a4e-config/,volume-driver=azurefile,volume-opt=share=a4e-config,volume-opt=gid=1001,volume-opt=filemode=0660,volume-opt=dirmode=0770,readonly=false" \
--constraint "node.labels.com.a4everyone.role.lab == yes" \
a4everyone/lab:release

## DEV

CERT_KEYFILE=${A4E_PROJ_ROOT}/infra/website/web/cert/localhost.key
CERT_CHAINFILE=${A4E_PROJ_ROOT}/infra/website/web/cert/STAR_localhost.chained.crt

docker service create --name web --replicas 1 --update-delay 2s --network a4e-web \
--publish "80:8001" --publish "443:4443" \
--mount "type=bind,src=${A4E_PROJ_ROOT}/website/DocPad/a4e_webapp/out,dst=/home/a4e-web/html/" \
--mount "type=bind,src=${A4E_PROJ_ROOT}/volumes/report-data,dst=/home/a4e-web/html/report/data" \
-e NG_WEBHOSTNAME="localhost" -e NG_WWW="" -e NG_IF_BASIC_AUTH="#" -e NG_FWD_TO_WWW="#" -e NG_PAGESPEED="#" -e NG_IF_HSTS="#" \
--secret source=a4e_cert_chain_v0003,target=a4e_cert_chain --secret source=a4e_cert_key_v0002,target=a4e_cert_key \
a4everyone/web:release
#~ --mount "type=bind,src=${A4E_PROJ_ROOT}/website/DocPad/a4e_webapp/out/,dst=/home/a4e-web/html/"

source ${A4E_PROJ_ROOT}/infra/tools/keytools.sh
loadstorageenv stage
loadmailingcredentials
loadweatherkeys

docker service create --name app --replicas 1 --update-delay 5s --network a4e-web \
--publish 8002:8001 \
-e INPUT_QUEUE="lab-in-devpato" -e MAIL_USER_RESPONSE="${MAIL_USER_RESPONSE}" -e MAIL_PASS_RESPONSE="${MAIL_PASS_RESPONSE}" \
-e STORAGE_USER_NAME="${AZURE_STORAGE_ACCOUNT}" -e STORAGE_PASS="${AZURE_STORAGE_ACCESS_KEY}" -e SRV_ENV="stage" \
--mount "type=bind,src=${A4E_PROJ_ROOT}/config/,dst=/home/a4e-app/config/cms/" \
--mount "type=bind,src=${A4E_PROJ_ROOT}/volumes/uploads,dst=/app-uploads/" \
a4everyone/app:release debug

docker service create --name conf --replicas 1 \
--mount "type=volume,src=conf-log,dst=/home/a4e-conf/log/,volume-driver=local" \
--mount "type=bind,src=${A4E_PROJ_ROOT}/volumes/config,dst=/home/config/" \
--network a4e-web \
-e SRV_ENV="stage" -e GITHUB_ACCESS_KEY="$(cat ${A4E_PROJ_ROOT}/infra/keys/keys-config/github-a4e-conf-client-rsa)" \
a4everyone/conf:release

docker service create --name lab-db --replicas 1 --update-delay 2s --network a4e-lab \
--publish "3306:3306" \
-e MYSQL_ROOT_PASSWORD='1qazZAQ!' \
--mount "type=bind,src=${A4E_PROJ_ROOT}/infra/images/lab-db/conf/,dst=/etc/mysql/conf.d/" \
--mount "type=bind,src=${A4E_PROJ_ROOT}/volumes/mysql-files,dst=/mysql-files" \
--mount "type=bind,src=${A4E_PROJ_ROOT}/volumes/mysql-data,dst=/mysql-data" \
a4everyone/lab-db:release

docker service create --name weather --replicas 1 --update-delay 2s --network a4e-lab \
-e WEATHER_KEY_HISTORY="${WEATHER_KEY_HISTORY}" \
-e WEATHER_KEY_FORECAST="${WEATHER_KEY_FORECAST}" \
--mount "type=bind,src=${A4E_PROJ_ROOT}/volumes/weather-work,dst=/home/a4e-weather/work" \
a4everyone/weather:release

docker service create --name lab-compute --replicas 1 --update-delay 0s --network a4e-lab \
-e LAB_IDX=${LAB_NAME} \
-e COMMON_PREFIX=dev \
-e STORAGE_ACC_CONN_STRING="DefaultEndpointsProtocol=https;AccountName=${AZURE_STORAGE_ACCOUNT};AccountKey=${AZURE_STORAGE_ACCESS_KEY}" \
-e PARALLEL_QUEUE_IN=parallel-in-dev${LAB_NAME} \
-e PARALLEL_QUEUE_OUT=parallel-out-dev${LAB_NAME} \
-e PARALLEL_EXEC_PATH=/parallel/dev${LAB_NAME} \
--mount "type=bind,src=${A4E_PROJ_ROOT}/infra/images/lab-compute/startup,dst=/home/a4everyone/startup" \
--mount "type=bind,src=${A4E_PROJ_ROOT}/infra/images/lab-compute/.build/lib/java,dst=/home/a4everyone/a4r-java/" \
--mount "type=bind,src=${A4E_PROJ_ROOT}/volumes/parallel,dst=/parallel" \
a4everyone/lab-compute:release com.a4e.dataproc.parallel.Worker

docker service create --name lab --replicas 1 --update-delay 0s --network a4e-lab \
-e LAB_IDX=${LAB_NAME} \
-e COMMON_PREFIX=dev \
-e STORAGE_ACC_CONN_STRING="DefaultEndpointsProtocol=https;AccountName=${AZURE_STORAGE_ACCOUNT};AccountKey=${AZURE_STORAGE_ACCESS_KEY}" \
-e QUEUE_REST_URI="${AZURE_STORAGE_QUEUE_REST_URI}" \
-e QUEUE_REST_AUTHPARAMS="${AZURE_STORAGE_QUEUE_REST_AUTHPARAMS}" \
-e INPUT_QUEUE=lab-in-dev${LAB_NAME} \
-e PARALLEL_QUEUE_IN=parallel-in-dev${LAB_NAME} \
-e PARALLEL_QUEUE_OUT=parallel-out-dev${LAB_NAME} \
-e PARALLEL_EXEC_PATH=/parallel/dev${LAB_NAME} \
-e DEV_ENV=true \
-e MYSQL_FILES_PATH=/mysql-files \
-e MYSQL_SCRIPTS_PATH=/mysql-scripts \
-e EXT_DATA_PATH=/a4r-ext-data \
-e PDFCONVERTER_PATH=/pdfconv \
-e CONFIG_PATH=/a4e-config \
-e OUT_PREFIX=auto- \
-e UPLOADS_PATH=/uploads \
-e OUTPUT_PATH=/output/dev${LAB_NAME} \
-e INPUT_PATH=/input/dev${LAB_NAME} \
-e LOGS_PATH=/logs/dev${LAB_NAME} \
-e A4ECONF_PATH=/a4e-config \
-e REPORT_DATA_PATH=/report-data \
-e LAB_DB_ADDR=lab-db \
--mount "type=bind,src=${A4E_PROJ_ROOT}/infra/images/lab/conf/,dst=/home/a4everyone/a4r-conf/" \
--mount "type=bind,src=${A4E_PROJ_ROOT}/infra/images/lab/startup/,dst=/home/a4everyone/startup/" \
--mount "type=bind,src=${A4E_PROJ_ROOT}/infra/images/lab-compute/.build/lib/java,dst=/home/a4everyone/a4r-java/" \
--mount "type=bind,src=${A4E_PROJ_ROOT}/lab/external-data/,dst=/a4r-ext-data/" \
--mount "type=bind,src=${A4E_PROJ_ROOT}/lab/scripts/,dst=/home/a4everyone/a4r-scripts/" \
--mount "type=bind,src=${A4E_PROJ_ROOT}/lab/math-exec/,dst=/home/a4everyone/a4r-maths/" \
--mount "type=bind,src=${A4E_PROJ_ROOT}/lab/command/,dst=/home/a4everyone/a4r-command/" \
--mount "type=bind,src=${A4E_PROJ_ROOT}/config/,dst=/a4e-config/cms/" \
--mount "type=bind,src=${A4E_PROJ_ROOT}/volumes/report-data/,dst=/report-data/" \
--mount "type=bind,src=${A4E_PROJ_ROOT}/volumes/parallel/,dst=/parallel/" \
--mount "type=bind,src=${A4E_PROJ_ROOT}/volumes/mysql-files/,dst=/mysql-files/" \
--mount "type=bind,src=${A4E_PROJ_ROOT}/volumes/mysql-scripts/,dst=/mysql-scripts/" \
--mount "type=bind,src=${A4E_PROJ_ROOT}/volumes/input/,dst=/input/" \
--mount "type=bind,src=${A4E_PROJ_ROOT}/volumes/output/,dst=/output/" \
--mount "type=bind,src=${A4E_PROJ_ROOT}/volumes/logs/,dst=/logs/" \
--mount "type=bind,src=${A4E_PROJ_ROOT}/volumes/uploads/,dst=/uploads/" \
--mount "type=bind,src=${A4E_PROJ_ROOT}/volumes/lab-conf-runtime/,dst=/home/a4everyone/a4r-conf-runtime/" \
a4everyone/lab:release


# TODO
# Aux data files - fill for 2017
# Submission should be named ORDER_STRATEGY, not NEDELYA_ORDER_STRATEGY
# Order strategy executed on proper trigger, not crontab in the image
# declarative description of infrastructure
# ansible to maintain machine upgrades?
# dynbamic lab machine powerup/down
# versioned docker images - build and deploy
# ARM template for the IP and LB

# pdfgen - mount the new storage account
# ftp service - in swarm
# Script that creates public IP, creates LB and its probes, backend pools and rules
# Weather cache - in volume
# Remove separation between lab and web
# Dev Env: utilise virtualbox
# Log to syslog server


docker service create --name cas1 --replicas 1 --with-registry-auth --network dbmesh --constraint "node.labels.com.a4e.role == db1" \
-e CASSANDRA_CLUSTER_NAME=testcas -e CASSANDRA_NUM_TOKENS=256 -e CASSANDRA_DC=uchino -e CASSANDRA_RACK=rack1 -e CASSANDRA_ENDPOINT_SNITCH=GossipingPropertyFileSnitch \
--mount "type=volume,src=cassandra,dst=/var/lib/cassandra,volume-driver=local" \
--endpoint-mode dnsrr \
cassandra

docker service create --name cas2 --replicas 1 --with-registry-auth --network dbmesh --constraint "node.labels.com.a4e.role == db2" \
-e CASSANDRA_CLUSTER_NAME=testcas -e CASSANDRA_NUM_TOKENS=256 -e CASSANDRA_DC=uchino -e CASSANDRA_RACK=rack2 -e CASSANDRA_ENDPOINT_SNITCH=GossipingPropertyFileSnitch \
-e CASSANDRA_SEEDS=cas1 \
--mount "type=volume,src=cassandra,dst=/var/lib/cassandra,volume-driver=local" \
cassandra
--publish "9043:9042" \
--endpoint-mode dnsrr \

docker service create --name cas3 --replicas 1 --with-registry-auth --network dbmesh --constraint "node.labels.com.a4e.role == db3" \
-e CASSANDRA_CLUSTER_NAME=testcas -e CASSANDRA_NUM_TOKENS=256 -e CASSANDRA_DC=uchino -e CASSANDRA_RACK=rack3 -e CASSANDRA_ENDPOINT_SNITCH=GossipingPropertyFileSnitch \
-e CASSANDRA_SEEDS=cas1 \
--mount "type=volume,src=cassandra,dst=/var/lib/cassandra,volume-driver=local" \
--publish "9042:9042" \
cassandra
--endpoint-mode dnsrr \


docker volume create -d azurefile \
  -o share=sharename \
  -o uid=999 \
  -o gid=999 \
  -o filemode=0600 \
  -o dirmode=0755 \
  -o nolock=true \
  -o remotepath=directory
