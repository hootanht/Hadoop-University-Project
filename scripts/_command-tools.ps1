function Write-CommandLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandText
    )

    Write-Host (">>> {0}" -f $CommandText) -ForegroundColor Magenta
}

function Invoke-LoggedCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandText,

        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock
    )

    Write-CommandLine $CommandText
    & $ScriptBlock
}