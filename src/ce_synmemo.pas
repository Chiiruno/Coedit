unit ce_synmemo;

{$I ce_defines.inc}

interface

uses
  Classes, SysUtils, controls,lcltype, Forms, graphics, ExtCtrls, crc,
  SynEdit, SynPluginSyncroEdit, SynCompletion, SynEditKeyCmds, LazSynEditText,
  SynHighlighterLFM, SynEditHighlighter, SynEditMouseCmds, SynEditFoldedView,
  SynEditMarks, SynEditTypes, SynHighlighterJScript,
  ce_common, ce_observer, ce_writableComponent, ce_d2syn, ce_txtsyn, ce_dialogs,
  ce_sharedres, ce_dlang;

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
    constructor create(aMemo: TCustomSynEdit);
    destructor destroy; override;
    procedure store;
    procedure back;
    procedure next;
  end;

  TCESynMemo = class(TSynEdit)
  private
    fFilename: string;
    fModified: boolean;
    fFileDate: double;
    fCacheLoaded: boolean;
    fIsDSource: boolean;
    fIsTxtFile: boolean;
    fIsConfig: boolean;
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
    procedure setMatchOpts(value: TIdentifierMatchOptions);
    function getMouseFileBytePos: Integer;
    procedure changeNotify(Sender: TObject);
    procedure highlightCurrentIdentifier;
    procedure saveCache;
    procedure loadCache;
    class procedure cleanCache; static;
    procedure setDefaultFontSize(aValue: Integer);
    procedure getCallTips;
    procedure DDocTimerEvent(sender: TObject);
    procedure AutoDotTimerEvent(sender: TObject);
    procedure InitHintWins;
    function getIfTemp: boolean;
    procedure setDDocDelay(aValue: Integer);
    procedure setAutoDotDelay(aValue: Integer);
    procedure completionExecute(sender: TObject);
    procedure getCompletionList;
    function completionItemPaint(const AKey: string; ACanvas: TCanvas;X, Y: integer;
      Selected: boolean; Index: integer): boolean;
    procedure completionCodeCompletion(var Value: string; SourceValue: string;
      var SourceStart, SourceEnd: TPoint; KeyChar: TUTF8Char; Shift: TShiftState);
    procedure gutterClick(Sender: TObject; X, Y, Line: integer; mark: TSynEditMark);
    procedure addBreakPoint(line: integer);
    procedure removeBreakPoint(line: integer);
    function  findBreakPoint(line: integer): boolean;
    procedure showCallTips(const tips: string);
    function lexCanCloseBrace: boolean;
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
    procedure loadFromFile(const aFilename: string);
    procedure saveToFile(const aFilename: string);
    procedure save;
    procedure saveTempFile;
    //
    procedure invertVersionAllNone;
    procedure showCallTips;
    procedure hideCallTips;
    procedure showDDocs;
    procedure hideDDocs;
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
    property isProjectFile: boolean read fIsConfig; // warning: never set !
    property isTemporary: boolean read getIfTemp;
    property TextView;
    //
    property disableFileDateCheck: boolean read fDisableFileDateCheck write fDisableFileDateCheck;
    property MouseStart: Integer read getMouseFileBytePos;
    property D2Highlighter: TSynD2Syn read fD2Highlighter;
    property TxtHighlighter: TSynTxtSyn read fTxtHighlighter;
    property defaultFontSize: Integer read fDefaultFontSize write setDefaultFontSize;
    property ddocDelay: Integer read fDDocDelay write setDDocDelay;
    property autoDotDelay: Integer read fAutoDotDelay write setAutoDotDelay;
    property autoCloseCurlyBrace: TBraceAutoCloseStyle read fAutoCloseCurlyBrace write fAutoCloseCurlyBrace;
  end;

  procedure SetDefaultCoeditKeystrokes(ed: TSynEdit);

  function CustomStringToCommand(const Ident: string; var Int: Longint): Boolean;
  function CustomCommandToSstring(Int: Longint; var Ident: string): Boolean;

const
  ecCompletionMenu    = ecUserFirst + 1;
  ecJumpToDeclaration = ecUserFirst + 2;
  ecPreviousLocation  = ecUserFirst + 3;
  ecNextLocation      = ecUserFirst + 4;
  ecRecordMacro       = ecUserFirst + 5;
  ecPlayMacro         = ecUserFirst + 6;
  ecShowDdoc          = ecUserFirst + 7;
  ecShowCallTips      = ecUserFirst + 8;
  ecCurlyBraceClose   = ecUserFirst + 9;
  ecCommentSelection  = ecUserFirst + 10;
  ecSwapVersionAllNone = ecUserFirst + 11;

