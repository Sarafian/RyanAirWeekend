try
{
    Push-Location "$PSScriptRoot\.."

    $hugoName="hugo_0.15_windows_amd64"

    #region download hugo
    $url = "https://github.com/spf13/hugo/releases/download/v0.15/$hugoName.zip"
    $downloadPath = Join-Path $env:TEMP "$hugoName.zip"
    if(Test-Path ($downloadPath))
    {
        Remove-Item $downloadPath -Force -Recurse | Out-Null
    }

    Write-Debug "Downloading $url to $downloadPath"
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($url, $downloadPath)
    Write-Verbose "Downloaded $url to $downloadPath"
    #endrergion

    #region expand
    $expandPath=Join-Path $env:TEMP $hugoName
    if(Test-Path ($expandPath))
    {
        Remove-Item $expandPath -Force -Recurse | Out-Null
    }

    New-Item -Path $expandPath -ItemType Directory|Out-Null
    Write-Verbose "Created directory $expandPath"
    
    Write-Debug "Expanding $downloadPath to $expandPath"
    [System.Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem')|Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory($downloadPath, $expandPath)|Out-Null
    Write-Verbose "Expanded $downloadPath to $expandPath"
    #endregion

    #region build
    $hugoPath=Join-Path $expandPath "$hugoName.exe"
    Write-Verbose "hugoPath=$hugoPath"

    Write-Debug "Executing $hugoPath"
    $arguments=@()
    $arguments+="-v"
	$hugoBuild=& $hugoPath $arguments
    $hugoBuild| ForEach-Object {Write-Host $_}

    if($hugoBuild -match "ERROR")
    {
        Write-Error "Hugo build failed"
        exit 1
    }
    Write-Verbose "Hugo build success"
    Write-Verbose "Executed $hugoPath"
    #endregion
}
catch
{
    Write-Error $_
    exit -1
}
finally
{
    Pop-Location
}