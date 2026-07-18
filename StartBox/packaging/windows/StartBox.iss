; -----------------------------------------------------------------------------
; StartBox Windows 安装程序 (Inno Setup 6.x)
; https://jrsoftware.org/isinfo.php
;
; 用法(ISCC 命令行):
;   ISCC.exe /DMyAppVersion=1.2.3 packaging\windows\StartBox.iss
;
; 可选覆盖:
;   /DMyAppVersion=X.Y.Z     版本号(默认从 Directory.Build.props 同步)
;   /DPublishDir=<绝对路径>  dotnet publish 输出目录(默认自动计算)
;
; 前置条件:
;   1. dotnet publish StartBox\StartBox.csproj -c Release -r win-x64 --self-contained
;   2. ISCC.exe StartBox\packaging\windows\StartBox.iss
;
; 产物: StartBox\packaging\windows\dist\StartBox-Setup-<VERSION>-win-x64.exe
; -----------------------------------------------------------------------------

; ---- 版本号(默认 1.0.0,CI 通过 /DMyAppVersion= 覆盖) ----
#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif

; ---- publish 目录(默认从 .iss 位置往上两级算) ----
#ifndef PublishDir
  #define PublishDir SourcePath + "\\..\\..\\bin\\Release\\net9.0\\win-x64\\publish"
#endif

; ---- 应用元数据 ----
#ifndef MyAppName
  #define MyAppName "StartBox"
#endif
#ifndef MyAppPublisher
  #define MyAppPublisher "wwnnl"
#endif
#ifndef MyAppURL
  #define MyAppURL "https://github.com/yourname/StartBox"
#endif
#define MyAppExeName MyAppName + ".exe"

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
; 把整个 publish 输出拷过去。
; PublishDir 默认 = SourcePath + "..\..\bin\Release\net9.0\win-x64\publish",
; 即 .iss 位置往上两级;通过 /DPublishDir=<绝对路径> 可覆盖。
Source: "{#PublishDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

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