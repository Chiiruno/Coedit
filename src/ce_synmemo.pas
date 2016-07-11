unit ce_synmemo;

{$I ce_defines.inc}

interface

uses
  Classes, SysUtils, controls,lcltype, Forms, graphics, ExtCtrls, crc, process,
  SynEdit, SynPluginSyncroEdit, SynCompletion, SynEditKeyCmds, LazSynEditText,
  SynHighlighterLFM, SynEditHighlighter, SynEditMouseCmds, SynEditFoldedView,
  SynEditMarks, SynEditTypes, SynHighlighterJScript, SynBeautifier, dialogs,
  fpjson, jsonparser, LazUTF8, LazUTF8Classes, Buttons, StdCtrls,
  ce_common, ce_writableComponent, ce_d2syn, ce_txtsyn, ce_dialogs,
  ce_sharedres, ce_dlang, ce_stringrange;

type

  TCESynMemo = class;

  TIdentifierMatchOption = (
    caseSensitive = longInt(ssoMatchCase),
    wholeWord = longInt(ssoWholeWord)
  );

  TBraceAutoCloseStyle = (
    autoCloseNever,
    autoCloseAtEof,
    autoCloseAlways,
    autoCloseLexically,
    autoCloseOnNewLineEof,
    autoCloseOnNewLineAlways,
    autoCloseOnNewLineLexically
  );

  TAutoClosedPair = (
    autoCloseSingleQuote,
    autoCloseDoubleQuote,
    autoCloseBackTick,
    autoCloseSquareBracket
  );

  TAutoClosePairs = set of TAutoClosedPair;

const

  autoClosePair2Char: array[TAutoClosedPair] of char = (#39, '"', '`', ']');

type

  TIdentifierMatchOptions = set of TIdentifierMatchOption;

  TBreakPointModification = (bpAdded, bpRemoved);

  // breakpoint added or removed
  TBreakPointModifyEvent = procedure(sender: TCESynMemo; line: integer;
    modification: TBreakPointModification) of object;

  // Simple THintWindow descendant allowing the font size to be in sync with the editor.
  TCEEditorHintWindow = class(THintWindow)
  public
    class var FontSize: Integer;
    function CalcHintRect(MaxWidth: Integer; const AHint: string;
      AData: Pointer): TRect; override;
  end;

  // Stores the state of a particular source code folding.
  TCEFoldCache = class(TCollectionItem)
  private
    fCollapsed: boolean;
    fLineIndex: Integer;
    fNestedIndex: Integer;
  published
    property isCollapsed: boolean read fCollapsed   write fCollapsed;
    property lineIndex: Integer   read fLineIndex   write fLineIndex;
    property nestedIndex: Integer read fNestedIndex write fNestedIndex;
  end;

  // Stores the state of a document between two cessions.
  TCESynMemoCache = class(TWritableLfmTextComponent)
  private
    fMemo: TCESynMemo;
    fFolds: TCollection;
    fCaretPosition: Integer;
    fSelectionEnd: Integer;
    fFontSize: Integer;
    fSourceFilename: string;
    procedure setFolds(someFolds: TCollection);
    procedure writeBreakpoints(str: TStream);
    procedure readBreakpoints(str: TStream);
  published
    property caretPosition: Integer read fCaretPosition write fCaretPosition;
    property sourceFilename: string read fSourceFilename write fSourceFilename;
    property folds: TCollection read fFolds write setFolds;
    property selectionEnd: Integer read fSelectionEnd write fSelectionEnd;
    property fontSize: Integer read fFontSize write fFontSize;
  public
    constructor create(aComponent: TComponent); override;
    destructor destroy; override;
    procedure DefineProperties(Filer: TFiler); override;
    //
    procedure beforeSave; override;
    procedure afterLoad; override;
    procedure save;
    procedure load;
  end;

  // Caret positions buffer allowing to jump fast to the most recent locations.
  // Replaces the bookmarks.
  TCESynMemoPositions = class
  private
    fPos: Integer;
    fMax: Integer;
    fList: TFPList;
    fMemo: TCustomSynEdit;
  public
    constructor create(memo: TCustomSynEdit);
    destructor destroy; override;
    procedure store;
    procedure back;
    procedure next;
  end;

  TSortDialog = class;

  TCESynMemo = class(TSynEdit)
  private
    fFilename: string;
    fDastWorxExename: string;
    fModified: boolean;
    fFileDate: double;
    fCacheLoaded: boolean;
    fIsDSource: boolean;
    fIsTxtFile: boolean;
    fFocusForInput: boolean;
    fIdentifier: string;
    fTempFileName: string;
    fMultiDocSubject: TObject;
    fDefaultFontSize: Integer;
    fPositions: TCESynMemoPositions;
    fMousePos: TPoint;
    fCallTipWin: TCEEditorHintWindow;
    fDDocWin: TCEEditorHintWindow;
    fDDocDelay: Integer;
    fAutoDotDelay: Integer;
    fDDocTimer: TIdleTimer;
    fAutoDotTimer: TIdleTimer;
    fCanShowHint: boolean;
    fCanAutoDot: boolean;
    fOldMousePos: TPoint;
    fSyncEdit: TSynPluginSyncroEdit;
    fCompletion: TSynCompletion;
    fD2Highlighter: TSynD2Syn;
    fTxtHighlighter: TSynTxtSyn;
    fImages: TImageList;
    fBreakPoints: TFPList;
    fBreakpointEvent: TBreakPointModifyEvent;
    fMatchSelectionOpts: TSynSearchOptions;
    fMatchIdentOpts: TSynSearchOptions;
    fMatchOpts: TIdentifierMatchOptions;
    fCallTipStrings: TStringList;
    fOverrideColMode: boolean;
    fAutoCloseCurlyBrace: TBraceAutoCloseStyle;
    fLexToks: TLexTokenList;
    fDisableFileDateCheck: boolean;
    fDetectIndentMode: boolean;
    fPhobosDocRoot: string;
    fAlwaysAdvancedFeatures: boolean;
    fIsProjectDescription: boolean;
    fAutoClosedPairs: TAutoClosePairs;
    fSortDialog: TSortDialog;
    procedure decCallTipsLvl;
    procedure setMatchOpts(value: TIdentifierMatchOptions);
    function getMouseBytePosition: Integer;
    procedure changeNotify(Sender: TObject);
    procedure highlightCurrentIdentifier;
    procedure saveCache;
    procedure loadCache;
    class procedure cleanCache; static;
    procedure setDefaultFontSize(value: Integer);
    procedure DDocTimerEvent(sender: TObject);
    procedure AutoDotTimerEvent(sender: TObject);
    procedure InitHintWins;
    function getIfTemp: boolean;
    procedure setDDocDelay(value: Integer);
    procedure setAutoDotDelay(value: Integer);
    procedure completionExecute(sender: TObject);
    procedure getCompletionList;
    function completionItemPaint(const AKey: string; ACanvas: TCanvas;X, Y: integer;
      Selected: boolean; Index: integer): boolean;
    procedure completionCodeCompletion(var value: string; SourceValue: string;
      var SourceStart, SourceEnd: TPoint; KeyChar: TUTF8Char; Shift: TShiftState);
    procedure gutterClick(Sender: TObject; X, Y, Line: integer; mark: TSynEditMark);
    procedure addBreakPoint(line: integer);
    procedure removeBreakPoint(line: integer);
    function  findBreakPoint(line: integer): boolean;
    procedure showCallTips(const tips: string);
    function lexCanCloseBrace: boolean;
    procedure handleStatusChanged(Sender: TObject; Changes: TSynStatusChanges);
    procedure gotoToChangedArea(next: boolean);
    procedure autoClosePair(value: TAutoClosedPair);
    procedure setSelectionOrWordCase(upper: boolean);
    procedure sortSelectedLines(descending, caseSensitive: boolean);
  protected
    procedure DoEnter; override;
    procedure DoExit; override;
    procedure DoOnProcessCommand(var Command: TSynEditorCommand; var AChar: TUTF8Char;
      Data: pointer); override;
    procedure MouseLeave; override;
    procedure SetVisible(Value: Boolean); override;
    procedure SetHighlighter(const Value: TSynCustomHighlighter); override;
    procedure UTF8KeyPress(var Key: TUTF8Char); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyUp(var Key: Word; Shift: TShiftState); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y:Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y:Integer); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
  public
    constructor Create(aOwner: TComponent); override;
    destructor destroy; override;
    procedure setFocus; override;
    //
    procedure checkFileDate;
    procedure loadFromFile(const fname: string);
    procedure saveToFile(const fname: string);
    procedure save;
    procedure saveTempFile;
    //
    procedure curlyBraceCloseAndIndent;
    procedure commentSelection;
    procedure commentIdentifier;
    procedure renameIdentifier;
    procedure invertVersionAllNone;
    procedure showCallTips(findOpenParen: boolean = true);
    procedure hideCallTips;
    procedure showDDocs;
    procedure hideDDocs;
    procedure ShowPhobosDoc;
    procedure nextChangedArea;
    procedure previousChangedArea;
    function implementMain: THasMain;
    procedure sortLines;
    //
    function breakPointsCount: integer;
    function breakPointLine(index: integer): integer;
    property onBreakpointModify: TBreakPointModifyEvent read fBreakpointEvent write fBreakpointEvent;
    //
    property IdentifierMatchOptions: TIdentifierMatchOptions read fMatchOpts write setMatchOpts;
    property Identifier: string read fIdentifier;
    property fileName: string read fFilename;
    property modified: boolean read fModified;
    property tempFilename: string read fTempFileName;
    //
    property completionMenu: TSynCompletion read fCompletion;
    property syncroEdit: TSynPluginSyncroEdit read fSyncEdit;
    property isDSource: boolean read fIsDSource;
    property isTemporary: boolean read getIfTemp;
    property TextView;
    //
    property isProjectDescription: boolean read fIsProjectDescription write fIsProjectDescription;
    property alwaysAdvancedFeatures: boolean read fAlwaysAdvancedFeatures write fAlwaysAdvancedFeatures;
    property phobosDocRoot: string read fPhobosDocRoot write fPhobosDocRoot;
    property detectIndentMode: boolean read fDetectIndentMode write fDetectIndentMode;
    property disableFileDateCheck: boolean read fDisableFileDateCheck write fDisableFileDateCheck;
    property MouseBytePosition: Integer read getMouseBytePosition;
    property D2Highlighter: TSynD2Syn read fD2Highlighter;
    property TxtHighlighter: TSynTxtSyn read fTxtHighlighter;
    property defaultFontSize: Integer read fDefaultFontSize write setDefaultFontSize;
    property ddocDelay: Integer read fDDocDelay write setDDocDelay;
    property autoDotDelay: Integer read fAutoDotDelay write setAutoDotDelay;
    property autoCloseCurlyBrace: TBraceAutoCloseStyle read fAutoCloseCurlyBrace write fAutoCloseCurlyBrace;
    property autoClosedPairs: TAutoClosePairs read fAutoClosedPairs write fAutoClosedPairs;
  end;

  TSortDialog = class(TForm)
  private
    class var fDescending: boolean;
    class var fCaseSensitive: boolean;
    fEditor: TCESynMemo;
    fCanUndo: boolean;
    procedure btnApplyClick(sender: TObject);
    procedure btnUndoClick(sender: TObject);
    procedure chkCaseSensClick(sender: TObject);
    procedure chkDescClick(sender: TObject);
  public
    constructor construct(editor: TCESynMemo);
  end;

  procedure SetDefaultCoeditKeystrokes(ed: TSynEdit);

  function CustomStringToCommand(const Ident: string; var Int: Longint): Boolean;
  function CustomCommandToSstring(Int: Longint; var Ident: string): Boolean;

