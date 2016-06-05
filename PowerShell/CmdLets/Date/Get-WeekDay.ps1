function Get-WeekDay{
    param(
        [Parameter(Mandatory=$true)]
        [DateTime] $From,
        [Parameter(Mandatory=$true)]
        [DateTime] $To,
        [Parameter(Mandatory=$true)]
        [System.DayOfWeek] $DayOfWeek
    )
    $todayDate=(Get-Date).Date
    if($From -le $todayDate)
    {
        $From=$todayDate
    }
    $date=$From.AddDays(-[int]$From.DayOfWeek).AddDays([int]$DayOfWeek)
    if($date -lt $From)
    {
        $date=$date.AddDays(7)
    }
    $dates=@()
    while($date -le $To)
    {
        $dates+=$date.Date
        $date=$date.AddDays(7)
    }
    return $dates
}