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

. "$PSScriptRoot\CmdLets\Badges\New-DateBadge.ps1"

. "$PSScriptRoot\CmdLets\Date\Get-WeekDay.ps1"
. "$PSScriptRoot\CmdLets\Date\New-WeekendExcursionSettings.ps1"
. "$PSScriptRoot\CmdLets\Date\Test-WeekDayZone.ps1"
Write-Verbose "Imported cmdlets"
#endregion

$weekendSettings=New-WeekendExcursionSettings

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

#region export block
$exportBlock={
    param(
        [Parameter(Mandatory=$true)]
        [string]$Origin,
        [Parameter(Mandatory=$true)]
        [string]$Destination,
        [Parameter(Mandatory=$true)]
        [string]$FirstFlightDate,
        [Parameter(Mandatory=$true)]
        [string]$LastFlightDate
    )
    if($PSSenderInfo)
    {
        $exportPath=$Using:exportPath
        $weekendSettings=$Using:weekendSettings
        $PSScriptRoot=$Using:PSScriptRoot

        $cmdLetsPath=Resolve-Path "$PSScriptRoot\..\CmdLets"

        . "$cmdLetsPath\Date\Get-WeekDay.ps1"
        . "$cmdLetsPath\Date\New-WeekendExcursionSettings.ps1"
        . "$cmdLetsPath\Date\Test-WeekDayZone.ps1"
    }

    $fileName="$Origin-$Destination.json"
    Write-Debug "fileName=$fileName"
    $filePath=Join-Path $exportPath $fileName
    Write-Debug "filePath=$filePath"
    try
    {
        $fromDate=Get-Date
        if($fromDate -lt $FirstFlightDate)
        {
            Write-Warning "Setting earliest date to $FirstFlightDate"
            $fromDate=$FirstFlightDate
        }
        $toDate=(Get-Date).AddMonths($Months)
        if($toDate -gt $LastFlightDate)
        {
            Write-Warning "Setting latest date to $LastFlightDate"
            $toDate=$LastFlightDate
        }
        Write-Verbose "Normalized date"

        $fridayDates=Get-WeekDay -From $fromDate -To $toDate -DayOfWeek Friday
        $flights=@()
        foreach($friday in $fridayDates)
        {
            Write-Debug "Process friday $friday"
            $temp=$Origin | Get-RyanAirFlights -Destination $Destination -DateOut $friday -FlexDaysOut 1 -DateIn $friday.AddDays(2) -FlexDaysIn 1
            $validOutbound=$temp|Where-Object {$_.Origin -eq $Origin}|Where-Object { 
                $validOnFriday=Test-WeekDayZone -Date $_.From -DayOfWeek Friday -FromHours $weekendSettings.OutboundEarliestFriday
                $validOnSaturday=Test-WeekDayZone -Date $_.To -DayOfWeek Saturday -ToHours $weekendSettings.OutboundLatestSaturday
                return $validOnFriday -or $validOnSaturday
            }
            $validInbound=$temp|Where-Object {$_.Origin -eq $Destination} | Where-Object { 
                $validOnSunday=Test-WeekDayZone -Date $_.From -DayOfWeek Sunday -FromHours $weekendSettings.InboundEarliestSunday
                $validOnMonday=Test-WeekDayZone -Date $_.To -DayOfWeek Monday -ToHours $weekendSettings.InboundLatestMonday
                return $validOnSunday -or $validOnMonday
            }
            Write-Verbose "validOutbound.Count=$($validOutbound.Count)"
            Write-Verbose "validInbound.Count=$($validInbound.Count)"
            if(($validOutbound.Count -eq 0) -or ($validInbound.Count -eq 0))
            {
                continue
            }
            $validOutbound |ForEach-Object {
                $outbound=$_
                $flights+=$validInbound|Select-Object -Property @{Name="Origin";Expression={$Origin}},
                @{Name="Destination";Expression={$Destination}},
                @{Name="Friday";Expression={$friday.DateTime}},
                @{Name="OutboundFrom";Expression={
                    $outbound.From.DateTime
                }},@{Name="OutboundTo";Expression={
                    $outbound.To.DateTime
                }},@{Name="InboundFrom";Expression={
                    $_.From.DateTime
                }},@{Name="InboundTo";Expression={
                    $_.To.DateTime
                }},@{Name="RegularFare";Expression={
                    $outbound.RegularFare+$_.RegularFare
                }},@{Name="BusinessFare";Expression={
                    $outbound.BusinessFare+$_.BusinessFare
                }}
            }
        }
        Write-Verbose "flights.Count=$($flights.Count)"
        if($flights.Count -gt 0)
        {
            Write-Debug "filePath=$filePath"
            $flights|ConvertTo-Json|Out-File $filePath
            Write-Verbose "Saved $filePath"
        }
    }
    catch
    {
        Write-Error $_
    }
    finally
    {
    }
}

#endregion



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
    $schedules= $origins | Get-RyanAirSchedules
    Write-Verbose "Got Schedules"
    $schedulesByOrigin=$schedules | Group-Object Origin
    
    if($AsParallel)
    {
        $schedulesByOrigin | ForEach-Object {
            $origin=$_.Name
            $_.Group | ForEach-Object {
                Start-Job -ScriptBlock $exportBlock -ArgumentList $origin,$_.Destination,$_.FirstFlightDate,$_.LastFlightDate -Name "Export.$origin,$($_.Destination)" |Out-Null
            }
        }
        $jobs=Get-Job -Name "Export.*" |Wait-Job
        $jobs|ForEach-Object {
            Write-Host "Finished $($_.Name)"
            $_|Receive-Job -AutoRemoveJob -Wait
        }
    }
    else
    {
        $schedulesByOrigin | ForEach-Object {
            $origin=$_.Name
            Write-Verbose "origin=$origin"

            $_.Group | ForEach-Object {
                Write-Verbose "_.Destination=$($_.Destination)"
                Invoke-Command -ScriptBlock $exportBlock -ArgumentList $origin,$_.Destination,$_.FirstFlightDate,$_.LastFlightDate
            }
        }
    }

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



