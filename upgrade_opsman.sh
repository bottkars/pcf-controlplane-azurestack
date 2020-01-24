#!/bin/bash
## experimental release to upgrade opsman
az vm delete --name ops_man_vm --resource-group ${AZS_RESOURCE_GROUP} --yes


OPS_MAN_RELEASE="2.8.2-build.203"


opsManVHD="ops-manager-${OPS_MAN_RELEASE}"
OPSMAN_IMAGE="${IMAGE_LOCATION}/ops-manager-${OPS_MAN_RELEASE}.vhd"



az group deployment validate --resource-group ${AZS_RESOURCE_GROUP} \
    --template-uri "https://raw.githubusercontent.com/bottkars/pcf-controlplane-azurestack/testing/azuredeploy_update.json" \
    --parameters \
    sshKeyData="$(cat ./ssh/opsman.key)" \
    opsManVHD=${opsManVHD} \
    mask=${MASK} \
    location=${AZS_LOCATION} \
    OpsManImageURI=${OPSMAN_IMAGE}


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
