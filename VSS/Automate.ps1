Param (
    [Parameter(
        Mandatory=$false
    )]
    [string]$ThemeBranch,
    [Parameter(
        Mandatory=$false
    )]
    [switch]$BuildDrafts=$false,
    [Parameter(
        Mandatory=$true
    )]
    [string]$GitToken,
    [Parameter(
        Mandatory=$false
    )]
    [switch]$Push=$false

)

$invokeGit= {
    Param (
        [Parameter(
            Mandatory=$true
        )]
        [string]$Reason,
        [Parameter(
            Mandatory=$true
        )]
        [string[]]$ArgumentsList
    )
    try
    {
        $gitPath=& "C:\Windows\System32\where.exe" git
        $gitErrorPath=Join-Path $env:TEMP "stderr.txt"
        $gitOutputPath=Join-Path $env:TEMP "stdout.txt"
        if($gitPath.Count -gt 1)
        {
            $gitPath=$gitPath[0]
        }

        Write-Verbose "[Git][$Reason] Begin"
        Write-Verbose "[Git][$Reason] gitPath=$gitPath"
        Write-Host "git $arguments"
        $process=Start-Process $gitPath -ArgumentList $ArgumentsList -NoNewWindow -PassThru -Wait -RedirectStandardError $gitErrorPath -RedirectStandardOutput $gitOutputPath
        $outputText=(Get-Content $gitOutputPath)
        $outputText | ForEach-Object {Write-Host $_}

        Write-Verbose "[Git][$Reason] process.ExitCode=$($process.ExitCode)"
        if($process.ExitCode -ne 0)
        {
            Write-Warning "[Git][$Reason] process.ExitCode=$($process.ExitCode)"
            $errorText=$(Get-Content $gitErrorPath)
            $errorText | ForEach-Object {Write-Host $_}

            if($errorText -ne $null)
            {
                exit $process.ExitCode
            }
        }
        return $outputText
    }
    catch
    {
        Write-Error "[Git][$Reason] Exception $_"
    }
    finally
    {
        Write-Verbose "[Git][$Reason] Done"
    }
}

try
{
    $gitPath=& "C:\Windows\System32\where.exe" git
    $gitErrorPath=Join-Path $env:TEMP "stderr.txt"
    $gitOutputPath=Join-Path $env:TEMP "stdout.txt"
    if($gitPath.Count -gt 1)
    {
        $gitPath=$gitPath[0]
    }
    Write-Verbose "gitPath=$gitPath"
    $sourceRepositoryPath=Resolve-Path "$PSScriptRoot\..\"
    Write-Verbose "sourceRepositoryPath=$sourceRepositoryPath"
    


    #region update the theme
    if($ThemeBranch)
    {
        $themePath="$sourceRepositoryPath\themes\my-hugo-future-imperfect"
        Write-Verbose "themePath=$sourceRepositoryPath"
        Push-Location $themePath
        try
        {
            $arguments=@(
                "status"
                "-b"
                "--porcelain"
            )
            $status=Invoke-Command -ScriptBlock $invokeGit -ArgumentList "Status porcelain",$arguments
            if($status -notmatch $ThemeBranch)
            {
                $arguments=@(
                    "checkout"
                    "$ThemeBranch"
                )
                Invoke-Command -ScriptBlock $invokeGit -ArgumentList "Checkout",$arguments
            }
            $arguments=@(
                "pull"
            )
            Invoke-Command -ScriptBlock $invokeGit -ArgumentList "Pull",$arguments
        }
        finally
        {
            Pop-Location

        }
    }
    #endregion


    Push-Location $sourceRepositoryPath
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

    #region checkout master sarafian.github.io
    #$githubUrl="https://github.com/Sarafian/sarafian.github.io.git"
    $githubUrl="https://$GitToken@github.com/Sarafian/sarafian.github.io.git"
    $clonePath=Join-Path $env:TEMP "clone"
    if(Test-Path ($clonePath))
    {
        Remove-Item $clonePath -Force -Recurse | Out-Null
    }
    New-Item $clonePath -ItemType Directory |Out-Null
    Write-Verbose "Cloning $githubUrl to $clonePath"
    Push-Location $clonePath
    try
    {
        $arguments=@(
            "clone"
            "-b"
            "master"
            "$githubUrl"
        )
        Invoke-Command -ScriptBlock $invokeGit -ArgumentList "Clone",$arguments
    }
    finally
    {
        Pop-Location

    }
    $targetRepositoryPath="$clonePath\sarafian.github.io"
    Write-Verbose "targetRepositoryPath=$targetRepositoryPath"

    #endregion

    #region build
    $hugoPath=Join-Path $expandPath "$hugoName.exe"
    Write-Verbose "hugoPath=$hugoPath"

    Write-Debug "Executing $hugoPath"
    $arguments=@()
    if($BuildDrafts)
    {
        $arguments+="--buildDrafts"
    }
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
    
    $publicPath=Join-Path $sourceRepositoryPath public
    Copy-Item "$publicPath\*" "$targetRepositoryPath" -Recurse -Force -Verbose
    #endregion


    #region push to origin master
    try
    {
        Push-Location $targetRepositoryPath
        $arguments=@(
            "status"
        )
        Invoke-Command -ScriptBlock $invokeGit -ArgumentList "Status",$arguments

        $msg="rebuilding site $(Get-Date)"
        $arguments=@(
            "add"
            "-A"
        )
        Invoke-Command -ScriptBlock $invokeGit -ArgumentList "Add",$arguments

        $arguments=@(
            "commit"
            "-m"
            '"'+$msg+'"'
        )
        Invoke-Command -ScriptBlock $invokeGit -ArgumentList "Commit",$arguments

        if($Push)
        {
            $arguments=@(
                "push"
            )
            Invoke-Command -ScriptBlock $invokeGit -ArgumentList "Push",$arguments
        }
        else
        {
            Write-Warning "Did not push"
        }
    }
    catch
    {
        Write-Error $_
        throw
    }
    finally
    {
        Pop-Location
    }

}
catch
{
    Write-Error $_
    throw
}
finally
{
    Pop-Location
}