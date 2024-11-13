function New-AzureVpnTerraformRoutes {

    [CmdletBinding()]
    param(
        [string]
        $AzureResourceRegex, # Regular expression for Azure resource names
        [string]
        $DestinationPath,
        [string]
        $JsonUrl,
        [switch]
        $IpV6
    )

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
        Write-Host "Downloading from $jsonUrl"
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

    $sb = [System.Text.StringBuilder]::new();
    $sb.AppendLine("locals {")
    $sb.AppendLine("  additional_routes = [")
    
    # Join CIDR ranges with a newline, each wrapped in single quotes
    $cidrList = ($newRanges | ForEach-Object { """$_""" }) -join (",", [Environment]::NewLine)
    $sb.AppendLine("    $cidrList")

    $sb.AppendLine("  ]")
    $sb.AppendLine("}")

    $sb.ToString() | Out-File -FilePath $DestinationPath -Encoding UTF8
}