const
  ecCompletionMenu      = ecUserFirst + 1;
  ecJumpToDeclaration   = ecUserFirst + 2;
  ecPreviousLocation    = ecUserFirst + 3;
  ecNextLocation        = ecUserFirst + 4;
  ecRecordMacro         = ecUserFirst + 5;
  ecPlayMacro           = ecUserFirst + 6;
  ecShowDdoc            = ecUserFirst + 7;
  ecShowCallTips        = ecUserFirst + 8;
  ecCurlyBraceClose     = ecUserFirst + 9;
  ecCommentSelection    = ecUserFirst + 10;
  ecSwapVersionAllNone  = ecUserFirst + 11;
  ecRenameIdentifier    = ecUserFirst + 12;
  ecCommentIdentifier   = ecUserFirst + 13;
  ecShowPhobosDoc       = ecUserFirst + 14;
  ecPreviousChangedArea = ecUserFirst + 15;
  ecNextChangedArea     = ecUserFirst + 16;
  ecUpperCaseWordOrSel  = ecUserFirst + 17;
  ecLowerCaseWordOrSel  = ecUserFirst + 18;
  ecSortLines           = ecUserFirst + 19;

var
  D2Syn: TSynD2Syn;     // used as model to set the options when no editor exists.
  TxtSyn: TSynTxtSyn;   // used as model to set the options when no editor exists.
  LfmSyn: TSynLfmSyn;   // used to highlight the native projects.
  JsSyn: TSynJScriptSyn;// used to highlight the DUB JSON projects.


implementation

uses
  ce_interfaces, ce_staticmacro, ce_dcd, SynEditHighlighterFoldBase, ce_lcldragdrop;

function TCEEditorHintWindow.CalcHintRect(MaxWidth: Integer; const AHint: String; AData: Pointer): TRect;
begin
  Font.Size:= FontSize;
  result := inherited CalcHintRect(MaxWidth, AHint, AData);
end;

{$REGION TSortDialog -----------------------------------------------------------}
constructor TSortDialog.construct(editor: TCESynMemo);
var
  pnl: TPanel;
begin
  inherited Create(nil);
  fEditor := editor;

  width := 150;
  Height:= 95;
  FormStyle:= fsStayOnTop;
  BorderStyle:= bsToolWindow;
  Position:= poScreenCenter;
  ShowHint:=true;

  with TCheckBox.Create(self) do
  begin
    parent := self;
    BorderSpacing.Around:=2;
    OnClick:=@chkCaseSensClick;
    Caption:='case sensitive';
    checked := fCaseSensitive;
    align := alTop;
  end;

  with TCheckBox.Create(self) do
  begin
    parent := self;
    BorderSpacing.Around:=2;
    OnClick:=@chkDescClick;
    Caption:='descending';
    Checked:= fDescending;
    align := alTop;
  end;

  pnl := TPanel.Create(self);
  pnl.Parent := self;
  pnl.Align:=alBottom;
  pnl.Caption:='';
  pnl.Height:= 32;
  pnl.BevelOuter:=bvLowered;

  with TSpeedButton.Create(self) do
  begin
    parent := pnl;
    BorderSpacing.Around:=2;
    OnClick:=@btnUndoClick;
    align := alRight;
    width := 28;
    Hint := 'undo changes';
    AssignPng(Glyph, 'ARROW_UNDO');
  end;

  with TSpeedButton.Create(self) do
  begin
    parent := pnl;
    BorderSpacing.Around:=2;
    OnClick:=@btnApplyClick;
    align := alRight;
    width := 28;
    Hint := 'apply sorting';
    AssignPng(Glyph, 'ACCEPT');
  end;
end;

procedure TSortDialog.btnApplyClick(sender: TObject);
begin
  fEditor.sortSelectedLines(fDescending, fCaseSensitive);
  fCanUndo:= true;
end;

procedure TSortDialog.btnUndoClick(sender: TObject);
begin
  if fCanUndo then
    fEditor.undo;
  fCanUndo:= false;
end;

procedure TSortDialog.chkCaseSensClick(sender: TObject);
begin
  fCaseSensitive := TCheckBox(sender).checked;
end;

procedure TSortDialog.chkDescClick(sender: TObject);
begin
  fDescending := TCheckBox(sender).checked;
end;
{$ENDREGION}

{$REGION TCESynMemoCache -------------------------------------------------------}
constructor TCESynMemoCache.create(aComponent: TComponent);
begin
  inherited create(nil);
  if (aComponent is TCESynMemo) then
  	fMemo := TCESynMemo(aComponent);
  fFolds := TCollection.Create(TCEFoldCache);
end;

destructor TCESynMemoCache.destroy;
begin
  fFolds.Free;
  inherited;
end;

procedure TCESynMemoCache.DefineProperties(Filer: TFiler);
begin
  inherited;
  Filer.DefineBinaryProperty('breakpoints', @readBreakpoints, @writeBreakpoints, true);
end;

procedure TCESynMemoCache.setFolds(someFolds: TCollection);
begin
  fFolds.Assign(someFolds);
end;

procedure TCESynMemoCache.writeBreakpoints(str: TStream);
var
  i: integer;
begin
  if fMemo.isNil then exit;
  {$HINTS OFF}
  for i:= 0 to fMemo.fBreakPoints.Count-1 do
    str.Write(PtrUint(fMemo.fBreakPoints.Items[i]), sizeOf(PtrUint));
  {$HINTS ON}
end;

procedure TCESynMemoCache.readBreakpoints(str: TStream);
var
  i, cnt: integer;
  line: ptrUint = 0;
begin
  if fMemo.isNil then exit;
  cnt := str.Size div sizeOf(PtrUint);
  for i := 0 to cnt-1 do
  begin
    str.Read(line, sizeOf(line));
    fMemo.addBreakPoint(line);
  end;
end;

procedure TCESynMemoCache.beforeSave;
var
  i, start, prev: Integer;
  itm : TCEFoldCache;
begin
  if fMemo.isNil then exit;
  //
  fCaretPosition := fMemo.SelStart;
  fSourceFilename := fMemo.fileName;
  fSelectionEnd := fMemo.SelEnd;
  fFontSize := fMemo.Font.Size;
  TCEEditorHintWindow.FontSize := fMemo.Font.Size;
  //
  // TODO-cimprovment: handle nested folding in TCESynMemoCache
  // cf. other ways: http://forum.lazarus.freepascal.org/index.php?topic=26748.msg164722#msg164722
  prev := fMemo.Lines.Count-1;
  for i := fMemo.Lines.Count-1 downto 0 do
  begin
    // - CollapsedLineForFoldAtLine() does not handle the sub-folding.
    // - TextView visibility is increased so this is not the standard way of getting the infos.
    start := fMemo.TextView.CollapsedLineForFoldAtLine(i);
    if start = -1 then
      continue;
    if start = prev then
      continue;
    prev := start;
    itm := TCEFoldCache(fFolds.Add);
    itm.isCollapsed := true;
    itm.fLineIndex := start;
  end;
end;

procedure TCESynMemoCache.afterLoad;
var
  i: integer;
  itm : TCEFoldCache;
begin
  if fMemo.isNil then exit;
  //
  if fFontSize > 0 then
    fMemo.Font.Size := fFontSize;
  // Currently collisions are not handled.
  if fMemo.fileName <> fSourceFilename then exit;
  //
  for i := 0 to fFolds.Count-1 do
  begin
    itm := TCEFoldCache(fFolds.Items[i]);
    if not itm.isCollapsed then
      continue;
    fMemo.TextView.FoldAtLine(itm.lineIndex-1);
  end;
  //
  fMemo.SelStart := fCaretPosition;
  fMemo.SelEnd := fSelectionEnd;
end;

{$IFDEF DEBUG}{$R-}{$ENDIF}
procedure TCESynMemoCache.save;
var
  fname: string;
  tempn: string;
  chksm: Cardinal;
begin
  tempn := fMemo.fileName;
  if tempn = fMemo.tempFilename then exit;
  if not tempn.fileExists then exit;
  //
  fname := getCoeditDocPath + 'editorcache' + DirectorySeparator;
  ForceDirectories(fname);
  chksm := crc32(0, nil, 0);
  chksm := crc32(chksm, @tempn[1], tempn.length);
  fname := fname + format('%.8X.txt', [chksm]);
  saveToFile(fname);
end;

procedure TCESynMemoCache.load;
var
  fname: string;
  tempn: string;
  chksm: Cardinal;
begin
  tempn := fMemo.fileName;
  if not tempn.fileExists then exit;
  //
  fname := getCoeditDocPath + 'editorcache' + DirectorySeparator;
  chksm := crc32(0, nil, 0);
  chksm := crc32(chksm, @tempn[1], tempn.length);
  fname := fname + format('%.8X.txt', [chksm]);
  //
  if not fname.fileExists then exit;
  loadFromFile(fname);
end;
{$IFDEF DEBUG}{$R+}{$ENDIF}
{$ENDREGION}

{$REGION TCESynMemoPositions ---------------------------------------------------}
constructor TCESynMemoPositions.create(memo: TCustomSynEdit);
begin
  fList := TFPList.Create;
  fMax  := 40;
  fMemo := memo;
  fPos  := -1;
end;

destructor TCESynMemoPositions.destroy;
begin
  fList.Free;
  inherited;
end;

procedure TCESynMemoPositions.back;
begin
  Inc(fPos);
  {$HINTS OFF}
  if fPos < fList.Count then
    fMemo.CaretY := NativeInt(fList.Items[fPos])
  {$HINTS ON}
  else Dec(fPos);
end;

procedure TCESynMemoPositions.next;
begin
  Dec(fPos);
  {$HINTS OFF}
  if fPos > -1 then
    fMemo.CaretY := NativeInt(fList.Items[fPos])
  {$HINTS ON}
  else Inc(fPos);
end;

