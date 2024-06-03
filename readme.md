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