# pcf-controlplane-azurestack
Control Plane for Pivotal PCF / AzureStack using Powershell 


## getting started

from a Windows 1809 or latesr install OpenSSH

```Powershell
Get-WindowsCapability -Online | ? name -like *OpenSSH.Server* |  Add-WindowsCapability -Online
```

Clone into this repo

```Powershell
git clone https://github.com/bottkars/pcf-controlplane-azurestack.git
```

Run the [prepare script](prepare_utils.ps1) to download latest versions of
 - om cli
 - cf cli
 - uaac including ruby env
 - credhub cli 
 - bosh cli
 - openssl

Create an env.json following [readme](env.json.example)



run
```Powershell
 .\deploy_pcf-opsman.ps1 -location sc2 -dnsdomain azurestack-rd.cf-app.com -TESTONLY
 ```
 ( replace location and dnsdomain with your values)