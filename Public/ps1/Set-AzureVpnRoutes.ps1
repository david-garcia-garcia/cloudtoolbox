function Set-AzureVpnRoutes {

    [CmdletBinding()]
    param(
        [string]
        $AzureResourceRegex, # Regular expression for Azure resource names
        [string]
        $ConfigXmlPath,
        [string]
        $JsonUrl,
        [switch]
        $IpV6
    )

    $persistentConfig = "$env:USERPROFILE\AppData\Local\Packages\Microsoft.AzureVpn_8wekyb3d8bbwe\LocalState\azurevpnconfig.xml"

    if ([string]::IsNullOrWhiteSpace($configXmlPath)) {
        $configXmlPath = $persistentConfig;
    }

    if (-not (Test-Path $configXmlPath)) {
        Write-Error "Configuration file not found."
        return;
    }

    # Retrieve the webpage content
    #$pageContent = (Invoke-WebRequest -Uri 'https://www.microsoft.com/en-us/download/details.aspx?id=56519').Content

    # Create a new instance of HttpClient
    if ([string]::IsNullOrWhiteSpace($jsonUrl)) {
        $httpClient = New-Object System.Net.Http.HttpClient
        $response = $httpClient.GetAsync('https://www.microsoft.com/en-us/download/details.aspx?id=56519').Result
        $pageContent = $response.Content.ReadAsStringAsync().Result

        # Use regex to find the JSON URL
        $regexPattern = '(https://download\.microsoft\.com/download/[^"]+/ServiceTags_Public_[0-9]+\.json)'
        if ($pageContent -match $regexPattern) {
            $jsonUrl = $matches[0]
            Write-Host "JSON URL found: $jsonUrl"
        }
        else {
            Write-Error "JSON URL not found."
        }
    }

    # Create a temporary file
    $tempFile = [System.IO.Path]::GetTempFileName()

    try {
        # Download the JSON file to the temporary file
        Invoke-WebRequest -Uri $jsonUrl -OutFile $tempFile

        # Read the JSON file from the temporary file
        $jsonContent = Get-Content -Path $tempFile -Raw
        $jsonDocument = [System.Text.Json.JsonDocument]::Parse($jsonContent)
    }
    catch {
        Write-Host "Error occurred: $($_.Message)"
        Remove-Item -Path $tempFile # Clean up temporary file
        return;
    }

    # Initialize an array to store the IPs
    $ipRanges = @()

    # Extract IP addresses
    foreach ($value in $jsonDocument.RootElement.GetProperty('values').EnumerateArray()) {
        $itemName = $value.GetProperty('name').GetString();
        if ($itemName -match $AzureResourceRegex) {
            Write-Host "Adding $itemName"
            foreach ($address in $value.GetProperty('properties').GetProperty('addressPrefixes').EnumerateArray()) {
                if ($IpV6 -and $address.GetString() -match ":") {
                    # Add only IPv6 addresses
                    $ipRanges += $address.GetString()
                }
                elseif (-not $IpV6 -and $address.GetString() -notmatch ":") {
                    # Add only IPv4 addresses
                    $ipRanges += $address.GetString()
                }
            }
        }
    }

    Write-Host "Original number of routes: $($ipRanges.Count)"
    $newRanges = Merge-CIDRIpRanges -CIDRAddresses $ipRanges;
    # $newRanges = $ipRanges;
    Write-Host "New number of routes: $($newRanges.Count)"

    function Convert-CidrToDestinationAndMask {
        param (
            [string]$cidr
        )

        $parts = $cidr -split '/'
        $destination = $parts[0]
        $mask = $parts[1]
        return @{
            destination = $destination
            mask        = $mask
        }
    }

    # Load the XML file
	[xml]$configXml = Get-Content $configXmlPath

    $vpnName = $configXml.AzVpnProfile.name.InnerText;
    if ([string]::IsNullOrWhiteSpace($vpnName)) {
        $vpnName = $configXml.AzVpnProfile.name;
    }

	# Navigate to the includeroutes node
    $includeRoutesNode = $configXml.SelectSingleNode("//*[local-name()='includeroutes']");

    # Check if the 'includeroutes' node exists
    if ($null -eq $includeRoutesNode) {
        # Create the 'includeroutes' node if it doesn't exist
        $includeRoutesNode = $configXml.CreateElement("includeroutes")
 
        # Append the new node to the parent node
		$includeRoutesParent = $configXml.SelectSingleNode("//*[local-name()='clientconfig']");
        $includeRoutesParent.AppendChild($includeRoutesNode)
    }
	
	$includeRoutesNode.RemoveAll()

    # Iterate over the IP ranges and add each as a route
    foreach ($cidr in $newRanges) {
        $ipInfo = Convert-CidrToDestinationAndMask -cidr $cidr

        # Create a new route element
        $newRoute = $configXml.CreateElement("route")
        $newDestination = $configXml.CreateElement("destination")
        $newMask = $configXml.CreateElement("mask")
    
        $newDestination.InnerText = $ipInfo.destination # IP range destination
        $newMask.InnerText = $ipInfo.mask # Subnet mask as prefix length

        # Append the new elements
        $newRoute.AppendChild($newDestination) | Out-Null
        $newRoute.AppendChild($newMask) | Out-Null
        $includeRoutesNode.AppendChild($newRoute) | Out-Null
    }

    # Backup
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $backupPath = "$persistentConfig.$timestamp.bak"
    Copy-Item -Path $persistentConfig -Destination $backupPath

    # Save the changes back to the XML file
    $tempFile = [System.IO.Path]::GetTempFileName()
    $configXml.Save($configXmlPath)

    # Clean up: Dispose of the JSON document and delete the temporary file
    $jsonDocument.Dispose()
    Remove-Item -Path $tempFile;

    # Make a persistent copy 
    if ($configXmlPath -ne $persistentConfig) {
        Copy-Item -Path $configXmlPath -Destination $persistentConfig -Force
    }

    # For this to work, we need to remove existing VPN connection with same name, and CLOSE the VPN CLIENT!
    $vpn = Get-VpnConnection -Name $vpnName -ErrorAction SilentlyContinue
    if ($vpn) {
        # Remove the VPN connection
        Remove-VpnConnection -Name $vpnName -Force -PassThru
        Write-Output "VPN connection '$vpnName' removed successfully."
    }

    $process = Get-Process -Name "AzVpnAppx" -ErrorAction SilentlyContinue
    if ($process) {
        # Stop the process
        Stop-Process -Name "AzVpnAppx" -Force
        Write-Output "Azure VPN client process closed successfully."
    }

    # Execute
    & "azurevpn" -i "azurevpnconfig.xml" -f
}