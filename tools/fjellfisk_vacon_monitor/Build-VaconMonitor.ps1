[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$dotnetCandidates = @(
    (Join-Path ${env:ProgramFiles(x86)} 'dotnet\dotnet.exe'),
    (Join-Path $env:ProgramFiles 'dotnet\dotnet.exe')
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

if ($dotnetCandidates.Count -eq 0) {
    throw 'Fant ikke .NET SDK. Installer .NET 6 SDK for Windows før VACON Monitor bygges.'
}

$dotnet = $dotnetCandidates[0]
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$monitorProject = Join-Path $root 'src\Fjellfisk.VaconMonitor\Fjellfisk.VaconMonitor.csproj'
$testProject = Join-Path $root 'tests\Fjellfisk.VaconMonitor.Tests\Fjellfisk.VaconMonitor.Tests.csproj'
$publishDirectory = Join-Path $root 'publish'

& $dotnet run --project $testProject --configuration Release
if ($LASTEXITCODE -ne 0) {
    throw "VACON Monitor-testene feilet med kode $LASTEXITCODE."
}

& $dotnet publish $monitorProject --configuration Release --runtime win-x86 --self-contained true `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    --output $publishDirectory
if ($LASTEXITCODE -ne 0) {
    throw "VACON Monitor publish feilet med kode $LASTEXITCODE."
}

Write-Host "Ferdig: $(Join-Path $publishDirectory 'Fjellfisk.VaconMonitor.exe')"

