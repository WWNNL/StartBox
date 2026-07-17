; -----------------------------------------------------------------------------
; StartBox Windows 安装程序 (Inno Setup 6.x)
; https://jrsoftware.org/isinfo.php
;
; 用法:
;   1. 安装 Inno Setup 6 (Windows) 或 Inno Setup Command Line Compiler
;   2. 在 Windows 上先跑 dotnet publish:
;        dotnet publish StartBox\StartBox.csproj -c Release -r win-x64 --self-contained
;      (加 --self-contained 是为了让用户机器不需要预装 .NET)
;   3. 跑 ISCC 编译:
;        ISCC.exe StartBox\packaging\windows\StartBox.iss
;   4. 产物: StartBox\packaging\windows\dist\StartBox-Setup-1.0.0-win-x64.exe
; -----------------------------------------------------------------------------

#define MyAppName "StartBox"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "wwnnl"
#define MyAppURL "https://github.com/yourname/StartBox"
#define MyAppExeName "StartBox.exe"

[Setup]
; 注意: AppId 必须唯一,改版本时不要改 AppId,否则升级逻辑会乱
AppId={{8E2C9B5F-7A4D-4F0A-9C3B-1D5E6F8A2B4C}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

; 输出文件
OutputBaseFilename=StartBox-Setup-{#MyAppVersion}-win-x64
OutputDir=dist

; 压缩
Compression=lzma2/ultra64
SolidCompression=yes
LZMAUseSeparateProcess=yes

; 安装包图标(可选,需要 StartBox.ico 放在同目录)
; SetupIconFile=StartBox.ico

; 权限(允许非管理员安装到用户目录)
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

; 64-bit
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

Uninstallable=yes
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}

; 漂亮的安装体验
WizardStyle=modern
WizardSizePercent=120

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; 把整个 publish 输出拷过去
; 注意: 需要在 Windows 上先跑 dotnet publish -c Release -r win-x64 --self-contained
Source: "..\..\bin\Release\net9.0\win-x64\publish\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

; 注意: 上面 Source 路径假设你在 StartBox\packaging\windows\ 目录跑 ISCC
; 也可以改成绝对路径或自己调整

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; 卸载时清理用户配置目录(可选,如果你的应用写到这里)
; Type: filesandordirs; Name: "{userappdata}\{#MyAppName}"

[Code]
// 安装完成后给个友好提示
function InitializeSetup(): Boolean;
begin
  Result := True;
end;
