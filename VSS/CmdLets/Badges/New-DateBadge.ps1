function New-DateBadge {
    $utcDate=(Get-Date).ToUniversalTime()
    $timeZoneInfo=[system.TimeZoneInfo]::FindSystemTimeZoneById("W. Europe Standard Time")
    $date=[System.TimeZoneInfo]::ConvertTime($utcDate,[System.TimeZoneInfo]::Utc,$timeZoneInfo)
    New-MDImage -Subject "Last update ($($timeZoneInfo.Id))" -Status $date.ToString() -Color blue
}