function Set-CultureInvariant {
	Process {
		$culture=[System.Globalization.CultureInfo]::InvariantCulture
		[System.Threading.Thread]::CurrentThread.CurrentUICulture = $culture
		[System.Threading.Thread]::CurrentThread.CurrentCulture = $culture

        $date=Get-Date
        Write-Verbose "Automatic date $($date.ToShortDateString())"
        Write-Verbose "Manual date $($date.ToString('dd/MM/yyyy'))"
	}
}