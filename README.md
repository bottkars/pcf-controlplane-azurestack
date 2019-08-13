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
