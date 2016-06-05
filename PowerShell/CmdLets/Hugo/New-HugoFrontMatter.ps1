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
        [boolean]$IsRoot
    )
    Begin {
        $markdown=New-MDParagraph "+++"
    }

    Process {
        $markdown+=New-MDParagraph ("title = ""$Title""")
        $markdown+=New-MDParagraph ("description = ""$Description""")
        $markdown+=New-MDParagraph ("root = $($IsRoot.ToString().ToLowerInvariant())")
    }

    End {
        $markdown+=New-MDParagraph "+++"
        $markdown
    }
}