$MODULE_BASE_DIR = Split-Path $MyInvocation.MyCommand.Path -Parent

# Dot source but not export private functions
Get-ChildItem "$MODULE_BASE_DIR/Private/ps1/*.ps1" | % {
    . $_.FullName;
}

# Dot source and export public functions
Get-ChildItem "$MODULE_BASE_DIR/Public/ps1/*.ps1" | % {
    . $_.FullName;
    $functionName = [IO.Path]::GetFileNameWithoutExtension($_.Name);
    Export-ModuleMember -Function $functionName;
}

