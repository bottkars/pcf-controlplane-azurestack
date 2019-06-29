#requires -module pivposh
param(
    [Parameter(Mandatory = $false)]	
    [Validatescript( {Test-Path -Path $_ })]
    $DIRECTOR_CONF_FILE="$HOME/director_control.json",
    $worker_instances='1',
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

$RG = $director_conf.RG
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

$TILE='p-control-plane-components'
$branch='master'
Write-Verbose "Release: $branch"
$PRODUCT_FILE = "$($HOME)/$($tile).json"
if (!(Test-Path $PRODUCT_FILE)) {

    $PRODUCT_FILE = "../examples/$($branch)/$($tile).json"
    Write-Verbose "using $PRODUCT_FILE"
}
$tile_conf = Get-Content $PRODUCT_FILE | ConvertFrom-Json
$PCF_VERSION = $tile_conf.PCF_VERSION
$config_file = $tile_conf.CONFIG_FILE
$downloaddir = $director_conf.downloaddir

Write-Host "getting Access Token"
$access_token = Get-PIVaccesstoken -refresh_token $PIVNET_UAA_TOKEN
if (!$access_token) {
    Write-Warning "Error getting token"
    break
}

Write-Host "Getting Release for $tile $PCF_VERSION"
$piv_release = Get-PIVRelease -id $tile | Where-Object version -Match $PCF_VERSION | Select-Object -First 1
Write-Host "Getting Release ID for $PCF_VERSION"
$piv_release_id = $piv_release | Get-PIVFileReleaseId

Write-Host "Accepting EULA for $tile $PCF_VERSION"
$eula = $piv_release | Confirm-PIVEula -access_token $access_token
$piv_objects = $piv_release_id | Where-Object aws_object_key -Like "*.tgz"
$output_directory = New-Item -ItemType Directory "$($downloaddir)/$($tile)_$($PCF_VERSION)" -Force

if (($force_product_download.ispresent) -or (!(Test-Path "$($output_directory.FullName)/download-file.json"))) {
    Write-Host "downloading $tile components"    
    foreach($piv_object in $piv_objects) {
     om --env $HOME/om_$($RG).env `
        --request-timeout 7200 `
        download-product `
        --pivnet-api-token $PIVNET_UAA_TOKEN `
        --pivnet-file-glob "$(Split-Path -Leaf $piv_object.aws_object_key)" `
        --pivnet-product-slug $tile `
        --product-version $PCF_VERSION `
        --output-directory  "$($output_directory.FullName)"

    }
}

## create temp om env
#om --env $HOME/om_$($RG).env bosh-env --ssh-private-key $HOME/opsman > $env:TEMP\bosh_init.ps1
Invoke-Expression $(om --env $HOME/om_$($RG).env  bosh-env --ssh-private-key $HOME/opsman | Out-String)
foreach($piv_object in $piv_objects) {
    bosh upload-release "$($output_directory.FullName)/$(Split-Path -Leaf $piv_object.aws_object_key)"
}

$STEMCELL_VER="250.17"
.\get-lateststemcells.ps1 -Families 250 -STEMRELEASE 17
bosh upload-stemcell "$DOWNLOADDIR/stemcells/$STEMCELL_VER/bosh-stemcell-$($STEMCELL_VER)-azure-hyperv-ubuntu-xenial-go_agent.tgz"

om --env $HOME/om_$($RG).env `
--request-timeout 7200 `
download-product `
--pivnet-api-token $PIVNET_UAA_TOKEN `
--pivnet-file-glob "*.yml" `
--pivnet-product-slug $tile `
--product-version $PCF_VERSION `
--output-directory  "$($output_directory.FullName)"


##### creating releases, extensions 
$local_control="$HOME/control/$RG"
New-Item -ItemType Directory $local_control -Force | Out-Null


"control-plane-lb: $($RG)-web-lb
control-plane-security-group: $($RG)-plane-security-group
" > "$local_control/vm-lb-extensions-vars.yml"

"control-minio-lb: $($RG)-minio-lb
control-minio-security-group: $($RG)-minio-security-group
" > "$local_control/vm-lb-extensions-minio-vars.yml"

"vm-extension-config:
  name: control-plane-lb
  cloud_properties:
   security_group: ((control-plane-security-group))
   load_balancer: ((control-plane-lb))
"  > "$local_control/vm-lb-extensions.yml"

"vm-extension-config:
  name: control-minio-lb
  cloud_properties:
   security_group: ((control-minio-security-group))
   load_balancer: ((control-minio-lb))
"  > "$local_control/vm-lb-extensions-minio.yml"

"- type: replace
  path: /instance_groups/name=web/vm_extensions?
  value: [control-plane-lb]
- type: replace
  path: /instance_groups/name=worker/instances
  value: $worker_instances  
"   > "$local_control/vm-extensions-control.yml"

"- type: replace
  path: /instance_groups/name=minio/vm_extensions?
  value: [control-minio-lb]
"   > "$local_control/vm-extensions-minio.yml"

om --env "$HOME/om_$($RG).env" `
  create-vm-extension  `
  --config  "$local_control/vm-lb-extensions.yml"  `
  --vars-file  "$local_control/vm-lb-extensions-vars.yml"

om --env "$HOME/om_$($RG).env" `
  create-vm-extension  `
  --config  "$local_control/vm-lb-extensions-minio.yml"  `
  --vars-file  "$local_control/vm-lb-extensions-minio-vars.yml"

om --env "$HOME/om_$($RG).env" `
  apply-changes 



"---
external_url: https://plane.$($PCF_SUBDOMAIN_NAME).$($PCF_DOMAIN_NAME)
persistent_disk_type: 204800
vm_type: Standard_DS11_v2
stemcell_version: $STEMCELL_VER
network_name: control-plane-subnet
azs: ['Availability Sets']
minio_accesskey: s3admin
minio_secretkey: $PIVNET_UAA_TOKEN 
minio_deployment_name: minio-$($RG) 
wildcard_domain: '*.$($PCF_SUBDOMAIN_NAME).$($PCF_DOMAIN_NAME)'
uaa_url: https://uaa.$($PCF_SUBDOMAIN_NAME).$($PCF_DOMAIN_NAME)
uaa_ca_cert: |
  $fullchain
" > "$local_control\bosh-vars.yml"

bosh deploy -n -d control-plane "$($output_directory.FullName)/control-plane-0.0.31-rc.1.yml" `
  --vars-file=$local_control\bosh-vars.yml `
  --ops-file=$local_control\vm-extensions-control.yml

bosh upload-release https://bosh.io/d/github.com/minio/minio-boshrelease

bosh deploy -n -d minio-$($RG) ..\templates\minio.yml `
  --vars-file=$local_control\bosh-vars.yml `
  --ops-file=$local_control\vm-extensions-minio.yml


Write-Host "You can now login to https://plane.$($PCF_SUBDOMAIN_NAME).$($PCF_DOMAIN_NAME) with below admin credentials"
Write-Host "once logged in, use `"fly --target plane login --concourse-url https://plane.$($PCF_SUBDOMAIN_NAME).$($PCF_DOMAIN_NAME)`" to signin to flycli"
(credhub.exe get /name:"/p-bosh/control-plane/uaa_users_admin" /j| ConvertFrom-Json).value

Pop-Location