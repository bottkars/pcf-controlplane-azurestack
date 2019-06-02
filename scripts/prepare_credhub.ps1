# transfer to powershell

# credhub login 


credhub set --name /concourse/main/${ENV_NAME}/tenant-id --type value --value ${TF_VAR_tenant_id}
credhub set --name /concourse/main/${ENV_NAME}/client-id --type value --value ${TF_VAR_client_id}
credhub set --name /concourse/main/${ENV_NAME}/client-secret --type value --value ${TF_VAR_client_secret}
credhub set --name /concourse/main/${ENV_NAME}/subscription-id --type value --value ${TF_VAR_subscription_id}
credhub set --name /concourse/main/${ENV_NAME}/pivnet-token --type value --value ${PIVNET_UAA_TOKEN}

credhub set --name /concourse/main/${ENV_NAME}/subnet --type value --value $(terraform output management_subnet_name)
credhub set --name /concourse/main/${ENV_NAME}/vnet --type value --value $(terraform output network_name)
credhub set --name /concourse/main/${ENV_NAME}/ops-manager-private-ip --type value --value $(terraform output ops_manager_private_ip)
credhub set --name /concourse/main/${ENV_NAME}/ops-manager-public-ip --type value --value $(terraform output ops_manager_public_ip)
credhub set --name /concourse/main/${ENV_NAME}/resource-group --type value --value ${ENV_NAME}
credhub set --name /concourse/main/${ENV_NAME}/foundation --type value --value ${ENV_NAME}
credhub set --name /concourse/main/${ENV_NAME}/location --type value --value ${LOCATION}
credhub set --name /concourse/main/${ENV_NAME}/ops-manager-dns --type value --value $(terraform output ops_manager_dns)