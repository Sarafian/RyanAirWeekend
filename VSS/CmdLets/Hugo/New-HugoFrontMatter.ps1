function New-HugoFrontMatter {
    [OutputType([string])]
    Param (
        [Parameter(
            Mandatory = $true
        )]
        [ValidateNotNullOrEmpty()]
        [string]$Title,
        [Parameter(
            Mandatory = $true
        )]
        [ValidateNotNullOrEmpty()]
        [string]$Description,
        [Parameter(
            Mandatory = $true
        )]
        [ValidateNotNullOrEmpty()]
        [boolean]$IsRoot,
        [Parameter(
            Mandatory = $false
        )]
        $Metadata=$null
    )
    Begin {
        $markdown=New-MDParagraph "+++" -NoNewLine
    }

    Process {
        $markdown+=New-MDParagraph ("title = ""$Title""") -NoNewLine
        $markdown+=New-MDParagraph ("description = ""$Description""") -NoNewLine
        $markdown+=New-MDParagraph ("root = ""$($IsRoot.ToString().ToLowerInvariant())""") -NoNewLine
        if($Metadata)
        {
            foreach ($h in $Metadata.Keys) 
            {
                $markdown+=New-MDParagraph ("$h = ""$($Metadata.Item($h))""") -NoNewLine
            }
        }
    }

    End {
        $markdown+=New-MDParagraph "+++"
        $markdown
    }
}