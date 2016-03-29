unit ce_common;

{$I ce_defines.inc}

interface

uses

  Classes, SysUtils,
  {$IFDEF WINDOWS}
  Windows, JwaTlHelp32,
  {$ELSE}
  ExtCtrls, FileUtil, LazFileUtils,
  {$ENDIF}
  {$IFNDEF CEBUILD}
  forms,
  {$ENDIF}
  process, asyncprocess, fgl;

const
  exeExt = {$IFDEF WINDOWS} '.exe' {$ELSE} ''   {$ENDIF};
  objExt = {$IFDEF WINDOWS} '.obj' {$ELSE} '.o' {$ENDIF};
  libExt = {$IFDEF WINDOWS} '.lib' {$ELSE} '.a' {$ENDIF};
  dynExt = {$IFDEF WINDOWS} '.dll' {$ENDIF} {$IFDEF LINUX}'.so'{$ENDIF} {$IFDEF DARWIN}'.dylib'{$ENDIF};

type

  TIntByString = class(specialize TFPGMap<string, integer>);

  TCECompiler = (dmd, gdc, ldc);

  // aliased to get a custom prop inspector
  TCEPathname = type string;
  TCEFilename = type string;
  TCEEditEvent = type boolean;

  // sugar for classes
  TObjectHelper = class helper for TObject
    function isNil: boolean;
    function isNotNil: boolean;
  end;

  // sugar for pointers
  TPointerHelper = type helper for Pointer
    function isNil: boolean;
    function isNotNil: boolean;
  end;

  // sugar for strings
  TStringHelper = type helper for string
    function isEmpty: boolean;
    function isNotEmpty: boolean;
    function isBlank: boolean;
    function extractFileName: string;
    function extractFileExt: string;
    function extractFilePath: string;
    function extractFileDir: string;
    function fileExists: boolean;
    function dirExists: boolean;
    function upperCase: string;
    function length: integer;
  end;

  (**
   *  TProcess with assign() 'overriden'.
   *)
  TProcessEx = class helper for TProcess
  public
    procedure Assign(aValue: TPersistent);
  end;

  (**
   * CollectionItem used to store a shortcut.
   *)
  TCEPersistentShortcut = class(TCollectionItem)
  private
    fShortcut: TShortCut;
    fActionName: string;
  published
    property shortcut: TShortCut read fShortcut write fShortcut;
    property actionName: string read fActionName write fActionName;
  public
    procedure assign(aValue: TPersistent); override;
  end;

  (**
   * Save a component with a readable aspect.
   *)
  procedure saveCompToTxtFile(const aComp: TComponent; const aFilename: string);

  (**
   * Load a component. Works in pair with saveCompToTxtFile().
   *)
  procedure loadCompFromTxtFile(const aComp: TComponent; const aFilename: string;
    aPropNotFoundHandler: TPropertyNotFoundEvent = nil; anErrorHandler: TReaderError = nil);

  (**
   * Converts a relative path to an absolute path.
   *)
  function expandFilenameEx(const aBasePath, aFilename: string): string;

  (**
   * Patches the directory separators from a string.
   * This is used to ensure that a project saved on a platform can be loaded
   * on another one.
   *)
  function patchPlateformPath(const aPath: string): string;
  procedure patchPlateformPaths(const sPaths: TStrings);

  (**
   * Patches the file extension from a string.
   * This is used to ensure that a project saved on a platform can be loaded
   * on another one. Note that the ext which are handled are specific to coedit projects.
   *)
  function patchPlateformExt(const aFilename: string): string;

  (**
   * Returns aFilename without its extension.
   *)
  function stripFileExt(const aFilename: string): string;

  (**
   * Returns an unique object identifier, based on its heap address.
   *)
  function uniqueObjStr(const aObject: TObject): string;

  (**
   * Reduces a filename if its length is over the threshold defined by charThresh.
   * Even if the result is not usable anymore, it avoids any "visually-overloaded" MRU menu.
   *)
  function shortenPath(const aPath: string; charThresh: Word = 60): string;

  (**
   * Returns the user data dir.
   *)
  function getUserDataPath: string;

  (**
   * Returns the folder where Coedit stores the data, the cache, the settings.
   *)
  function getCoeditDocPath: string;

  (**
   * Fills aList with the names of the files located in aPath.
   *)
  procedure listFiles(aList: TStrings; const aPath: string; recursive: boolean = false);

  (**
   * Fills aList with the names of the folders located in aPath.
   *)
  procedure listFolders(aList: TStrings; const aPath: string);

  (**
   * Returns true if aPath contains at least one sub-folder.
   *)
  function hasFolder(const aPath: string): boolean;

  (**
   * Fills aList with the system drives.
   *)
  procedure listDrives(aList: TStrings);

  (**
   * If aPath ends with an asterisk then fills aList with the names of the files located in aPath.
   * Returns true if aPath was 'asterisk-ifyed'.
   *)
  function listAsteriskPath(const aPath: string; aList: TStrings; someExts: TStrings = nil): boolean;

  (**
   * Lets the shell open a file.
   *)
  function shellOpen(const aFilename: string): boolean;

  (**
   * Returns true if anExeName can be spawn without its full path.
   *)
  function exeInSysPath(anExeName: string): boolean;

  (**
   * Returns the full path to anExeName. Works if exeInSysPath() returns true.
   *)
  function exeFullName(anExeName: string): string;

  (**
   * Clears then fills aList with aProcess output stream.
   *)
  procedure processOutputToStrings(aProcess: TProcess; var aList: TStringList);

  (**
   * Copy available process output to a stream.
   *)
  procedure processOutputToStream(aProcess: TProcess; output: TMemoryStream);

  (**
   * Terminates and frees aProcess.
   *)
  procedure killProcess(var aProcess: TAsyncProcess);

  (**
   * Ensures that the i/o process pipes are not redirected if it waits on exit.
   *)
  procedure ensureNoPipeIfWait(aProcess: TProcess);

  (**
   * Returns true if ExeName is already running.
   *)
  function AppIsRunning(const ExeName: string):Boolean;

  (**
   * Returns the length of the line ending in aFilename.
   *)
  function getLineEndingLength(const aFilename: string): byte;

  (**
   * Returns the length of the line ending for the current platform.
   *)
  function getSysLineEndLen: byte;

  (**
   * Returns the common folder of the file names stored in aList.
   *)
  function commonFolder(const someFiles: TStringList): string;

  (**
   * Returns true if ext matches a file extension whose type is highlightable.
   *)
  function hasDlangSyntax(const ext: string): boolean;

  (**
   * Returns true if ext matches a file extension whose type can be passed as source.
   *)
  function isDlangCompilable(const ext: string): boolean;

  (**
   * Returns true if ext matches a file extension whose type is editable in Coedit.
   *)
  function isEditable(const ext: string): boolean;

  (**
   * Returns true if str starts with a semicolon or a double slash.
   * This is used to disable TStringList items in several places
   *)
  function isStringDisabled(const str: string): boolean;

  (**
   * Deletes the duplicates in a TStrings instance.
   *)
  procedure deleteDups(str: TStrings);

  (**
   * Indicates wether str is only made of blank characters
   *)
  function isBlank(const str: string): boolean;

  (**
   * Converts a global match expression to a regular expression.
   * Limitation: Windows style, negation of set not handled [!a-z] [!abc]
   *)
  function globToReg(const glob: string ): string;

