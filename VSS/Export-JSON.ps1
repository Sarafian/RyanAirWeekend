param (
    [Parameter(Mandatory=$false)]
    [int]
    $Months=12,
    [Parameter(Mandatory=$false)]
    [string[]]
    $Origin=$null,
    [Parameter(Mandatory=$false)]
    [switch]
    $AsParallel=$false
)
If ($PSBoundParameters.Debug -eq $true) { $DebugPreference='continue' }

Write-Debug "Remove existing Export.* jobs"
Get-Job -Name "Export.*" |Remove-Job -Force
Write-Debug "Removed existing Export.* jobs"

#region import commandlets
Write-Debug "Import cmdlets"

. "$PSScriptRoot\CmdLets\Session\Initialize-CurrentCulture.ps1"

Write-Verbose "Imported cmdlets"
#endregion

Initialize-CurrentCulture

$date=Get-Date -Format "yyyyMMdd"
$exportPath=Join-Path $env:TEMP $date
if(Test-Path $exportPath)
{
    Remove-Item "$exportPath\*" -Recurse -Force
}
else
{
    New-Item $exportPath -ItemType Directory |Out-Null
}
Write-Verbose "$exportPath is ready"

try
{
	$ryanAirPSCommand=Get-Command Get-RyanAirSchedules -ErrorAction SilentlyContinue

	if(-not ($ryanAirPSCommand)) {
		Write-Warning "RyanAirPS module not found"
		$env:PSModulePath+=";$PSScriptRoot\Modules"
	}

    Write-Verbose "env:PSModulePath is ready"
    $env:PSModulePath -split ';' |Write-Verbose

    $airports=Get-RyanAirCommon -Type Airports
    $airports|ConvertTo-Json |Out-File (Join-Path $exportPath "Airports.json")
    Write-Verbose "Saved airports"

    $cities=Get-RyanAirCommon -Type Cities
    $cities|ConvertTo-Json |Out-File (Join-Path $exportPath "Cities.json")
    Write-Verbose "Saved cities"

    $countries=Get-RyanAirCommon -Type Countries
    $countries|ConvertTo-Json |Out-File (Join-Path $exportPath "Countries.json")
    Write-Verbose "Saved countries"

    $iataCodes=$airports | Select-Object -ExpandProperty IataCode

    if($Origin)
    {
        $origins=$iataCodes|Where-Object {$Origin -contains $_}
        Write-Verbose "Filtered with $Origin"
    }
    else
    {
        $origins=$iataCodes
    }
    $exportJsonPath=Join-Path $PSScriptRoot "ExportJson\ExportJson\bin\Release\ExportJson.exe"
    $exportJsonConfigPath=Join-Path $PSScriptRoot "ExportJson\ExportJson\bin\Release\nlog.config"
    Write-Debug "exportJsonPath=$exportJsonPath"

    $arguments=@(
        "-Origin"
        $origins -join ","
        "-Months"
        $Months
    )
    if($AsParallel)
    {
        $arguments+="-AsParallel"
    }

    # & $exportJsonPath -ArgumentList $arguments
}
catch
{
    Write-Error $_
    exit -1
}
finally
{
    $exportPath
}



