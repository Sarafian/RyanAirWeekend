<#
    .SYNOPSIS
        This commandlet queries ryan air api for rountrip available flights

    .DESCRIPTION
        This commandlet queries ryan air api for available flights during specific dates

    .PARAMETER  Origin
        The IATA code of origin airport

    .PARAMETER  Destination
        The IATA code of destination airport

    .EXAMPLE 
        Get-RyanAirSchedules -Origin BRU

    .EXAMPLE 
        Get-RyanAirSchedules -Origin BRU -Destination SXF

    .EXAMPLE 
        @("BRU","CLR") | Get-RyanAirSchedules

    .EXAMPLE 
        Get-RyanAirSchedules -Origin BRU -Destination SXF

    .EXAMPLE 
        @("BRU","ATH") | Get-RyanAirSchedules -Destination SXF

    .EXAMPLE 
        Get-RyanAirSchedules -Origin BRU

    .INPUTS
        The IATA code of origin airport

    .OUTPUTS
        The available flights

#>
function Get-RyanAirSchedules{
    [CmdletBinding()]
    [OutputType([PSObject[]])]
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline = $true)]
        [string] $Origin,
        [Parameter(Mandatory=$false)]
        [string] $Destination=$null
    )
    Begin {
    }
    Process {
        try
        {

            if($Destination)
            {
                $ryanAirApi="https://api.ryanair.com/timetable/3/schedules/$Origin/$Destination/period"
            }
            else
            {
                $ryanAirApi="https://api.ryanair.com/timetable/3/schedules/$origin/periods"
            }
            Write-Debug $ryanAirApi
            $json=Invoke-RestMethod -Uri "$ryanAirApi" -Method Get
            Write-Debug $json
            $schedules=@()
            $hash=@{}
            if($Destination)
            {
                $hash["Origin"]=$Origin
                $hash["Destination"]=$Destination
                $hash["Months"]=$json.months
                $hash["MonthsFromToday"]=$json.monthsFromToday
                $hash["FirstFlightDate"]=Get-Date $json.firstFlightDate
                $hash["LastFlightDate"]=Get-Date $json.lastFlightDate
                New-Object PSObject –Prop $hash
            }
            else
            {
                $destinations=@()
                $json|Get-Member |Where-Object {$_.MemberType -eq "NoteProperty"} |ForEach-Object {
                    $scheduleJson=$json| Select -ExpandProperty $_.Name
                    $hash["Origin"]=$Origin
                    $hash["Destination"]=$_.Name
                    $hash["Months"]=$scheduleJson.months
                    $hash["MonthsFromToday"]=$scheduleJson.monthsFromToday
                    $hash["FirstFlightDate"]=Get-Date $scheduleJson.firstFlightDate
                    $hash["LastFlightDate"]=Get-Date $scheduleJson.lastFlightDate
                    New-Object PSObject –Prop $hash
                }
            }
        }
        catch
        {
            Write-Error $_
        }
    }
    
    End {
    }
}