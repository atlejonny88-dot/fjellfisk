[CmdletBinding()]
param(
    [string]$InstallerScript = (Join-Path $PSScriptRoot 'FjellfiskCollectorSetup.iss'),
    [string]$PublishDirectory = (Join-Path $PSScriptRoot '..\src\Fjellfisk.SensorCollector.Production\bin\Release\net6.0-windows\win-x86\publish')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $InstallerScript -PathType Leaf)) {
    throw "Installer script was not found: $InstallerScript"
}

if (-not (Test-Path -LiteralPath $PublishDirectory -PathType Container)) {
    throw "Production publish directory was not found: $PublishDirectory"
}

$scriptContent = Get-Content -LiteralPath $InstallerScript -Raw
$requiredFragments = @(
    'AppName=Fjellfisk Collector',
    'AppPublisher=Fjellfisk',
    'DefaultDirName={commonpf32}\Fjellfisk\Collector',
    'CreateUninstallRegKey=yes',
    'UsePreviousAppDir=yes',
    'CloseApplications=no',
    'AlwaysRestart=no',
    'RestartIfNeededByRun=no',
    'Source: "{#CollectorPublish}\*"',
    'Fjellfisk.Collector.ServiceTool*',
    'Name: "{commonappdata}\Fjellfisk\SensorCollector"; Permissions: users-modify; Flags: uninsneveruninstall',
    'Name: "{commonappdata}\Fjellfisk\SensorCollector\config"; Permissions: users-modify; Flags: uninsneveruninstall',
    'Name: "{commonappdata}\Fjellfisk\SensorCollector\identity"; Permissions: users-modify; Flags: uninsneveruninstall',
    'Name: "{commonappdata}\Fjellfisk\SensorCollector\logs"; Permissions: users-modify; Flags: uninsneveruninstall',
    'Name: "{commonappdata}\Fjellfisk\SensorCollector\buffer"; Permissions: users-modify; Flags: uninsneveruninstall',
    'DeleteCollectorData := False;',
    'MB_YESNO or MB_DEFBUTTON2',
    "DelTree(ExpandConstant('{commonappdata}\Fjellfisk\SensorCollector'), True, True, True);",
    'if (CurUninstallStep = usUninstall) and DeleteCollectorData then'
)

foreach ($fragment in $requiredFragments) {
    if (-not $scriptContent.Contains($fragment, [StringComparison]::Ordinal)) {
        throw "Installer script is missing required configuration: $fragment"
    }
}

$persistentRoot = '{commonappdata}\Fjellfisk\SensorCollector'
$uninstallDeletePattern = '(?is)\[UninstallDelete\][^\[]*\{commonappdata\}\\Fjellfisk\\SensorCollector'
if ($scriptContent -match $uninstallDeletePattern) {
    throw 'Installer script contains an automatic [UninstallDelete] rule for persistent Collector data.'
}

$promptResultPattern = '(?s)DeleteCollectorData\s*:=\s*MsgBox\(.*?MB_YESNO\s+or\s+MB_DEFBUTTON2\)\s*=\s*IDYES;'
if ($scriptContent -notmatch $promptResultPattern) {
    throw 'Persistent Collector data must only be selected for deletion when the interactive prompt returns IDYES.'
}

$deleteCall = "DelTree(ExpandConstant('$persistentRoot'), True, True, True);"
$deleteCallIndex = $scriptContent.IndexOf($deleteCall, [StringComparison]::Ordinal)
$deleteGateIndex = $scriptContent.IndexOf(
    'if (CurUninstallStep = usUninstall) and DeleteCollectorData then',
    [StringComparison]::Ordinal
)

if ($deleteCallIndex -lt 0 -or $deleteGateIndex -lt 0 -or $deleteGateIndex -gt $deleteCallIndex) {
    throw 'Persistent Collector data deletion must be guarded by the explicit uninstall confirmation.'
}

if (($scriptContent.Split($deleteCall).Count - 1) -ne 1) {
    throw 'Persistent Collector data may only have one explicit deletion call.'
}

$forbiddenFragments = @(
    '[Run]',
    '[UninstallRun]',
    '[Registry]',
    '[UninstallDelete]',
    'uninsalwaysuninstall',
    'uninsdeletevalue',
    'uninsdeletekey',
    'schtasks',
    'New-Service',
    'sc.exe',
    'netsh',
    'RunOnce',
    '{userstartup}',
    '{commonstartup}'
)

foreach ($fragment in $forbiddenFragments) {
    if ($scriptContent.Contains($fragment, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Installer script contains forbidden runtime configuration: $fragment"
    }
}

$requiredProductionFiles = @(
    'Fjellfisk.SensorCollector.exe',
    'Fjellfisk.SensorCollector.dll',
    'Fjellfisk.SensorCollector.deps.json',
    'Fjellfisk.SensorCollector.runtimeconfig.json',
    'pairing-ui\Fjellfisk.Collector.PairingUi.exe'
)

foreach ($file in $requiredProductionFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $PublishDirectory $file) -PathType Leaf)) {
        throw "Production publish is missing required file: $file"
    }
}

$forbiddenFiles = Get-ChildItem -LiteralPath $PublishDirectory -File -Recurse |
    Where-Object {
        $_.Name -like 'Fjellfisk.Collector.ServiceTool*' -or
        $_.Extension -in '.pdb', '.pfx', '.p12', '.key', '.pem', '.snk' -or
        $_.Name -eq 'serviceAccountKey.json' -or
        $_.Name -like 'firebase-adminsdk*.json' -or
        $_.Name -eq '.env' -or
        $_.Name -like '*.env'
    }

if ($forbiddenFiles) {
    throw "Production publish contains forbidden installer input: $($forbiddenFiles.FullName -join ', ')"
}

Write-Host 'Installer layout validation passed.'
