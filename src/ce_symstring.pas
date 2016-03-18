unit ce_symstring;

{$I ce_defines.inc}

interface

uses
  ce_observer, ce_interfaces, ce_nativeproject, ce_synmemo, ce_common,
  ce_stringrange;

type

  (**
   * Enumerates the symbol kinds, used to index an associative array.
   *)
  TCESymbol = (CAF, CAP, CFF, CFP, CI, CPF, CPP, CPO, CPR, CPN, CPFS, CPCD);

  (**
   * TCESymbolExpander is designed to expand Coedit symbolic strings,
   * using the information collected from several observer interfaces.
   *)
  TCESymbolExpander = class(ICEMultiDocObserver, ICEProjectObserver)
  private
    fProj: TCENativeProject;
    fProjInterface: ICECommonProject;
    fDoc: TCESynMemo;
    fNeedUpdate: boolean;
    fSymbols: array[TCESymbol] of string;
    procedure updateSymbols;
    //
    procedure projNew(aProject: ICECommonProject);
    procedure projClosing(aProject: ICECommonProject);
    procedure projFocused(aProject: ICECommonProject);
    procedure projChanged(aProject: ICECommonProject);
    procedure projCompiling(aProject: ICECommonProject);
    procedure projCompiled(aProject: ICECommonProject; success: boolean);
    //
    procedure docNew(aDoc: TCESynMemo);
    procedure docClosing(aDoc: TCESynMemo);
    procedure docFocused(aDoc: TCESynMemo);
    procedure docChanged(aDoc: TCESynMemo);
  public
    constructor Create;
    destructor Destroy; override;
    // expands the symbols contained in symString
    function get(const symString: string): string;
  end;

var
  symbolExpander: TCESymbolExpander;

implementation

uses
  Forms, SysUtils, Classes;

{$REGION Standard Comp/Obj------------------------------------------------------}
constructor TCESymbolExpander.Create;
begin
  EntitiesConnector.addObserver(self);
  fNeedUpdate := true;
end;

destructor TCESymbolExpander.Destroy;
begin
  fNeedUpdate := false;
  EntitiesConnector.removeObserver(self);
  inherited;
end;
{$ENDREGION}

{$REGION ICEProjectObserver ----------------------------------------------------}
procedure TCESymbolExpander.projNew(aProject: ICECommonProject);
begin
  fProjInterface := aProject;
  case aProject.getFormat of
    pfNative: fProj := TCENativeProject(aProject.getProject);
    pfDub: fProj := nil;
  end;
  fNeedUpdate := true;
end;

procedure TCESymbolExpander.projClosing(aProject: ICECommonProject);
begin
  fProjInterface := nil;
  if fProj <> aProject.getProject then
    exit;
  fProj := nil;
  fNeedUpdate := true;
end;

procedure TCESymbolExpander.projFocused(aProject: ICECommonProject);
begin
  fProjInterface := aProject;
  case aProject.getFormat of
    pfNative: fProj := TCENativeProject(aProject.getProject);
    pfDub: fProj := nil;
  end;
  fNeedUpdate := true;
end;

procedure TCESymbolExpander.projChanged(aProject: ICECommonProject);
begin
  fProjInterface := aProject;
  if fProj <> aProject.getProject then
    exit;
  fNeedUpdate := true;
end;

procedure TCESymbolExpander.projCompiling(aProject: ICECommonProject);
begin
end;

procedure TCESymbolExpander.projCompiled(aProject: ICECommonProject; success: boolean);
begin
end;
{$ENDREGION}

{$REGION ICEMultiDocObserver ---------------------------------------------------}
procedure TCESymbolExpander.docNew(aDoc: TCESynMemo);
begin
  fDoc := aDoc;
  fNeedUpdate := true;
end;

procedure TCESymbolExpander.docClosing(aDoc: TCESynMemo);
begin
  if aDoc <> fDoc then
    exit;
  fDoc := nil;
  fNeedUpdate := true;
end;

procedure TCESymbolExpander.docFocused(aDoc: TCESynMemo);
begin
  if (aDoc.isNotNil) and (fDoc = aDoc) then
    exit;
  fDoc := aDoc;
  fNeedUpdate := true;
end;

procedure TCESymbolExpander.docChanged(aDoc: TCESynMemo);
begin
  if aDoc <> fDoc then
    exit;
  fNeedUpdate := true;
