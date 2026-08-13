#ifndef MyAppVersion
  #define MyAppVersion "0.2.0"
#endif

#define MyAppName "AI Limit Status"
#define MyAppPublisher "AI Limit Status"
#define MyAppExeName "ai_limit_status.exe"

[Setup]
AppId=com.ailimitstatus.aiLimitStatus
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\Programs\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\..\dist
OutputBaseFilename=AI-Limit-Status-{#MyAppVersion}-Windows-x64-Setup
SetupIconFile=..\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; AppUserModelID: "com.ailimitstatus.AILimitStatus"; AppUserModelToastActivatorCLSID: "6F4E47C9-7E92-47E4-A8A2-81C21E74B7AC"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; AppUserModelID: "com.ailimitstatus.AILimitStatus"; AppUserModelToastActivatorCLSID: "6F4E47C9-7E92-47E4-A8A2-81C21E74B7AC"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
