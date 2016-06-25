unit ce_controls;

{$I ce_defines.inc}

interface

uses
  Classes, SysUtils, Forms, Controls, ComCtrls, ExtCtrls, buttons, Graphics;

type
  TCEPageControlButton = (pbClose, pbMoveLeft, pbMoveRight, pbAdd, pbSplit);
  TCEPageControlButtons = set of TCEPageControlButton;

const
  CEPageControlDefaultButtons = [pbClose, pbMoveLeft, pbMoveRight, pbAdd, pbSplit];

type

  // Used instead of a TTabSheet since only the caption is interesting
  TCEPage = class(TCustomControl)
  private
    function getIndex: integer;
  protected
    procedure realSetText(const Value: TCaption); override;
  public
    property index: integer read getIndex;
  end;

  TCEPageControlOption = (poPageHistory, poBottomHeader, poFlatButtons);
  TCEPageControlOptions = set of TCEPageControlOption;

const

  defPagesOpt = [poPageHistory];

type

  (**
   * Minimalist page-control dedicated to Coedit
   *
   * - get rid of the framed aspect of the default LCL one
   * - no published props, no need for design time support
   * - add/close/move left and right speed buttons
   * - a particular tab can be set to reside on a split view
   *)
  TCEPageControl = class(TWinControl)
  private
    fHeader: TWinControl;
    fTabs: TTabControl;
    fCloseBtn: TSpeedButton;
    fMoveLeftBtn: TSpeedButton;
    fMoveRightBtn: TSpeedButton;
    fAddBtn: TSpeedButton;
    fSplitBtn: TSpeedButton;
    fContent: TPanel;
    fPages: TFPList;
    fPagesHistory: TFPList;
    fPageIndex: integer;
    fSplittedPageIndex: integer;
    fButtons: TCEPageControlButtons;
    fOnChanged: TNotifyEvent;
    fOnChanging: TTabChangingEvent;
    fSplitter: TSplitter;
    fOldSplitPos: integer;
    fOptions: TCEPageControlOptions;
    fOnDragDrop: TDragDropEvent;
    fOnDragOver: TDragOverEvent;

    procedure btnCloseClick(sender: TObject);
    procedure btnMoveLeftClick(sender: TObject);
    procedure btnMoveRightClick(sender: TObject);
    procedure btnAddClick(sender: TObject);
    procedure btnSplitClick(sender: TObject);

    procedure tabsChanging(Sender: TObject; var AllowChange: Boolean);
    procedure tabsChanged(sender: TObject);
    procedure hidePage(index: integer);
    procedure showPage(index: integer);
    procedure setPageIndex(index: integer);
    procedure setButtons(value: TCEPageControlButtons);
    procedure setCurrentPage(value: TCEPage);
    function getCurrentPage: TCEPage;
    function getPageCount: integer;
    function getPage(index: integer): TCEPage;
    function getSplitPage: TCEPage;

    procedure changedNotify;
    procedure updateButtonsState;

    procedure setOnDragOver(value: TDragOverEvent);
    procedure setOnDragDrop(value: TDragDropEvent);
    procedure setPagesOptions(value: TCEPageControlOptions);
    procedure setHeaderPosition(bottom: boolean);

  public
    constructor Create(aowner: TComponent); override;
    destructor Destroy; override;

    function  addPage: TCEPage;
    procedure deletePage(index: integer);
    function  getPageIndex(page: TCEPage): integer;
    procedure movePageRight;
    procedure movePageLeft;

    property splitPage: TCEPage read getSplitPage;
    property currentPage: TCEPage read getCurrentPage write setCurrentPage;
    property pageIndex: integer read fPageIndex write setPageIndex;
    property pageCount: integer read getPageCount;
    property pages[index: integer]: TCEPage read getPage; default;

    property buttons: TCEPageControlButtons read fButtons write setButtons;
    property closeButton: TSpeedButton read fCloseBtn;
    property moveLeftButton: TSpeedButton read fMoveLeftBtn;
    property moveRightButton: TSpeedButton read fMoveRightBtn;
    property addButton: TSpeedButton read fAddBtn;
    property splitButton: TSpeedButton read fSplitBtn;

    property onChanged: TNotifyEvent read fOnChanged write fOnChanged;
    property onChanging: TTabChangingEvent read fOnChanging write fOnChanging;

    property options: TCEPageControlOptions read fOptions write setPagesOptions default defPagesOpt;

    property OnDragOver read fOnDragOver write setOnDragOver;
    property OnDragDrop read fOnDragDrop write setOnDragDrop;
  end;

implementation

function TCEPage.getIndex: integer;
var
  ctrl: TCEPageControl;
  i: integer;
begin
  ctrl := TCEPageControl(owner);
  for i := 0 to ctrl.pageCount-1 do
      if ctrl.pages[i] = self then
        exit(i);
  exit(-1);
