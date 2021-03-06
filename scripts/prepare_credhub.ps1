# transfer to powershell
Push-Location $PSScriptRoot
$director_conf = Get-Content $DIRECTOR_CONF_FILE | ConvertFrom-Json
$OM_Target = $director_conf.OM_TARGET
$domain = $director_conf.domain
$PCF_DOMAIN_NAME = $domain
$PCF_SUBDOMAIN_NAME = $director_conf.PCF_SUBDOMAIN_NAME

$RG = $director_conf.RG
#some env´s
$env_vars = Get-Content $HOME/env.json | ConvertFrom-Json
$OM_Password = $env_vars.OM_Password
$OM_Username = $env_vars.OM_Username
$OM_Target = $OM_Target
$env:Path = "$($env:Path);$HOME/OM;$HOME/bosh;$HOME/credhub"
$env_vars = Get-Content $HOME/env.json | ConvertFrom-Json
$PIVNET_UAA_TOKEN = $env_vars.PIVNET_UAA_TOKEN

$ssh_public_key = Get-Content $HOME/opsman.pub
$ssh_private_key = Get-Content $HOME/opsman
$ssh_private_key = $ssh_private_key -join "\r\n"
$ca_cert = Get-Content $HOME/root.pem
$ca_cert = $ca_cert -join "\r\n"

$fullchain = get-content "$($HOME)/$($PCF_SUBDOMAIN_NAME).$($PCF_DOMAIN_NAME).crt"
$fullchain = $fullchain -join "`r`n  "
## READ OM KEYS and CERT wit `n`r ad passed as dos strings
$om_cert = Get-Content "$($HOME)/$($OM_Target).crt"
$om_cert = $om_cert -join "`r`n"

$om_key = get-content "$($HOME)/$($OM_Target).key"
$om_key = $om_key -join "`r`n"

$OM_ENV_FILE = "$HOME/OM_$($director_conf.RG).env"   



$CREDHUB_URL="https://plane.control.westus.stackpoc.com:8844"
$CREDHUB_PASSWORD=(credhub get /name:'/p-bosh/control-plane/credhub_admin_client_password' /j | ConvertFrom-Json).value
$CLIENT_NAME="credhub_admin_client"
$CA_CERT=credhub get /name:'/p-bosh/control-plane/control-plane-tls' -k certificate
credhub login /server:$CREDHUB_URL /client-name:$CLIENT_NAME /client-secret:$credhub_password /skip-tls-validation


credhub set /name:'/concourse/main/$($RG)/tenant-id' /type:value --value ${TF_VAR_tenant_id}
credhub set /name:"/concourse/main/$($RG)/client-id" /type:value --value $($env_vars.AZURE_CLIENT_ID)
credhub set /name:'/concourse/main/$($RG)/client-secret' /type:value --value ${TF_VAR_client_secret}
credhub set /name:'/concourse/main/$($RG)/subscription-id' /type:value --value ${TF_VAR_subscription_id}
credhub set /name:'/concourse/main/$($RG)/pivnet-token' /type:value --value ${PIVNET_UAA_TOKEN}

credhub set /name:'/concourse/main/$($RG)/subnet' /type:value --value $(terraform output management_subnet_name)
credhub set /name:'/concourse/main/$($RG)/vnet' /type:value --value $(terraform output network_name)
credhub set /name:'/concourse/main/$($RG)/ops-manager-private-ip' /type:value --value $(terraform output ops_manager_private_ip)
credhub set /name:'/concourse/main/$($RG)/ops-manager-public-ip' /type:value --value $(terraform output ops_manager_public_ip)
credhub set /name:'/concourse/main/$($RG)/resource-group' /type:value --value $($RG)
credhub set /name:'/concourse/main/$($RG)/foundation' /type:value --value $($RG)
credhub set /name:'/concourse/main/$($RG)/location' /type:value --value ${LOCATION}
credhub set /name:'/concourse/main/$($RG)/ops-manager-dns' /type:value --value $(terraform output ops_manager_dns)