function Initialize-CurrentCulture {
	Process {
        $currentThread = [System.Threading.Thread]::CurrentThread
        $culture = $CurrentThread.CurrentCulture.Clone()
        $culture.DateTimeFormat.ShortDatePattern = 'dd/MM/yyyy'
        $currentThread.CurrentCulture = $culture
        $currentThread.CurrentUICulture = $culture

        $date=Get-Date
        Write-Verbose "Automatic date $($date.ToShortDateString())"
        Write-Verbose "Manual date $($date.ToString('dd/MM/yyyy'))"
	}
}