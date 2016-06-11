param (
    [Parameter(Mandatory=$false)]
    [switch]
    $MockHugo=$false
)
$contentPath=Resolve-Path "$PSScriptRoot\..\content"

if(Test-Path $contentPath)
{
    Remove-Item "$contentPath\*" -Recurse -Force
}
else
{
    New-Item $contentPath -ItemType Directory | Out-Null
}
Write-Verbose "$contentPath is ready"


#region import commandlets

. "$PSScriptRoot\CmdLets\Badges\New-DateBadge.ps1"
if($MockHugo)
{
    $hugoFolderName="Hugo.Mock"
}
else
{
    $hugoFolderName="Hugo"
}
. "$PSScriptRoot\CmdLets\$hugoFolderName\ConvertTo-HugoRef.ps1"
. "$PSScriptRoot\CmdLets\$hugoFolderName\New-HugoFrontMatter.ps1"

. "$PSScriptRoot\CmdLets\Date\Get-WeekDay.ps1"
. "$PSScriptRoot\CmdLets\Date\New-WeekendExcursionSettings.ps1"
. "$PSScriptRoot\CmdLets\Date\Test-WeekDayZone.ps1"
#endregion

$weekendSettings=New-WeekendExcursionSettings


#region process origin
$renderFlightsBlock={
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("ByWeekend","ByFare")]
        [string]$GroupMethod,
        [Parameter(Mandatory=$true)]
        [psobject[]]$flights
    )
    try
    {
        $origin=$flights| Select-Object -ExpandProperty Origin -Unique
        $originCity=$flights| Select-Object -ExpandProperty OriginCity -Unique
        $originCountry=$flights| Select-Object -ExpandProperty OriginCountry -Unique

        $destination=$flights| Select-Object -ExpandProperty Destination -Unique
        $destinationCity=$flights| Select-Object -ExpandProperty DestinationCity -Unique
        $destinationCountry=$flights| Select-Object -ExpandProperty DestinationCountry -Unique
        
        $relativeFolderPath="From\$originCountry\$originCity-$origin\To\$destinationCountry"
        $mdRelativeFileName="$destinationCity-$destination.Flights.$GroupMethod.md"
        $mdRelativePath=Join-Path $relativeFolderPath $mdRelativeFileName           

        $mdPath=Join-Path $contentPath $mdRelativePath

        $title="Weekends from $originCity ($origin) to $destinationCity ($destination)"
        $description="Available weekend excursions from $originCity of $originCountry to $destinationCity of $destinationCountry arranged by "
        switch ($GroupMethod)
        {
            'ByWeekend' {$description+="weekend"}
            'ByFare' {$description+="Fare price"}
        }
        
        $metadata=@{
            origin=$origin
            originCity=$originCity
            originCountry=$originCountry
            destination=$destination
            destinationCity=$destinationCity
            destinationCountry=$destinationCountry
        }

        switch ($GroupMethod)
        {
            'ByWeekend' {
                $metadata["Organize"]="By weekend"
                $metadata["AlternateTitle"]="By fare"
                $metadata["AlternateFile"]=$mdRelativeFileName.Replace($GroupMethod,"ByFare")
            }
            'ByFare' {
                $metadata["Organize"]="By fare"
                $metadata["AlternateTitle"]="By weekend"
                $metadata["AlternateFile"]=$mdRelativeFileName.Replace($GroupMethod,"ByWeekend")
            }
        }

        $markdown=New-HugoFrontMatter -Title $title -Description $description -IsRoot $false -Metadata $metadata

        $markdown+=New-MDHeader "Price zones" -Level 2
        $markdown+=New-MDParagraph
                
        $maximumRegularFare=($flights | Measure -Maximum -Property RegularFare).Maximum
        $minimumRegularFare=($flights | Measure -Minimum -Property RegularFare).Minimum

        $regular25=$minimumRegularFare+($maximumRegularFare-$minimumRegularFare)*0.25
        $regular50=$minimumRegularFare+($maximumRegularFare-$minimumRegularFare)*0.50
        $regular75=$minimumRegularFare+($maximumRegularFare-$minimumRegularFare)*0.75

        $lines=@(
            "For this destination the cheapest round trip regular fare is  "+ ("{0:N2}" -f $minimumRegularFare)
            " and the most expensive "+ ("{0:N2}" -f $maximumRegularFare)
            ". The prices are split and marked based on the following maximums:"
        )
        $markdown+=$lines|New-MDParagraph
        $markdown+=New-MDParagraph
        $zones=@(
            New-MDImage -Subject "Low" -Status ("{0:N2}" -f $minimumRegularFare +" - "+ "{0:N2}" -f $regular25) -Color green
            New-MDImage -Subject "Normal" -Status ("{0:N2}" -f $regular25 +" - "+ "{0:N2}" -f $regular50) -Color blue
            New-MDImage -Subject "High" -Status ("{0:N2}" -f $regular50 +" - "+ "{0:N2}" -f $regular75) -Color orange
            New-MDImage -Subject "Highest" -Status ("{0:N2}" -f $regular25 +" - "+ "{0:N2}" -f $maximumRegularFare) -Color red
        )
        $markdown+=$zones|New-MDList -Style Ordered
        $markdown+=New-MDParagraph

        if($GroupMethod -eq "ByWeekend")
        {
            $markdown+=New-MDHeader "Grouped by weekend"
            $markdown+=New-MDParagraph
            $flights|Sort-Object -Property Friday|Group-Object -Property Friday |ForEach-Object {
                $markdown+=New-MDHeader "Weekend of $($_.Values[0].ToShortDateString())" -Level 2
                $markdown+=New-MDParagraph

                $data=$_.Group
                $table=$data|Sort-Object -Property RegularFare|Select-Object -Property @{Name="Outbound Day";Expression={
                    $_.OutboundFrom.DayOfWeek
                }},@{Name="Outbound From";Expression={
                    $_.OutboundFrom.ToShortTimeString()
                }},@{Name="Outbound To";Expression={
                    $_.OutboundTo.ToShortTimeString()
                }},@{Name="Inbound Day";Expression={
                    $_.InboundFrom.DayOfWeek
                }},@{Name="Inbound From";Expression={
                    $_.InboundFrom.ToShortTimeString()
                }},@{Name="Inbound To";Expression={
                    $_.InboundTo.ToShortTimeString()
                }},@{Name="Regular Fare";Expression={
                    $total=$_.RegularFare
                    if($total -lt $regular25)
                    {
                        New-MDImage -Subject "Low" -Status ("{0:N2}" -f $total) -Color green
                    }
                    elseif ($total -lt $regular50)
                    {
                        New-MDImage -Subject "Normal" -Status ("{0:N2}" -f $total) -Color blue
                    }
                    elseif ($total -lt $regular75)
                    {
                        New-MDImage -Subject "High" -Status ("{0:N2}" -f $total) -Color orange
                    }
                    else
                    {
                        New-MDImage -Subject "Highest" -Status ("{0:N2}" -f $total) -Color red
                    }
                }}
                $markdown+=$table | New-MDTable -Columns ([ordered]@{"Outbound Day"="left";"Outbound From"="left";"Outbound To"="left";"InBound Day"="center";"InBound From"="center";"InBound To"="center";"Regular Fare"="right"})
            }
        }

        if($GroupMethod -eq "ByFare")
        {
            $markdown+=New-MDHeader "Ordered by Fare"
            $markdown+=New-MDParagraph
            $table=$flights|Sort-Object -Property RegularFare|Select-Object -Property @{Name="Weekend";Expression={
                "$($_.Friday.AddDays(1).Day)-$($_.Friday.AddDays(2).Day)/$($_.Friday.Month)/$($_.Friday.Year)"
            }},@{Name="Outbound Day";Expression={
                $_.OutboundFrom.DayOfWeek
            }},@{Name="Outbound From";Expression={
                $_.OutboundFrom.ToShortTimeString()
            }},@{Name="Outbound To";Expression={
                $_.OutboundTo.ToShortTimeString()
            }},@{Name="Inbound Day";Expression={
                $_.InboundFrom.DayOfWeek
            }},@{Name="Inbound From";Expression={
                $_.InboundFrom.ToShortTimeString()
            }},@{Name="Inbound To";Expression={
                $_.InboundTo.ToShortTimeString()
            }},@{Name="Regular Fare";Expression={
                $total=$_.RegularFare
                if($total -lt $regular25)
                {
                    New-MDImage -Subject "Low" -Status ("{0:N2}" -f $total) -Color green
                }
                elseif ($total -lt $regular50)
                {
                    New-MDImage -Subject "Normal" -Status ("{0:N2}" -f $total) -Color blue
                }
                elseif ($total -lt $regular75)
                {
                    New-MDImage -Subject "High" -Status ("{0:N2}" -f $total) -Color orange
                }
                else
                {
                    New-MDImage -Subject "Highest" -Status ("{0:N2}" -f $total) -Color red
                }
            }}
            $markdown+=$table | New-MDTable -Columns ([ordered]@{"Weekend"="right";"Outbound Day"="left";"Outbound From"="left";"Outbound To"="left";"InBound Day"="center";"InBound From"="center";"InBound To"="center";"Regular Fare"="right"})
        }

    }
    catch
    {
        Write-Error $_
        $markdown+=New-MDParagraph "Error captured"
        $markdown+=New-MDQuote $_
    }
    finally
    {
        New-Item $mdPath -ItemType File -Force | Out-Null
        $markdown|Out-File $mdPath -Encoding ASCII -Force
    }
}

