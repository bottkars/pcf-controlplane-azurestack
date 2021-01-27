#!/bin/bash

IMAGE_CONTAINER=images
IMAGE_ACCOUNT=opsmanagerimage
OPSMAN_NIC=OPSMANNIC
OPSMAN_VMNAME=ops_man_vm
OPSMAN_VHD="ops-manager-2.10.5-build.147.vhd"

#
######
if [[ ! $( az storage blob show --account-name ${IMAGE_ACCOUNT} --name ${OPSMAN_VHD} \
 --container-name ${IMAGE_CONTAINER}) ]]
then
  echo "Blob ${OPSMAN_VHD} not found, need to copy"
 az storage blob copy start --destination-blob ${OPSMAN_VHD} --destination-container ${IMAGE_CONTAINER} \
    --account-name ${IMAGE_ACCOUNT} \
    --source-uri "https://opsmanagerwesteurope.blob.core.windows.net/images/${OPSMAN_VHD}"
fi  


echo "Querying Blob Copy Status"

until az storage blob show \
	--name ${OPSMAN_VHD}\
	--container-name ${IMAGE_CONTAINER} \
	--account-name ${IMAGE_ACCOUNT} \
	--output json --query "[properties.copy.status=='success']" \
	2>/dev/null 
	do
		printf '.'
		sleep 5
	done

#####
OPSMAN_VHD=$(az storage blob list --container-name ${IMAGE_CONTAINER} --account-name ${IMAGE_ACCOUNT} --query "[?contains(name, 'ops-manager')].name"  --output tsv | sort -r --version-sort | head -1)
OPSMAN_RELEASE=$(echo $OPSMAN_VHD | egrep -o '[0-9]+.*-build.[0-9]+')
OPSMAN_RELEASE=${OPSMAN_RELEASE%'.vhd'}
echo "${OPSMAN_RELEASE}"


om export-installation --output-file opsman.exp

az vm delete --name ${OPSMAN_VMNAME} \
  --resource-group "${AZS_RESOURCE_GROUP}" -y

az image create --resource-group "${AZS_RESOURCE_GROUP}" \
--name "${OPSMAN_RELEASE}" \
--source "${IMAGE_LOCATION}/${OPSMAN_VHD}" \
--location "${AZS_LOCATION}" \
--os-type Linux

chmod 600 "${DEPLOYMENT}/env/opsman.key"

az vm create --name ${OPSMAN_VMNAME} --resource-group "${AZS_RESOURCE_GROUP}" \
 --location "${AZS_LOCATION}" \
 --nics "${OPSMAN_NIC}" \
 --image "${OPSMAN_RELEASE} "\
 --os-disk-name "${OPSMAN_RELEASE}-osdisk" \
 --admin-username ubuntu \
 --os-disk-size-gb 127 \
 --size Standard_DS2_v2 \
 --storage-sku Standard_LRS \
 --ssh-key-value "$(ssh-keygen -y -f ${DEPLOYMENT}/env/opsman.key)"

om import-installation --installation opsman.exp

om apply-changes --skip-deploy-products
