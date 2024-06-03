function Start-PsTaskManager {
    
    [CmdletBinding()]
    param (
    )

    while ($true) {

        # Get all process CPU usage samples
        $cimProcesses = Get-CimInstance -ClassName Win32_Process | Select-Object Name, ProcessId, CommandLine, ParentProcessId, WorkingSetSize
        $allProcessesCpu = (Get-Counter '\Process V2(*)\% Processor Time' -ErrorAction SilentlyContinue).CounterSamples 
        #$allProcessesMemory = (Get-Counter '\Process V2(*)\Working Set' -ErrorAction SilentlyContinue).CounterSamples 

        # Initialize an array to hold the process information
        $result = @()

        foreach ($cimProc in $cimProcesses) {
            # Get the process ID
            $processId = $cimProc.ProcessId
            
            # Find the corresponding CPU usage sample
            $cpuSample = $allProcessesCpu | 
                Where-Object { $_.InstanceName -match ":$($processId)" }

            #$memorySample = $allProcessesMemory | 
            #    Where-Object { $_.InstanceName -match ":$($processId)" }

            if ($cpuSample) {
                    $cpuUsage = '';
                    if ($cpuSample.CookedValue -is [Double]) {
                        $cpuUsage = [math]::Round($cpuSample.CookedValue, 0);
                    }

                    $memoryUsage = '';
                    if ($cimProc.WorkingSetSize -is [UInt64]) {
                        $memoryUsage = [math]::Round($cimProc.WorkingSetSize / 1mb, 0);
                    }

                    # Add the process information to the result array
                    $result += [PSCustomObject]@{
                        Name            = $cimProc.Name
                        ID              = $processId
                        CPU             = $cpuUsage
                        Memory          = $memoryUsage
                        ParentProcessID = $cimProc.ParentProcessId
                        CommandLine     = $cimProc.CommandLine
                    }
                
            }
        }

        Clear-Host
        Write-Host "$(Get-Date)"
        $result | Format-Table -AutoSize
        Start-Sleep -Milliseconds 500
    }
}

