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
        $markdown=""
        $markdown+=New-MDParagraph
    }

    Process {
        $markdown+=New-MDHeader -Text $Title
        $markdown+=New-MDParagraph
        $markdown+=New-MDParagraph  -Lines $Description
        $markdown+=New-MDParagraph
    }

    End {
        $markdown
    }
}