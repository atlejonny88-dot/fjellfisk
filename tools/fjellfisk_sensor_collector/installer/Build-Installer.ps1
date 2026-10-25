[CmdletBinding()]
param(
    [string]$Version,
    [string]$BuildId = 'local',
    [string]$CertificateThumbprint,
    [string]$TimestampUrl
)

$ErrorActionPreference = 'Stop'

function Get-DotNetExecutable {
    $candidates = @(@(
        (Get-Command dotnet.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1),
        (Join-Path ${env:ProgramFiles(x86)} 'dotnet\dotnet.exe'),
        (Join-Path $env:ProgramFiles 'dotnet\dotnet.exe')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) })

    if (-not $candidates) {
        throw 'The .NET SDK was not found. Install a supported .NET SDK before building the installer.'
    }

    return $candidates[0]
}

function Get-InnoCompiler {
    $candidates = @(@(
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
        (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) })

    if (-not $candidates) {
        throw 'Inno Setup 6 compiler was not found. Expected ISCC.exe under Program Files (x86), Program Files, or LOCALAPPDATA\Programs. It was not installed automatically.'
    }

    return $candidates[0]
}

function Get-WindowsVersion([string]$ProductVersion) {
    if ($ProductVersion -notmatch '^\d+(\.\d+){1,3}$') {
        throw "Product version must be numeric, for example 1.0.0. Received: $ProductVersion"
    }

    $parts = [System.Collections.Generic.List[string]]($ProductVersion.Split('.'))
    while ($parts.Count -lt 4) {
        $parts.Add('0')
    }

    return $parts -join '.'
}

if ([string]::IsNullOrWhiteSpace($CertificateThumbprint) -xor [string]::IsNullOrWhiteSpace($TimestampUrl)) {
    throw 'Provide both CertificateThumbprint and TimestampUrl when signing, or neither for an unsigned build.'
}

$collectorRoot = Split-Path $PSScriptRoot -Parent
$productionProject = Join-Path $collectorRoot 'src\Fjellfisk.SensorCollector.Production\Fjellfisk.SensorCollector.Production.csproj'
$installerScript = Join-Path $PSScriptRoot 'FjellfiskCollectorSetup.iss'
$publishDirectory = Join-Path $collectorRoot 'src\Fjellfisk.SensorCollector.Production\bin\Release\net6.0-windows\win-x86\publish'
$setupPath = Join-Path $PSScriptRoot 'output\FjellfiskCollectorSetup.exe'

if ([string]::IsNullOrWhiteSpace($Version)) {
    [xml]$project = Get-Content -LiteralPath $productionProject -Raw
    $Version = ($project.Project.PropertyGroup | Where-Object { $_.Version } | Select-Object -First 1).Version
}

if ([string]::IsNullOrWhiteSpace($Version)) {
    throw 'No Product Version was provided and the Production project does not define one.'
}

$dotnet = Get-DotNetExecutable
& $dotnet publish $productionProject --configuration Release --runtime win-x86 --self-contained true "-p:Version=$Version" "-p:FjellfiskBuildId=$BuildId"
if ($LASTEXITCODE -ne 0) {
    throw 'Production publish failed.'
}

& (Join-Path $PSScriptRoot 'Test-InstallerLayout.ps1') -InstallerScript $installerScript -PublishDirectory $publishDirectory

if ($CertificateThumbprint) {
    & (Join-Path $collectorRoot 'scripts\Sign-Collector.ps1') `
        -CertificateThumbprint $CertificateThumbprint `
        -TimestampUrl $TimestampUrl `
        -Path (Join-Path $publishDirectory 'Fjellfisk.SensorCollector.exe')
}

$iscc = Get-InnoCompiler
$versionInfo = Get-WindowsVersion $Version
& $iscc "/DCollectorPublish=$publishDirectory" "/DCollectorVersion=$Version" "/DCollectorVersionInfo=$versionInfo" $installerScript
if ($LASTEXITCODE -ne 0) {
    throw 'Inno Setup compilation failed.'
}

if (-not (Test-Path -LiteralPath $setupPath -PathType Leaf)) {
    throw "Inno Setup completed without producing the expected artifact: $setupPath"
}

if ($CertificateThumbprint) {
    & (Join-Path $collectorRoot 'scripts\Sign-Collector.ps1') `
        -CertificateThumbprint $CertificateThumbprint `
        -TimestampUrl $TimestampUrl `
        -Path $setupPath
}

Write-Host "Installer build completed: $setupPath"