var
  D2Syn: TSynD2Syn;     // used as model to set the options when no editor exists.
  TxtSyn: TSynTxtSyn;   // used as model to set the options when no editor exists.
  LfmSyn: TSynLfmSyn;   // used to highlight the native projects.
  JsSyn: TSynJScriptSyn; // used to highlight the DUB JSON projects.


implementation

uses
  ce_interfaces, ce_staticmacro, ce_dcd, SynEditHighlighterFoldBase, ce_lcldragdrop;

function TCEEditorHintWindow.CalcHintRect(MaxWidth: Integer; const AHint: String; AData: Pointer): TRect;
begin
  Font.Size:= FontSize;
  result := inherited CalcHintRect(MaxWidth, AHint, AData);
end;

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
constructor TCESynMemoPositions.create(aMemo: TCustomSynEdit);
begin
  fList := TFPList.Create;
  fMax  := 40;
  fMemo := aMemo;
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
  AssignPng(fSyncEdit.GutterGlyph, 'link_edit');
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
  fImages.AddLazarusResource('bullet_red');
  fImages.AddLazarusResource('bullet_green');
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
  //
  if fTempFileName.fileExists then
    sysutils.DeleteFile(fTempFileName);
  //
  inherited;
end;

procedure TCESynMemo.setDefaultFontSize(aValue: Integer);
var
  old: Integer;
begin
  old := Font.Size;
  if aValue < 5 then aValue := 5;
  fDefaultFontSize:= aValue;
  if Font.Size = old then
    Font.Size := fDefaultFontSize;
end;

procedure TCESynMemo.setFocus;
begin
  inherited;
  checkFileDate;
  //
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
    else exit(false);
  end;
end;

procedure curlyBraceCloseAndIndent(editor: TSynEdit);
var
  beg: string;
  i: integer = 1;
  j: integer;
