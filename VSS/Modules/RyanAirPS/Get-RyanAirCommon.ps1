<#
    .SYNOPSIS
        This commandlet queries ryan air api for countries, cities and airports

    .DESCRIPTION
        This commandlet queries ryan air api for countries, cities and airports

    .PARAMETER  Type
        One of the Countries, Cities or Airports

    .EXAMPLE
        Get-RyanAirCommon -Type Countries

    .EXAMPLE
        Get-RyanAirCommon -Type Cities

    .EXAMPLE
        Get-RyanAirCommon -Type Airports

    .OUTPUTS
        An array of Countries or Cities or Airports

#>
function Get-RyanAirCommon{
    [OutputType([PSObject[]])]
    Param (
        [Parameter(
            Mandatory = $true,
            Position = 0
        )]
        [ValidateSet("Countries","Cities","Airports")]
        [string]$Type
    )
    Begin {
    }

    Process {
        switch ($Type) 
        { 
            "Countries" {
                $embedded+="countries"
            } 
            "Cities" {
                $embedded+="cities"
            } 
            "Airports" {
                $embedded+="airports"
            } 
        }    
        $ryanAirApi="https://api.ryanair.com/aggregate/3/common?embedded=$embedded&market=en-gb"
        Write-Verbose "ryanAirApi=$ryanAirApi"
        $json=Invoke-RestMethod -Uri "$ryanAirApi" -Method Get

        switch ($Type) 
        { 
            "Countries" {
                foreach($countryJson in $json.countries)
                {
                    $countryHash=@{}
                    $countryHash["Code"]=$countryJson.code
                    $countryHash["Name"]=$countryJson.name
                    $countryHash["Currency"]=$countryJson.currency
                    New-Object PSObject –Prop $countryHash
                }
            } 
            "Cities" {
                foreach($cityJson in $json.cities)
                {
                    $cityHash=@{}
                    $cityHash["Code"]=$cityJson.code
                    $cityHash["Name"]=$cityJson.name
                    $cityHash["CountryCode"]=$cityJson.countryCode
                    New-Object PSObject –Prop $cityHash
                }
            } 
            "Airports" {
                foreach($airportJson in $json.airports)
                {
                    $airportHash=@{}
                    $airportHash["IataCode"]=$airportJson.iataCode
                    $airportHash["Name"]=$airportJson.name
                    $airportHash["Base"]=[boolean]$airportJson.base
                    $airportHash["CountryCode"]=$airportJson.countryCode
                    $airportHash["CityCode"]=$airportJson.cityCode
                    New-Object PSObject –Prop $airportHash
                }
            } 
        }    
    }

    End {
    }

}