var
  // supplementatl directories to find background tools
  additionalPath: string;


implementation

uses
  ce_main;

procedure TCEPersistentShortcut.assign(aValue: TPersistent);
var
  src: TCEPersistentShortcut;
begin
  if aValue is TCEPersistentShortcut then
  begin
    src := TCEPersistentShortcut(Avalue);
    fActionName := src.fActionName;
    fShortcut := src.fShortcut;
  end
  else inherited;
end;

function TObjectHelper.isNil: boolean;
begin
  exit(self = nil);
end;

function TObjectHelper.isNotNil: boolean;
begin
  exit(self <> nil);
end;

function TPointerHelper.isNil: boolean;
begin
  exit(self = nil);
end;

function TPointerHelper.isNotNil: boolean;
begin
  exit(self <> nil);
end;

function TStringHelper.isEmpty: boolean;
begin
  exit(self = '');
end;

function TStringHelper.isNotEmpty: boolean;
begin
  exit(self <> '');
end;

function TStringHelper.isBlank: boolean;
begin
  exit(ce_common.isBlank(self));
end;

function TStringHelper.extractFileName: string;
begin
  exit(sysutils.extractFileName(self));
end;

function TStringHelper.extractFileExt: string;
begin
  exit(sysutils.extractFileExt(self));
