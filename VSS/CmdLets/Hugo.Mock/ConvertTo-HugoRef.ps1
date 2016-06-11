function ConvertTo-HugoRef {
    [CmdletBinding()]
    [OutputType([string])]
    Param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
            
        )]
        [ValidateNotNullOrEmpty()]
        [string]$RelLink
    )
    Begin {
    }

    Process {
        $RelLink
    }

    End {
    }
}