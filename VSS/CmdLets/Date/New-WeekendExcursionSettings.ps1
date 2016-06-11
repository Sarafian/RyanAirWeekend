function New-WeekendExcursionSettings{
    param(
        [Parameter(Mandatory=$false)]
        [int] $OutboundEarliestFriday=17,
        [Parameter(Mandatory=$false)]
        [int] $OutboundLatestSaturday=13,
        [Parameter(Mandatory=$false)]
        [int] $InboundEarliestSunday=18,
        [Parameter(Mandatory=$false)]
        [int]$InboundLatestMonday=9
    )

    $settingsHash=@{
            "OutboundEarliestFriday"=$OutboundEarliestFriday;
            "OutboundLatestSaturday"=$OutboundLatestSaturday;
            "InboundEarliestSunday"=$InboundEarliestSunday;
            "InboundLatestMonday"=$InboundLatestMonday;
            }
    return New-Object PSObject –Prop $settingsHash
}
