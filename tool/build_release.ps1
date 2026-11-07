[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('web', 'apk', 'appbundle')]
    [string]$Target,
    [string]$CollectorBackendUrl = 'https://api.tosprotein.com'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

Push-Location $projectRoot
try {
    & node tool/release_config.cjs $CollectorBackendUrl
    if ($LASTEXITCODE -ne 0) { throw 'Release configuration validation failed.' }

    $dartDefine = "--dart-define=FJELLFISK_COLLECTOR_BACKEND_URL=$CollectorBackendUrl"
    & flutter build $Target --release $dartDefine
    if ($LASTEXITCODE -ne 0) { throw "Flutter $Target release build failed." }

    if ($Target -eq 'web') {
        & node -e "const c=require('./tool/release_config.cjs'); c.writeWebBuildConfig('build/web', process.argv[1]);" $CollectorBackendUrl
        if ($LASTEXITCODE -ne 0) { throw 'Unable to stamp web release configuration.' }
    }
} finally {
    Pop-Location
}
