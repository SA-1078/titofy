; Script de Inno Setup para Titofy en Windows
; Genera: Titofy-Setup-v1.0.0.exe

#define MyAppName "Titofy"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Titofy Team"
#define MyAppURL "https://github.com/tu-usuario/titofy"
#define MyAppExeName "titofy.exe"

[Setup]
AppId={{9F4A4E5C-3C73-4BD9-9A61-2A1B1C8E9D01}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
DisableProgramGroupPage=yes
DisableWelcomePage=no
LicenseFile=..\..\LICENSE
InfoBeforeFile=info_instalacion.txt
InfoAfterFile=info_final.txt
OutputDir=.
OutputBaseFilename=Titofy-Setup-v1.0.0
SetupIconFile=..\..\desktop\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64

CloseApplications=yes
CloseApplicationsFilter=*.exe,titofy.exe,api_server.exe
RestartApplications=no

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Binario principal de Flutter renombrado a titofy.exe
Source: "..\..\desktop\build\windows\x64\runner\Release\desktop.exe"; DestDir: "{app}"; DestName: "titofy.exe"; Flags: ignoreversion
; Resto de archivos del bundle de Flutter (DLLs, data, plugins)
Source: "..\..\desktop\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "desktop.exe,backend\*"
; Ejecutable del backend FastAPI compilado
Source: "..\..\desktop\build\windows\x64\runner\Release\backend\api_server.exe"; DestDir: "{app}\backend"; Flags: ignoreversion
; Backend de IA Python y scripts (excluye ejecutables duplicados, entornos virtuales o caches)
Source: "..\..\backend\*"; DestDir: "{app}\backend"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: ".venv,venv,__pycache__,*.pyc,logs\*,data\*,dist,build,*.spec,*.exe"

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "taskkill.exe"; Parameters: "/F /IM api_server.exe /IM titofy.exe /T"; Flags: runhidden

[Code]
procedure KillProcesses();
var
  ResultCode: Integer;
begin
  Exec('taskkill.exe', '/F /IM api_server.exe /IM titofy.exe /T', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
end;

function InitializeSetup(): Boolean;
begin
  KillProcesses();
  Result := True;
end;

function InitializeUninstall(): Boolean;
begin
  KillProcesses();
  Result := True;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
  begin
    KillProcesses();
  end;
end;
