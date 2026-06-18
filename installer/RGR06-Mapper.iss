#define MyAppName "RGR06 Mapper"
#define MyAppVersion "0.19"
#define MyAppPublisher "RGR06 Mapper"
#define MyAppExeName "RGR06-Mapper.exe"

[Setup]
AppId={{B96A8A48-1DBA-47B0-A73E-7EE77E430A3F}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\RGR06 Mapper
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\dist\installer
OutputBaseFilename=RGR06-Mapper-Setup-v0.19
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
AlwaysRestart=yes
SetupLogging=yes
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "chinesesimp"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "快捷方式："; Flags: checkedonce
Name: "startup"; Description: "随 Windows 启动 RGR06 Mapper"; GroupDescription: "启动选项："; Flags: checkedonce
Name: "launch"; Description: "安装后立即启动 RGR06 Mapper"; GroupDescription: "完成后："; Flags: unchecked

[Files]
Source: "..\dist\RGR06-Mapper-v0.19.exe"; DestDir: "{app}"; DestName: "{#MyAppExeName}"; Flags: ignoreversion
Source: "..\Lib\*"; DestDir: "{app}\Lib"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\tools\interception-test\Interception\Interception\command line installer\install-interception.exe"; DestDir: "{app}\drivers\Interception\command line installer"; Flags: ignoreversion
Source: "install-driver.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "uninstall-driver.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "INSTALL-README.md"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\RGR06 Mapper"; Filename: "{app}\{#MyAppExeName}"
Name: "{commondesktop}\RGR06 Mapper"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{group}\安装 Interception 驱动"; Filename: "{app}\install-driver.cmd"; WorkingDir: "{app}"
Name: "{group}\卸载 Interception 驱动"; Filename: "{app}\uninstall-driver.cmd"; WorkingDir: "{app}"
Name: "{group}\安装说明"; Filename: "{app}\INSTALL-README.md"
Name: "{commonstartup}\RGR06 Mapper"; Filename: "{app}\{#MyAppExeName}"; Parameters: "--startup"; Tasks: startup

[Run]
Filename: "{app}\drivers\Interception\command line installer\install-interception.exe"; Parameters: "/install"; WorkingDir: "{app}\drivers\Interception\command line installer"; StatusMsg: "正在安装 Interception 驱动..."; Flags: runhidden waituntilterminated
Filename: "{app}\{#MyAppExeName}"; Parameters: "--startup"; Description: "启动 RGR06 Mapper"; Flags: nowait postinstall skipifsilent; Tasks: launch

[UninstallRun]
Filename: "{app}\drivers\Interception\command line installer\install-interception.exe"; Parameters: "/uninstall"; WorkingDir: "{app}\drivers\Interception\command line installer"; Flags: runhidden waituntilterminated; RunOnceId: "UninstallInterceptionDriver"
