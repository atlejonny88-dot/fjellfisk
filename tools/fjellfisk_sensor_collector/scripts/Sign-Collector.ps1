param(
    [Parameter(Mandatory = $true)]
    [string]$CertificateThumbprint,
    [Parameter(Mandatory = $true)]
    [string]$TimestampUrl,
    [Parameter(Mandatory = $true)]
    [string[]]$Path
)

$signTool = Get-Command signtool.exe -ErrorAction Stop

foreach ($file in $Path) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        throw "Signing target was not found: $file"
    }

    & $signTool.Source sign /sha1 $CertificateThumbprint /fd SHA256 /tr $TimestampUrl /td SHA256 $file
    if ($LASTEXITCODE -ne 0) {
        throw "Authenticode signing failed for $file"
    }
}
