#requires -module pivposh
param(
    [Parameter(Mandatory = $true)]	
    [Validatescript( {Test-Path -Path $_ })]
    $DIRECTOR_CONF_FILE,

    [Parameter(Mandatory = $false)]
    [switch]
    $DO_NOT_APPLY
)
Push-Location $PSScriptRoot
$director_conf = Get-Content $DIRECTOR_CONF_FILE | ConvertFrom-Json
$OM_Target = $director_conf.OM_TARGET
$domain = $director_conf.domain
$PCF_DOMAIN_NAME = $domain
$PCF_SUBDOMAIN_NAME = $director_conf.PCF_SUBDOMAIN_NAME

$boshstorageaccountname = $director_conf.boshstorageaccountname
$RG = $director_conf.RG
$local_control="$HOME/control/$RG"
New-Item -ItemType Directory $local_control -Force | Out-Null

$deploymentstorageaccount = $director_conf.deploymentstorageaccount
$plane_cidr = $director_conf.plane_cidr
$plane_range = $director_conf.plane_range
$plane_gateway = $director_conf.plane_gateway
$infrastructure_range = $director_conf.infrastructure_range
$infrastructure_cidr = $director_conf.infrastructure_cidr
$infrastructure_gateway = $director_conf.infrastructure_gateway
#some env´s
$env_vars = Get-Content $HOME/env.json | ConvertFrom-Json
$OM_Password = $env_vars.OM_Password
$OM_Username = $env_vars.OM_Username
$OM_Target = $OM_Target
$env:Path = "$($env:Path);$HOME/OM"

$PIVNET_UAA_TOKEN = $env_vars.PIVNET_UAA_TOKEN
$ntp_servers_string = $env_vars.NTP_SERVERS_STRING

$env_vars = Get-Content $HOME/env.json | ConvertFrom-Json
$PIVNET_UAA_TOKEN = $env_vars.PIVNET_UAA_TOKEN

$ssh_public_key = Get-Content $HOME/opsman.pub
$ssh_private_key = Get-Content $HOME/opsman
$ssh_private_key = $ssh_private_key -join "\r\n"
$ca_cert = Get-Content $HOME/root.pem
$ca_cert = $ca_cert -join "\r\n"

$fullchain = get-content "$($HOME)/$($PCF_SUBDOMAIN_NAME).$($PCF_DOMAIN_NAME).crt"
$fullchain = $fullchain -join "\r\n"
## READ OM KEYS and CERT wit `n`r ad passed as dos strings
$om_cert = Get-Content "$($HOME)/$($OM_Target).crt"
$om_cert = $om_cert -join "`r`n"

$om_key = get-content "$($HOME)/$($OM_Target).key"
$om_key = $om_key -join "`r`n"

$OM_ENV_FILE = "$HOME/OM_$($director_conf.RG).env"   

"
---
target: $OM_Target
connect-timeout: 30          # default 5
request-timeout: 3600        # default 1800
skip-ssl-validation: true   # default false
username: $OM_USERNAME
password: $OM_PASSWORD
decryption-passphrase: $PIVNET_UAA_TOKEN
" | Set-Content $OM_ENV_FILE

        Write-Host "Creating OM Environment $OM_ENV_FILE"


$content = get-content "../templates/director_vars.yml"
$content += "authentication: $($director_conf.Authentication)"
$content += "default_security_group: $RG-bosh-deployed-vms-security-group"
$content += "subscription_id: $((Get-AzureRmContext).Subscription.Id)"
$content += "tenant_id: $((Get-AzureRmContext).Tenant.Id)"
$content += "client_id: $($env_vars.client_id)"
$content += "client_secret: $($env_vars.client_secret)"
$content += "domain: $domain"
$content += "fullchain: `"$fullchain`""
$content += "deployments_storage_account_name: `"$deploymentstorageaccount`""
$content += "resource_group_name: $RG"
$content += "bosh_storage_account_name: $boshstorageaccountname"
$content += "ntp_servers_string: $ntp_servers_string"
$content += "ressource: $((Get-AzureRmContext).Environment.ActiveDirectoryServiceEndpointResourceId)"
$content += "ssh_public_key: `"$ssh_public_key`""
$content += "ssh_private_key: `"$ssh_private_key`""
$content += "ca_cert: `"$ca_cert`""
$content += "plane_cidr: $plane_cidr"
$content += "plane_range: $plane_range"
$content += "plane_gateway: $plane_gateway"
$content += "infrastructure_cidr: $infrastructure_cidr"
$content += "infrastructure_range: $infrastructure_range"
$content += "infrastructure_gateway: $infrastructure_gateway"
$content += "infrastructure-subnet: $RG-virtual-network/$RG-infrastructure-subnet"
$content += "plane-subnet: $RG-virtual-network/$RG-plane-subnet"
$content += "availability_mode: availability_sets"
$content += "singleton_availability_zone: 'null'"
$content | Set-Content $HOME/director_vars.yml
# we go api for this next iteration
 om --env $HOME/om_$($director_conf.RG).env `
    configure-authentication `
    --password $OM_Password `
    --username $OM_Username `
    --decryption-passphrase $PIVNET_UAA_TOKEN

Write-Host "Now Uploading OM Certs"

 om --env $HOME/om_$($director_conf.RG).env `
    update-ssl-certificate `
    --certificate-pem "$om_cert" `
    --private-key-pem "$om_key" 

 om --env $HOME/om_$($director_conf.RG).env `
    deployed-products

 om --env $HOME/om_$($director_conf.RG).env `
    configure-director --config "$PSScriptRoot/../templates/director_config.yml" --vars-file "$HOME/director_vars.yml"

if (!$DO_NOT_APPLY.IsPresent) {
     om --env $HOME/om_$($director_conf.RG).env apply-changes
}

 om --env $HOME/om_$($director_conf.RG).env `
    deployed-products



Pop-Location

    