end;

procedure TCEPage.RealSetText(const Value: TCaption);
var
  i: integer;
  ctrl: TCEPageControl;
begin
  inherited;
  ctrl :=  TCEPageControl(owner);
  i := ctrl.getPageIndex(self);
  if i <> -1 then ctrl.fTabs.Tabs[i] := caption;
end;

constructor TCEPageControl.Create(aowner: TComponent);
begin
  inherited;

  fHeader := TWinControl.Create(self);
  fHeader.Parent:= self;
  fHeader.Align := alTop;
  fHeader.Height:= 32;

  fSplittedPageIndex:=-1;

  fTabs := TTabControl.Create(self);
  fTabs.Parent:= fHeader;
  fTabs.Align := alClient;
  fTabs.Options:=[];
  fTabs.OnChange:=@tabsChanged;
  fTabs.OnChanging:=@tabsChanging;
  {$IFDEF WINDOWS}
  fTabs.BorderSpacing.Top:= 8;
  {$ENDIF}

  fMoveLeftBtn:= TSpeedButton.Create(self);
  fMoveLeftBtn.Parent := fHeader;
  fMoveLeftBtn.Align:= alRight;
  fMoveLeftBtn.Width:= 28;
  fMoveLeftBtn.BorderSpacing.Around:= 2;
  fMoveLeftBtn.ShowCaption:=false;
  fMoveLeftBtn.OnClick:=@btnMoveLeftClick;
  fMoveLeftBtn.Hint:='move current page to the left';

  fMoveRightBtn:= TSpeedButton.Create(self);
  fMoveRightBtn.Parent := fHeader;
  fMoveRightBtn.Align:= alRight;
  fMoveRightBtn.Width:= 28;
  fMoveRightBtn.BorderSpacing.Around:= 2;
  fMoveRightBtn.ShowCaption:=false;
  fMoveRightBtn.OnClick:=@btnMoveRightClick;
  fMoveRightBtn.Hint:='move current page to the right';

  fAddBtn:= TSpeedButton.Create(self);
  fAddBtn.Parent := fHeader;
  fAddBtn.Align:= alRight;
  fAddBtn.Width:= 28;
  fAddBtn.BorderSpacing.Around:= 2;
  fAddBtn.ShowCaption:=false;
  fAddBtn.OnClick:=@btnAddClick;
  fAddBtn.Hint:='add a new page';

  fCloseBtn := TSpeedButton.Create(self);
  fCloseBtn.Parent := fHeader;
  fCloseBtn.Align:= alRight;
  fCloseBtn.Width:= 28;
  fCloseBtn.BorderSpacing.Around:= 2;
  fCloseBtn.ShowCaption:=false;
  fCloseBtn.OnClick:=@btnCloseClick;
  fCloseBtn.Hint:='close current page';

  fSplitBtn := TSpeedButton.Create(self);
  fSplitBtn.Parent := fHeader;
  fSplitBtn.Align:= alRight;
  fSplitBtn.Width:= 28;
  fSplitBtn.BorderSpacing.Around:= 2;
  fSplitBtn.ShowCaption:=false;
  fSplitBtn.OnClick:=@btnSplitClick;
  fSplitBtn.Hint:= 'pin or un-pin the page to the right';

  fContent := TPanel.Create(self);
  fContent.Parent := self;
  fContent.Align  := alClient;
  fContent.BevelInner:= bvNone;
  fContent.BevelOuter:= bvNone;
  fContent.BorderStyle:=bsNone;
  fContent.BorderSpacing.Top:=3;

  fSplitter := TSplitter.Create(self);
  fSplitter.Parent := fContent;
  fSplitter.Visible:= false;
  fSplitter.Align := alLeft;
  fSplitter.Width := 6;

  fPages := TFPList.Create;
  fPagesHistory := TFPList.Create;
  fPageIndex := -1;

  setPagesOptions(defPagesOpt);

  fButtons:= CEPageControlDefaultButtons;
  updateButtonsState;
end;

destructor TCEPageControl.Destroy;
begin
  while fPages.Count > 0 do
    deletePage(fPages.Count-1);
  fPages.Free;
  fPagesHistory.Free;
  inherited;
end;

procedure TCEPageControl.setOnDragOver(value: TDragOverEvent);
begin
  if fOnDragOver = value then
    exit;
  fOnDragOver:=value;
  fContent.OnDragOver:=value;
  fTabs.OnDragOver:=value;
end;

procedure TCEPageControl.setOnDragDrop(value: TDragDropEvent);
begin
  if fOnDragDrop = value then
    exit;
  fOnDragDrop:=value;
  fContent.OnDragDrop:=value;
  fTabs.OnDragDrop:=value;