end;
{$ENDREGION}

{$REGION Symbol things ---------------------------------------------------------}
procedure TCESymbolExpander.updateSymbols;
var
  hasNativeProj: boolean;
  hasProjItf: boolean;
  hasDoc: boolean;
  fname: string;
  i: Integer;
  e: TCESymbol;
  str: TStringList;
const
  na = '``';
begin
  if not fNeedUpdate then exit;
  fNeedUpdate := false;
  //
  hasNativeProj := fProj.isNotNil;
  hasProjItf := fProjInterface <> nil;
  hasDoc := fDoc.isNotNil;
  //
  for e := low(TCESymbol) to high(TCESymbol) do
    fSymbols[e] := na;
  //
  // application
  fSymbols[CAF] := Application.ExeName;
  fSymbols[CAP] := fSymbols[CAF].extractFilePath;
  // document
  if hasDoc then
  begin
    if not fDoc.fileName.fileExists then
      fDoc.saveTempFile;
    fSymbols[CFF] := fDoc.fileName;
    fSymbols[CFP] := fDoc.fileName.extractFilePath;
    if fDoc.Identifier.isNotEmpty then
      fSymbols[CI] := fDoc.Identifier;
  end;
  // project interface
  if hasProjItf then
  begin
    fname := fProjInterface.filename;
    fSymbols[CPF] := fname;
    fSymbols[CPP] := fSymbols[CPF].extractFilePath;
    fSymbols[CPN] := stripFileExt(fSymbols[CPF].extractFileName);
    fSymbols[CPO] := fProjInterface.outputFilename;
    if fProjInterface.sourcesCount <> 0 then
    begin
      str := TStringList.Create;
      try
        for i := 0 to fProjInterface.sourcesCount-1 do
        begin
          fname := fProjInterface.sourceAbsolute(i);
          if not isEditable(fname.extractFileExt) then
            continue;
          str.Add(fname);
        end;
        fSymbols[CPFS] := str.Text;
        if str.Count = 1 then
          fSymbols[CPCD] := str[0].extractFileDir
        else
          fSymbols[CPCD] := commonFolder(str);
      finally
        str.Free;
      end;
    end;
  end;
  if hasNativeProj then
  begin
    if fProj.fileName.fileExists then
    begin
      fSymbols[CPR] := expandFilenameEx(fProj.basePath, fProj.RootFolder);
      if fSymbols[CPR].isEmpty then
        fSymbols[CPR] := fSymbols[CPP];
    end;
  end;
end;

function TCESymbolExpander.get(const symString: string): string;
var
  rng: TStringRange;
  sym: string;
begin
  Result := '';
  if symString.isEmpty then
    exit;
  //
  updateSymbols;
  rng := TStringRange.create(symString);
  while true do
  begin
    if rng.empty then
      break;
    Result += rng.takeUntil('<').yield;
    if not rng.empty and (rng.front = '<') then
    begin
      rng.popFront;
      sym := rng.takeUntil('>').yield;
      if not rng.empty and (rng.front = '>') then
      begin
        rng.popFront;
        case sym of
          'CAF', 'CoeditApplicationFile': Result += fSymbols[CAF];
          'CAP', 'CoeditApplicationPath': Result += fSymbols[CAP];
          //
          'CFF', 'CurrentFileFile'      : Result += fSymbols[CFF];
          'CFP', 'CurrentFilePath'      : Result += fSymbols[CFP];
          'CI', 'CurrentIdentifier'     : Result += fSymbols[CI];
          //
          'CPF', 'CurrentProjectFile'   : Result += fSymbols[CPF];
          'CPFS', 'CurrentProjectFiles' : Result += fSymbols[CPFS];
          'CPN', 'CurrentProjectName'   : Result += fSymbols[CPN];
          'CPO', 'CurrentProjectOutput' : Result += fSymbols[CPO];
          'CPP', 'CurrentProjectPath'   : Result += fSymbols[CPP];
          'CPR', 'CurrentProjectRoot'   : Result += fSymbols[CPR];
          'CPCD','CurrentProjectCommonDirectory': Result += fSymbols[CPCD];
          else Result += '<' + sym + '>';
        end;
      end
      else Result += '<' + sym;
    end;
  end;
end;
{$ENDREGION}

initialization
  symbolExpander := TCESymbolExpander.Create;

finalization
  symbolExpander.Free;
end.
