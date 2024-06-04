function New-TrustedCertificate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $DnsName,

        [Parameter(Mandatory=$true)]
        [string]
        $OutputDirectory
    )

    $certStoreLocation = "cert:\LocalMachine\My"
    $rootStoreLocation = "cert:\LocalMachine\Root"

    # Open the personal store to check for existing certificates
    $srcStore = New-Object System.Security.Cryptography.X509Certificates.X509Store "My", "LocalMachine"
    $srcStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    $dstStore = New-Object System.Security.Cryptography.X509Certificates.X509Store "Root", "LocalMachine"
    $dstStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)

    try {
        # Remove existing certificates from Personal Store
        $existingCertsSrc = $srcStore.Certificates | Where-Object {
            $_.Subject -eq "CN=$DnsName"
        }
        foreach ($cert in $existingCertsSrc) {
            $srcStore.Remove($cert)
            Write-Output "Removed existing certificate from the My store."
        }

        # Remove existing certificates from Trusted Root Store
        $existingCertsDst = $dstStore.Certificates | Where-Object {
            $_.Subject -eq "CN=$DnsName"
        }
        foreach ($cert in $existingCertsDst) {
            $dstStore.Remove($cert)
            Write-Output "Removed existing certificate from the Root store."
        }

        # Create a new self-signed certificate
        $selfCert = New-SelfSignedCertificate -DnsName $DnsName -CertStoreLocation $certStoreLocation -Subject "CN=$DnsName" -NotAfter (Get-Date).AddYears(2)
        $dstStore.Add($selfCert)

        $pfxPasswordPlain = "YourPFXPassword"

        # Export certificate to PFX
        $pfxPath = Join-Path -Path $OutputDirectory -ChildPath "cert.pfx"
        $pfxPassword = ConvertTo-SecureString -String $pfxPasswordPlain -Force -AsPlainText
        $selfCert | Export-PfxCertificate -FilePath $pfxPath -Password $pfxPassword

        # Export certificate to PEM (Certificate only)
        $certPath = Join-Path -Path $OutputDirectory -ChildPath "cert.pem"
        $keyPath = Join-Path -Path $OutputDirectory -ChildPath "key.pem"

        $keyCmd = "openssl pkcs12 -in $pfxPath -password pass:$pfxPasswordPlain  -out $keyPath -nocerts -nodes"
        $certCmd = "openssl pkcs12 -in $pfxPath -password pass:$pfxPasswordPlain  -out $certPath -nokeys -clcerts"

        cmd.exe /c $keyCmd;
        cmd.exe /c $certCmd;
    } finally {
        $srcStore.Close()
        $dstStore.Close()
    }
}