end;

procedure TCEPageControl.setPagesOptions(value: TCEPageControlOptions);
var
  flat: boolean;
begin
  if fOptions = value then
    exit;
  fOptions := value;
  fPagesHistory.Clear;
  setHeaderPosition(poBottomHeader in fOptions);
  flat := poFlatButtons in fOptions;
  fAddBtn.Flat:= flat;
  fCloseBtn.Flat:= flat;
  fMoveLeftBtn.Flat:=flat;
  fMoveRightBtn.Flat:=flat;
  fSplitBtn.Flat:=flat;
end;

procedure TCEPageControl.setHeaderPosition(bottom: boolean);
begin
  if bottom then
  begin
    fTabs.TabPosition:= tpBottom;
    fHeader.Align:= alBottom;
  end else
  begin
    fTabs.TabPosition:= tpTop;
    fHeader.Align:= alTop;
  end;
end;

procedure TCEPageControl.changedNotify;
begin
  updateButtonsState;
  if assigned(fOnChanged) then
    fOnChanged(self);
end;

procedure TCEPageControl.tabsChanged(sender: TObject);
begin
  if fTabs.TabIndex < fPages.Count then
    setPageIndex(fTabs.TabIndex);
end;

procedure TCEPageControl.tabsChanging(Sender: TObject; var AllowChange: Boolean);
begin
  if assigned(fOnChanging) then fOnChanging(self, AllowChange);
end;

procedure TCEPageControl.hidePage(index: integer);
var
  pge: TCEPage;
begin
  if (index < 0) or (index > fPages.Count-1) then
    exit;

  pge := TCEPage(fPages[index]);
  pge.Visible:=false;
end;

procedure TCEPageControl.showPage(index: integer);
var
  pge: TCEPage;
  ctl: TControl;
begin
  if (index < 0) or (index > fPages.Count-1) then
    exit;

  pge := TCEPage(fPages[index]);
  if (fSplittedPageIndex = -1) or (index = fSplittedPageIndex) then
    pge.Align:=alClient;
  pge.Visible:=true;
  pge.Repaint;
  for ctl in pge.GetEnumeratorControls do
    ctl.Visible:=true;
end;

procedure TCEPageControl.setPageIndex(index: integer);
var
  leftp, rightp: TCEPage;
begin
  if (fPageIndex <> fSplittedPageIndex) then
    fOldSplitPos := fSplitter.Left;
  if (index > fPages.Count-1) then
    index := fPages.Count-1;
  if (index < 0) then
      exit;

  if (fSplittedPageIndex = -1) or (index = fSplittedPageIndex) then
  begin
    hidePage(fPageIndex);
    fPageIndex := index;
    showPage(fPageIndex);
    fSplitter.Visible:= false;
  end
  else if (fSplittedPageIndex <> -1)  then
  begin
    hidePage(fPageIndex);
    fPageIndex := index;

    fSplitter.Visible:= true;

    rightp := getPage(fSplittedPageIndex);
    rightp.Align := alClient;
    showPage(fSplittedPageIndex);

    leftp := getPage(fPageIndex);
    leftp.Align := alLeft;
    if fOldSplitPos = 0 then
      leftp.Width:= (fContent.Width - fSplitter.Width) div 2
    else
      leftp.Width:= fOldSplitPos;
    showPage(fPageIndex);
  end;

  if fTabs.TabIndex <> fPageIndex then
    fTabs.TabIndex:= fPageIndex;

  changedNotify;
end;

function TCEPageControl.addPage: TCEPage;
var
  pge: TCEPage;
begin

  if poPageHistory in fOptions then
    {$PUSH}{$HINTS OFF}{$WARNINGS OFF}
    fPagesHistory.Insert(0, Pointer(PtrUint(fPageIndex)));
    {$POP}

  pge := TCEPage.Create(self);
  pge.Parent := fContent;
  pge.Align:= alClient;

  fPages.Add(pge);
  fTabs.Tabs.Add(format('', [fPages.Count]));
  setPageIndex(fTabs.Tabs.Count-1);

  result := pge;
end;

procedure TCEPageControl.deletePage(index: integer);
begin
  if (index > fPages.Count-1) or (index < 0) then
    exit;

  if index = fSplittedPageIndex then
    fSplittedPageIndex := -1
  else if index < fSplittedPageIndex then
    fSplittedPageIndex -= 1;

  TCEPage(fPages[index]).Free;
  if fPageIndex >= fPages.Count then
    fPageIndex -= 1;

  fPages.Delete(index);
  fTabs.Tabs.Delete(index);

  if (poPageHistory in fOptions) and (fPagesHistory.Count > 0) then
  begin
    {$PUSH}{$HINTS OFF}{$WARNINGS OFF}
    fPageIndex := Integer(fPagesHistory[0]);
    fPagesHistory.Delete(0);
    {$POP}
  end;

  if fPages.Count = 0 then
    fPageIndex:=-1;

  updateButtonsState;
  setPageIndex(fPageIndex);