procedure TCESynMemoPositions.store;
var
  delta: NativeInt;
const
  thresh = 6;
begin
  fPos := 0;
  {$PUSH}
  {$HINTS OFF}{$WARNINGS OFF}
  if fList.Count > 0 then
  begin
    delta := fMemo.CaretY - NativeInt(fList.Items[fPos]);
    if (delta > -thresh) and (delta < thresh) then exit;
  end;
  fList.Insert(0, Pointer(NativeInt(fMemo.CaretY)));
  {$POP}
  while fList.Count > fMax do
    fList.Delete(fList.Count-1);
end;
{$ENDREGION --------------------------------------------------------------------}

{$REGION TCESynMemo ------------------------------------------------------------}

{$REGION Standard Obj and Comp -------------------------------------------------}
constructor TCESynMemo.Create(aOwner: TComponent);
begin
  inherited;
  //
  OnStatusChange:= @handleStatusChanged;
  fDefaultFontSize := 10;
  Font.Size:=10;
  SetDefaultCoeditKeystrokes(Self); // not called in inherited if owner = nil !
  fLexToks:= TLexTokenList.Create;
  //
  OnDragDrop:= @ddHandler.DragDrop;
  OnDragOver:= @ddHandler.DragOver;
  //
  ShowHint := false;
  InitHintWins;
  fDDocDelay := 200;
  fDDocTimer := TIdleTimer.Create(self);
  fDDocTimer.AutoEnabled:=true;
  fDDocTimer.Interval := fDDocDelay;
  fDDocTimer.OnTimer := @DDocTimerEvent;
  //
  fAutoDotDelay := 20;
  fAutoDotTimer := TIdleTimer.Create(self);
  fAutoDotTimer.AutoEnabled:=true;
  fAutoDotTimer.Interval := fAutoDotDelay;
  fAutoDotTimer.OnTimer := @AutoDotTimerEvent;
  //
  Gutter.LineNumberPart.ShowOnlyLineNumbersMultiplesOf := 5;
  Gutter.LineNumberPart.MarkupInfo.Foreground := clWindowText;
  Gutter.LineNumberPart.MarkupInfo.Background := clBtnFace;
  Gutter.SeparatorPart.LineOffset := 0;
  Gutter.SeparatorPart.LineWidth := 1;
  Gutter.OnGutterClick:= @gutterClick;
  BracketMatchColor.Foreground:=clRed;
  //
  fSyncEdit := TSynPluginSyncroEdit.Create(self);
  fSyncEdit.Editor := self;
  fSyncEdit.CaseSensitive := true;
  AssignPng(fSyncEdit.GutterGlyph, 'LINK_EDIT');
  //
  fCompletion := TSyncompletion.create(nil);
  fCompletion.ShowSizeDrag := true;
  fCompletion.Editor := Self;
  fCompletion.OnExecute:= @completionExecute;
  fCompletion.OnCodeCompletion:=@completionCodeCompletion;
  fCompletion.OnPaintItem:= @completionItemPaint;
  fCompletion.CaseSensitive:=false;
  fCompletion.LongLineHintType:=sclpNone;
  fCompletion.TheForm.ShowInTaskBar:=stNever;
  fCompletion.ShortCut:=0;
  fCompletion.LinesInWindow:=15;
  fCompletion.Width:= 250;
  fCallTipStrings:= TStringList.Create;
  //
  MouseLinkColor.Style:= [fsUnderline];
  with MouseActions.Add do begin
    Command := emcMouseLink;
    shift := [ssCtrl];
    ShiftMask := [ssCtrl];
  end;
  //
  fD2Highlighter := TSynD2Syn.create(self);
  fTxtHighlighter := TSynTxtSyn.Create(self);
  Highlighter := fD2Highlighter;
  //
  fTempFileName := GetTempDir(false) + 'temp_' + uniqueObjStr(self) + '.d';
  fFilename := '<new document>';
  fModified := false;
  TextBuffer.AddNotifyHandler(senrUndoRedoAdded, @changeNotify);
  //
  fImages := TImageList.Create(self);
  fImages.AddResourceName(HINSTANCE, 'BULLET_RED');
  fImages.AddResourceName(HINSTANCE, 'BULLET_GREEN');
  fBreakPoints := TFPList.Create;
  //
  fPositions := TCESynMemoPositions.create(self);
  fMultiDocSubject := TCEMultiDocSubject.create;
  //
  HighlightAllColor.Foreground := clNone;
  HighlightAllColor.Background := clSilver;
  HighlightAllColor.BackAlpha  := 70;
  IdentifierMatchOptions:= [caseSensitive];
  //
  LineHighlightColor.Background := color - $080808;
  LineHighlightColor.Foreground := clNone;
  //
  fAutoCloseCurlyBrace:= autoCloseOnNewLineLexically;
  fAutoClosedPairs:= [autoCloseSquareBracket];
  //
  fDastWorxExename:= exeFullName('dastworx' + exeExt);
  //
  subjDocNew(TCEMultiDocSubject(fMultiDocSubject), self);
end;

destructor TCESynMemo.destroy;
begin
  saveCache;
  //
  subjDocClosing(TCEMultiDocSubject(fMultiDocSubject), self);
  fMultiDocSubject.Free;
  fPositions.Free;
  fCompletion.Free;
  fBreakPoints.Free;
  fCallTipStrings.Free;
  fLexToks.Clear;
  fLexToks.Free;
  fSortDialog.Free;
  //
  if fTempFileName.fileExists then
    sysutils.DeleteFile(fTempFileName);
  //
  inherited;
end;

procedure TCESynMemo.setDefaultFontSize(value: Integer);
var
  old: Integer;
begin
  old := Font.Size;
  if value < 5 then value := 5;
  fDefaultFontSize:= value;
  if Font.Size = old then
    Font.Size := fDefaultFontSize;
end;

procedure TCESynMemo.setFocus;
begin
  inherited;
  checkFileDate;
  highlightCurrentIdentifier;
  subjDocFocused(TCEMultiDocSubject(fMultiDocSubject), self);
end;

procedure TCESynMemo.DoEnter;
begin
  inherited;
  checkFileDate;
  if not fFocusForInput then
    subjDocFocused(TCEMultiDocSubject(fMultiDocSubject), self);
  fFocusForInput := true;
end;

procedure TCESynMemo.DoExit;
begin
  inherited;
  fFocusForInput := false;
  hideDDocs;
  hideCallTips;
  if fCompletion.IsActive then
    fCompletion.Deactivate;
end;

procedure TCESynMemo.SetVisible(Value: Boolean);
begin
  inherited;
  if Value then
  begin
    setFocus;
    if not fCacheLoaded then
      loadCache;
    fCacheLoaded := true;
  end
  else begin
    hideDDocs;
    hideCallTips;
    if fCompletion.IsActive then
      fCompletion.Deactivate;
  end;
end;
{$ENDREGION --------------------------------------------------------------------}

