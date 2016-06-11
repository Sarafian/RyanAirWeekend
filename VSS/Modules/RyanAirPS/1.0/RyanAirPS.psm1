$names=@(
    "Get-RyanAirFlights"
    "Get-RyanAirCommon"
    "Get-RyanAirSchedules"
)

$names | ForEach-Object {. $PSScriptRoot\$_.ps1 }

Export-ModuleMember $names


