#!/bin/bash
## experimental release to upgrade opsman
# current opsman: ger it with 'om curl --path /api/v0/info -s | jq -r .info.version'
####
###
#
#
#
opsManVHD="ops-manager-2.8.2-build.203.vhd"
az storage blob copy start --destination-blob ${opsManVHD} --destination-container images \
 --account-name opsmanagerimage \
 --source-uri https://opsmanagerwesteurope.blob.core.windows.net/images/${opsManVHD}
#
######
om export-installation --output-file opsman.exp

OPS_MAN_VHD=$(az storage blob list --container-name images --account-name opsmanagerimage --query "[?contains(name, 'ops-manager')].name"  --output tsv | sort -r --version-sort | head -1)

OPS_MAN_RELEASE=$(echo $OPS_MAN_VHD | egrep -o '[0-9]+.*-build.[0-9]+')
OPS_MAN_RELEASE=${OPS_MAN_RELEASE%'.vhd'}
echo ${OPS_MAN_RELEASE}


opsManVHD="ops-manager-${OPS_MAN_RELEASE}"
OPSMAN_IMAGE="${IMAGE_LOCATION}/${OPS_MAN_VHD}"






az group deployment validate --resource-group ${AZS_RESOURCE_GROUP} \
    --template-uri "https://raw.githubusercontent.com/bottkars/pcf-controlplane-azurestack/testing/azuredeploy_update.json" \
    --parameters \
    sshKeyData="$(ssh-keygen -y -f plane/env/opsman.key)" \
    opsManVHD=${opsManVHD} \
    mask=${MASK} \
    location=${AZS_LOCATION} \
    OpsManImageURI=${OPSMAN_IMAGE}

az vm delete --name ops_man_vm --resource-group ${AZS_RESOURCE_GROUP} --yes

az group deployment create --resource-group ${AZS_RESOURCE_GROUP} \
    --template-uri "https://raw.githubusercontent.com/bottkars/pcf-controlplane-azurestack/testing/azuredeploy_update.json" \
    --parameters \
    sshKeyData="$(ssh-keygen -y -f plane/env/opsman.key)" \
    opsManVHD=${opsManVHD} \
    mask=${MASK} \
    location=${AZS_LOCATION} \
    OpsManImageURI=${OPSMAN_IMAGE}




az storage blob copy start --destination-blob ${opsManVHD} --destination-container images \
 --account-name opsmanagerimage \
 --source-uri "https://images.blob.sc2.azurestack-rd.cf-app.com/images/ops-manager-2.8.2-build.203.vhd?sv=2017-04-17&ss=bqt&srt=sco&sp=rwdlacup&se=2020-01-24T23:17:11Z&st=2020-01-24T15:17:11Z&spr=https&sig=QdAObjF2ASAf1QxI7PNeFtzwHRKLP7hRwmZB%2FSguuLA%3D"    