#endregion



#region Index.md
try
{
    $markdownPSCommand=Get-Command New-MDParagraph -ErrorAction SilentlyContinue
	if(-not ($markdownPSCommand)) {
		Write-Warning "MarkdownPS module not found"
		$env:PSModulePath+=";$PSScriptRoot\Modules"
	}

    $date=Get-Date -Format "yyyyMMdd"
    $exportPath=Join-Path $env:TEMP $date

    $flightFilePath=Get-ChildItem -Path $exportPath -Exclude @("Airports.json","Cities.json","Countries.json")
    $flights=@()
    $flightFilePath|ForEach-Object {
        $flights+=$_|Get-Content|ConvertFrom-Json
    }

    $airports=Get-Content -Path (Join-Path $exportPath "Airports.json")| ConvertFrom-Json
    $cities=Get-Content -Path (Join-Path $exportPath "Cities.json") | ConvertFrom-Json
    $countries=Get-Content -Path (Join-Path $exportPath "Countries.json")| ConvertFrom-Json

    $uniqueIATACodes= $flights|Select-Object -ExpandProperty Origin -Unique
    if(-not ($uniqueIATACodes.GetType().IsArray))
    {
        $uniqueIATACodes=@($uniqueIATACodes)    
    }
    $uniqueIATACodes+= $flights|Select-Object -ExpandProperty Destination -Unique
    $uniqueIATACode=$uniqueIATACodes|Select-Object -Unique

    $processedLocations=@()
    $uniqueIATACodes|ForEach-Object {
        $hash=@{}
        $airport=$airports |Where-Object -Property IataCode -EQ $_
        $hash["IATA"]=$_
        $hash["City"]=$cities| Where-Object -Property Code -EQ $airport.CityCode|Select-Object -ExpandProperty Name
        $hash["Country"]=$countries| Where-Object -Property Code -EQ $airport.CountryCode|Select-Object -ExpandProperty Name
        $processedLocations+=New-Object PSObject –Prop $hash
    }

    $flights|ForEach-Object {
        $_.Friday=Get-Date $_.Friday
        $_.OutboundFrom=Get-Date $_.OutboundFrom
        $_.OutboundTo=Get-Date $_.OutboundTo
        $_.InboundFrom=Get-Date $_.InboundFrom
        $_.InboundTo=Get-Date $_.InboundTo
        $originLocation=$processedLocations|Where-Object -Property IATA -EQ $_.Origin
        $destinationLocation=$processedLocations|Where-Object -Property IATA -EQ $_.Destination
        $_ | Add-Member -NotePropertyName OriginCountry -NotePropertyValue $originLocation.Country
        $_ | Add-Member -NotePropertyName OriginCity -NotePropertyValue $originLocation.City
        $_ | Add-Member -NotePropertyName DestinationCountry -NotePropertyValue $destinationLocation.Country
        $_ | Add-Member -NotePropertyName DestinationCity -NotePropertyValue $destinationLocation.City
    }


    $mdPath=Join-Path $contentPath "Index.md"
    $minMaxDate=$flights|Measure-Object -Property Friday -Maximum -Minimum
    #$minDate=$minMaxDate.Minimum.Value.ToShortDate()
    #$maxDate=$minMaxDate.Maximum.Value.ToShortDate()

    $title="Ryan Air Weekend excursions"
    #$description="Available Ryan Air weekends from $minDate to $maxDate"
    $description="Available Ryan Air weekends."

    $markdown=New-HugoFrontMatter -Title $title -Description $description -IsRoot $true

    $markdown+=New-MDParagraph "Flights are filtered with the following conditions:"
    $lines=@(
       "Depart to destination after Friday $($weekendSettings.OutboundEarliestFriday):00"
       "Arrive at destination until Saturday $($weekendSettings.OutboundLatestSaturday):00"
       "Depart from destination after Sunday $($weekendSettings.InboundEarliestSunday):00"
       "Return until Monday $($weekendSettings.InboundLatestMonday):00"
    )
    $markdown+=New-MDParagraph
    $markdown+=$lines |New-MDList -Style Unordered
    $markdown+=New-MDParagraph

    $markdown+=New-MDParagraph "Countries processed:"
    $markdown+=New-MDParagraph
    $markdown+=($processedLocations|Select-Object -ExpandProperty Country) -join ', ' |  New-MDQuote 
    $markdown+=New-MDParagraph

    $markdown+=New-MDParagraph "Cities processed:"
    $markdown+=New-MDParagraph
    $markdown+=($processedLocations|Select-Object -ExpandProperty City) -join ', ' |  New-MDQuote 
    $markdown+=New-MDParagraph

    $flights|Group-Object Origin|ForEach-Object {
        $origin=$_.Name
        $originLocation=$processedLocations|Where-Object -Property IATA -EQ $origin

        $table=$_.Group|Sort-Object -Property DestinationCity |Select-Object -ExpandProperty Destination -Unique| Select-Object -Property @{Name="Destination";Expression={
            $destinationLocation=$processedLocations|Where-Object -Property IATA -EQ $_
            New-MDCharacterStyle -Text $destinationLocation.City -Style Bold
            " "
            "("+(New-MDCharacterStyle -Text $destinationLocation.Country -Style Italic)+")"
        }},@{Name="Grouped By Weekend";Expression={
            $destinationLocation=$processedLocations|Where-Object -Property IATA -EQ $_
            $relativeFolderPath="From\$($originLocation.Country)\$($originLocation.City)-$origin\To\$($destinationLocation.Country)"
            $mdRelativePath=Join-Path $relativeFolderPath "$($destinationLocation.City)-$_.Flights.ByWeekend.md" |ConvertTo-HugoRef          
            New-MDLink -Text "Open Flights" -Link $mdRelativePath
        }},@{Name="Ordered By Fare";Expression={
            $destinationLocation=$processedLocations|Where-Object -Property IATA -EQ $_
            $relativeFolderPath="From\$($originLocation.Country)\$($originLocation.City)-$origin\To\$($destinationLocation.Country)"
            $mdRelativePath=Join-Path $relativeFolderPath "$($destinationLocation.City)-$_.Flights.ByFare.md" |ConvertTo-HugoRef
            New-MDLink -Text "Open Flights" -Link $mdRelativePath
        }}

        $markdown+=New-MDHeader "Destinations from $($originLocation.City) ($origin) in $($originLocation.Country)" -Level 2
        $markdown+=New-MDParagraph
        $markdown+=$table |Sort-Object Country | New-MDTable -Columns ([ordered]@{Destination="left";"Grouped By Weekend"="right";"Ordered By Fare"="right"})
        $markdown+=New-MDParagraph

    }
    $flights|Group-Object Origin,Destination|ForEach-Object {
        Invoke-Command -ScriptBlock $renderFlightsBlock -ArgumentList ("ByWeekend",$_.Group)
        Invoke-Command -ScriptBlock $renderFlightsBlock -ArgumentList ("ByFare",$_.Group)
    }
    $markdown+=New-MDParagraph
}
catch
{
    Write-Error $_
    $markdown+=New-MDParagraph "Error captured"
    $markdown+=New-MDQuote $_
    exit -1
}
finally
{
    $markdown+=New-MDParagraph
    $markdown+=New-DateBadge
    $markdown|Out-File $mdPath -Encoding ASCII -Force
    Write-verbose "Saved $mdPath"
}
#endregion


