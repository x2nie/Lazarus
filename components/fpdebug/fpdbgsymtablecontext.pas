unit fpDbgSymTableContext;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  FpDbgLoader,
  FpImgReaderBase,
  DbgIntfBaseTypes,
  fpDbgSymTable,
  FpdMemoryTools,
  FpDbgInfo,
  FpDbgCommon;

type

  { TFpSymbolTableProc }

  TFpSymbolTableProc = class(TFpSymbol)
  public
    constructor Create(const AName: String; AnAddr: TDbgPtr);
  end;

  TFpSymbolInfo = class;

  { TFpSymbolContext }

  TFpSymbolContext = class(TFpDbgSymbolScope)
  private
    FFpSymbolInfo: TFpSymbolInfo;
    FSizeOfAddress: integer;
  protected
    function GetAddress: TDbgPtr; override;
    function GetStackFrame: Integer; override;
    function GetThreadId: Integer; override;
    function GetSizeOfAddress: Integer; override;
  public
    constructor Create(AFpSymbolInfo: TFpSymbolInfo);
    function FindSymbol(const AName: String): TFpValue; override;
  end;

  { TFpSymbolInfo }

  TFpSymbolInfo = class(TDbgInfo)
  private
    FSymbolList: TfpSymbolList;
    FContext: TFpSymbolContext;
    FLibName: String;
  public
    constructor Create(ALoaderList: TDbgImageLoaderList; AMemManager: TFpDbgMemManager); override;
    constructor Create(ALoaderList: TDbgImageLoaderList; AMemManager: TFpDbgMemManager; ALibName: String);
    destructor Destroy; override;
    function FindSymbolScope(AThreadId, AStackFrame: Integer; AAddress: TDbgPtr = 0): TFpDbgSymbolScope; override;
    function FindProcSymbol(const AName: String): TFpSymbol; override; overload;
    function FindProcSymbol(AnAdress: TDbgPtr): TFpSymbol; overload;
  end;

implementation

{ TFpSymbolTableProc }

constructor TFpSymbolTableProc.Create(const AName: String; AnAddr: TDbgPtr);
begin
  inherited Create(AName);
  SetAddress(TargetLoc(AnAddr));
  SetKind(skProcedure);
  SetSymbolType(stType);
end;

{ TFpSymbolContext }

function TFpSymbolContext.GetAddress: TDbgPtr;
begin
  result := 0;
end;

function TFpSymbolContext.GetStackFrame: Integer;
begin
  result := 0;
end;

function TFpSymbolContext.GetThreadId: Integer;
begin
  result := 1;
end;

function TFpSymbolContext.GetSizeOfAddress: Integer;
begin
  result := FSizeOfAddress;
end;

constructor TFpSymbolContext.Create(AFpSymbolInfo: TFpSymbolInfo);
begin
  inherited create;
  FFpSymbolInfo:=AFpSymbolInfo;
  if AFpSymbolInfo.TargetInfo.bitness = b64 then
    FSizeOfAddress:=8
  else
    FSizeOfAddress:=4;
end;

function TFpSymbolContext.FindSymbol(const AName: String): TFpValue;
var
  i: integer;
  val: TFpDbgMemLocation;
begin
  i := FFpSymbolInfo.FSymbolList.IndexOf(AName);
  if i > -1 then
  begin
    val := Default(TFpDbgMemLocation);
    val.Address:=FFpSymbolInfo.FSymbolList.DataPtr[i]^.Addr;
    val.MType:=mlfTargetMem;
    result := TFpValueConstAddress.Create(val);
  end
  else
    result := nil;
end;

{ TFpSymbolInfo }

constructor TFpSymbolInfo.Create(ALoaderList: TDbgImageLoaderList;
  AMemManager: TFpDbgMemManager);

var
  i: Integer;
begin
  inherited Create(ALoaderList, AMemManager);
  FContext := TFpSymbolContext.Create(self);

  FSymbolList := TfpSymbolList.Create;
  for i := 0 to ALoaderList.Count-1 do
    ALoaderList[i].ParseSymbolTable(FSymbolList);
  FTargetInfo := ALoaderList.TargetInfo;
  if FSymbolList.Count > 0 then
    SetHasInfo;
end;

constructor TFpSymbolInfo.Create(ALoaderList: TDbgImageLoaderList;
  AMemManager: TFpDbgMemManager; ALibName: String);
begin
  FLibName := ALibName;
  Create(ALoaderList, AMemManager);
end;

destructor TFpSymbolInfo.Destroy;
begin
  FSymbolList.Free;
  FContext.Free;
  inherited Destroy;
end;

function TFpSymbolInfo.FindSymbolScope(AThreadId, AStackFrame: Integer;
  AAddress: TDbgPtr): TFpDbgSymbolScope;
begin
  assert(False, 'TFpSymbolInfo.FindSymbolScope: False');
  Result:=FContext; // TODO: nil
end;

function TFpSymbolInfo.FindProcSymbol(const AName: String): TFpSymbol;
var
  i: integer;
begin
  i := FSymbolList.IndexOf(AName);
  if i >= 0 then
    Result := TFpSymbolTableProc.Create(AName, FSymbolList.DataPtr[i]^.Addr)
  else
    result := nil;
end;

function TFpSymbolInfo.FindProcSymbol(AnAdress: TDbgPtr): TFpSymbol;
var
  CheckRange: Boolean;
  i, NearestIdx: integer;
  a, NearestAddr: TDBGPtr;
  NPreFix: String;
  d: PfpLinkerSymbol;
begin
  NPreFix := '';
  if FLibName <> '' then
    NPreFix := FLibName+':';
  CheckRange :=
    (FSymbolList.HighAddr > FSymbolList.LowAddr) and
    (AnAdress >= FSymbolList.LowAddr) and
    (AnAdress < FSymbolList.HighAddr);
  NearestIdx := -1;
  NearestAddr := 0;

  Result := nil;
  i := FSymbolList.Count - 1;
  while i >= 0 do begin
    d := FSymbolList.DataPtr[i];
    a := d^.Addr;
    if (a = AnAdress) then begin
      Result := TFpSymbolTableProc.Create(NPreFix + FSymbolList.Keys[i], a);
      exit;
    end;
    if CheckRange and (a <= AnAdress) and (a > NearestAddr) and
       ( (d^.SectionEnd = 0) or (AnAdress <= d^.SectionEnd) )
    then begin
      NearestIdx := i;
      NearestAddr := a;
    end;
    dec(i);
  end;
  if NearestIdx >= 0 then begin
    Result := TFpSymbolTableProc.Create(NPreFix + FSymbolList.Keys[NearestIdx], FSymbolList.DataPtr[NearestIdx]^.Addr);
  end;
end;

end.

