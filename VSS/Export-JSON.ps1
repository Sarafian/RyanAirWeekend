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
Get-Job -Name "Export.*" |Remove-Job -Force

#region import commandlets

. "$PSScriptRoot\CmdLets\Badges\New-DateBadge.ps1"

. "$PSScriptRoot\CmdLets\Date\Get-WeekDay.ps1"
. "$PSScriptRoot\CmdLets\Date\New-WeekendExcursionSettings.ps1"
. "$PSScriptRoot\CmdLets\Date\Test-WeekDayZone.ps1"
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
    $filePath=Join-Path $exportPath $fileName
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

        $fridayDates=Get-WeekDay -From $fromDate -To $toDate -DayOfWeek Friday
        $flights=@()
        foreach($friday in $fridayDates)
        {
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
        if($flights.Count -gt 0)
        {
            $flights|ConvertTo-Json|Out-File $filePath
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
    $airports=Get-RyanAirCommon -Type Airports
    $airports|ConvertTo-Json |Out-File (Join-Path $exportPath "Airports.json")
    $cities=Get-RyanAirCommon -Type Cities
    $cities|ConvertTo-Json |Out-File (Join-Path $exportPath "Cities.json")

    $countries=Get-RyanAirCommon -Type Countries
    $countries|ConvertTo-Json |Out-File (Join-Path $exportPath "Countries.json")

    $iataCodes=$airports | Select-Object -ExpandProperty IataCode

    if($Origin)
    {
        $origins=$iataCodes|Where-Object {$Origin -contains $_}
    }
    else
    {
        $origins=$iataCodes
    }

    $schedules= $origins | Get-RyanAirSchedules
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
            $_.Group | ForEach-Object {
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



