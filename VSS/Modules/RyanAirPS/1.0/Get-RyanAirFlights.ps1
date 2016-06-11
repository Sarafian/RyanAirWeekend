<#
    .SYNOPSIS
        This commandlet queries ryan air api for rountrip available flights

    .DESCRIPTION
        This commandlet queries ryan air api for available flights during specific dates

    .PARAMETER  Origin
        The IATA code of origin airport

    .PARAMETER  Destination
        The IATA code of destination airport

    .PARAMETER  DateOut
        The date of departure

    .PARAMETER  DateIN
        The date of return

    .PARAMETER  FlexDaysOut
        The number of extra days to include with DateOut

    .PARAMETER  FlexDaysIn
        The number of extra days to include with DateIn

    .EXAMPLE
        $date=Get-Date
        Get-RyanAirFlights -Origin BRU -Destination SXF -DateOut $date

    .EXAMPLE
        $date=Get-RyanAirFlights
        Get-RyanAirAvailability -Origin BRU -Destination SXF -DateOut $date -FlexDaysOut 1

    .EXAMPLE
        $date=Get-Date
        Get-RyanAirFlights -Origin BRU -Destination SXF -DateOut $date -DateIn ($date.AddDays(2))

    .EXAMPLE
        $date=Get-Date
        Get-RyanAirFlights -Origin BRU -Destination SXF -DateOut $date -FlexDaysOut 1 -DateIn ($date.AddDays(2)) -FlexDaysIn 1

    .INPUTS
        The IATA code of origin airport

    .OUTPUTS
        The available flights

#>
function Get-RyanAirFlights{
    [CmdletBinding()]
    [OutputType([PSObject[]])]
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline = $true,ParameterSetName = "Default Param Set")]
        [Parameter(Mandatory=$true,ValueFromPipeline = $true,ParameterSetName="RoundTrip")]
        [string] $Origin,
        [Parameter(Mandatory=$true,ParameterSetName = "Default Param Set")]
        [Parameter(Mandatory=$true,ParameterSetName="RoundTrip")]
        [string] $Destination,
        [Parameter(Mandatory=$true,ParameterSetName = "Default Param Set")]
        [Parameter(Mandatory=$true,ParameterSetName="RoundTrip")]
        [DateTime] $DateOut,
        [Parameter(Mandatory=$false,ParameterSetName = "Default Param Set")]
        [Parameter(Mandatory=$false,ParameterSetName="RoundTrip")]
        [int] $FlexDaysOut,
        [Parameter(Mandatory=$true,ParameterSetName="RoundTrip")]
        [DateTime] $DateIn,
        [Parameter(Mandatory=$false,ParameterSetName="RoundTrip")]
        [int] $FlexDaysIn
    )
    Begin {
        $ryanAirApi="https://desktopapps.ryanair.com/en-gb/availability"
        Write-Debug $ryanAirApi
        $queryParameters=@{
            "DateOut"=$DateOut.ToString("yyyy-MM-dd")
        }

        if($Destination)
        {
            $queryParameters["Destination"]=$Destination
        }
        if($DateIn)
        {
            $queryParameters["DateIn"]=$DateIn.ToString("yyyy-MM-dd")
            $queryParameters["RoundTrip"]=$true
        }
        if($FlexDaysOut)
        {
            $queryParameters["FlexDaysOut"]=$FlexDaysOut
        }
        if($FlexDaysIn)
        {
            $queryParameters["FlexDaysIn"]=$FlexDaysIn
        }
    }

    Process {
        try
        {
            $queryParameters["Origin"]=$Origin
            Write-Debug $queryParameters
            $json=Invoke-RestMethod -Uri "$ryanAirApi" -Body $queryParameters -Method Get
            Write-Debug $json
            $flights=@()
            foreach($tripJson in $json.trips)
            {
                foreach($dateJson in $tripJson.dates)
                {
                    foreach($flightJson in $dateJson.flights)
                    {
                        $flightHash=@{}
                        $flightHash["Origin"]=$tripJson.origin
                        $flightHash["Destination"]=$tripJson.destination
                
                        $flightHash["Date"]=$dateJson.dateOut

                        $flightHash["FlightNumber"]=$flightJson.flightNumber
                        $flightHash["From"]=Get-Date $flightJson.time[0]
                        $flightHash["To"]=Get-Date $flightJson.time[1]
                        $flightHash["FromUTC"]=Get-Date $flightJson.timeUTC[0]
                        $flightHash["ToUTC"]=Get-Date $flightJson.timeUTC[1]
                        $flightHash["Duration"]=$flightJson.duration
                        $flightHash["FaresLeft"]=$flightJson.faresLeft
                        $flightHash["InfantsLeft"]=$flightJson.infantsLeft

                        $flightHash["RegularFare"]=$flightJson.regularFare.fares |Where-Object {$_.Type -eq "ADT"}|Select-Object -ExpandProperty amount
                        $flightHash["BusinessFare"]=$flightJson.businessFare.fares |Where-Object {$_.Type -eq "ADT"}|Select-Object -ExpandProperty amount
                        New-Object PSObject –Prop $flightHash
                    }
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