end;

function TStringHelper.extractFilePath: string;
begin
  exit(sysutils.extractFilePath(self));
end;

function TStringHelper.extractFileDir: string;
begin
  exit(sysutils.extractFileDir(self));
end;

function TStringHelper.fileExists: boolean;
begin
  exit(sysutils.FileExists(self));
end;

function TStringHelper.dirExists: boolean;
begin
  exit(sysutils.DirectoryExists(self));
end;

function TStringHelper.upperCase: string;
begin
  exit(sysutils.upperCase(self));
end;

function TStringHelper.length: integer;
begin
  exit(system.length(self));
end;

procedure TProcessEx.Assign(aValue: TPersistent);
var
  src: TProcess;
begin
  if aValue is TProcess then
  begin
    src := TProcess(aValue);
    PipeBufferSize := src.PipeBufferSize;
    Active := src.Active;
    Executable := src.Executable;
    Parameters := src.Parameters;
    ConsoleTitle := src.ConsoleTitle;
    CurrentDirectory := src.CurrentDirectory;
    Desktop := src.Desktop;
    Environment := src.Environment;
    Options := src.Options;
    Priority := src.Priority;
    StartupOptions := src.StartupOptions;
    ShowWindow := src.ShowWindow;
    WindowColumns := src.WindowColumns;
    WindowHeight := src.WindowHeight;
    WindowLeft := src.WindowLeft;
    WindowRows := src.WindowRows;
    WindowTop := src.WindowTop;
    WindowWidth := src.WindowWidth;
    FillAttribute := src.FillAttribute;
    XTermProgram := src.XTermProgram;
  end
  else inherited;
end;

procedure saveCompToTxtFile(const aComp: TComponent; const aFilename: string);
var
  str1, str2: TMemoryStream;
begin
  str1 := TMemoryStream.Create;
  str2 := TMemoryStream.Create;
  try
    str1.WriteComponent(aComp);
    str1.Position := 0;
    ObjectBinaryToText(str1,str2);
    ForceDirectories(aFilename.extractFilePath);
    str2.SaveToFile(aFilename);
  finally
    str1.Free;
    str2.Free;
  end;
end;

procedure loadCompFromTxtFile(const aComp: TComponent; const aFilename: string;
  aPropNotFoundHandler: TPropertyNotFoundEvent = nil; anErrorHandler: TReaderError = nil);
var
  str1, str2: TMemoryStream;
  rdr: TReader;
begin
  str1 := TMemoryStream.Create;
  str2 := TMemoryStream.Create;
  try
    str1.LoadFromFile(aFilename);
    str1.Position := 0;
    ObjectTextToBinary(str1, str2);
    str2.Position := 0;
    try
      rdr := TReader.Create(str2, 4096);
      try
        rdr.OnPropertyNotFound := aPropNotFoundHandler;
        rdr.OnError := anErrorHandler;
        rdr.ReadRootComponent(aComp);
      finally
        rdr.Free;
      end;
    except
    end;
  finally
    str1.Free;
    str2.Free;
  end;
end;

function expandFilenameEx(const aBasePath, aFilename: string): string;
var
  curr: string = '';
begin
  getDir(0, curr);
  try
    if (curr <> aBasePath) and aBasePath.dirExists then
      chDir(aBasePath);
    result := expandFileName(aFilename);
  finally
    chDir(curr);
  end;
end;

function patchPlateformPath(const aPath: string): string;
function patchProc(const src: string; const invalid: char): string;
var
  i: Integer;
  dir: string;
begin
  dir := ExtractFileDrive(src);
  if dir.length > 0 then
    result := src[dir.length+1..src.length]
  else
    result := src;
  i := pos(invalid, result);
  if i <> 0 then
  begin
    repeat
      result[i] := directorySeparator;
      i := pos(invalid,result);
    until
      i = 0;
  end;
  result := dir + result;