const
  blk = [' ', #9];
begin
  beg := editor.LineText;
  if beg.isEmpty then exit;
  beg := beg[1..editor.CaretX];
  if beg.isEmpty then exit;
  while true do
  begin
    if (i > beg.length) or not (beg[i] in blk) then
      break;
    i += 1;
  end;
  i -= 1;
  editor.BeginUndoBlock;
  editor.CommandProcessor(ecInsertLine, '', nil);
  editor.CommandProcessor(ecDown, '', nil);
  editor.CommandProcessor(ecInsertLine, '', nil);
  editor.CommandProcessor(ecDown, '', nil);
  while editor.CaretX <> 1 do editor.CommandProcessor(ecLeft, '' , nil);
  for j := 1 to i do
  begin
    if beg[j] = #9 then
      editor.CommandProcessor(ecTab, '', nil)
    else
      editor.CommandProcessor(ecChar, beg[j], nil);
  end;
  editor.CommandProcessor(ecChar, '}', nil);
  editor.CommandProcessor(ecUp, '', nil);
  for j := 1 to i do
  begin
    if beg[j] = #9 then
      editor.CommandProcessor(ecTab, '', nil)
    else
      editor.CommandProcessor(ecChar, beg[j], nil);
  end;
  editor.CommandProcessor(ecTab, '', nil);
  while editor.LogicalCaretXY.X > 1 + i + editor.TabWidth do editor.CommandProcessor(ecLeft, '' , nil);
  editor.EndUndoBlock;
end;

procedure commentSelection(editor: TSynEdit);
  procedure commentHere;
  begin
    editor.ExecuteCommand(ecChar, '/', nil);
    editor.ExecuteCommand(ecChar, '/', nil);
  end;
  procedure unCommentHere;
  begin
    editor.ExecuteCommand(ecLineTextStart, '', nil);
    editor.ExecuteCommand(ecDeleteChar, '', nil);
    editor.ExecuteCommand(ecDeleteChar, '', nil);
  end;
var
  i, j, dx, lx, numUndo: integer;
  line: string;
  undo: boolean = false;
  pt, cp: TPoint;
begin
  if not editor.SelAvail then
  begin
    i := editor.CaretX;
    line := TrimLeft(editor.LineText);
    undo := (line.length > 1) and (line[1..2] = '//');
    editor.BeginUndoBlock;
    editor.ExecuteCommand(ecLineTextStart, '', nil);
    if not undo then
    begin
      commentHere;
      editor.CaretX:= i+2;
    end
    else
    begin
      unCommentHere;
      editor.CaretX:= i-2;
    end;
    editor.EndUndoBlock;
  end else
  begin
    undo := false;
    pt.X:= high(pt.X);
    cp := editor.CaretXY;
    numUndo := 0;
    for i := editor.BlockBegin.Y-1 to editor.BlockEnd.Y-1 do
    begin
      line := TrimLeft(editor.Lines[i]);
      dx := editor.Lines[i].length - line.length;
      lx := 0;
      for j := 1 to dx do
        if editor.Lines[i][j] = #9 then
          lx += editor.TabWidth
        else
          lx += 1;
      if lx + 1 < pt.X then
        pt.X:= lx + 1;
      if (line.length > 1) and (line[1..2] = '//') then
        numUndo += 1;
    end;
    if numUndo = 0 then
      undo := false
    else if numUndo = editor.BlockEnd.Y + 1 - editor.BlockBegin.Y then
      undo := true;
    editor.BeginUndoBlock;
    for i := editor.BlockBegin.Y to editor.BlockEnd.Y do
    begin
      pt.Y:= i;
      editor.ExecuteCommand(ecGotoXY, '', @pt);
      if not undo then
      begin
        commentHere;
      end
      else
        unCommentHere;
    end;
    if not undo then
      cp.X += 2
    else
      cp.X -= 2;
    editor.CaretXY := cp;
    editor.EndUndoBlock;
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
      showDDocs;
    end;
    ecShowCallTips:
    begin
      hideCallTips;
      hideDDocs;
      showCallTips;
    end;
    ecCurlyBraceClose:
      curlyBraceCloseAndIndent(self);
    ecCommentSelection:
      commentSelection(self);
    ecSwapVersionAllNone:
      invertVersionAllNone;
  end;
  if fOverrideColMode and not SelAvail then
  begin
    fOverrideColMode := false;
    Options := Options - [eoScrollPastEol];
  end;
end;

procedure TCESynMemo.invertVersionAllNone;
var
  i: integer;
  c: char;
  tok, tok1, tok2, tok3: PLexToken;
  pt, cp, st, nd: TPoint;
  sel: boolean;
begin
  fLexToks.Clear;
  lex(lines.Text, fLexToks);
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
    if i = 2 then
      tok1 := nil
    else
      tok1 := PLexToken(fLexToks[i-3]);
    tok2 := PLexToken(fLexToks[i-2]);
    tok3 := PLexToken(fLexToks[i-1]);
    //
    if  ((tok2^.kind = ltkKeyword) and (tok2^.data = 'version')
      and (tok3^.kind = ltkSymbol) and (tok3^.data = '('))
    or ((tok1 <> nil) and (tok1^.kind = ltkKeyword) and (tok1^.data = 'version')
      and (tok3^.kind = ltkComment) and
        (tok2^.kind = ltkSymbol) and (tok2^.data = '(')) then
    begin
      pt := tok^.position;
      pt.X += 1;
      BeginUndoBlock;
      ExecuteCommand(ecGotoXY, '', @pt);
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
{$ENDREGIOn}

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

procedure TCESynMemo.showCallTips;
var
  str: string;
  i: integer;
begin
  if not fCallTipWin.Visible then
    fCallTipStrings.Clear;
  str := LineText[1..CaretX];
  i := CaretX;
  while true do
  begin
    if i = 1 then
      break;
    if str[i-1] = '(' then
    begin
      CaretX := i;
      break;
    end;
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
end;

procedure TCESynMemo.showCallTips(const tips: string);
var
  pnt: TPoint;
begin
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

procedure TCESynMemo.showDDocs;
var
  str: string;
begin
  fCanShowHint := false;
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

procedure TCESynMemo.getCallTips();
begin
  showCallTips;
end;

procedure TCESynMemo.setDDocDelay(aValue: Integer);
begin
  fDDocDelay:=aValue;
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
  fCompletion.TheForm.Font.Size := Font.Size;
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

procedure TCESynMemo.completionCodeCompletion(var Value: string;
  SourceValue: string; var SourceStart, SourceEnd: TPoint; KeyChar: TUTF8Char;
  Shift: TShiftState);
begin
  // warning: '20' depends on ce_dcd, case knd of, string literals length
  Value := Value[1..Value.length-20];
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

procedure TCESynMemo.setAutoDotDelay(aValue: Integer);
begin
  fAutoDotDelay:=aValue;
  fAutoDotTimer.Interval:=fAutoDotDelay;
end;
{$ENDREGION --------------------------------------------------------------------}

{$REGION Coedit memo things ----------------------------------------------------}
function TCESynMemo.lexCanCloseBrace: boolean;
var
  i: integer;
  c: integer = 0;
  tok: PLexToken;
begin
  for i := 0 to fLexToks.Count-1 do
  begin
    tok := fLexToks[i];
    c += byte((tok^.kind = TLexTokenKind.ltkSymbol) and (((tok^.Data = '{')) or (tok^.Data = 'q{')));
    c -= byte((tok^.kind = TLexTokenKind.ltkSymbol) and (tok^.Data = '}'));
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

procedure TCESynMemo.loadFromFile(const aFilename: string);
var
  ext: string;
begin
  ext := aFilename.extractFileExt;
  if not hasDlangSyntax(ext) then
    Highlighter := TxtSyn;
  Lines.LoadFromFile(aFilename);
  fFilename := aFilename;
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
  subjDocChanged(TCEMultiDocSubject(fMultiDocSubject), self);
end;

procedure TCESynMemo.saveToFile(const aFilename: string);
var
  ext: string;
begin
  ext := aFilename.extractFilePath;
  if FileIsReadOnly(ext) then
  begin
    getMessageDisplay.message('No write access in: ' + ext, self, amcEdit, amkWarn);
    exit;
  end;
  ReadOnly := false;
  Lines.SaveToFile(aFilename);
  fFilename := aFilename;
  ext := aFilename.extractFileExt;
  if hasDlangSyntax(ext) then
    Highlighter := fD2Highlighter;
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
        SelectAll;
        SelText:= str.Text;
        SelStart:=0;
        SelEnd:=0;
        fModified := true;
      finally
        str.Free;
      end;
    end;
  end;
  fFileDate := newDate;
end;

function TCESynMemo.getMouseFileBytePos: Integer;
var
  i, len, llen: Integer;
begin
  result := 0;
  if fMousePos.y-1 > Lines.Count-1 then exit;
  llen := Lines[fMousePos.y-1].length;
  if fMousePos.X > llen  then exit;
  //
  // something note really clear:
  // TCEEditorWidget.getSymbolLoc works when using the line ending of the file.
  // TCESynMemo.getMouseFileBytePos works when using the line ending from the system.
  len := getSysLineEndLen;
  for i:= 0 to fMousePos.y-2 do
    result += Lines[i].length + len;
  result += fMousePos.x;
end;
{$ENDREGION --------------------------------------------------------------------}

{$REGION user input ------------------------------------------------------------}
procedure TCESynMemo.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    if (fAutoCloseCurlyBrace in [autoCloseOnNewLineEof .. autoCloseOnNewLineLexically])
    and (CaretX > 1) and (LineText[LogicalCaretXY.X - 1] = '{') then
    case fAutoCloseCurlyBrace of
      autoCloseOnNewLineAlways:
      begin
        Key := 0;
        curlyBraceCloseAndIndent(self);
      end;
      autoCloseOnNewLineEof:
        if (CaretY = Lines.Count) and (CaretX = LineText.length+1) then
        begin
          Key := 0;
          curlyBraceCloseAndIndent(self);
        end;
      autoCloseOnNewLineLexically:
      begin
        fLexToks.Clear;
        lex(lines.Text, fLexToks);
        if lexCanCloseBrace then
        begin
          Key := 0;
          curlyBraceCloseAndIndent(self);
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
  i: integer;
begin
  c := Key;
  inherited;
  case c of
    '(': getCallTips;
    ')': if fCallTipWin.Visible then
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
    '{':
        case fAutoCloseCurlyBrace of
          autoCloseAlways:
            curlyBraceCloseAndIndent(self);
          autoCloseAtEof:
            if (CaretY = Lines.Count) and (CaretX = LineText.length+1) then
              curlyBraceCloseAndIndent(self);
          autoCloseLexically:
          begin
            fLexToks.Clear;
            lex(lines.Text, fLexToks);
            if lexCanCloseBrace then
              curlyBraceCloseAndIndent(self);
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
