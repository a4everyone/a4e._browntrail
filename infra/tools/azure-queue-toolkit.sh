#! /bin/bash

CURRDIR=$(readlink -f ${BASH_SOURCE[0]})
CURRDIR=$(dirname $CURRDIR)

AZURE_API_VERSION=2016-03-30

source ${CURRDIR}/keytools.sh

# Usage: peek storagename queuename nummessages
function get_message_count {
	#~ set -e
	local accountName=$1
	local queueName=$2
	
	loadstorageenv $accountName
	
	local peekResp=$(curl -sX GET \
	-H "Content-Length: 0" \
	-H "x-ms-date: $(date -Ru | sed s/+0000/GMT/)" \
	"${AZURE_STORAGE_QUEUE_REST_URI}/${queueName}/messages?peekonly=true&numofmessages=${3:-1}&${AZURE_STORAGE_QUEUE_REST_AUTHPARAMS}")
	#~ if [ $? -eq 0 ]; then
	grep -o '<MessageId>' <<< ${peekResp} | wc -l
	#~ fi
    #~ set +e
}

function get_machine_status {
	
	#~ set -e
	local subAccountName=$1
	local rgName=$2
	local vmName=$3
	
	loadazurekeys $subAccountName
	
	get_auth_token $subAccountName
	
	local stateResp=$(curl -sX GET \
            -H "Content-Length: 0" \
            -H "Authorization: Bearer ${AZURE_ACCESS_TOKEN}" \
            https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${rgName}/providers/Microsoft.Compute/virtualMachines/${vmName}/InstanceView?api-version=${AZURE_API_VERSION})
	#~ echo RESP "${stateResp}"
	jq -r '[.statuses[].code] | map(select(test("PowerState.*")))[]' <<< ${stateResp}
 
	#~ .statuses | map(.code) | map(select(test("Provision")))[]
	#~ [.statuses[].code] | map(select(test("Provisioning.*")))[]
            #~ PowerState/deallocated
            #~ PowerState/running
            #~ PowerState/starting
            #~ PowerState/deallocating
            
      #~ ProvisioningState/updating

    #~ set +e
}

function get_auth_token {
	
	loadazurekeys $1
	AZURE_ACCESS_TOKEN=$(\
curl -sX POST https://login.windows.net/${AZURE_TENANT}/oauth2/token \
--data "resource=https://management.core.windows.net/&client_id=${AZURE_USERNAME}&grant_type=client_credentials&client_secret=${AZURE_SP_PASSWORD}" | \
jq -r ."access_token")

}