end;
begin
  result := aPath;
  {$IFDEF WINDOWS}
  result := patchProc(result, '/');
  {$ELSE}
  result := patchProc(result, '\');
  {$ENDIF}
end;

procedure patchPlateformPaths(const sPaths: TStrings);
var
  i: Integer;
  str: string;
begin
  for i:= 0 to sPaths.Count-1 do
  begin
    str := sPaths[i];
    sPaths[i] := patchPlateformPath(str);
  end;
end;

function patchPlateformExt(const aFilename: string): string;
var
  ext, newext: string;
begin
  ext := aFilename.extractFileExt;
  newext := '';
  {$IFDEF MSWINDOWS}
  case ext of
    '.so':    newext := '.dll';
    '.dylib': newext := '.dll';
    '.a':     newext := '.lib';
    '.o':     newext := '.obj';
    else      newext := ext;
  end;
  {$ENDIF}
  {$IFDEF LINUX}
  case ext of
    '.dll':   newext := '.so';
    '.dylib': newext := '.so';
    '.lib':   newext := '.a';
    '.obj':   newext := '.o';
    '.exe':   newext := '';
    else      newext := ext;
  end;
  {$ENDIF}
  {$IFDEF DARWIN}
  case ext of
    '.dll': newext := '.dylib';
    '.so':  newext := '.dylib';
    '.lib': newext := '.a';
    '.obj': newext := '.o';
    '.exe': newext := '';
    else    newext := ext;
  end;
  {$ENDIF}
  result := ChangeFileExt(aFilename, newext);
end;

function stripFileExt(const aFilename: string): string;
begin
  if Pos('.', aFilename) > 1 then
    exit(ChangeFileExt(aFilename, ''))
  else
    exit(aFilename);
end;

function uniqueObjStr(const aObject: Tobject): string;
begin
  {$PUSH}{$HINTS OFF}{$WARNINGS OFF}{$R-}
  exit( format('%.8X',[NativeUint(aObject)]));
  {$POP}
end;

function shortenPath(const aPath: string; charThresh: Word = 60): string;
var
  i: NativeInt;
  sepCnt: integer = 0;
  drv: string;
  pth1: string;
begin
  if aPath.length <= charThresh then
    exit(aPath);

  drv := extractFileDrive(aPath);
  i := aPath.length;
  while(i <> drv.length+1) do
  begin
    Inc(sepCnt, Byte(aPath[i] = directorySeparator));
    if sepCnt = 2 then
      break;
    Dec(i);
  end;
  pth1 := aPath[i..aPath.length];
  exit(format('%s%s...%s', [drv, directorySeparator, pth1]));
end;

function getUserDataPath: string;
begin
  {$IFDEF WINDOWS}
  result := sysutils.GetEnvironmentVariable('APPDATA');
  {$ENDIF}
  {$IFDEF LINUX}
  result := sysutils.GetEnvironmentVariable('HOME') + '/.config';
  {$ENDIF}
  {$IFDEF DARWIN}
  result := sysutils.GetEnvironmentVariable('HOME') + '/Library/Application Support';
  {$ENDIF}
  if not DirectoryExists(result) then
    raise Exception.Create('Coedit failed to retrieve the user data folder');
  if result[result.length] <> DirectorySeparator then
    result += directorySeparator;
end;

function getCoeditDocPath: string;
begin
  result := getUserDataPath + 'Coedit' + directorySeparator;
end;

function isFolder(sr: TSearchRec): boolean;
begin
  result := (sr.Name <> '.') and  (sr.Name <> '..' ) and  (sr.Name <> '' ) and
    (sr.Attr and faDirectory = faDirectory);
end;

procedure listFiles(aList: TStrings; const aPath: string; recursive: boolean = false);
var
  sr: TSearchrec;
procedure tryAdd;
begin
  if sr.Attr and faDirectory <> faDirectory then
    aList.Add(aPath+ directorySeparator + sr.Name);
end;
begin
  if findFirst(aPath + directorySeparator + '*', faAnyFile, sr) = 0 then
  try
    repeat
      tryAdd;
      if recursive then if isFolder(sr) then
        listFiles(aList, aPath + directorySeparator + sr.Name, recursive);
    until
      findNext(sr) <> 0;
  finally
    sysutils.FindClose(sr);
  end;
end;

procedure listFolders(aList: TStrings; const aPath: string);
var
  sr: TSearchrec;
begin
  if findFirst(aPath + '*', faAnyFile, sr) = 0 then
  try
    repeat if isFolder(sr) then
      aList.Add(aPath + sr.Name);
    until findNext(sr) <> 0;
  finally
    sysutils.FindClose(sr);
  end;
end;

function hasFolder(const aPath: string): boolean;
var
  sr: TSearchrec;
  res: boolean;
begin
  res := false;
  if findFirst(aPath + directorySeparator + '*', faDirectory, sr) = 0 then
  try
    repeat if isFolder(sr) then
    begin
      res := true;
      break;
    end;
    until findNext(sr) <> 0;
  finally
    sysutils.FindClose(sr);
  end;
  result := res;
end;

function listAsteriskPath(const aPath: string; aList: TStrings; someExts: TStrings = nil): boolean;
var
  pth, ext, fname: string;
  files: TStringList;
begin
  result := false;
  if aPath.isEmpty then
    exit;
  //
  if aPath[aPath.length] = '*' then
  begin
    pth := aPath[1..aPath.length-1];
    if pth[pth.length] in ['/', '\'] then
      pth := pth[1..pth.length-1];
    if not pth.dirExists then exit(false);
    //
    files := TStringList.Create;
    try
      listFiles(files, pth, true);
      for fname in files do
      begin
        if someExts = nil then
          aList.Add(fname)
        else
        begin
          ext := fname.extractFileExt;
          if someExts.IndexOf(ext) <> -1 then
            aList.Add(fname);
        end;
      end;
    finally
      files.Free;
    end;
    exit(true);
  end;
  exit(false);
end;

procedure listDrives(aList: TStrings);
{$IFDEF WINDOWS}
var
  drv: char;
  ltr, nme: string;
  OldMode : Word;
  {$ENDIF}
begin
  {$IFDEF WINDOWS}
  setLength(nme, 255);
  OldMode := SetErrorMode(SEM_FAILCRITICALERRORS);
  try
    for drv := 'A' to 'Z' do
    begin
      try
        ltr := drv + ':\';
        if not GetVolumeInformation(PChar(ltr), PChar(nme), 255, nil, nil, nil, nil, 0) then
          continue;
        case GetDriveType(PChar(ltr)) of
           DRIVE_REMOVABLE, DRIVE_FIXED, DRIVE_REMOTE: aList.Add(ltr);
        end;
      except
        // SEM_FAILCRITICALERRORS: exception is sent to application.
      end;
    end;
  finally
    SetErrorMode(OldMode);
  end;
  {$ELSE}
  aList.Add('//');
  {$ENDIF}
end;

function shellOpen(const aFilename: string): boolean;
begin
  {$IFDEF WINDOWS}
  result := ShellExecute(0, 'OPEN', PChar(aFilename), nil, nil, SW_SHOW) > 32;
  {$ENDIF}
  {$IFDEF LINUX}
  with TProcess.Create(nil) do
  try
    Executable := 'xdg-open';
    Parameters.Add(aFilename);
    Execute;
  finally
    result := true;
    Free;
  end;
  {$ENDIF}
  {$IFDEF DARWIN}
  with TProcess.Create(nil) do
  try
    Executable := 'open';
    Parameters.Add(aFilename);
    Execute;
  finally
    result := true;
    Free;
  end;
  {$ENDIF}
end;

function exeInSysPath(anExeName: string): boolean;
begin
  exit(exeFullName(anExeName) <> '');
end;

function exeFullName(anExeName: string): string;
var
  ext: string;
  env: string;
begin
  ext := anExeName.extractFileExt;
  if ext.isEmpty then
    anExeName += exeExt;
  //full path already specified
  if anExeName.fileExists and (not anExeName.extractFileName.fileExists) then
    exit(anExeName);
  //
  env := sysutils.GetEnvironmentVariable('PATH');
  // maybe in current dir
  if anExeName.fileExists then
    env += PathSeparator + GetCurrentDir;
  if additionalPath.isNotEmpty then
    env += PathSeparator + additionalPath;
  {$IFNDEF CEBUILD}
  if Application <> nil then
    env += PathSeparator + ExtractFileDir(application.ExeName.ExtractFilePath);
  {$ENDIF}
  exit(ExeSearch(anExeName, env));
end;

procedure processOutputToStrings(aProcess: TProcess; var aList: TStringList);
var
  str: TMemoryStream;
  sum: Integer = 0;
  cnt: Integer;
  buffSz: Integer;
begin
  if not (poUsePipes in aProcess.Options) then
    exit;
  //
  // note: aList.LoadFromStream() does not work, lines can be split, which breaks message parsing (e.g filename detector).
  //
  {
    Split lines:
    ------------

    The problem comes from TAsynProcess.OnReadData. When the output is read in the
    event, it does not always finish on a full line.

    Resolution:
    -----------

    in TAsynProcess.OnReadData Accumulate avalaible output in a stream.
    Detects last line terminator in the accumation.
    Load TStrings from this stream range.
  }
  str := TMemoryStream.Create;
  try
    buffSz := aProcess.PipeBufferSize;
    // temp fix: messages are cut if the TAsyncProcess version is used on simple TProcess.
    if aProcess is TAsyncProcess then begin
      while aProcess.Output.NumBytesAvailable <> 0 do begin
        str.SetSize(sum + buffSz);
        cnt := aProcess.Output.Read((str.Memory + sum)^, buffSz);
        sum += cnt;
      end;
    end else begin
      repeat
        str.SetSize(sum + buffSz);
        cnt := aProcess.Output.Read((str.Memory + sum)^, buffSz);
        sum += cnt;
      until
        cnt = 0;
    end;
    str.Size := sum;
    aList.LoadFromStream(str);
  finally
    str.Free;
  end;
end;

procedure processOutputToStream(aProcess: TProcess; output: TMemoryStream);
var
  sum, cnt: Integer;
const
  buffSz = 2048;
begin
  if not (poUsePipes in aProcess.Options) then
    exit;
  //
  sum := output.Size;
  while aProcess.Output.NumBytesAvailable <> 0 do begin
    output.SetSize(sum + buffSz);
    cnt := aProcess.Output.Read((output.Memory + sum)^, buffSz);
    sum += cnt;
  end;
  output.SetSize(sum);
  output.Position := sum;
end;

procedure killProcess(var aProcess: TAsyncProcess);
begin
  if aProcess = nil then
    exit;
  if aProcess.Running then
    aProcess.Terminate(0);
  aProcess.Free;
  aProcess := nil;
end;

procedure ensureNoPipeIfWait(aProcess: TProcess);
begin
  if not (poWaitonExit in aProcess.Options) then
    exit;
  aProcess.Options := aProcess.Options - [poStderrToOutPut, poUsePipes];
end;

function getLineEndingLength(const aFilename: string): byte;
var
  value: char = #0;
  le: string = LineEnding;
begin
  result := le.length;
  if not fileExists(aFilename) then
    exit;
  with TMemoryStream.Create do
  try
    LoadFromFile(aFilename);
    while true do
    begin
      if Position = Size then
        exit;
      read(value,1);
      if value = #10 then
        exit(1);
      if value = #13 then
        exit(2);
    end;
  finally
    Free;
  end;
end;

function getSysLineEndLen: byte;
begin
  {$IFDEF WINDOWS}
  exit(2);
  {$ELSE}
  exit(1);
  {$ENDIF}
end;

function countFolder(aFilename: string): integer;
var
  parent: string;
begin
  result := 0;
  while(true) do begin
    parent := aFilename.extractFileDir;
    if parent = aFilename then exit;
    aFilename := parent;
    result += 1;
  end;
end;

//TODO-cfeature: make it working with relative paths
function commonFolder(const someFiles: TStringList): string;
var
  i,j,k: integer;
  sink: TStringList;
  dir: string;
  cnt: integer;
begin
  result := '';
  if someFiles.Count = 0 then exit;
  sink := TStringList.Create;
  try
    sink.Assign(someFiles);
    for i := sink.Count-1 downto 0 do
      if (not sink[i].fileExists) and (not sink[i].dirExists) then
        sink.Delete(i);
    // folders count
    cnt := 256;
    for dir in sink do
    begin
      k := countFolder(dir);
      if k < cnt then
        cnt := k;
    end;
    for i := sink.Count-1 downto 0 do
    begin
      while (countFolder(sink[i]) <> cnt) do
        sink[i] := sink[i].extractFileDir;
    end;
    // common folder
    while true do
    begin
      for i := sink.Count-1 downto 0 do
      begin
        dir := sink[i].extractFileDir;
        j := sink.IndexOf(dir);
        if j = -1 then
          sink[i] := dir
        else if j <> i then
          sink.Delete(i);
      end;
      if sink.Count < 2 then
        break;
    end;
    if sink.Count = 0 then
      result := ''
    else
      result := sink[0];
  finally
    sink.free;
  end;
end;

{$IFDEF WINDOWS}
function internalAppIsRunning(const ExeName: string): integer;
var
  ContinueLoop: BOOL;
  FSnapshotHandle: THandle;
  FProcessEntry32: TProcessEntry32;
begin
  FSnapshotHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  FProcessEntry32.dwSize := SizeOf(FProcessEntry32);
  ContinueLoop := Process32First(FSnapshotHandle, FProcessEntry32);
  Result := 0;
  while integer(ContinueLoop) <> 0 do
    begin
    if ((UpperCase(ExtractFileName(FProcessEntry32.szExeFile)) =
      UpperCase(ExeName)) or (UpperCase(FProcessEntry32.szExeFile) =
      UpperCase(ExeName))) then
      begin
      Inc(Result);
      // SendMessage(Exit-Message) possible?
      end;
    ContinueLoop := Process32Next(FSnapshotHandle, FProcessEntry32);
    end;
  CloseHandle(FSnapshotHandle);
end;
{$ENDIF}

{$IFDEF LINUX}
function internalAppIsRunning(const ExeName: string): integer;
var
  proc: TProcess;
  lst: TStringList;
begin
  Result := 0;
  proc := tprocess.Create(nil);
  proc.Executable := 'ps';
  proc.Parameters.Add('-C');
  proc.Parameters.Add(ExeName);
  proc.Options := [poUsePipes, poWaitonexit];
  try
    proc.Execute;
    lst := TStringList.Create;
    try
      lst.LoadFromStream(proc.Output);
      Result := Pos(ExeName, lst.Text);
    finally
      lst.Free;
    end;
  finally
    proc.Free;
  end;
end;
{$ENDIF}

{$IFDEF DARWIN}
function internalAppIsRunning(const ExeName: string): integer;
var
  proc: TProcess;
  lst: TStringList;
begin
  Result := 0;
  proc := tprocess.Create(nil);
  proc.Executable := 'pgrep';
  proc.Parameters.Add(ExeName);
  proc.Options := [poUsePipes, poWaitonexit];
  try
    proc.Execute;
    lst := TStringList.Create;
    try
      lst.LoadFromStream(proc.Output);
      Result := StrToIntDef(Trim(lst.Text), 0);
    finally
      lst.Free;
    end;
  finally
    proc.Free;
  end;
end;
{$ENDIF}

function AppIsRunning(const ExeName: string):Boolean;
begin
  Result:= internalAppIsRunning(ExeName) > 0;
end;

function hasDlangSyntax(const ext: string): boolean;
begin
  result := false;
  case ext of
    '.d', '.di': result := true;
  end;
end;


function isDlangCompilable(const ext: string): boolean;
begin
  result := false;
  case ext of
    '.d', '.di', '.dd', '.obj', '.o', '.a', '.lib': result := true;
  end;
end;

function isEditable(const ext: string): boolean;
begin
  result := false;
  case ext of
    '.d', '.di', '.dd', '.lst', '.md', '.txt', '.map': result := true;
  end;
end;

function isStringDisabled(const str: string): boolean;
begin
  result := false;
  if str.isEmpty then
    exit;
  if str[1] = ';' then
    result := true;
  if (str.length > 1) and (str[1..2] = '//') then
    result := true;
end;

procedure deleteDups(str: TStrings);
var
  i: integer;
begin
  {$PUSH}{$HINTS OFF}
  if str = nil then exit;
  for i:= str.Count-1 downto 0 do
    // if less than 0 -> not found -> unsigned -> greater than current index.
    if cardinal(str.IndexOf(str[i])) <  i then
      str.Delete(i);
  {$POP}
end;

function isBlank(const str: string): boolean;
var
  c: char;
begin
  result := true;
  for c in str do
    if not (c in [#9, ' ']) then
      exit(false);
end;

function globToReg(const glob: string ): string;
  procedure quote(var r: string; c: char);
  begin
    if not (c in ['a'..'z', 'A'..'Z', '0'..'9', '_', '-']) then
      r += '\';
    r += c;
  end;
var
  i: integer = 0;
  b: integer = 0;
begin
  result := '^';
  while i < length(glob) do
  begin
    i += 1;
    case glob[i] of
      '*': result += '.*';
      '?': result += '.';
      '[', ']': result += glob[i];
      '{':
        begin
          b += 1;
          result += '(';
        end;
      '}':
        begin
          b -= 1;
          result += ')';
        end;
      ',':
        begin
          if b > 0 then
            result += '|'
          else
            quote(result, glob[i]);
        end;
      else
        quote(result, glob[i]);
    end;
  end;
end;

initialization
  registerClasses([TCEPersistentShortcut]);
end.
