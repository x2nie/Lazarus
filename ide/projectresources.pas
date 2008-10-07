unit projectresources;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, FileUtil,
  projectresourcesintf,
  W32VersionInfo, W32Manifest, ProjectIcon,
  CodeToolManager, CodeCache, CodeAtom;

type

  { TProjectResources }

  TProjectResources = class(TAbstractProjectResources)
  private
    FModified: Boolean;
    FOnModified: TNotifyEvent;
    FInModified: Boolean;

    FSystemResources: TStringList;
    FLazarusResources: TStringList;

    rcFileName: String;
    lrsFileName: String;

    FVersionInfo: TProjectVersionInfo;
    FXPManifest: TProjectXPManifest;
    FProjectIcon: TProjectIcon;

    procedure SetFileNames(const AWorkingDir, MainFileName: String);
    procedure SetModified(const AValue: Boolean);
    function Update(TargetOS: String): Boolean;
    procedure EmbeddedObjectModified(Sender: TObject);
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddSystemResource(const AResource: String); override;
    procedure AddLazarusResource(AResource: TStream; const ResourceName, ResourceType: String); override;

    procedure Clear;
    function Regenerate(const AWorkingDir, MainFileName, TargetOS: String): Boolean;
    function UpdateMainSourceFile(const AFilename: string): Boolean;

    function HasSystemResources: Boolean;
    function HasLazarusResource: Boolean;

    property VersionInfo: TProjectVersionInfo read FVersionInfo;
    property XPManifest: TProjectXPManifest read FXPManifest;
    property ProjectIcon: TProjectIcon read FProjectIcon;

    property Modified: Boolean read FModified write SetModified;
    property OnModified: TNotifyEvent read FOnModified write FOnModified;
  end;

implementation

{ TProjectResources }

procedure TProjectResources.SetFileNames(const AWorkingDir, MainFileName: String);
var
  BasePart: String;
begin
  BasePart := AWorkingDir + ExtractFileNameWithoutExt(MainFileName);

  rcFileName :=  BasePart + '.rc';
  lrsFileName := BasePart + '.lrs';
end;

procedure TProjectResources.SetModified(const AValue: Boolean);
begin
  if FInModified then
    Exit;
  FInModified := True;
  if FModified = AValue then exit;
  FModified := AValue;
  if not FModified then
  begin
    VersionInfo.Modified := False;
    XPManifest.Modified := False;
    ProjectIcon.Modified := False;
  end;
  FInModified := False;
  if Assigned(FOnModified) then
    OnModified(Self);
end;

function TProjectResources.Update(TargetOS: String): Boolean;
begin
  Clear;
  // handle versioninfo
  Result := VersionInfo.UpdateResources(Self, rcFileName, TargetOS);
  if not Result then
    Exit;

  // handle manifest
  Result := XPManifest.UpdateResources(Self, rcFileName, TargetOS);
  if not Result then
    Exit;

  // handle project icon
  Result := ProjectIcon.UpdateResources(Self, rcFileName, TargetOS);
end;

procedure TProjectResources.EmbeddedObjectModified(Sender: TObject);
begin
  Modified :=
    VersionInfo.Modified or
    XPManifest.Modified or
    ProjectIcon.Modified;
end;

constructor TProjectResources.Create;
begin
  FInModified := False;

  FSystemResources := TStringList.Create;
  FLazarusResources := TStringList.Create;

  FVersionInfo := TProjectVersionInfo.Create;
  FVersionInfo.OnModified := @EmbeddedObjectModified;

  FXPManifest := TProjectXPManifest.Create;
  FXPManifest.UseManifest := False;
  FXPManifest.OnModified := @EmbeddedObjectModified;

  FProjectIcon := TProjectIcon.Create;
  FProjectIcon.OnModified := @EmbeddedObjectModified;
end;

destructor TProjectResources.Destroy;
begin
  FVersionInfo.Free;
  FXPManifest.Free;
  FProjectIcon.Free;

  FSystemResources.Free;
  FLazarusResources.Free;
end;

procedure TProjectResources.AddSystemResource(const AResource: String);
begin
  FSystemResources.Add(AResource);
end;

procedure TProjectResources.AddLazarusResource(AResource: TStream;
  const ResourceName, ResourceType: String);
var
  OutStream: TStringStream;
begin
  OutStream := TStringStream.Create('');
  BinaryToLazarusResourceCode(AResource, OutStream, ResourceName, ResourceType);
  FLazarusResources.Add(OutStream.DataString);
  OutStream.Free;
end;

procedure TProjectResources.Clear;
begin
  FSystemResources.Clear;
  FLazarusResources.Clear;
end;

function TProjectResources.Regenerate(const AWorkingDir, MainFileName, TargetOS: String): Boolean;
var
  AStream: TStream;
begin
  Result := False;
  SetFileNames(AWorkingDir, MainFileName);

  if not Update(TargetOS) then
    Exit;

  AStream := nil;
  if HasSystemResources then
  begin
    try
      AStream := TFileStream.Create(UTF8ToSys(rcFileName), fmCreate);
      FSystemResources.SaveToStream(AStream);
    finally
      AStream.Free;
    end;
  end;
  if HasLazarusResource then
  begin
    try
      AStream := TFileStream.Create(UTF8ToSys(lrsFileName), fmCreate);
      FLazarusResources.SaveToStream(AStream);
    finally
      AStream.Free;
    end;
  end;
  Result := True;
end;

function TProjectResources.HasSystemResources: Boolean;
begin
  Result := FSystemResources.Count > 0;
end;

function TProjectResources.HasLazarusResource: Boolean;
begin
  Result := FLazarusResources.Count > 0;
end;

function TProjectResources.UpdateMainSourceFile(const AFilename: string): Boolean;
var
  NewX, NewY, NewTopLine: integer;
  CodeBuf, NewCode: TCodeBuffer;
  Filename: String;
begin
  Result := False;
  CodeBuf := CodeToolBoss.LoadFile(AFilename, False, False);
  if CodeBuf <> nil then
  begin
    SetFileNames('', AFileName);
    Filename := ExtractFileName(rcFileName);
    if CodeToolBoss.FindResourceDirective(CodeBuf, 1, 1,
                               NewCode, NewX, NewY,
                               NewTopLine, Filename, false) then
    begin
      // there is a resource directive in the source
      if not HasSystemResources then
      begin
        if not CodeToolBoss.RemoveDirective(NewCode, NewX,NewY,true) then
        begin
          // Messages.Add('Could not remove "{$R'+ Filename +'"} from main source!');
          Exit;
        end;
      end;
    end
    else
    if HasSystemResources then
    begin
      if not CodeToolBoss.AddResourceDirective(CodeBuf,
        Filename,false,'{$IFDEF WINDOWS}{$R '+Filename+'}{$ENDIF}') then
      begin
        // Messages.Add('Could not add "{$R'+ Filename +'"} to main source!');
        Exit;
      end;
    end;
  end;
  Result := True;
end;

end.

