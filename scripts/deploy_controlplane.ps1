#requires -module pivposh
param(
    [Parameter(Mandatory = $false)]	
    [Validatescript( {Test-Path -Path $_ })]
    $DIRECTOR_CONF_FILE="$HOME/director_control.json",

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
$env:Path = "$($env:Path);$HOME/OM"
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
else {
    Write-Verbose $access_token
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
    Write-Host "downloading $(Split-Path -Leaf $piv_object.aws_object_key) to $($output_directory.FullName)"    
    foreach($piv_object in $piv_objects) {
     om --env $HOME/om_$($director_conf.RG).env `
        --request-timeout 7200 `
        download-product `
        --pivnet-api-token $PIVNET_UAA_TOKEN `
        --pivnet-file-glob "$(Split-Path -Leaf $piv_object.aws_object_key)" `
        --pivnet-product-slug $tile `
        --product-version $PCF_VERSION `
        --output-directory  "$($output_directory.FullName)"
    }
}


# om --env $HOME_DIR/om_$($ENV_NAME).env bosh-env --ssh-private-key $HOME/opsman
Pop-Location