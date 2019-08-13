#requires -module pivposh
param(
    [Parameter(Mandatory = $false)]	
    [Validatescript( { Test-Path -Path $_ })]
    $DIRECTOR_CONF_FILE = "$HOME/director_control.json",
    $worker_instances = '1',
    [Parameter(Mandatory = $false)]
    [switch]
    $DO_NOT_APPLY,
    [switch]
    $NO_DOWNLOAD,
    [switch]
    $AIRGAPPED
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

$TILE = 'p-control-plane-components'
$branch = 'master'
$downloaddir = $director_conf.downloaddir
## create bosh env
Invoke-Expression $(om --env $HOME/om_$($RG).env  bosh-env --ssh-private-key $HOME/opsman | Out-String)
## getting releases from version table
$releases = Get-Content ../templates/versions.yml
$releases = $releases -replace ":", "="
$releases = $releases -replace "`"", ""  
$releases = @"
$($releases -join "`r`n")
"@ | ConvertFrom-StringData

if ($AIRGAPPED.IsPresent) {
    if (!$NO_DOWNLOAD.IsPresent) {

        $downloaddir = "$downloaddir/controlplane"
        New-Item -ItemType Directory $downloaddir

        invoke-webrequest -Uri "https://bosh.io/d/github.com/concourse/concourse-bosh-release?v=$($releases.'concourse-bosh-release')" `
            -OutFile "$downloaddir/concourse-bosh-release-$($releases.'concourse-bosh-release').tgz"

        invoke-webrequest -Uri "https://bosh.io/d/github.com/cloudfoundry/uaa-release?v=$($releases.'uaa-release')" `
            -OutFile "$downloaddir/uaa-release-$($releases.'uaa-release').tgz"

        invoke-webrequest -Uri "https://bosh.io/d/github.com/cloudfoundry/bpm-release?v=$($releases.'bpm-release')" `
            -OutFile "$downloaddir/bpm-release-$($releases.'bpm-release').tgz"

        invoke-webrequest -Uri "https://bosh.io/d/github.com/cloudfoundry/bosh-dns-aliases-release?v=$($releases.'bosh-dns-aliases-release')" `
            -OutFile "$downloaddir/bosh-dns-aliases-release-$($releases.'bosh-dns-aliases-release').tgz"

        invoke-webrequest -Uri "https://bosh.io/d/github.com/cloudfoundry/garden-runc-release?v=$($releases.'garden-runc-release')" `
            -OutFile "$downloaddir/garden-runc-release-$($releases.'garden-runc-release').tgz"

        invoke-webrequest -Uri "https://bosh.io/d/github.com/cloudfoundry/postgres-release?v=$($releases.'postgres-release')" `
            -OutFile "$downloaddir/postgres-release-$($releases.'postgres-release').tgz"


        invoke-webrequest -Uri "https://bosh.io/d/github.com/pivotasl-cf/credhub-release?v=$($releases.'credhub-release')" `
            -OutFile "$downloaddir/credhub-release-$($releases.'credhub-release').tgz"

        invoke-webrequest -Uri "https://bosh.io/d/github.com/cloudfoundry-incubator/windows-utilities-release?v=$($releases.'windows-utilities-release')" `
            -OutFile "$downloaddir/windows-utilities-release-$($releases.'windows-utilities-release').tgz"

        invoke-webrequest -Uri "https://bosh.io/d/github.com/cloudfoundry-incubator/windowsfs-online-release?v=$($releases.'windowsfs-online-release')" `
            -OutFile "$downloaddir/windowsfs-online-release-$($releases.'windowsfs-online-release').tgz"

        invoke-webrequest -Uri "https://bosh.io/d/github.com/cloudfoundry-incubator/winc-release?v=$($releases.'winc-release')" `
            -OutFile "$downloaddir/winc-release-$($releases.'winc-release').tgz"

        invoke-webrequest -Uri "https://bosh.io/d/github.com/cloudfoundry-incubator/garden-windows-bosh-release?v=$($releases.'garden-windows-bosh-release')" `
            -OutFile "$downloaddir/garden-windows-bosh-release-$($releases.'garden-windows-bosh-release').tgz"

    }

}
else {
  
    bosh upload-release `
        https://bosh.io/d/github.com/concourse/concourse-bosh-release?v=$($releases.'concourse-bosh-release')

    bosh upload-release  `
        https://bosh.io/d/github.com/cloudfoundry/uaa-release?v=$($releases.'uaa-release')

    bosh upload-release `
        https://bosh.io/d/github.com/cloudfoundry/bpm-release?v=$($releases.'bpm-release')

    bosh upload-release `
        https://bosh.io/d/github.com/cloudfoundry/bosh-dns-aliases-release?v=$($releases.'bosh-dns-aliases-release')

    bosh upload-release `
        https://bosh.io/d/github.com/cloudfoundry/garden-runc-release?v=$($releases.'garden-runc-release')

    bosh upload-release `
        https://bosh.io/d/github.com/pivotal-cf/credhub-release?v=$($releases.'credhub-release')

    bosh upload-release  `
        https://bosh.io/d/github.com/cloudfoundry/postgres-release?v=$($releases.'postgres-release')

    bosh upload-stemcell `
        https://s3.amazonaws.com/bosh-core-stemcells/$($releases.'stemcell-release')/bosh-stemcell-$($releases.'stemcell-release')-azure-hyperv-ubuntu-xenial-go_agent.tgz
    
    bosh upload-release `
        https://bosh.io/d/github.com/cloudfoundry-incubator/windows-utilities-release?v=$($releases.'windows-utilities-release')

    bosh upload-release `
        https://bosh.io/d/github.com/cloudfoundry/windowsfs-online-release?v=$($releases.'windowsfs-online-release')
  
    bosh upload-release  `
        https://bosh.io/d/github.com/cloudfoundry-incubator/winc-release?v=$($releases.'winc-release')
  
    bosh upload-release  `
        https://bosh.io/d/github.com/cloudfoundry-incubator/garden-windows-bosh-release?v=$($releases.'garden-windows-bosh-release')

}




##### creating releases, extensions 
$local_control = "$HOME/control/$RG"
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
  path: /instance_groups/name=worker-linux/instances
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
worker_vm_type: Standard_DS4_v2
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


    bosh deploy -n -d control-plane ..\templates\control-plane-deployment-kb-5.yml `
    --vars-file=$local_control\bosh-vars.yml `
    --ops-file=$local_control\vm-extensions-control.yml `
    --vars-file=..\templates\versions.yml

bosh upload-release https://bosh.io/d/github.com/minio/minio-boshrelease

bosh deploy -n -d minio-$($RG) ..\templates\minio.yml `
    --vars-file=$local_control\bosh-vars.yml `
    --ops-file=$local_control\vm-extensions-minio.yml `
    --vars-file=..\templates\versions.yml



Write-Host "You can now login to https://plane.$($PCF_SUBDOMAIN_NAME).$($PCF_DOMAIN_NAME) with below admin credentials"
Write-Host "once logged in, use `"fly --target plane login --concourse-url https://plane.$($PCF_SUBDOMAIN_NAME).$($PCF_DOMAIN_NAME)`" to signin to flycli"
(credhub.exe get /name:"/p-bosh/control-plane/uaa_users_admin" /j | ConvertFrom-Json).value

Pop-Location