end;

function TCEPageControl.getPageIndex(page: TCEPage): integer;
begin
  exit(fPages.IndexOf(page));
end;

function TCEPageControl.getCurrentPage: TCEPage;
begin
  if (fPageIndex < 0) or (fPageIndex > fPages.Count-1) then
    exit(nil)
  else
    exit(TCEPage(fPages[fPageIndex]));
end;

procedure TCEPageControl.setCurrentPage(value: TCEPage);
begin
  setPageIndex(getPageIndex(value));
end;

function TCEPageControl.getPageCount: integer;
begin
  exit(fPages.Count);
end;

function TCEPageControl.getPage(index: integer): TCEPage;
begin
  exit(TCEPage(fPages[index]));
end;

function TCEPageControl.getSplitPage: TCEPage;
begin
  if fSplittedPageIndex = -1 then
    exit(nil)
  else
    exit(getPage(fSplittedPageIndex));
end;

procedure TCEPageControl.movePageRight;
var
  i: integer;
begin
  if fPageIndex = fPages.Count-1 then
    exit;

  fPages.Exchange(fPageIndex, fPageIndex + 1);
  fTabs.Tabs.Exchange(fPageIndex, fPageIndex + 1);

  {$PUSH}{$HINTS OFF}{$WARNINGS OFF}
  for i := 0 to fPagesHistory.Count-1 do
  begin
    if PtrInt(fPagesHistory[i]) = fPageIndex then
      fPagesHistory[i] := Pointer(PtrInt(fPageIndex+1))
    else if PtrInt(fPagesHistory[i]) = fPageIndex+1 then
      fPagesHistory[i] := Pointer(PtrInt(fPageIndex))
  end;
  {$POP}

  if fPageIndex = fSplittedPageIndex then
    fSplittedPageIndex += 1;
  setPageIndex(fPageIndex+1);
end;

procedure TCEPageControl.movePageLeft;
var
  i: integer;
begin
  if fPageIndex <= 0 then
    exit;

  fPages.Exchange(fPageIndex, fPageIndex - 1);
  fTabs.Tabs.Exchange(fPageIndex, fPageIndex - 1);

  {$PUSH}{$HINTS OFF}{$WARNINGS OFF}
  for i := 0 to fPagesHistory.Count-1 do
  begin
    if PtrInt(fPagesHistory[i]) = fPageIndex then
      fPagesHistory[i] := Pointer(PtrInt(fPageIndex-1))
    else if PtrInt(fPagesHistory[i]) = fPageIndex-1 then
      fPagesHistory[i] := Pointer(PtrInt(fPageIndex))
  end;
  {$POP}

  if fPageIndex = fSplittedPageIndex then
    fSplittedPageIndex -= 1;
  setPageIndex(fPageIndex-1);
end;

procedure TCEPageControl.btnCloseClick(sender: TObject);
begin
  deletePage(fPageIndex);
end;

procedure TCEPageControl.btnMoveLeftClick(sender: TObject);
begin
  movePageLeft;
end;

procedure TCEPageControl.btnMoveRightClick(sender: TObject);
begin
  movePageRight;
end;

procedure TCEPageControl.btnAddClick(sender: TObject);
begin
  addPage;
end;

procedure TCEPageControl.btnSplitClick(sender: TObject);
begin
  if fPageIndex = fSplittedPageIndex then
    fSplittedPageIndex := -1
  else
  begin
    if (fSplittedPageIndex <> -1) then
      hidePage(fSplittedPageIndex);
    fSplittedPageIndex:= fPageIndex;
  end;
  setPageIndex(fPageIndex);
end;

procedure TCEPageControl.setButtons(value: TCEPageControlButtons);
begin
  if fButtons = value then
    exit;

  fButtons := value;
  updateButtonsState;
  fHeader.ReAlign;
end;

procedure TCEPageControl.updateButtonsState;
begin
  fHeader.DisableAlign;
  fMoveLeftBtn.Visible := pbMoveLeft in fButtons;
  fMoveRightBtn.Visible := pbMoveRight in fButtons;
  fAddBtn.Visible := pbAdd in fButtons;
  fCloseBtn.Visible := pbClose in fButtons;
  fSplitBtn.Visible := pbSplit in fButtons;
  fSplitBtn.Enabled := fPages.Count > 0;
  fHeader.EnableAlign;
  fCloseBtn.Enabled := fPageIndex <> -1;
  fMoveLeftBtn.Enabled := fPageIndex > 0;
  fMoveRightBtn.Enabled := fPageIndex < fPages.Count-1;
end;

end.