{$REGION Custom editor commands and shortcuts ----------------------------------}
procedure SetDefaultCoeditKeystrokes(ed: TSynEdit);
begin
  with ed do begin
    Keystrokes.Clear;
    //
    AddKey(ecUp, VK_UP, [], 0, []);
    AddKey(ecSelUp, VK_UP, [ssShift], 0, []);
    AddKey(ecScrollUp, VK_UP, [ssCtrl], 0, []);
    AddKey(ecDown, VK_DOWN, [], 0, []);
    AddKey(ecSelDown, VK_DOWN, [ssShift], 0, []);
    AddKey(ecScrollDown, VK_DOWN, [ssCtrl], 0, []);
    AddKey(ecLeft, VK_LEFT, [], 0, []);
    AddKey(ecSelLeft, VK_LEFT, [ssShift], 0, []);
    AddKey(ecWordLeft, VK_LEFT, [ssCtrl], 0, []);
    AddKey(ecWordEndLeft, VK_LEFT, [ssCtrl,ssAlt], 0, []);
    AddKey(ecWordEndRight, VK_RIGHT, [ssCtrl,ssAlt], 0, []);
    AddKey(ecSelWordLeft, VK_LEFT, [ssShift,ssCtrl], 0, []);
    AddKey(ecRight, VK_RIGHT, [], 0, []);
    AddKey(ecSelRight, VK_RIGHT, [ssShift], 0, []);
    AddKey(ecWordRight, VK_RIGHT, [ssCtrl], 0, []);
    AddKey(ecSelWordRight, VK_RIGHT, [ssShift,ssCtrl], 0, []);
    AddKey(ecPageDown, VK_NEXT, [], 0, []);
    AddKey(ecSelPageDown, VK_NEXT, [ssShift], 0, []);
    AddKey(ecPageBottom, VK_NEXT, [ssCtrl], 0, []);
    AddKey(ecSelPageBottom, VK_NEXT, [ssShift,ssCtrl], 0, []);
    AddKey(ecPageUp, VK_PRIOR, [], 0, []);
    AddKey(ecSelPageUp, VK_PRIOR, [ssShift], 0, []);
    AddKey(ecPageTop, VK_PRIOR, [ssCtrl], 0, []);
    AddKey(ecSelPageTop, VK_PRIOR, [ssShift,ssCtrl], 0, []);
    AddKey(ecLineStart, VK_HOME, [], 0, []);
    AddKey(ecSelLineStart, VK_HOME, [ssShift], 0, []);
    AddKey(ecEditorTop, VK_HOME, [ssCtrl], 0, []);
    AddKey(ecSelEditorTop, VK_HOME, [ssShift,ssCtrl], 0, []);
    AddKey(ecLineEnd, VK_END, [], 0, []);
    AddKey(ecSelLineEnd, VK_END, [ssShift], 0, []);
    AddKey(ecEditorBottom, VK_END, [ssCtrl], 0, []);
    AddKey(ecSelEditorBottom, VK_END, [ssShift,ssCtrl], 0, []);
    AddKey(ecToggleMode, VK_INSERT, [], 0, []);
    AddKey(ecDeleteChar, VK_DELETE, [], 0, []);
    AddKey(ecDeleteLastChar, VK_BACK, [], 0, []);
    AddKey(ecDeleteLastWord, VK_BACK, [ssCtrl], 0, []);
    AddKey(ecLineBreak, VK_RETURN, [], 0, []);
    AddKey(ecSelectAll, ord('A'), [ssCtrl], 0, []);
    AddKey(ecCopy, ord('C'), [ssCtrl], 0, []);
    AddKey(ecBlockIndent, ord('I'), [ssCtrl,ssShift], 0, []);
    AddKey(ecInsertLine, ord('N'), [ssCtrl], 0, []);
    AddKey(ecDeleteWord, ord('T'), [ssCtrl], 0, []);
    AddKey(ecBlockUnindent, ord('U'), [ssCtrl,ssShift], 0, []);
    AddKey(ecPaste, ord('V'), [ssCtrl], 0, []);
    AddKey(ecCut, ord('X'), [ssCtrl], 0, []);
    AddKey(ecDeleteLine, ord('Y'), [ssCtrl], 0, []);
    AddKey(ecDeleteEOL, ord('Y'), [ssCtrl,ssShift], 0, []);
    AddKey(ecUndo, ord('Z'), [ssCtrl], 0, []);
    AddKey(ecRedo, ord('Z'), [ssCtrl,ssShift], 0, []);
    AddKey(ecFoldLevel1, ord('1'), [ssAlt,ssShift], 0, []);
    AddKey(ecFoldLevel2, ord('2'), [ssAlt,ssShift], 0, []);
    AddKey(ecFoldLevel3, ord('3'), [ssAlt,ssShift], 0, []);
    AddKey(ecFoldLevel4, ord('4'), [ssAlt,ssShift], 0, []);
    AddKey(ecFoldLevel5, ord('5'), [ssAlt,ssShift], 0, []);
    AddKey(ecFoldLevel6, ord('6'), [ssAlt,ssShift], 0, []);
    AddKey(ecFoldLevel7, ord('7'), [ssAlt,ssShift], 0, []);
    AddKey(ecFoldLevel8, ord('8'), [ssAlt,ssShift], 0, []);
    AddKey(ecFoldLevel9, ord('9'), [ssAlt,ssShift], 0, []);
    AddKey(ecFoldLevel0, ord('0'), [ssAlt,ssShift], 0, []);
    AddKey(ecFoldCurrent, ord('-'), [ssAlt,ssShift], 0, []);
    AddKey(ecUnFoldCurrent, ord('+'), [ssAlt,ssShift], 0, []);
    AddKey(EcToggleMarkupWord, ord('M'), [ssAlt], 0, []);
    AddKey(ecNormalSelect, ord('N'), [ssCtrl,ssShift], 0, []);
    AddKey(ecColumnSelect, ord('C'), [ssCtrl,ssShift], 0, []);
    AddKey(ecLineSelect, ord('L'), [ssCtrl,ssShift], 0, []);
    AddKey(ecTab, VK_TAB, [], 0, []);
    AddKey(ecShiftTab, VK_TAB, [ssShift], 0, []);
    AddKey(ecMatchBracket, ord('B'), [ssCtrl,ssShift], 0, []);
    AddKey(ecColSelUp, VK_UP,    [ssAlt, ssShift], 0, []);
    AddKey(ecColSelDown, VK_DOWN,  [ssAlt, ssShift], 0, []);
    AddKey(ecColSelLeft, VK_LEFT, [ssAlt, ssShift], 0, []);
    AddKey(ecColSelRight, VK_RIGHT, [ssAlt, ssShift], 0, []);
    AddKey(ecColSelPageDown, VK_NEXT, [ssAlt, ssShift], 0, []);
    AddKey(ecColSelPageBottom, VK_NEXT, [ssAlt, ssShift,ssCtrl], 0, []);
    AddKey(ecColSelPageUp, VK_PRIOR, [ssAlt, ssShift], 0, []);
    AddKey(ecColSelPageTop, VK_PRIOR, [ssAlt, ssShift,ssCtrl], 0, []);
    AddKey(ecColSelLineStart, VK_HOME, [ssAlt, ssShift], 0, []);
    AddKey(ecColSelLineEnd, VK_END, [ssAlt, ssShift], 0, []);
    AddKey(ecColSelEditorTop, VK_HOME, [ssAlt, ssShift,ssCtrl], 0, []);
    AddKey(ecColSelEditorBottom, VK_END, [ssAlt, ssShift,ssCtrl], 0, []);
    AddKey(ecSynPSyncroEdStart, ord('E'), [ssCtrl], 0, []);
    AddKey(ecSynPSyncroEdEscape, ord('E'), [ssCtrl, ssShift], 0, []);
    AddKey(ecCompletionMenu, ord(' '), [ssCtrl], 0, []);
    AddKey(ecJumpToDeclaration, VK_UP, [ssCtrl,ssShift], 0, []);
    AddKey(ecPreviousLocation, 0, [], 0, []);
    AddKey(ecNextLocation, 0, [], 0, []);
    AddKey(ecRecordMacro, ord('R'), [ssCtrl,ssShift], 0, []);
    AddKey(ecPlayMacro, ord('P'), [ssCtrl,ssShift], 0, []);
    AddKey(ecShowDdoc, 0, [], 0, []);
    AddKey(ecShowCallTips, 0, [], 0, []);
    AddKey(ecCurlyBraceClose, 0, [], 0, []);
    AddKey(ecCommentSelection, ord('/'), [ssCtrl], 0, []);
    AddKey(ecSwapVersionAllNone, 0, [], 0, []);
    AddKey(ecRenameIdentifier, VK_F2, [], 0, []);
    AddKey(ecCommentIdentifier, 0, [], 0, []);
    AddKey(ecShowPhobosDoc, VK_F1, [], 0, []);
    AddKey(ecPreviousChangedArea, VK_UP, [ssAlt], 0, []);
    AddKey(ecNextChangedArea, VK_DOWN, [ssAlt], 0, []);
    addKey(ecLowerCaseWordOrSel, 0, [], 0, []);
    addKey(ecUpperCaseWordOrSel, 0, [], 0, []);
    addKey(ecSortLines, 0, [], 0, []);
  end;
end;

function CustomStringToCommand(const Ident: string; var Int: Longint): Boolean;
begin
  case Ident of
    'ecCompletionMenu':     begin Int := ecCompletionMenu; exit(true); end;
    'ecJumpToDeclaration':  begin Int := ecJumpToDeclaration; exit(true); end;
    'ecPreviousLocation':   begin Int := ecPreviousLocation; exit(true); end;
    'ecNextLocation':       begin Int := ecNextLocation; exit(true); end;
    'ecRecordMacro':        begin Int := ecRecordMacro; exit(true); end;
    'ecPlayMacro':          begin Int := ecPlayMacro; exit(true); end;
    'ecShowDdoc':           begin Int := ecShowDdoc; exit(true); end;
    'ecShowCallTips':       begin Int := ecShowCallTips; exit(true); end;
    'ecCurlyBraceClose':    begin Int := ecCurlyBraceClose; exit(true); end;
    'ecCommentSelection':   begin Int := ecCommentSelection; exit(true); end;
    'ecSwapVersionAllNone': begin Int := ecSwapVersionAllNone; exit(true); end;
    'ecRenameIdentifier':   begin Int := ecRenameIdentifier; exit(true); end;
    'ecCommentIdentifier':  begin Int := ecCommentIdentifier; exit(true); end;
    'ecShowPhobosDoc':      begin Int := ecShowPhobosDoc; exit(true); end;
    'ecNextChangedArea':    begin Int := ecNextChangedArea; exit(true); end;
    'ecPreviousChangedArea':begin Int := ecPreviousChangedArea; exit(true); end;
    'ecUpperCaseWordOrSel': begin Int := ecUpperCaseWordOrSel; exit(true); end;
    'ecLowerCaseWordOrSel': begin Int := ecLowerCaseWordOrSel; exit(true); end;
    'ecSortLines':          begin Int := ecSortLines; exit(true); end;
    else exit(false);
  end;
end;

function CustomCommandToSstring(Int: Longint; var Ident: string): Boolean;
begin
  case Int of
    ecCompletionMenu:     begin Ident := 'ecCompletionMenu'; exit(true); end;
    ecJumpToDeclaration:  begin Ident := 'ecJumpToDeclaration'; exit(true); end;
    ecPreviousLocation:   begin Ident := 'ecPreviousLocation'; exit(true); end;
    ecNextLocation:       begin Ident := 'ecNextLocation'; exit(true); end;
    ecRecordMacro:        begin Ident := 'ecRecordMacro'; exit(true); end;
    ecPlayMacro:          begin Ident := 'ecPlayMacro'; exit(true); end;
    ecShowDdoc:           begin Ident := 'ecShowDdoc'; exit(true); end;
    ecShowCallTips:       begin Ident := 'ecShowCallTips'; exit(true); end;
    ecCurlyBraceClose:    begin Ident := 'ecCurlyBraceClose'; exit(true); end;
    ecCommentSelection:   begin Ident := 'ecCommentSelection'; exit(true); end;
    ecSwapVersionAllNone: begin Ident := 'ecSwapVersionAllNone'; exit(true); end;
    ecRenameIdentifier:   begin Ident := 'ecRenameIdentifier'; exit(true); end;
    ecCommentIdentifier:  begin Ident := 'ecCommentIdentifier'; exit(true); end;
    ecShowPhobosDoc:      begin Ident := 'ecShowPhobosDoc'; exit(true); end;
    ecNextChangedArea:    begin Ident := 'ecNextChangedArea'; exit(true); end;
    ecPreviousChangedArea:begin Ident := 'ecPreviousChangedArea'; exit(true); end;
    ecUpperCaseWordOrSel: begin Ident := 'ecUpperCaseWordOrSel'; exit(true); end;
    ecLowerCaseWordOrSel: begin Ident := 'ecLowerCaseWordOrSel'; exit(true); end;
    ecSortLines:          begin Ident := 'ecSortLines'; exit(true); end;
    else exit(false);
  end;
end;

procedure TCESynMemo.DoOnProcessCommand(var Command: TSynEditorCommand;
  var AChar: TUTF8Char; Data: pointer);
begin
  inherited;
  case Command of
    ecCompletionMenu:
    begin
      fCanAutoDot:=false;
      if not fIsDSource and not alwaysAdvancedFeatures then
        exit;
      fCompletion.Execute(GetWordAtRowCol(LogicalCaretXY),
        ClientToScreen(point(CaretXPix, CaretYPix + LineHeight)));
    end;
    ecPreviousLocation:
      fPositions.back;
    ecNextLocation:
      fPositions.next;
    ecShowDdoc:
    begin
      hideCallTips;
      hideDDocs;
      if not fIsDSource and not alwaysAdvancedFeatures then
        exit;
      showDDocs;
    end;
    ecShowCallTips:
    begin
      hideCallTips;
      hideDDocs;
      if not fIsDSource and not alwaysAdvancedFeatures then
        exit;
      showCallTips(true);
    end;
    ecCurlyBraceClose:
      curlyBraceCloseAndIndent;
    ecCommentSelection:
      commentSelection;
    ecSwapVersionAllNone:
      invertVersionAllNone;
    ecRenameIdentifier:
      renameIdentifier;
    ecCommentIdentifier:
      commentIdentifier;
    ecShowPhobosDoc:
      ShowPhobosDoc;
    ecNextChangedArea:
      gotoToChangedArea(true);
    ecPreviousChangedArea:
      gotoToChangedArea(false);
    ecUpperCaseWordOrSel:
      setSelectionOrWordCase(true);
    ecLowerCaseWordOrSel:
      setSelectionOrWordCase(false);
    ecSortLines:
      sortLines;
  end;
  if fOverrideColMode and not SelAvail then
  begin
    fOverrideColMode := false;
    Options := Options - [eoScrollPastEol];
  end;
