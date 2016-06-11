function Test-WeekDayZone{
    param(
        [Parameter(Mandatory=$true)]
        [DateTime] $Date,
        [Parameter(Mandatory=$true)]
        [System.DayOfWeek] $DayOfWeek,
        [Parameter(Mandatory=$false)]
        [int] $FromHours=0,
        [Parameter(Mandatory=$false)]
        [int] $ToHours=24
    )
    if(-not ($Date.DayOfWeek -eq $DayOfWeek))
    {
        return $false
    }
    $fromDate=Get-Date -Date $Date -Hour $FromHours -Minute 0 -Second 0 -Millisecond 0
    if($ToHours -eq 24)
    {
        $toDate=(Get-Date -Date $fromDate).AddDays(1).Date
    }
    else
    {
        $toDate=(Get-Date -Date $fromDate).Date.AddHours($ToHours)
    }
    return ($Date  -ge $fromDate) -and ($Date -le $toDate)
}