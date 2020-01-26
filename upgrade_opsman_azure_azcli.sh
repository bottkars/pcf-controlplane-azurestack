#!/bin/bash
opsManVHD="ops-manager-2.8.2-build.203.vhd"
az storage blob copy start --destination-blob ${opsManVHD} --destination-container ${IMAGE_CONTAINER} \
 --account-name ${IMAGE_ACCOUNT} \
 --source-uri https://opsmanagerwesteurope.blob.core.windows.net/images/${opsManVHD}
#
######

 az storage blob show --account-name ${IMAGE_ACCOUNT} --name ${opsManVHD} \                                  bottk@SurfaceBook3
 --container-name ${IMAGE_CONTAINER}

echo "Querying Blob Copy Status"
while [ $(az storage blob show \
 --name ${opsManVHD}\
 --container-name ${IMAGE_CONTAINER} \
 --account-name ${IMAGE_ACCOUNT} \
 --query '[properties.copy.status]' --output tsv) != "success" ]
do
printf '.'
sleep 5
done

#####
OPS_MAN_VHD=$(az storage blob list --container-name ${IMAGE_CONTAINER} --account-name ${IMAGE_ACCOUNT} --query "[?contains(name, 'ops-manager')].name"  --output tsv | sort -r --version-sort | head -1)
OPS_MAN_RELEASE=$(echo $OPS_MAN_VHD | egrep -o '[0-9]+.*-build.[0-9]+')
OPS_MAN_RELEASE=${OPS_MAN_RELEASE%'.vhd'}
echo ${OPS_MAN_RELEASE}


om export-installation --output-file opsman.exp

az vm delete --name ${AZS_RESOURCE_GROUP}-ops-manager-vm \
  --resource-group ${AZS_RESOURCE_GROUP} -y

az image create --resource-group ${AZS_RESOURCE_GROUP} \
--name ${OPS_MAN_RELEASE} \
--source "${IMAGE_LOCATION}/${opsManVHD}" \
--location ${AZS_LOCATION} \
--os-type Linux


az vm create --name ops-man-vm --resource-group ${AZS_RESOURCE_GROUP} \
 --location ${AZS_LOCATION} \
 --nics ${AZS_RESOURCE_GROUP}-ops-manager-nic \
 --image ${OPS_MAN_RELEASE} \
 --os-disk-name ${OPS_MAN_RELEASE}-osdisk \
 --admin-username ubuntu \
 --os-disk-size-gb 127 \
 --size Standard_DS2_v2 \
 --storage-sku StandardSSD_LRS \
 --ssh-key-value "$(ssh-keygen -y -f plane/env/opsman.key)"

om import-installation --installation opsman.exp

om update-ssl-certificate \
    --certificate-pem "$(cat ${HOME_DIR}/fullchain.cer)" \
    --private-key-pem "$(cat ${HOME_DIR}/${CONTROLPLANE_SUBDOMAIN_NAME}.${CONTROLPLANE_DOMAIN_NAME}.key)"

om apply-changes --skip-deploy-products