end;

procedure TCESynMemo.curlyBraceCloseAndIndent;
var
  i: integer;
  beg: string = '';
  numTabs: integer = 0;
  numSpac: integer = 0;
begin
  if not fIsDSource and not alwaysAdvancedFeatures then
      exit;
  i := CaretY - 1;
  while true do
  begin
    if i < 0 then
      break;
    beg := Lines[i];
    if (Pos('{', beg) = 0) then
      i -= 1
    else
      break;
  end;

  for i:= 1 to beg.length do
  begin
    case beg[i] of
      #9: numTabs += 1;
      ' ': numSpac += 1;
      else break;
    end;
  end;
  numTabs += numSpac div TabWidth;

  BeginUndoBlock;

  CommandProcessor(ecInsertLine, '', nil);
  CommandProcessor(ecDown, '', nil);

  CommandProcessor(ecInsertLine, '', nil);
  CommandProcessor(ecDown, '', nil);
  while CaretX <> 1 do CommandProcessor(ecLeft, '' , nil);
  for i:= 0 to numTabs-1 do CommandProcessor(ecTab, '', nil);
  CommandProcessor(ecChar, '}', nil);

  CommandProcessor(ecUp, '', nil);
  while CaretX <> 1 do CommandProcessor(ecLeft, '' , nil);
  for i:= 0 to numTabs do CommandProcessor(ecTab, '', nil);

  EndUndoBlock;
end;

procedure TCESynMemo.commentSelection;
  procedure commentHere;
  begin
    ExecuteCommand(ecChar, '/', nil);
    ExecuteCommand(ecChar, '/', nil);
  end;
  procedure unCommentHere;
  begin
    ExecuteCommand(ecLineTextStart, '', nil);
    ExecuteCommand(ecDeleteChar, '', nil);
    ExecuteCommand(ecDeleteChar, '', nil);
  end;
var
  i, j, dx, lx, numUndo: integer;
  line: string;
  mustUndo: boolean = false;
  pt, cp: TPoint;
begin
  if not SelAvail then
  begin
    i := CaretX;
    line := TrimLeft(LineText);
    mustUndo := (line.length > 1) and (line[1..2] = '//');
    BeginUndoBlock;
    ExecuteCommand(ecLineTextStart, '', nil);
    if not mustUndo then
    begin
      commentHere;
      CaretX:= i+2;
    end
    else
    begin
      unCommentHere;
      CaretX:= i-2;
    end;
    EndUndoBlock;
  end else
  begin
    mustUndo := false;
    pt.X:= high(pt.X);
    cp := CaretXY;
    numUndo := 0;
    for i := BlockBegin.Y-1 to BlockEnd.Y-1 do
    begin
      line := TrimLeft(Lines[i]);
      dx := Lines[i].length - line.length;
      lx := 0;
      for j := 1 to dx do
        if Lines[i][j] = #9 then
          lx += TabWidth
        else
          lx += 1;
      if (lx + 1 < pt.X) and not line.isEmpty then
        pt.X:= lx + 1;
      if (line.length > 1) and (line[1..2] = '//') then
        numUndo += 1;
    end;
    if numUndo = 0 then
      mustUndo := false
    else if numUndo = BlockEnd.Y + 1 - BlockBegin.Y then
      mustUndo := true;
    BeginUndoBlock;
    for i := BlockBegin.Y to BlockEnd.Y do
    begin
      pt.Y:= i;
      ExecuteCommand(ecGotoXY, '', @pt);
      while CaretX < pt.X do
        ExecuteCommand(ecChar, ' ', nil);
      if not mustUndo then
      begin
        commentHere;
      end
      else
        unCommentHere;
    end;
    if not mustUndo then
      cp.X += 2
    else
      cp.X -= 2;
    CaretXY := cp;
    EndUndoBlock;
  end;
end;

procedure TCESynMemo.commentIdentifier;
var
  str: string;
  comment: boolean = true;
  tkType, st: Integer;
  attrib: TSynHighlighterAttributes;
begin
  if not GetHighlighterAttriAtRowColEx(CaretXY, str, tkType, st, attrib) then
    exit;
  if str.isEmpty then
    exit;

  if (str.length > 1) and ((str[1..2] = '/*') or
    (str[str.length-1..str.length] = '*/')) then
      comment := false;

  if comment then
  begin
    BeginUndoBlock;
    ExecuteCommand(ecWordLeft, '', nil);
    ExecuteCommand(ecChar, '/', nil);
    ExecuteCommand(ecChar, '*', nil);
    ExecuteCommand(ecWordEndRight, '', nil);
    ExecuteCommand(ecChar, '*', nil);
    ExecuteCommand(ecChar, '/', nil);
    EndUndoBlock;
  end else
  //TODO-ceditor: handle spaces between ident and comment beg end.
  begin
    BeginUndoBlock;
    if str[1..2] = '/*' then
    begin
      ExecuteCommand(ecWordLeft, '', nil);
      ExecuteCommand(ecLeft, '', nil);
      ExecuteCommand(ecLeft, '', nil);
      ExecuteCommand(ecDeleteChar, '', nil);
      ExecuteCommand(ecDeleteChar, '', nil);
    end;
    if str[str.length-1..str.length] = '*/' then
    begin
      ExecuteCommand(ecWordEndRight, '', nil);
      ExecuteCommand(ecDeleteChar, '', nil);
      ExecuteCommand(ecDeleteChar, '', nil);
    end;
    EndUndoBlock;
  end;
end;

procedure TCESynMemo.invertVersionAllNone;
var
  i: integer;
  c: char;
  tok, tok1, tok2: PLexToken;
  cp, st, nd: TPoint;
  sel: boolean;
begin
  fLexToks.Clear;
  lex(lines.Text, fLexToks, nil, [lxoNoComments]);
  cp := CaretXY;
  if SelAvail then
  begin
    sel := true;
    st := BlockBegin;
    nd := BlockEnd;
  end else
  begin
    sel := false;
    st := Point(0,0);
    nd := Point(0,0);
  end;
  for i := fLexToks.Count-1 downto 2 do
  begin
    tok := PLexToken(fLexToks[i]);
    //
    if sel and ((tok^.position.Y < st.Y)
      or (tok^.position.Y > nd.Y)) then
        continue;
    if ((tok^.Data <> 'all') and (tok^.Data <> 'none'))
      or (tok^.kind <> ltkIdentifier) or (i < 2) then
        continue;
    //
    tok1 := PLexToken(fLexToks[i-2]);
    tok2 := PLexToken(fLexToks[i-1]);
    //
    if  ((tok1^.kind = ltkKeyword) and (tok1^.data = 'version')
      and (tok2^.kind = ltkSymbol) and (tok2^.data = '(')) then
    begin
      BeginUndoBlock;
      LogicalCaretXY := tok^.position;
      CaretX:=CaretX+1;
      case tok^.Data of
        'all':
        begin
          for c in 'all'  do ExecuteCommand(ecDeleteChar, '', nil);
          for c in 'none' do ExecuteCommand(ecChar, c, nil);
        end;
        'none':
        begin
          for c in 'none' do ExecuteCommand(ecDeleteChar, '', nil);
          for c in 'all'  do ExecuteCommand(ecChar, c, nil);
        end;
      end;
      EndUndoBlock;
    end;
  end;
  CaretXY := cp;
end;

procedure TCESynMemo.renameIdentifier;
var
  locs: TIntOpenArray = nil;
  old, idt, line: string;
  i, j, loc: integer;
  c: char;
begin
  if not DcdWrapper.available then
    exit;
  line := lineText;
  if (CaretX = 1) or not (line[LogicalCaretXY.X] in IdentChars) or
    not (line[LogicalCaretXY.X-1] in IdentChars)  then exit;
  old := GetWordAtRowCol(LogicalCaretXY);
  DcdWrapper.getLocalSymbolUsageFromCursor(locs);
  if length(locs) = 0 then
  begin
    dlgOkInfo('Unknown, ambiguous or non-local symbol for "'+ old +'"');
    exit;
  end;
  //
  idt := 'new identifier for "' + old + '"';
  idt := InputBox('Local identifier renaming', idt, old);
  if idt.isEmpty or idt.isBlank then
    exit;
  //
  for i:= high(locs) downto 0 do
  begin
    loc := locs[i];
    if loc = -1 then
      continue;
    BeginUndoBlock;
    SelStart := loc + 1;
    for j in [0..old.length-1] do
      ExecuteCommand(ecDeleteChar, '', nil);
    for c in idt do
      ExecuteCommand(ecChar, c, nil);
    EndUndoBlock;
  end;
end;

procedure TCESynMemo.ShowPhobosDoc;
  procedure errorMessage;
  begin
    dlgOkError('html documentation cannot be found for "' + Identifier + '"');
  end;
var
  str: string;
  pth: string;
  idt: string;
  pos: integer;
  len: integer;
  sum: integer;
  edt: TSynEdit;
  rng: TStringRange = (ptr:nil; pos:0; len: 0);
  i: integer;
  linelen: integer;
begin
  DcdWrapper.getDeclFromCursor(str, pos);
  if not str.fileExists then
  begin
    errorMessage;
    exit;
  end;
  // verify that the decl is in phobos
  pth := str;
  while true do
  begin
    if pth.extractFilePath = pth then
    begin
      errorMessage;
      exit;
    end;
    pth := pth.extractFilePath;
    setLength(pth,pth.length-1);
    if (pth.extractFilename = 'phobos') or (pth.extractFilename = 'core')
      or (pth.extractFilename = 'etc') then
        break;
  end;
  // get the declaration name
  if pos <> -1 then
  begin
    edt := TSynEdit.Create(nil);
    edt.Lines.LoadFromFile(str);
    sum := 0;
    len := getLineEndingLength(str);
    for i := 0 to edt.Lines.Count-1 do
    begin
      linelen := edt.Lines[i].length;
      if sum + linelen + len > pos then
      begin
        edt.CaretY := i + 1;
        edt.CaretX := pos - sum + len;
        edt.SelectWord;
        idt := '.html#.' + edt.SelText;
        break;
      end;
      sum += linelen;
      sum += len;
    end;
    edt.Free;
  end;
  // guess the htm file + anchor
  rng.init(str);
  while true do
  begin
    if rng.empty then
      exit;
    rng.popUntil(DirectorySeparator);
    if not rng.empty then
      rng.popFront;
    if rng.startsWith('std' + DirectorySeparator) or rng.startsWith('core' + DirectorySeparator)
      or rng.startsWith('etc' + DirectorySeparator) then
        break;
  end;
  if fPhobosDocRoot.dirExists then
    pth := 'file://' + fPhobosDocRoot
  else
    pth := fPhobosDocRoot;
  while not rng.empty do
  begin
    pth += rng.takeUntil([DirectorySeparator, '.']).yield;
    if rng.startsWith('.d') then
      break;
    pth += '_';
    rng.popFront;
  end;
  pth += idt;
  {$IFDEF WINDOWS}
  if fPhobosDocRoot.dirExists then
    for i:= 1 to pth.length do
      if pth[i] = '\' then
        pth[i] := '/';
  {$ENDIF}
  OpenURL(pth);
