; Fjellfisk Production Collector installer. This package contains only the
; self-contained Production publish output and configures the local pairing
; startup task. It performs allowlisted read-only collection after pairing.
; It never configures VIGO or P-NET.

#ifndef CollectorPublish
  #define CollectorPublish "..\src\Fjellfisk.SensorCollector.Production\bin\Release\net6.0-windows\win-x86\publish"
#endif

#ifndef CollectorVersion
  #define CollectorVersion "1.0.6"
#endif

#ifndef CollectorVersionInfo
  #define CollectorVersionInfo "1.0.6.0"
#endif

#ifndef CollectorPairingBackendUrl
  #define CollectorPairingBackendUrl ""
#endif

[Setup]
AppId={{8DDA9AF0-E978-47DE-A98F-A3F16D8F3F68}
AppName=Fjellfisk Collector
AppVersion={#CollectorVersion}
AppPublisher=Fjellfisk
DefaultDirName={commonpf32}\Fjellfisk\Collector
DisableWelcomePage=no
DisableDirPage=no
DisableProgramGroupPage=yes
UsePreviousAppDir=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x86compatible
CloseApplications=no
AlwaysRestart=no
RestartIfNeededByRun=no
CreateUninstallRegKey=yes
Uninstallable=yes
UninstallDisplayName=Fjellfisk Collector
OutputBaseFilename=FjellfiskCollectorSetup
OutputDir=output
Compression=lzma2
SolidCompression=yes
VersionInfoVersion={#CollectorVersionInfo}
VersionInfoCompany=Fjellfisk
VersionInfoDescription=Fjellfisk Collector Installer
VersionInfoProductName=Fjellfisk Collector

[Languages]
Name: "norwegian"; MessagesFile: "compiler:Languages\Norwegian.isl"

[Files]
Source: "{#CollectorPublish}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "Fjellfisk.Collector.ServiceTool*;*.pdb;*.xml;*.cs;*.csproj;*.sln;*.md;*.ps1;*.iss;*.pfx;*.p12;*.key;*.pem;*.snk;serviceAccountKey.json;firebase-adminsdk*.json;.env;*.env;tests\*;docs\*;collector-state\*"

[Dirs]
; Collector state is persistent. Only the explicit, interactive Yes choice in
; CurUninstallStepChanged may remove this root and its contents.
Name: "{commonappdata}\Fjellfisk\SensorCollector"; Permissions: users-modify; Flags: uninsneveruninstall
Name: "{commonappdata}\Fjellfisk\SensorCollector\config"; Permissions: users-modify; Flags: uninsneveruninstall
Name: "{commonappdata}\Fjellfisk\SensorCollector\identity"; Permissions: users-modify; Flags: uninsneveruninstall
Name: "{commonappdata}\Fjellfisk\SensorCollector\logs"; Permissions: users-modify; Flags: uninsneveruninstall
Name: "{commonappdata}\Fjellfisk\SensorCollector\buffer"; Permissions: users-modify; Flags: uninsneveruninstall

[Code]
const
  CollectorTaskName = 'Fjellfisk Collector';
  CollectorExecutableName = 'Fjellfisk.SensorCollector.exe';

var
  DeleteCollectorData: Boolean;

function CollectorConfigPath(): String;
begin
  Result := ExpandConstant('{commonappdata}\Fjellfisk\SensorCollector\config\pairing-backend.json');
end;

procedure CreatePairingBackendConfiguration();
var
  ConfigPath: String;
  ConfigContents: String;
begin
  ConfigPath := CollectorConfigPath();
  if FileExists(ConfigPath) then
    Exit;

  if '{#CollectorPairingBackendUrl}' = '' then
    RaiseException('Collector-installasjonen mangler en konfigurert HTTPS-adresse for pairing-backend.');

  ConfigContents := '{"endpoint":"{#CollectorPairingBackendUrl}"}';
  if not SaveStringToFile(ConfigPath, ConfigContents, False) then
    RaiseException('Kunne ikke lagre Collector-konfigurasjonen.');
end;

procedure CreateOrUpdateCollectorAutostartTask();
var
  ResultCode: Integer;
  Parameters: String;
begin
  { Avoid storing a quoted executable as Command when the target path contains
    spaces. Task Scheduler expands this environment variable at launch. }
  Parameters := '/Create /TN "' + CollectorTaskName +
    '" /TR "%ProgramFiles(x86)%\Fjellfisk\Collector\' + CollectorExecutableName +
    ' --run" /SC ONLOGON /DELAY 0001:00 /IT /RL LIMITED /F';

  if (not Exec(ExpandConstant('{sys}\schtasks.exe'), Parameters, '', SW_HIDE,
      ewWaitUntilTerminated, ResultCode)) or (ResultCode <> 0) then
    RaiseException('Kunne ikke opprette autostart for Fjellfisk Collector.');
end;

procedure RemoveCollectorAutostartTask();
var
  ResultCode: Integer;
begin
  Exec(ExpandConstant('{sys}\schtasks.exe'), '/Delete /TN "' + CollectorTaskName +
    '" /F', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;

function InitializeUninstall(): Boolean;
begin
  DeleteCollectorData := False;

  if not UninstallSilent then
  begin
    DeleteCollectorData := MsgBox(
      'Slett ogsa lokale Fjellfisk Collector-data og identitet?' + #13#10 + #13#10 +
      'Dette fjerner bare C:\ProgramData\Fjellfisk\SensorCollector. Velg Nei for a beholde dataene.',
      mbConfirmation,
      MB_YESNO or MB_DEFBUTTON2) = IDYES;
  end;

  Result := True;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
    RemoveCollectorAutostartTask();

  if (CurUninstallStep = usUninstall) and DeleteCollectorData then
  begin
    DelTree(ExpandConstant('{commonappdata}\Fjellfisk\SensorCollector'), True, True, True);
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    CreatePairingBackendConfiguration();
    CreateOrUpdateCollectorAutostartTask();

    if not WizardSilent then
      MsgBox('Fjellfisk Collector er installert og starter 60 sekunder etter neste innlogging.', mbInformation, MB_OK);
  end;
end;
