#!/bin/bash

IMAGE_CONTAINER=images
IMAGE_ACCOUNT=opsmanagerimage
OPS_MAN_NIC=OPSMANNIC
opsManVHD="ops-manager-2.10.3-build.127.vhd"

#
######
if [[ ! $( az storage blob show --account-name ${IMAGE_ACCOUNT} --name ${opsManVHD} \
 --container-name ${IMAGE_CONTAINER}) ]]
then
  echo "Blob ${opsManVHD} not found, need to copy"
 az storage blob copy start --destination-blob ${opsManVHD} --destination-container ${IMAGE_CONTAINER} \
    --account-name ${IMAGE_ACCOUNT} \
    --source-uri "https://opsmanagerwesteurope.blob.core.windows.net/images/${opsManVHD}"
fi  


echo "Querying Blob Copy Status"

until az storage blob show \
	--name ${opsManVHD}\
	--container-name ${IMAGE_CONTAINER} \
	--account-name ${IMAGE_ACCOUNT} \
	--output json --query "[properties.copy.status=='success']" \
	2>/dev/null 
	do
		printf '.'
		sleep 5
	done

#####
OPS_MAN_VHD=$(az storage blob list --container-name ${IMAGE_CONTAINER} --account-name ${IMAGE_ACCOUNT} --query "[?contains(name, 'ops-manager')].name"  --output tsv | sort -r --version-sort | head -1)
OPS_MAN_RELEASE=$(echo $OPS_MAN_VHD | egrep -o '[0-9]+.*-build.[0-9]+')
OPS_MAN_RELEASE=${OPS_MAN_RELEASE%'.vhd'}
echo "${OPS_MAN_RELEASE}"


om export-installation --output-file opsman.exp

az vm delete --name ops-man-vm \
  --resource-group "${AZS_RESOURCE_GROUP}" -y

az image create --resource-group "${AZS_RESOURCE_GROUP}" \
--name "${OPS_MAN_RELEASE}" \
--source "${IMAGE_LOCATION}/${opsManVHD}" \
--location "${AZS_LOCATION}" \
--os-type Linux

chmod 600 "${DEPLOYMENT}/env/opsman.key"

az vm create --name ops-man-vm --resource-group "${AZS_RESOURCE_GROUP}" \
 --location "${AZS_LOCATION}" \
 --nics "${OPS_MAN_NIC}" \
 --image "${OPS_MAN_RELEASE} "\
 --os-disk-name "${OPS_MAN_RELEASE}-osdisk" \
 --admin-username ubuntu \
 --os-disk-size-gb 127 \
 --size Standard_DS2_v2 \
 --storage-sku Standard_LRS \
 --ssh-key-value "$(ssh-keygen -y -f ${DEPLOYMENT}/env/opsman.key)"

om import-installation --installation opsman.exp

om apply-changes --skip-deploy-products
