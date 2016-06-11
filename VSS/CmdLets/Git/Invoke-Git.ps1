function Invoke-Git {
    Param (
        [Parameter(
            Mandatory=$true
        )]
        [string]$Reason,
        [Parameter(
            Mandatory=$true
        )]
        [string[]]$ArgumentsList,
        [Parameter(
            Mandatory=$false
        )]
        [switch]$PipeOutput=$false
    )
    PROCESS {

        try
        {
            $gitPath=& "C:\Windows\System32\where.exe" git
            $gitErrorPath=Join-Path $env:TEMP "stderr.txt"
            $gitOutputPath=Join-Path $env:TEMP "stdout.txt"
            if($gitPath.Count -gt 1)
            {
                $gitPath=$gitPath[0]
            }

            Write-Verbose "[Git][$Reason] Begin"
            Write-Verbose "[Git][$Reason] gitPath=$gitPath"
            Write-Host "git $arguments"
            $process=Start-Process $gitPath -ArgumentList $ArgumentsList -NoNewWindow -PassThru -Wait -RedirectStandardError $gitErrorPath -RedirectStandardOutput $gitOutputPath
            $outputText=(Get-Content $gitOutputPath)
            $outputText | ForEach-Object {Write-Host $_}
            if($PipeOutput)
            {
                $outputText | ForEach-Object {Write-Output $_}
            }

            Write-Verbose "[Git][$Reason] process.ExitCode=$($process.ExitCode)"
            if($process.ExitCode -ne 0)
            {
                Write-Warning "[Git][$Reason] process.ExitCode=$($process.ExitCode)"
                $errorText=$(Get-Content $gitErrorPath)
                $errorText | ForEach-Object {Write-Host $_}

                if($errorText -ne $null)
                {
                    throw "Git exited with $($process.ExitCode)"
                }
            }
        }
        catch
        {
            Write-Error "[Git][$Reason] Exception $_"
            throw $_
        }
        finally
        {
            Write-Verbose "[Git][$Reason] Done"
        }
    }
}