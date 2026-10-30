; Instalador de Pokelocke (Inno Setup 6). Lo compila app\empaquetar.py, que pasa Version, Origen, Salida e Icono.
; Instala en %LOCALAPPDATA%\Pokelocke, la misma carpeta que usaba el .exe de un solo archivo: las partidas
; (datos\ y tools\azahar\citra-1920\user\) no van en el instalador, así que actualizar o desinstalar no las borra.

[Setup]
AppId={{6F1C2B8E-4D7A-4E25-9C3B-8A5D2E7F1043}
AppName=Pokelocke
AppVersion={#Version}
AppVerName=Pokelocke {#Version}
AppPublisher=David Martínez Palacios
AppCopyright=David Martínez Palacios
VersionInfoVersion={#Version}
VersionInfoCompany=David Martínez Palacios
VersionInfoDescription=Instalador de Pokelocke
VersionInfoProductName=Pokelocke
DefaultDirName={localappdata}\Pokelocke
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir={#Salida}
OutputBaseFilename=PokelockeSetup
SetupIconFile={#Icono}
UninstallDisplayIcon={app}\Pokelocke.exe
UninstallDisplayName=Pokelocke
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; cierra Pokelocke y Citra si están abiertos, para poder actualizar sus archivos
CloseApplications=force
RestartApplications=no

[Languages]
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "escritorio"; Description: "Crear un acceso directo en el escritorio"

[InstallDelete]
; lo que dejaba el .exe de un solo archivo al descomprimirse
Type: files; Name: "{app}\version.txt"

[Files]
Source: "{#Origen}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Pokelocke"; Filename: "{app}\Pokelocke.exe"
Name: "{autodesktop}\Pokelocke"; Filename: "{app}\Pokelocke.exe"; Tasks: escritorio

[Run]
Filename: "{app}\Pokelocke.exe"; Description: "Abrir Pokelocke"; Flags: nowait postinstall skipifsilent
; la actualización desde la app es silenciosa: al acabar, Pokelocke se vuelve a abrir solo
Filename: "{app}\Pokelocke.exe"; Flags: nowait; Check: WizardSilent

[Code]
// la sala no tiene ventana y puede seguir abierta sin Pokelocke: hay que cerrarla para poder cambiar sus archivos
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  Codigo: Integer;
begin
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM citra-room.exe', '', SW_HIDE, ewWaitUntilTerminated, Codigo);
  Result := '';
end;
