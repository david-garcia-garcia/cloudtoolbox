Function Merge-CIDRIpRanges() {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [ValidateScript( { $_ -match '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)/([0-9]|[0-2][0-9]|3[0-2])$' })]
        [System.String[]] $CIDRAddresses
    )

    Begin {}

    Process {
        $sortedRanges = $CIDRAddresses | Foreach-Object {
            $range = $_
            $mask, [int]$bits = $range.Split('/')
            $bitMask = $mask -split '\.' | ForEach-Object -Begin { 
                [long]$address = 0
            } -Process { 
                $address = $address -shl 8
                $address += [int]$_
                # Write-Host $_ $address
            } -End { 
                $address
            }
            $bitMaskString = [convert]::tostring($address, 2).PadLeft(32,'0').Substring(0, $bits)
            [PSCustomObject]@{
                Range = $range
                Mask = $mask
                Bits = $bits
                BitMaks = $bitMask
                BitMaskString = $bitMaskString
                Subrange = $false
            }
        } | Sort-Object -Property Bits, BitMaskString -Unique
        $linkedList = [System.Collections.Generic.LinkedList[psobject]]::new()
        foreach ($range in $sortedRanges) {
            $linkedList.AddLast($range) *> $null
        }
        $outerCurrent = $linkedList.First
        $Index = 0
        while ($outerCurrent) {
            $Index++
            $ProgressPercent = ($Index / ($CIDRAddresses.Count) * 100)
            $Progress = @{
                Activity         = "Filtering Overlapping CIDR IP Ranges"
                Status           = "Examining.."
                CurrentOperation = "IP: $Index of $($CIDRAddresses.Count)"
                Id               = 1
                PercentComplete  = $ProgressPercent
            }
            Write-Progress @Progress
            $master = $outerCurrent.Value
            $innerCurrent = $outerCurrent.Next
            while ($innerCurrent) {
                $slave = $innerCurrent.Value
                $next = $innerCurrent.Next
                if ($slave.BitMaskString.StartsWith($master.BitMaskString)) {
                    $linkedList.Remove($innerCurrent)
                }
                $innerCurrent = $next
            }
            $outerCurrent = $outerCurrent.Next
        }
        $LinkedList.Range
    }

    End {}
}
