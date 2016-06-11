function New-DateBadge {
    $utcDate=(Get-Date).ToUniversalTime()
    New-MDImage -Subject "Last update (UTC)" -Status $utcDate.ToString() -Color lightgrey
}