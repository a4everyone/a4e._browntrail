source keytools.sh
loadazurekeys $1

AD_APP_NAME=labmanager

azure config mode arm
azure login
azure account set ${AZURE_SUBSCRIPTION_ID}

azure ad app create --name "$AD_APP_NAME" --home-page "https://a4everyone.com" --identifier-uris "https://a4everyone.com/id" --password ${AZURE_SP_PASSWORD}

azure ad sp create $(azure ad app show --search $AD_APP_NAME --json | jq -r '.[0].appId')
 
sleep 10
azure role assignment create --objectId $(azure ad sp list --json | jq -r '.[] | select(."displayName" == "'$AD_APP_NAME'" ) | .objectId') -o Contributor -c /subscriptions/${AZURE_SUBSCRIPTION_ID}/

#~ AZURE_EFREMOV_USERNAME=a7d28be5-451c-4831-83cd-34abdbb0c25f
#~ AZURE_EFREMOV_TENANT=9f25e7db-3da2-43a0-a0a6-e98cd176e97e

echo -e AZURE_$1_USERNAME=$(azure ad app show --search $AD_APP_NAME --json | jq -r '.[0].appId')
echo -e AZURE_$1_TENANT=$(azure account show -s ${AZURE_SUBSCRIPTION_ID} --json | jq -r '.[0].tenantId')
echo -e "azure login -u $(azure ad app show --search $AD_APP_NAME --json | jq -r '.[0].appId') --service-principal --tenant $(azure account show -s ${AZURE_SUBSCRIPTION_ID} --json | jq -r '.[0].tenantId') -p ${AZURE_SP_PASSWORD}"
