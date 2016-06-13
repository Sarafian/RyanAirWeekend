Param (
    [Parameter(Mandatory=$true)]
    [string]$GitHubToken=$null,
    [Parameter(Mandatory=$false)]
    [switch]$Push=$false
)
If ($PSBoundParameters.Debug -eq $true) { $DebugPreference='continue' }

. "$PSScriptRoot\CmdLets\Session\Initialize-CurrentCulture.ps1"
. "$PSScriptRoot\Cmdlets\Git\Invoke-Git.ps1"

Initialize-CurrentCulture

try
{
    $stamp=Get-Date -Format "yyyyMMdd"
    $ghPagesPath=Join-Path $env:TEMP "$stamp.RyanAirWeekend"
    
    #region Clean gh-pages path directory
    Write-Debug "ghPagesPath=$ghPagesPath"
    if(Test-Path $ghPagesPath)
    {
        Remove-Item "$ghPagesPath\*" -Force -Recurse
    }
    else
    {
        New-Item $ghPagesPath -ItemType Directory |Out-Null
    }
    Write-Verbose "$ghPagesPath is ready"
    #endregion

    $githubUrl="https://github.com/Sarafian/RyanAirWeekend.git"
    Write-Debug "githubUrl=$githubUrl"
            
    if($GitHubToken)
    {
        $githubUrlWithToken=$githubUrl.Replace("https://","https://$GitHubToken@")
    }
    else
    {
        $githubUrlWithToken=$githubUrl
    }


    #region Add github.com remote
    $githubRemoteName="github"
    Write-Debug "githubRemoteName=$githubRemoteName"

    Write-Debug "Push-Location $ghPagesPath"
    Push-Location $ghPagesPath

    #region init
    $arguments=@(
        "init"
    )
    Invoke-Git -Reason "Git init" -ArgumentsList $arguments
    #endregion
            
    #region add origin
            
    $arguments=@(
        "remote"
        "add"
        $githubRemoteName
        $githubUrlWithToken
    )
    Invoke-Git -Reason "Add remote $githubRemoteName" -ArgumentsList $arguments
    #endregion

    #region fetch
            
    $arguments=@(
        "fetch"
        $githubRemoteName
    )
    Invoke-Git -Reason "Fetch $githubRemoteName" -ArgumentsList $arguments
    #endregion

    #region check if branch exists
            
    $arguments=@(
        "branch"
        "-a"
    )
    $branches=Invoke-Git -Reason "Query all branches" -ArgumentsList $arguments -PipeOutput

    $remoteBranchExits=$branches -match "remotes/$githubRemoteName/gh-pages"
    Write-Debug "remoteBranchExits=$remoteBranchExits"
    #endregion

    #region checkout
            
    $arguments=@(
        "checkout"
        "-b"
        "gh-pages"
    )

    if($remoteBranchExits)
    {
        $arguments+="$githubRemoteName/gh-pages"
    }
    Invoke-Git -Reason "Checkout " -ArgumentsList $arguments
    #endregion

    #region pull
    if($remoteBranchExits)
    {
        $arguments=@(
            "pull"
            $githubRemoteName
        )
        Invoke-Git -Reason "Pull " -ArgumentsList $arguments
    }

    #endregion

    #region Clean folder
    Write-Debug "Remove files"
    Get-ChildItem -Exclude ".git" |Remove-Item -Force -Recurse | Out-Null
    Write-Verbose "Removed files"
    #endregion

    #region copy files from _site
    Write-Debug "Copy files from _site"
    $publichPath=Resolve-Path "$PSScriptRoot\..\public"
    Write-Debug "publichPath=$publichPath"
    Copy-Item "$publichPath\*" -Recurse -Force
    #endregion

    #region add files to branch
    $arguments=@(
        "add"
        "-A"
    )
    Invoke-Git -Reason "Add files to gh-pages" -ArgumentsList $arguments
    #endregion

    #region Commit files
    $msg="Update on $stamp"
    $arguments=@(
        "commit"
        "-m"
        '"'+$msg+'"'
    )
    Invoke-Git -Reason "Commit files to gh-pages" -ArgumentsList $arguments
    #endregion

    #region push the gh-pages
    if($GitHubToken -and $Push)
    {
        if($remoteBranchExits)
        {
            $arguments=@(
                "push"
                $githubRemoteName 
            )
        }
        else
        {
            $arguments=@(
                "push"
                "--set-upstream"
                $githubRemoteName 
                "gh-pages"

            )
        }
        Invoke-Git -Reason "Push to remote $githubRemoteName with branch gh-pages" -ArgumentsList $arguments
    }
    else
    {
        Write-Warning "Skipped pushing to the gh-pages"
    }
}
catch
{
    Write-Error $_
    exit -1
}
finally
{
    Pop-Location
    Write-Verbose "Pop-Location $(Get-Location |Select-Object -ExpandProperty Path)"
}