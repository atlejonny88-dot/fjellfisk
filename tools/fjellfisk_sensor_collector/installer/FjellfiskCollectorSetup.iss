; Fjellfisk Production Collector installer. This package contains only the
; self-contained Production publish output. It does not configure runtime behavior.

#ifndef CollectorPublish
  #define CollectorPublish "..\src\Fjellfisk.SensorCollector.Production\bin\Release\net6.0-windows\win-x86\publish"
#endif

#ifndef CollectorVersion
  #define CollectorVersion "1.0.1"
#endif

#ifndef CollectorVersionInfo
  #define CollectorVersionInfo "1.0.1.0"
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
var
  DeleteCollectorData: Boolean;

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
  if (CurUninstallStep = usUninstall) and DeleteCollectorData then
  begin
    DelTree(ExpandConstant('{commonappdata}\Fjellfisk\SensorCollector'), True, True, True);
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if (CurStep = ssPostInstall) and not WizardSilent then
  begin
    MsgBox('Fjellfisk Collector er installert.', mbInformation, MB_OK);
  end;
end;
