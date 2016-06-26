param (
    [Parameter(Mandatory=$false)]
    [switch]
    $MockHugo=$false
)
If ($PSBoundParameters.Debug -eq $true) { $DebugPreference='continue' }

$contentPath="$PSScriptRoot\..\content"

if(Test-Path $contentPath)
{
    Remove-Item "$contentPath\*" -Recurse -Force
}
else
{
    New-Item $contentPath -ItemType Directory | Out-Null
}
$contentPath=Resolve-Path $contentPath
Write-Verbose "$contentPath is ready"


#region import commandlets
Write-Debug "Import cmdlets"

. "$PSScriptRoot\CmdLets\Session\Initialize-CurrentCulture.ps1"
. "$PSScriptRoot\CmdLets\Badges\New-DateBadge.ps1"
. "$PSScriptRoot\CmdLets\Date\New-WeekendExcursionSettings.ps1"
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

Write-Verbose "Imported cmdlets"
#endregion

Initialize-CurrentCulture

$weekendSettings=New-WeekendExcursionSettings
Write-Verbose "weekendSettings is ready"

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
        Write-Debug "GroupMethod=$GroupMethod" 
        Write-Debug "flights.Count=$($flights.Count)" 

        $origin=$flights| Select-Object -ExpandProperty Origin -Unique
        $originCity=$flights| Select-Object -ExpandProperty OriginCity -Unique
        $originCountry=$flights| Select-Object -ExpandProperty OriginCountry -Unique
        Write-Debug "origin=$origin" 
        Write-Debug "originCity=$originCity" 
        Write-Debug "originCountry=$originCountry" 

        $destination=$flights| Select-Object -ExpandProperty Destination -Unique
        $destinationCity=$flights| Select-Object -ExpandProperty DestinationCity -Unique
        $destinationCountry=$flights| Select-Object -ExpandProperty DestinationCountry -Unique
        Write-Debug "destination=$destination" 
        Write-Debug "destinationCity=$destinationCity" 
        Write-Debug "destinationCountry=$destinationCountry" 
        
        $relativeFolderPath="From\$originCountry\$originCity-$origin\To\$destinationCountry"
        $mdRelativeFileName="$destinationCity-$destination.Flights.$GroupMethod.md"
        $mdRelativePath=Join-Path $relativeFolderPath $mdRelativeFileName           

        $mdPath=Join-Path $contentPath $mdRelativePath
        Write-Debug "mdPath=$mdPath" 

        $maximumRegularFare=($flights | Measure -Maximum -Property RegularFare).Maximum
        $minimumRegularFare=($flights | Measure -Minimum -Property RegularFare).Minimum

        $title="Weekends from $originCity ($origin) of $originCountry to $destinationCity ($destination) of $destinationCountry"
        $description="Available valid weekend excursions arranged by "
        switch ($GroupMethod)
        {
            'ByWeekend' {$description+="weekend."}
            'ByFare' {$description+="fare price."}
        }
        $badgeMinimumRegularFare=New-MDImage -Subject "Lowest" -Status ("{0:N2}" -f $minimumRegularFare) -Color green
        $badgeMaximumRegularFare=New-MDImage -Subject "Highest" -Status ("{0:N2}" -f $maximumRegularFare) -Color red
        $description+=" Prices range from $badgeMinimumRegularFare to $badgeMaximumRegularFare."
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

        $regular25=$minimumRegularFare+($maximumRegularFare-$minimumRegularFare)*0.25
        $regular50=$minimumRegularFare+($maximumRegularFare-$minimumRegularFare)*0.50
        $regular75=$minimumRegularFare+($maximumRegularFare-$minimumRegularFare)*0.75

        if($GroupMethod -eq "ByWeekend")
        {
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
        Write-Verbose "Saved $mdPath"
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
    Write-Verbose "env:PSModulePath is ready"
    $env:PSModulePath -split ';' |Write-Verbose

    $date=Get-Date -Format "yyyyMMdd"
    $exportPath=Join-Path $env:TEMP $date
    Write-Verbose "exportPath=$exportPath"

    $flightFilePath=Get-ChildItem -Path $exportPath -Exclude @("Airports.json","Cities.json","Countries.json")
    $flights=@()
    $flightFilePath|ForEach-Object {
        Write-Verbose "Reading $($_.FullName)"
        $flights+=$_|Get-Content -Raw |ConvertFrom-Json
        Write-Verbose "Read $($_.FullName)"
    }
    $mdPath=Join-Path $contentPath "index.md"

    $airports=Get-Content -Path (Join-Path $exportPath "Airports.json")  -Raw| ConvertFrom-Json
    Write-Verbose "Read airports"
    $cities=Get-Content -Path (Join-Path $exportPath "Cities.json") -Raw| ConvertFrom-Json
    Write-Verbose "Read cities"
    $countries=Get-Content -Path (Join-Path $exportPath "Countries.json") -Raw| ConvertFrom-Json
    Write-Verbose "Read countries"

    $uniqueIATACodes= $flights|Select-Object -ExpandProperty Origin -Unique
    if(-not ($uniqueIATACodes.GetType().IsArray))
    {
        $uniqueIATACodes=@($uniqueIATACodes)    
    }
    $uniqueIATACodes+= $flights|Select-Object -ExpandProperty Destination -Unique
    $uniqueIATACodes=$uniqueIATACodes|Select-Object -Unique
    Write-Verbose "uniqueIATACodes=$uniqueIATACodes"

    $processedLocations=@()
    $uniqueIATACodes|ForEach-Object {
        $hash=@{}
        $airport=$airports |Where-Object -Property IataCode -EQ $_
        $hash["IATA"]=$_
        $hash["City"]=$cities| Where-Object -Property Code -EQ $airport.CityCode|Select-Object -ExpandProperty Name
        $hash["Country"]=$countries| Where-Object -Property Code -EQ $airport.CountryCode|Select-Object -ExpandProperty Name
        $processedLocations+=New-Object PSObject –Prop $hash
    }
    Write-Debug "processedLocations.Count=$($processedLocations.Count)"

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
    Write-Debug "flights adjusted"
    $flights=$flights|Sort-Object OriginCountry
    Write-Debug "flights sorted per country"

    $ryanAirLink=New-MDLink -Text "RyanAir" -Link "https://ryanair.com/"

    $title="Ryan Air Weekend excursions"
    $description="Possible $ryanAirLink weekend excursions organized by origin and destination."

    $markdown=New-HugoFrontMatter -Title $title -Description $description -IsRoot $true

    $markdown+=New-MDHeader "Quick jump list {#top}"-Level 2
    $markdown+=New-MDParagraph
    $markdown+=$flights|Select-Object -ExpandProperty OriginCountry -Unique| ForEach-Object {
      New-MDLink -Text $_ -Link (ConvertTo-HugoRef -RelLink "#$_")
    }|New-MDList -Style Unordered
    $markdown+=New-MDParagraph

    $flights|Group-Object OriginCountry|ForEach-Object {
        $originCountry=$_.Name
        $flightsInCountry=$_.Group |Sort-Object OriginCity

        $achors+=
        $markdown+=New-MDHeader "$originCountry {#$originCountry}"-Level 2
        $markdown+=New-MDParagraph

        $flightsInCountry|Group-Object Origin | ForEach-Object {
            $origin=$_.Name
            $originCity=$_.Group|Select-Object -ExpandProperty OriginCity -First 1
            $flightsInCity=$_.Group |Sort-Object DestinationCity

            $markdown+=New-MDHeader "$originCity ($origin)" -Level 3
            $markdown+=New-MDParagraph
            #$markdown+="Flights departing from $originCity ($origin)" |New-MDParagraph

            $table=$flightsInCity |Select-Object -ExpandProperty Destination -Unique| Select-Object -Property @{Name="Destination";Expression={
                $destinationLocation=$processedLocations|Where-Object -Property IATA -EQ $_
                New-MDCharacterStyle -Text $destinationLocation.City -Style Bold
                " "
                "("+(New-MDCharacterStyle -Text $destinationLocation.Country -Style Italic)+")"
            }},@{Name="Grouped By Weekend";Expression={
                $destinationLocation=$processedLocations|Where-Object -Property IATA -EQ $_
                $relativeFolderPath="From\$($originCountry)\$($originCity)-$origin\To\$($destinationLocation.Country)"
                $mdRelativePath=Join-Path $relativeFolderPath "$($destinationLocation.City)-$_.Flights.ByWeekend.md" |ConvertTo-HugoRef          
                New-MDLink -Text "Open Flights" -Link $mdRelativePath
            }},@{Name="Ordered By Fare";Expression={
                $destinationLocation=$processedLocations|Where-Object -Property IATA -EQ $_
                $relativeFolderPath="From\$($originCountry)\$($originCity)-$origin\To\$($destinationLocation.Country)"
                $mdRelativePath=Join-Path $relativeFolderPath "$($destinationLocation.City)-$_.Flights.ByFare.md" |ConvertTo-HugoRef
                New-MDLink -Text "Open Flights" -Link $mdRelativePath
            }}

            $markdown+=$table | New-MDTable -Columns ([ordered]@{Destination="left";"Grouped By Weekend"="right";"Ordered By Fare"="right"})
            $markdown+=New-MDParagraph
            $markdown+=New-MDLink -Text "Back to the top" -Link (ConvertTo-HugoRef -RelLink "#top")
            $markdown+=New-MDParagraph
        }
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

#region About.md
try
{
    $mdPath=Join-Path $contentPath "about.md"

    $title="about"
    $description="Introduction and documentation for this site. Page was generated on $((Get-Date).ToShortDateString())"

    $markdown=New-HugoFrontMatter -Title $title -Description $description -IsRoot $false

    $markdown+=New-MDHeader "Introduction" -Level 2
    $markdown+=New-MDParagraph

    $ryanAirLink=New-MDLink -Text "RyanAir" -Link "https://ryanair.com/" -Title "RyanAir"
    $ryanAirImage=New-MDImage -Source "/RyanAir.jpg" -AltText "RyanAir" -Title "RyanAir"
    $lines=@(
        '{{< img-post path="/img/" file="RyanAir.jpg" alt="RyanAir" type="left" >}}'
        "This website shows valid weekend flights with $ryanAirLink organized by origin, destination and then by price or weekend."
        "With this web site you can quickly identify a possible weekend city trip from the airports in your vicinity."
        "When interested in a specific weekend then you browse the page organized "+("by weekend"|New-MDCharacterStyle -Style Bold)+"."
        "When interested in the best price then you browse the page organized "+("by fair price"|New-MDCharacterStyle -Style Bold)+"."
    )
    $markdown+=$lines |New-MDParagraph

    $markdown+=New-MDHeader "Why are the prices color coded?" -Level 2
    $markdown+=New-MDParagraph
    $lines=@(
        "Color coding enables you to quickly identify the most competitive weekends. This is how it works. "
        "For every combination of origin and destination the minimum and maximum fair is calculated and then split in four zones by 25% each. "
        "For example if the lowest price is 50.00 and the maximum is 250 then the color coding will be ranked like this:"
    )
    $markdown+=$lines|New-MDParagraph
    $minimumRegularFare=50
    $maximumRegularFare=250
    $regular25=$minimumRegularFare+($maximumRegularFare-$minimumRegularFare)*0.25
    $regular50=$minimumRegularFare+($maximumRegularFare-$minimumRegularFare)*0.50
    $regular75=$minimumRegularFare+($maximumRegularFare-$minimumRegularFare)*0.75

    $zones=@(
        New-MDImage -Subject "Low" -Status ("{0:N2}" -f $minimumRegularFare +" - "+ "{0:N2}" -f $regular25) -Color green
        New-MDImage -Subject "Normal" -Status ("{0:N2}" -f $regular25 +" - "+ "{0:N2}" -f $regular50) -Color blue
        New-MDImage -Subject "High" -Status ("{0:N2}" -f $regular50 +" - "+ "{0:N2}" -f $regular75) -Color orange
        New-MDImage -Subject "Highest" -Status ("{0:N2}" -f $regular75 +" - "+ "{0:N2}" -f $maximumRegularFare) -Color red
    )
    $markdown+=$zones|New-MDList -Style Ordered
    $markdown+=New-MDParagraph

    $markdown+=New-MDHeader "What defines a valid weekend?" -Level 2
    $markdown+=New-MDParagraph
    $markdown+="This site is focused on short city trips during a weekend. A valid journey is one that:"|New-MDParagraph
    $markdown+=New-MDParagraph

    $lines=@(
       "Departs to target city from Friday $($weekendSettings.OutboundEarliestFriday):00 or arrives there until Saturday $($weekendSettings.OutboundLatestSaturday):00"
       "Departs from target city from Sunday $($weekendSettings.InboundEarliestSunday):00 or arrives back until Monday $($weekendSettings.InboundLatestMonday):00"
    )
    $markdown+=$lines |New-MDList -Style Unordered
    $markdown+=New-MDParagraph

    $markdown+=New-MDHeader "Range of data" -Level 2
    $markdown+=New-MDParagraph
    $minMaxDate=$flights| Measure-Object -Property "OutboundFrom" -Minimum -Maximum
    $months=$minMaxDate.Maximum.Date.Subtract($minMaxDate.Minimum.Date).Months
    $lines=@(
        "Earliest flight date is on $($minMaxDate.Minimum.Date.ToShortDateString()) and latest on $($minMaxDate.Maximum.Date.ToShortDateString()). "
        New-MDParagraph
        "Location processed are:"
    )
    $markdown+=$lines|New-MDParagraph
    $markdown+=$processedLocations|Select-Object -Property @{Name="Name";Expression={
            "$($_.City |New-MDCharacterStyle -Style Bold) ($($_.IATA)) in $($_.Country)"
        }} | Select-Object -ExpandProperty Name| New-MDList -Style Unordered 
    $markdown+=New-MDParagraph

    $markdown+=New-MDHeader "Technical information" -Level 2
    $markdown+=New-MDParagraph

    $githubLink=New-MDLink -Text "Github" -Link "https://github.com/" -Title "Github"
    $githubPagesLink=New-MDLink -Text "Github pages" -Link "https://pages.github.com/" -Title "Github pages"
    $hugoLink=New-MDLink -Text "Hugo" -Link "https://gohugo.io/" -Title "Hugo"
    $repositoryLink=New-MDLink -Text "RyanAirWeekend" -Link "https://github.com/Sarafian/RyanAirWeekend/" -Title "RyanAirWeekend"
    $readmeLink=New-MDLink -Text "README.md" -Link "https://github.com/Sarafian/RyanAirWeekend/blob/master/README.md" -Title "README.md"
    $markdownPSLink=New-MDLink -Text "MarkdownPS" -Link "https://www.powershellgallery.com/packages/MarkdownPS/" -Title "MarkdownPS"
    $ryanAirPSLink=New-MDLink -Text "RyanAirPS" -Link "https://www.powershellgallery.com/packages/RyanAirPS/" -Title "RyanAirPS"
    $visualStudioTeamServicesLink=New-MDLink -Text "Visual Studio Team Services" -Link "https://visualstudio.com/" -Title "Visual Studio Team Services"
    $lines=@(
        "All data owned by $ryanAirLink are extracted using their api. "
        "The site is powered by $githubPagesLink and $hugoLink. "
        "$visualStudioTeamServicesLink drives the continuous build. "
        "Code is available in github repository $repositoryLink."
    )
    $markdown+=$lines|New-MDList -Style Unordered
    $markdown+=New-MDParagraph
    $markdown+="The process is implemented in PowerShell and is split in the following steps:"|New-MDParagraph
    $markdown+=New-MDParagraph

    $steps=@(
        "PowerShell module $ryanAirPSLink extracts the data from $ryanAirLink"
        "PowerShell module $markdownPSLink helps scripts render markdown files as $hugoLink content."
        "$hugoLink processes the markdown content and generates static html files."
        "Scripts push the html files to gh-pages branch in $repositoryLink"
    )

    $markdown+=$steps|New-MDList -Style Ordered
    $markdown+=New-MDParagraph

    $markdown+="Read more about the process in $readmeLink"|New-MDParagraph
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