end;

procedure TCESynMemo.nextChangedArea;
begin
  gotoToChangedArea(true);
end;

procedure TCESynMemo.previousChangedArea;
begin
  gotoToChangedArea(false);
end;

procedure TCESynMemo.gotoToChangedArea(next: boolean);
var
  i: integer;
  s: TSynLineState;
  d: integer;
  b: integer = 0;
  p: TPoint;
begin
  i := CaretY - 1;
  s := GetLineState(i);
  case next of
    true: begin d := 1; b := lines.count-1; end;
    false:d := -1;
  end;
  if i = b then
    exit;
  // exit the current area if it's modified
  while s <> slsNone do
  begin
    s := GetLineState(i);
    if i = b then
      exit;
    i += d;
  end;
  // find next modified area
  while s = slsNone do
  begin
    s := GetLineState(i);
    if i = b then
      break;
    i += d;
  end;
  // goto area beg/end
  if (s <> slsNone) and (i <> CaretY + 1) then
  begin
    p.X:= 1;
    p.Y:= i + 1 - d;
    ExecuteCommand(ecGotoXY, #0, @p);
  end;
end;

function TCESynMemo.implementMain: THasMain;
var
  res: char = '0';
  prc: TProcess;
  src: string;
begin
  if fDastWorxExename.length = 0 then
    exit(mainDefaultBehavior);
  src := Lines.Text;
  prc := TProcess.Create(nil);
  try
    prc.Executable:= fDastWorxExename;
    prc.Parameters.Add('-m');
    prc.Options := [poUsePipes{$IFDEF WINDOWS}, poNewConsole{$ENDIF}];
    prc.ShowWindow := swoHIDE;
    prc.Execute;
    prc.Input.Write(src[1], src.length);
    prc.CloseInput;
    while prc.Running do
      sleep(1);
    prc.Output.Read(res, 1);
  finally
    prc.Free;
  end;
  case res = '1' of
    false:result := mainNo;
    true: result := mainYes;
  end;
end;

procedure TCESynMemo.autoClosePair(value: TAutoClosedPair);
var
  i, p: integer;
  tk0, tk1: PLexToken;
  str: string;
begin
  if value in [autoCloseBackTick, autoCloseDoubleQuote] then
  begin
    p := selStart;
    lex(Lines.Text, fLexToks);
    for i:=0 to fLexToks.Count-2 do
    begin
      tk0 := fLexToks[i];
      tk1 := fLexToks[i+1];
      if (tk0^.offset+1 <= p) and (p < tk1^.offset+2) and
        (tk0^.kind in [ltkString, ltkComment]) then exit;
    end;
    tk0 := fLexToks[fLexToks.Count-1];
    if (tk0^.offset+1 <= p) and (tk0^.kind <> ltkIllegal) then
      exit;
  end
  else if value = autoCloseSingleQuote then
  begin
    p := selStart;
    lex(Lines.Text, fLexToks);
    for i:=0 to fLexToks.Count-2 do
    begin
      tk0 := fLexToks[i];
      tk1 := fLexToks[i+1];
      if (tk0^.offset+1 <= p) and (p < tk1^.offset+2) and
        (tk0^.kind in [ltkChar, ltkComment]) then exit;
    end;
    tk0 := fLexToks[fLexToks.Count-1];
    if (tk0^.offset+1 <= p) and (tk0^.kind <> ltkIllegal) then
      exit;
  end
  else if value = autoCloseSquareBracket then
  begin
    p := selStart;
    lex(Lines.Text, fLexToks);
    for i:=0 to fLexToks.Count-2 do
    begin
      tk0 := fLexToks[i];
      tk1 := fLexToks[i+1];
      if (tk0^.offset+1 <= p) and (p < tk1^.offset+2) and
        (tk0^.kind = ltkComment) then exit;
    end;
    tk0 := fLexToks[fLexToks.Count-1];
    if (tk0^.offset+1 <= p) and (tk0^.kind <> ltkIllegal) then
      exit;
    str := lineText;
    i := LogicalCaretXY.X;
    if (i <= str.length) and (lineText[i] = ']') then
      exit;
  end;
  BeginUndoBlock;
  ExecuteCommand(ecChar, autoClosePair2Char[value], nil);
  ExecuteCommand(ecLeft, #0, nil);
  EndUndoBlock;
end;

procedure TCESynMemo.setSelectionOrWordCase(upper: boolean);
var
  i: integer;
  txt: string;
begin
  if SelAvail then
  begin
    BeginUndoBlock;
    case upper of
      false: txt := UTF8LowerString(SelText);
      true:  txt := UTF8UpperString(SelText);
    end;
    ExecuteCommand(ecBlockDelete, #0, nil);
    for i:= 1 to txt.length do
    case txt[i] of
      #13: continue;
      #10: ExecuteCommand(ecLineBreak, #0, nil);
      else ExecuteCommand(ecChar, txt[i], nil);
    end;
    EndUndoBlock;
  end else
  begin
    txt := GetWordAtRowCol(LogicalCaretXY);
    if txt.isBlank then
      exit;
    BeginUndoBlock;
    ExecuteCommand(ecWordLeft, #0, nil);
    case upper of
      false: txt := UTF8LowerString(txt);
      true:  txt := UTF8UpperString(txt);
    end;
    ExecuteCommand(ecDeleteWord, #0, nil);
    for i:= 1 to txt.length do
      ExecuteCommand(ecChar, txt[i], nil);
    EndUndoBlock;
  end;
end;

procedure TCESynMemo.sortSelectedLines(descending, caseSensitive: boolean);
var
  i,j: integer;
  lne: string;
  lst: TStringListUTF8;
  pt0: TPoint;
begin
  if BlockEnd.Y - BlockBegin.Y < 1 then
    exit;
  lst := TStringListUTF8.Create;
  try
    BeginUndoBlock;
    for i:= BlockBegin.Y-1 to BlockEnd.Y-1 do
      lst.Add(lines[i]);
    pt0 := BlockBegin;
    pt0.X:=1;
    ExecuteCommand(ecGotoXY, #0, @pt0);
    lst.CaseSensitive:=caseSensitive;
    if not caseSensitive then
      lst.Sorted:=true;
    case descending of
      false: for i:= 0 to lst.Count-1 do
        begin
          ExecuteCommand(ecDeleteLine, #0, nil);
          ExecuteCommand(ecInsertLine, #0, nil);
          lne := lst[i];
          for j := 1 to lne.length do
            ExecuteCommand(ecChar, lne[j], nil);
          ExecuteCommand(ecDown, #0, nil);
        end;
      true: for i:= lst.Count-1 downto 0 do
        begin
          ExecuteCommand(ecDeleteLine, #0, nil);
          ExecuteCommand(ecInsertLine, #0, nil);
          lne := lst[i];
          for j := 1 to lne.length do
            ExecuteCommand(ecChar, lne[j], nil);
          ExecuteCommand(ecDown, #0, nil);
        end;
    end;
    EndUndoBlock;
  finally
    lst.Free;
  end;
end;

procedure TCESynMemo.sortLines;
begin
  if not assigned(fSortDialog) then
    fSortDialog := TSortDialog.construct(self);
  fSortDialog.Show;
end;
{$ENDREGION}

{$REGION DDoc & CallTip --------------------------------------------------------}
procedure TCESynMemo.InitHintWins;
begin
  if fCallTipWin.isNil then
  begin
    fCallTipWin := TCEEditorHintWindow.Create(self);
    fCallTipWin.Color := clInfoBk + $01010100;
    fCallTipWin.Font.Color:= clInfoText;
  end;
  if fDDocWin.isNil then
  begin
    fDDocWin := TCEEditorHintWindow.Create(self);
    fDDocWin.Color := clInfoBk + $01010100;
    fDDocWin.Font.Color:= clInfoText;
  end;
end;

procedure TCESynMemo.showCallTips(findOpenParen: boolean = true);
var
  str: string;
  i, x: integer;
begin
  if not fIsDSource and not alwaysAdvancedFeatures then
    exit;
  if not fCallTipWin.Visible then
    fCallTipStrings.Clear;
  str := LineText[1..CaretX];
  x := CaretX;
  i := x;
  if findOpenParen then while true do
  begin
    if i = 1 then
      break;
    if str[i-1] = '(' then
    begin
      LogicalCaretXY := Point(i, CaretY);
      break;
    end;
    if str[i] = #9 then
      i -= TabWidth
    else
      i -= 1;
  end;
  DcdWrapper.getCallTip(str);
  if str.isNotEmpty then
  begin
    i := fCallTipStrings.Count;
    if fCallTipStrings.Count <> 0 then
      fCallTipStrings.Insert(0, '---');
    fCallTipStrings.Insert(0, str);
    i := fCallTipStrings.Count - i;
    // overload count to delete on ')'
    {$PUSH}{$HINTS OFF}{$WARNINGS OFF}
    fCallTipStrings.Objects[0] := TObject(pointer(i));
    {$POP}
    str := fCallTipStrings.Text;
    {$IFDEF WINDOWS}
    str := str[1..str.length-2];
    {$ELSE}
    str := str[1..str.length-1];
    {$ENDIF}
    showCallTips(str);
  end;
  if findOpenParen then
    CaretX:=x;
end;

procedure TCESynMemo.showCallTips(const tips: string);
var
  pnt: TPoint;
begin
  if not fIsDSource and not alwaysAdvancedFeatures then
    exit;
  if tips.isEmpty then exit;
  //
  pnt := ClientToScreen(point(CaretXPix, CaretYPix));
  fCallTipWin.FontSize := Font.Size;
  fCallTipWin.HintRect := fCallTipWin.CalcHintRect(0, tips, nil);
  fCallTipWin.OffsetHintRect(pnt, Font.Size * 2);
  fCallTipWin.ActivateHint(tips);
end;

procedure TCESynMemo.hideCallTips;
begin
  fCallTipStrings.Clear;
  fCallTipWin.Hide;
end;

procedure TCESynMemo.decCallTipsLvl;
var
  i: integer;
begin
  {$PUSH}{$HINTS OFF}{$WARNINGS OFF}
  i := integer(pointer(fCallTipStrings.Objects[0]));
  {$POP}
  for i in [0..i-1] do
    fCallTipStrings.Delete(0);
  if fCallTipStrings.Count = 0 then
    hideCallTips
  else
    showCallTips(fCallTipStrings.Text);
end;

procedure TCESynMemo.showDDocs;
var
  str: string;
begin
  fCanShowHint := false;
  if not fIsDSource and not alwaysAdvancedFeatures then
    exit;
  DcdWrapper.getDdocFromCursor(str);
  //
  if str.isNotEmpty then
  begin
    fDDocWin.FontSize := Font.Size;
    fDDocWin.HintRect := fDDocWin.CalcHintRect(0, str, nil);
    fDDocWin.OffsetHintRect(mouse.CursorPos, Font.Size);
    fDDocWin.ActivateHint(fDDocWin.HintRect, str);
  end;
end;

procedure TCESynMemo.hideDDocs;
begin
  fCanShowHint := false;
  fDDocWin.Hide;
end;

procedure TCESynMemo.setDDocDelay(value: Integer);
begin
  fDDocDelay:=value;
  fDDocTimer.Interval:=fDDocDelay;
end;

procedure TCESynMemo.DDocTimerEvent(sender: TObject);
begin
  if not Visible then exit;
  if not isDSource then exit;
  //
  if not fCanShowHint then exit;
  showDDocs;
end;
{$ENDREGION --------------------------------------------------------------------}

{$REGION Completion ------------------------------------------------------------}
procedure TCESynMemo.completionExecute(sender: TObject);
begin
  if not fIsDSource and not alwaysAdvancedFeatures then
    exit;
  fCompletion.TheForm.Font.Size := Font.Size;
  fCompletion.TheForm.BackgroundColor:= self.Color;
  fCompletion.TheForm.TextColor:= fD2Highlighter.identifiers.Foreground;
  getCompletionList;
end;

procedure TCESynMemo.getCompletionList;
begin
  if not DcdWrapper.available then exit;
  //
  fCompletion.Position := 0;
  fCompletion.ItemList.Clear;
  DcdWrapper.getComplAtCursor(fCompletion.ItemList);
end;

procedure TCESynMemo.completionCodeCompletion(var value: string;
  SourceValue: string; var SourceStart, SourceEnd: TPoint; KeyChar: TUTF8Char;
  Shift: TShiftState);
begin
  // warning: '20' depends on ce_dcd, case knd of, string literals length
  value := value[1..value.length-20];
end;

function TCESynMemo.completionItemPaint(const AKey: string; ACanvas: TCanvas;X, Y: integer;
  Selected: boolean; Index: integer): boolean;
var
  lft, rgt: string;
  len: Integer;
begin
  // empty items can be produced if completion list is too long
  if aKey.isEmpty then exit(true);
  // otherwise always at least 20 chars but...
  // ... '20' depends on ce_dcd, case knd of, string literals length
  result := true;
  lft := AKey[1 .. AKey.length-20];
  rgt := AKey[AKey.length-19 .. AKey.length];
  ACanvas.Font.Style := [fsBold];
  len := ACanvas.TextExtent(lft).cx;
  ACanvas.TextOut(2 + X , Y, lft);
  ACanvas.Font.Style := [fsItalic];
  ACanvas.TextOut(2 + X + len + 2, Y, rgt);
end;

procedure TCESynMemo.AutoDotTimerEvent(sender: TObject);
begin
  if not fCanAutoDot then exit;
  if fAutoDotDelay = 0 then exit;
  fCanAutoDot := false;
  fCompletion.Execute('', ClientToScreen(point(CaretXPix, CaretYPix + LineHeight)));
end;

procedure TCESynMemo.setAutoDotDelay(value: Integer);
begin
  fAutoDotDelay:=value;
  fAutoDotTimer.Interval:=fAutoDotDelay;
end;
{$ENDREGION --------------------------------------------------------------------}

{$REGION Coedit memo things ----------------------------------------------------}
procedure TCESynMemo.handleStatusChanged(Sender: TObject; Changes: TSynStatusChanges);
begin
  if scOptions in Changes then
  begin
    if Beautifier.isNotNil and (Beautifier is TSynBeautifier) then
    begin
      if not (eoTabsToSpaces in Options) and not (eoSpacesToTabs in Options) then
        TSynBEautifier(Beautifier).IndentType := sbitConvertToTabOnly
      else if eoSpacesToTabs in options then
        TSynBEautifier(Beautifier).IndentType := sbitConvertToTabOnly
      else
        TSynBEautifier(Beautifier).IndentType := sbitSpace;
    end
  end;
end;

function TCESynMemo.lexCanCloseBrace: boolean;
var
  i: integer;
  p: integer;
  c: integer = 0;
  tok: PLexToken;
  ton: PLexToken;
  bet: boolean;
begin
  p := SelStart;
  for i := 0 to fLexToks.Count-1 do
  begin
    tok := fLexToks[i];
    if (i <> fLexToks.Count-1) then
    begin
      ton := fLexToks[i+1];
      bet := (tok^.offset + 1 <= p) and (p < ton^.offset + 2);
    end else
      bet := false;
    if bet and (tok^.kind = ltkComment) then
      exit(false);
    c += byte((tok^.kind = TLexTokenKind.ltkSymbol) and (((tok^.Data = '{')) or (tok^.Data = 'q{')));
    c -= byte((tok^.kind = TLexTokenKind.ltkSymbol) and (tok^.Data = '}'));
    if bet and (c = 0) then
      exit(false);
  end;
  if (tok <> nil) and (tok^.kind = ltkIllegal) then
    result := false
  else
    result := c > 0;
end;

procedure TCESynMemo.SetHighlighter(const Value: TSynCustomHighlighter);
begin
  inherited;
  fIsDSource := Highlighter = fD2Highlighter;
  fIsTxtFile := Highlighter = fTxtHighlighter;
end;

procedure TCESynMemo.highlightCurrentIdentifier;
var
  str: string;
  i: integer;
begin
  fIdentifier := GetWordAtRowCol(LogicalCaretXY);
  if (fIdentifier.length > 2) and (not SelAvail) then
    SetHighlightSearch(fIdentifier, fMatchIdentOpts)
  else if SelAvail and (BlockBegin.Y = BlockEnd.Y) then
  begin
    str := SelText;
    for i := 1 to str.length do
    begin
      if not (str[i] in [' ', #10, #13]) then
      begin
        SetHighlightSearch(str, fMatchSelectionOpts);
        break;
      end;
      if i = str.length then
        SetHighlightSearch('', []);
    end;
  end
  else SetHighlightSearch('', []);
end;

procedure TCESynMemo.setMatchOpts(value: TIdentifierMatchOptions);
begin
  fMatchOpts:= value;
  fMatchIdentOpts := TSynSearchOptions(fMatchOpts);
  fMatchSelectionOpts:= TSynSearchOptions(fMatchOpts - [wholeWord]);
end;

procedure TCESynMemo.changeNotify(Sender: TObject);
begin
  highlightCurrentIdentifier;
  fModified := true;
  fPositions.store;
  subjDocChanged(TCEMultiDocSubject(fMultiDocSubject), self);
end;

procedure TCESynMemo.loadFromFile(const fname: string);
var
  ext: string;
begin
  ext := fname.extractFileExt;
  fIsDsource := hasDlangSyntax(ext);
  if not fIsDsource then
    Highlighter := TxtSyn;
  Lines.LoadFromFile(fname);
  fFilename := fname;
  FileAge(fFilename, fFileDate);
  ReadOnly := FileIsReadOnly(fFilename);
  //
  fModified := false;
  if Showing then
  begin
    setFocus;
    loadCache;
    fCacheLoaded := true;
  end;
  if detectIndentMode then
  begin
    case indentationMode(lines) of
      imTabs: Options:= Options - [eoTabsToSpaces];
      imSpaces: Options:= Options + [eoTabsToSpaces];
    end;
  end;
  subjDocChanged(TCEMultiDocSubject(fMultiDocSubject), self);
end;

procedure TCESynMemo.saveToFile(const fname: string);
var
  ext: string;
begin
  ext := fname.extractFilePath;
  if FileIsReadOnly(ext) then
  begin
    getMessageDisplay.message('No write access in: ' + ext, self, amcEdit, amkWarn);
    exit;
  end;
  ReadOnly := false;
  Lines.SaveToFile(fname);
  fFilename := fname;
  ext := fname.extractFileExt;
  fIsDsource := hasDlangSyntax(ext);
  if fIsDsource then
    Highlighter := fD2Highlighter
  else if not isProjectDescription then
    Highlighter := TxtHighlighter;
  FileAge(fFilename, fFileDate);
  fModified := false;
  if fFilename <> fTempFileName then
  begin
    if fTempFileName.fileExists then
      sysutils.DeleteFile(fTempFileName);
    subjDocChanged(TCEMultiDocSubject(fMultiDocSubject), self);
  end;
end;

procedure TCESynMemo.save;
begin
  if readOnly then
    exit;
  Lines.SaveToFile(fFilename);
  FileAge(fFilename, fFileDate);
  fModified := false;
  if fFilename <> fTempFileName then
    subjDocChanged(TCEMultiDocSubject(fMultiDocSubject), self);
end;

procedure TCESynMemo.saveTempFile;
begin
  saveToFile(fTempFileName);
  fModified := false;
end;

function TCESynMemo.getIfTemp: boolean;
begin
  exit(fFilename = fTempFileName);
end;

procedure TCESynMemo.saveCache;
var
  cache: TCESynMemoCache;
begin
  cache := TCESynMemoCache.create(self);
  try
    cache.save;
  finally
    cache.free;
  end;
end;

procedure TCESynMemo.loadCache;
var
  cache: TCESynMemoCache;
begin
  cache := TCESynMemoCache.create(self);
  try
    cache.load;
  finally
    cache.free;
  end;
end;

class procedure TCESynMemo.cleanCache;
var
  lst: TStringList;
  today, t: TDateTime;
  fname: string;
  y, m, d: word;
begin
  lst := TStringList.Create;
  try
    listFiles(lst, getCoeditDocPath + 'editorcache' + DirectorySeparator);
    today := date();
    for fname in lst do if FileAge(fname, t) then
    begin
      DecodeDate(t, y, m, d);
      IncAMonth(y, m, d, 3);
      if EncodeDate(y, m, d) <= today then
        sysutils.DeleteFile(fname);
    end;
  finally
    lst.free;
  end;
end;

procedure TCESynMemo.checkFileDate;
var
  newDate: double;
  str: TStringList;
begin
  if fFilename = fTempFileName then exit;
  if fDisableFileDateCheck then exit;
  if not FileAge(fFilename, newDate) then exit;
  if fFileDate = newDate then exit;
  if fFileDate <> 0.0 then
  begin
    // note: this could cause a bug during the DST switch.
    // e.g: save at 2h59, 3h00 reset to 2h00, set the focus on the doc: new version message.
    if dlgYesNo(format('"%s" has been modified by another program, load the new version ?',
      [shortenPath(fFilename, 25)])) = mrYes then
    begin
      str := TStringList.Create;
      try
        str.LoadFromFile(fFilename);
        ClearAll;
        InsertTextAtCaret(str.Text);
        SelStart:= high(integer);
        ExecuteCommand(ecDeleteLastChar, #0, nil);
        fModified := true;
      finally
        str.Free;
      end;
    end;
  end;
  fFileDate := newDate;
end;

function TCESynMemo.getMouseBytePosition: Integer;
var
  i, len, llen: Integer;
begin
  result := 0;
  if fMousePos.y-1 > Lines.Count-1 then exit;
  llen := Lines[fMousePos.y-1].length;
  if fMousePos.X > llen  then exit;
  len := getSysLineEndLen;
  for i:= 0 to fMousePos.y-2 do
    result += Lines[i].length + len;
  result += fMousePos.x;
end;
{$ENDREGION --------------------------------------------------------------------}

{$REGION user input ------------------------------------------------------------}
procedure TCESynMemo.KeyDown(var Key: Word; Shift: TShiftState);
var
  line: string;
begin
  case Key of
    VK_BACK: if fCallTipWin.Visible and (CaretX > 1)
      and (LineText[LogicalCaretXY.X-1] = '(') then
        decCallTipsLvl;
    VK_RETURN:
    begin
      line := LineText;
      if (fAutoCloseCurlyBrace in [autoCloseOnNewLineEof .. autoCloseOnNewLineLexically]) then
      case fAutoCloseCurlyBrace of
        autoCloseOnNewLineAlways: if (CaretX > 1) and (line[LogicalCaretXY.X - 1] = '{') then
        begin
          Key := 0;
          curlyBraceCloseAndIndent;
        end;
        autoCloseOnNewLineEof: if (CaretX > 1) and (line[LogicalCaretXY.X - 1] = '{') then
          if (CaretY = Lines.Count) and (CaretX = line.length+1) then
          begin
            Key := 0;
            curlyBraceCloseAndIndent;
          end;
        autoCloseOnNewLineLexically: if (LogicalCaretXY.X - 1 >= line.length)
            or isBlank(line[LogicalCaretXY.X .. line.length]) then
        begin
          fLexToks.Clear;
          lex(lines.Text, fLexToks);
          if lexCanCloseBrace then
          begin
            Key := 0;
            curlyBraceCloseAndIndent;
          end;
        end;
      end;
    end;
  end;
  inherited;
  highlightCurrentIdentifier;
  if fCompletion.IsActive then
      fCompletion.CurrentString:= GetWordAtRowCol(LogicalCaretXY);
  case Key of
    VK_BROWSER_BACK: fPositions.back;
    VK_BROWSER_FORWARD: fPositions.next;
    VK_ESCAPE:
      begin
        hideCallTips;
        hideDDocs;
      end;
  end;
  if not (Shift = [ssCtrl]) then exit;
  case Key of
    VK_ADD: if Font.Size < 50 then Font.Size := Font.Size + 1;
    VK_SUBTRACT: if Font.Size > 3 then Font.Size := Font.Size - 1;
    VK_DECIMAL: Font.Size := fDefaultFontSize;
  end;
  fCanShowHint:=false;
  fDDocWin.Hide;
end;

procedure TCESynMemo.KeyUp(var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_PRIOR, VK_NEXT, VK_UP: fPositions.store;
    VK_OEM_PERIOD, VK_DECIMAL: fCanAutoDot := true;
  end;
  inherited;
  //
  if StaticEditorMacro.automatic then
    StaticEditorMacro.Execute;
end;

procedure TCESynMemo.UTF8KeyPress(var Key: TUTF8Char);
var
  c: TUTF8Char;
begin
  c := Key;
  inherited;
  case c of
    #39: if autoCloseSingleQuote in fAutoClosedPairs then
      autoClosePair(autoCloseSingleQuote);
    '"': if autoCloseDoubleQuote in fAutoClosedPairs then
      autoClosePair(autoCloseDoubleQuote);
    '`': if autoCloseBackTick in fAutoClosedPairs then
      autoClosePair(autoCloseBackTick);
    '[': if autoCloseSquareBracket in fAutoClosedPairs then
      autoClosePair(autoCloseSquareBracket);
    '(': showCallTips(false);
    ')': if fCallTipWin.Visible then decCallTipsLvl;
    '{':
        case fAutoCloseCurlyBrace of
          autoCloseAlways:
            curlyBraceCloseAndIndent;
          autoCloseAtEof:
            if (CaretY = Lines.Count) and (CaretX = LineText.length+1) then
              curlyBraceCloseAndIndent;
          autoCloseLexically:
          begin
            fLexToks.Clear;
            lex(lines.Text, fLexToks);
            if lexCanCloseBrace then
              curlyBraceCloseAndIndent;
          end;
        end;
  end;
  if fCompletion.IsActive then
    fCompletion.CurrentString:=GetWordAtRowCol(LogicalCaretXY);
end;

procedure TCESynMemo.MouseLeave;
begin
  inherited;
  hideDDocs;
  hideCallTips;
end;

procedure TCESynMemo.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  dx, dy: Integer;
begin
  hideDDocs;
  hideCallTips;
  inherited;
  dx := X - fOldMousePos.x;
  dy := Y - fOldMousePos.y;
  fCanShowHint:=false;
  if (shift = []) then if
    ((dx < 0) and (dx > -5) or (dx > 0) and (dx < 5)) or
      ((dy < 0) and (dy > -5) or (dy > 0) and (dy < 5)) then
        fCanShowHint:=true;
  fOldMousePos := Point(X, Y);
  fMousePos := PixelsToRowColumn(fOldMousePos);
  if ssLeft in Shift then
    highlightCurrentIdentifier;
end;

procedure TCESynMemo.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y:Integer);
begin
  inherited;
  highlightCurrentIdentifier;
  fCanShowHint := false;
  hideCallTips;
  hideDDocs;
  if (emAltSetsColumnMode in MouseOptions) and not (eoScrollPastEol in Options)
    and (ssLeft in shift) and (ssAlt in Shift) then
  begin
    fOverrideColMode := true;
    Options := Options + [eoScrollPastEol];
  end;
end;

procedure TCESynMemo.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y:Integer);
begin
  inherited;
  case Button of
    mbMiddle: if (Shift = [ssCtrl]) then
      Font.Size := fDefaultFontSize;
    mbExtra1: fPositions.back;
    mbExtra2: fPositions.next;
    mbLeft:   fPositions.store;
  end;
  if fOverrideColMode and not SelAvail then
  begin
    fOverrideColMode := false;
    Options := Options - [eoScrollPastEol];
  end;
end;

function TCESynMemo.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  result := inherited DoMouseWheel(Shift, WheelDelta, MousePos);
  fCanShowHint:=false;
  fDDocTimer.Enabled:=false;
end;
{$ENDREGION --------------------------------------------------------------------}

{$REGION breakpoints -----------------------------------------------------------}
function TCESynMemo.breakPointsCount: integer;
begin
  exit(fBreakPoints.Count);
end;

function TCESynMemo.BreakPointLine(index: integer): integer;
begin
  if index >= fBreakPoints.Count then
    exit(0);
  {$PUSH}{$WARNINGS OFF}{$HINTS OFF}
  exit(Integer(fBreakPoints.Items[index]));
  {$POP}
end;

procedure TCESynMemo.addBreakPoint(line: integer);
var
  m: TSynEditMark;
begin
  if findBreakPoint(line) then
    exit;
  m:= TSynEditMark.Create(self);
  m.Line := line;
  m.ImageList := fImages;
  m.ImageIndex := 0;
  m.Visible := true;
  Marks.Add(m);
  {$PUSH}{$WARNINGS OFF}{$HINTS OFF}
  fBreakPoints.Add(pointer(line));
  {$POP}
  if assigned(fBreakpointEvent) then
    fBreakpointEvent(self, line, bpAdded);
end;

procedure TCESynMemo.removeBreakPoint(line: integer);
begin
  if not findBreakPoint(line) then
    exit;
  if marks.Line[line].isNotNil and (marks.Line[line].Count > 0) then
    marks.Line[line].Clear(true);
  {$PUSH}{$WARNINGS OFF}{$HINTS OFF}
  fBreakPoints.Remove(pointer(line));
  {$POP}
  if assigned(fBreakpointEvent) then
    fBreakpointEvent(self, line, bpRemoved);
end;

function TCESynMemo.findBreakPoint(line: integer): boolean;
begin
  {$PUSH}{$WARNINGS OFF}{$HINTS OFF}
  exit(fBreakPoints.IndexOf(pointer(line)) <> -1);
  {$POP}
end;

procedure TCESynMemo.gutterClick(Sender: TObject; X, Y, Line: integer; mark: TSynEditMark);
begin
  if findBreakPoint(line) then
    removeBreakPoint(line)
  else
    addBreakPoint(line);
end;
{$ENDREGION --------------------------------------------------------------------}

{$ENDREGION --------------------------------------------------------------------}

initialization
  D2Syn := TSynD2Syn.create(nil);
  LfmSyn := TSynLFMSyn.Create(nil);
  TxtSyn := TSynTxtSyn.create(nil);
  JsSyn := TSynJScriptSyn.Create(nil);
  //
  LfmSyn.KeyAttri.Foreground := clNavy;
  LfmSyn.KeyAttri.Style := [fsBold];
  LfmSyn.NumberAttri.Foreground := clMaroon;
  LfmSyn.StringAttri.Foreground := clBlue;
  LfmSyn.SymbolAttribute.Foreground:= clPurple;
  LfmSyn.SymbolAttribute.Style := [fsBold];
  //
  JsSyn.KeyAttri.Foreground := clNavy;
  JsSyn.KeyAttri.Style := [fsBold];
  JsSyn.NumberAttri.Foreground := clMaroon;
  JsSyn.StringAttri.Foreground := clBlue;
  JsSyn.SymbolAttribute.Foreground:= clPurple;
  JsSyn.SymbolAttribute.Style := [fsBold];
  //
  TCEEditorHintWindow.FontSize := 10;
  //
  RegisterKeyCmdIdentProcs(@CustomStringToCommand, @CustomCommandToSstring);
  RegisterClasses([TCESynMemoCache, TCEFoldCache]);
finalization
  D2Syn.Free;
  LfmSyn.Free;
  TxtSyn.Free;
  JsSyn.Free;
  //
  TCESynMemo.cleanCache;
end.
