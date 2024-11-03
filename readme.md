## Set-AzureVpnRoutes

Use to install and configure an Azure VPN Open Vpn Profile to route Azure Public IP's through the VPN tunnel. The information about the current IP's is automatically retrieved from:

https://www.microsoft.com/en-us/download/details.aspx?id=56519

The first time you call this, you need to provide the path to the configuration XML file you get from Azure:

```powershell
# Route all IP's from france central, west us, and AD
Set-AzureVpnRoutes -ConfigXmlPath "d:\azurevpnconfig.xml" -AzureResourceRegex "(\.FranceCentral$)|(.\.WestUS$)|(AzureActiveDirectory)"
```

Do **not** be tempted to provide a wildcard ".*" to the service regular expression match, the AzureVPN client will not load with such a huge number of routes.

On future reconfigurations, a copy of the config is stored, and it's enough to just pass in the AzureResourceRegex argument:

```powershell
# Route all IP's from france central, west us, and AD
Set-AzureVpnRoutes -AzureResourceRegex "(\.FranceCentral$)|(AzureActiveDirectory)"
```

## Start-PsTaskManager 

Powershell based task manager resource usage. Ideal for windows containers.



# How to Connect to Azure VPN - Step-by-Step Guide

Follow these steps to set up and connect to Azure VPN.

### Prerequisites

- Ensure you have an updated config file (`azurevpnconfig.xml`) and it is located at `d:\azurevpnconfig.xml`.

### Steps

1. **Open PowerShell 7**
   Launch PowerShell 7 (`pwsh`).

2. **Import Necessary Functions**
   Run the `debugimport.ps1` script to import required functions:

   `. .\debugimport.ps1`

3. **Run the VPN Route Script**
   Execute the `Set-AzureVpnRoutes.ps1` script with your chosen flags:

   `Set-AzureVpnRoutes -ConfigXmlPath "d:\azurevpnconfig.xml" -AzureResourceRegex "(\.FranceCentral$)"`

4. **Open and Connect to Azure VPN**
   Launch the Azure VPN Client, connect, and log in with your Azure account.

5. **Verify VPN Routes**
   Confirm that all desired VPN routes have loaded successfully.