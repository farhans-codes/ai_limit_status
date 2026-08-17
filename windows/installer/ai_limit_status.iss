#ifndef MyAppVersion
  #define MyAppVersion "0.3.0"
#endif

#define MyAppName "AI Limit Status"
#define MyAppPublisher "farhans-codes"
#define MyAppExeName "ai_limit_status.exe"

[Setup]
AppId=com.ailimitstatus.aiLimitStatus
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL=https://github.com/farhans-codes/ai_limit_status
AppSupportURL=https://github.com/farhans-codes/ai_limit_status/issues
AppUpdatesURL=https://github.com/farhans-codes/ai_limit_status/releases/latest
DefaultDirName={localappdata}\Programs\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\..\dist
OutputBaseFilename=AI-Limit-Status-Windows-x64-Setup
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
