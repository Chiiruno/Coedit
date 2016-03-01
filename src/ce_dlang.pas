unit ce_dlang;

{$I ce_defines.inc}

interface

uses
  Classes, SysUtils, ce_dlangutils;

const

  D2Kw: array[0..109] of string =
    ('abstract', 'alias', 'align', 'asm', 'assert', 'auto',
    'body', 'bool', 'break', 'byte',
    'case', 'cast', 'catch', 'cdouble', 'cent', 'cfloat', 'char', 'class',
    'const', 'continue', 'creal',
    'dchar', 'debug', 'default', 'delegate', 'delete', 'deprecated', 'do', 'double',
    'else', 'enum', 'export', 'extern',
    'false', 'final', 'finally', 'float', 'for', 'foreach',
    'foreach_reverse', 'function',
    'goto',
    'idouble', 'if', 'ifloat', 'immutable', 'import', 'in', 'inout', 'int',
    'interface', 'invariant', 'ireal', 'is',
    'lazy', 'long',
    'macro', 'mixin', 'module',
    'new', 'nothrow', 'null',
    'out', 'override',
    'package', 'pragma', 'private', 'protected', 'ptrdiff_t', 'public', 'pure',
    'real', 'ref', 'return',
    'size_t', 'scope', 'shared', 'short', 'static', 'string', 'struct',
    'super', 'switch', 'synchronized',
    'template', 'this', 'throw', 'true', 'try', 'typedef', 'typeid', 'typeof',
    'ubyte', 'ucent', 'uint', 'ulong', 'union', 'unittest', 'ushort',
    'version', 'void', 'volatile',
    'wchar', 'while', 'with',
    '__FILE__', '__MODULE__', '__LINE__', '__FUNCTION__', '__PRETTY_FUNCTION__'
    );

type

  (**
   * sector for an array of Keyword with a common hash.
   *)
  TD2DictionaryEntry = record
    filled: Boolean;
    values: array of string;
  end;

  (**
   * Dictionary for the D2 keywords.
   *)
  TD2Dictionary = object
  private
    fLongest, fShortest: NativeInt;
    fEntries: array[Byte] of TD2DictionaryEntry;
    function toHash(const aValue: string): Byte; {$IFNDEF DEBUG}inline;{$ENDIF}
    procedure addEntry(const aValue: string);
  public
    constructor Create;
    destructor Destroy; // do not remove even if empty (compat with char-map version)
    function find(const aValue: string): boolean;
  end;

  (**
   * Represents the pointer in a source file.
   * Automatically updates the line and the column.
   *)
  TReaderHead = object
  private
    fLineIndex: Integer;
    fColumnIndex: Integer;
    fAbsoluteIndex: Integer;
    fReaderHead: PChar;
    fPreviousLineColum: Integer;
    function getColAndLine: TPoint;
  public
    constructor Create(const aText: PChar; const aColAndLine: TPoint);
    procedure setReader(const aText: PChar; const aColAndLine: TPoint);
    //
    function Next: PChar;
    function previous: PChar;
    //
    property AbsoluteIndex: Integer read fAbsoluteIndex;
    property LineIndex: Integer read fLineIndex;
    property ColumnIndex: Integer read fColumnIndex;
    property LineAnColumn: TPoint read getColAndLine;
    //
    property head: PChar read fReaderHead;
  end;

  TLexTokenKind = (ltkIllegal, ltkChar, ltkComment, ltkIdentifier, ltkKeyword,
    ltkNumber, ltkOperator, ltkString, ltkSymbol);

const
  LexTokenKindString: array[TLexTokenKind] of string =
    ('Illegal', 'Character', 'Comment', 'Identifier', 'Keyword',
    'Number', 'Operator', 'String', 'Symbol');

type

  (*****************************************************************************
   * Lexer token
   *)
  PLexToken = ^TLexToken;

  TLexToken = record
    position: TPoint;
    kind: TLexTokenKind;
    Data: string;
  end;

  TLexFoundEvent = procedure(const aToken: PLexToken; out doStop: boolean) of Object;

  (*****************************************************************************
   * List of lexer tokens
   *)
  TLexTokenList = class(TFPList)
  private
    function getToken(index: integer): TLexToken;
  public
    procedure Clear;
    procedure addToken(aValue: PLexToken);
    property token[index: integer]: TLexToken read getToken;
  end;

  TLexTokenEnumerator = class
    fList: TLexTokenList;
    fIndex: Integer;
    function GetCurrent: TLexToken;
    function MoveNext: Boolean;
    property Current: TLexToken read GetCurrent;
  end;

  (*****************************************************************************
   * Error record
   *)
  PLexError = ^TLexError;

  TLexError = record
    position: TPoint;
    msg: string;
  end;

  (*****************************************************************************
   * Error list
   *)
  TLexErrorList = class(TFPList)
  private
    function getError(index: integer): TLexError;
  public
    procedure Clear;
    procedure addError(aValue: PLexError);
    property error[index: integer]: TLexError read getError;
  end;

  TLexErrorEnumerator = class
    fList: TLexErrorList;
    fIndex: Integer;
    function GetCurrent: TLexError;
    function MoveNext: Boolean;
    property Current: TLexError read GetCurrent;
  end;

operator enumerator(aTokenList: TLexTokenList): TLexTokenEnumerator;
operator enumerator(anErrorList: TLexErrorList): TLexErrorEnumerator;

  (*****************************************************************************
   * Lexes aText and fills aList with the TLexToken found.
   *)
procedure lex(const aText: string; aList: TLexTokenList; aCallBack: TLexFoundEvent = nil);

  (*****************************************************************************
   * Detects various syntactic errors in a TLexTokenList
   *)
procedure checkSyntacticErrors(const aTokenList: TLexTokenList; const anErrorList: TLexErrorList);

  (*****************************************************************************
   * Outputs the module name from a tokenized D source.
   *)
function getModuleName(const aTokenList: TLexTokenList): string;

  (*****************************************************************************
   * Compares two TPoints.
   *)
operator = (lhs: TPoint; rhs: TPoint): boolean;

implementation

var
  D2Dictionary: TD2Dictionary;

{$REGION TReaderHead------------------------------------------------------------}
operator = (lhs: TPoint; rhs: TPoint): boolean;
begin
  exit((lhs.y = rhs.y) and (lhs.x = rhs.x));
end;

constructor TReaderHead.Create(const aText: PChar; const aColAndLine: TPoint);
begin
  setReader(aText, aColAndLine);
end;

procedure TReaderHead.setReader(const aText: PChar; const aColAndLine: TPoint);
begin
  fLineIndex := aColAndLine.y;
  fColumnIndex := aColAndLine.x;
  fReaderHead := aText;
  while (LineAnColumn <> aColAndLine) do
    Next;
  //
  // editor not 0 based ln index
  if fLineIndex = 0 then
    fLineIndex := 1;
end;

function TReaderHead.getColAndLine: TPoint;
begin
  exit(Point(fColumnIndex, fLineIndex));
end;

function TReaderHead.Next: PChar;
begin
  if (fReaderHead^ = #10) then
  begin
    Inc(fLineIndex);
    fPreviousLineColum := fColumnIndex;
    fColumnIndex := -1;
  end;
  Inc(fReaderHead);
  Inc(fAbsoluteIndex);
  Inc(fColumnIndex);
  exit(fReaderHead);
end;

function TReaderHead.previous: PChar;
begin
  Dec(fReaderHead);
  Dec(fColumnIndex);
  Dec(fAbsoluteIndex);
  if (fReaderHead^ = #10) then
  begin
    Dec(fLineIndex);
    fColumnIndex:= fPreviousLineColum;
  end;
  exit(fReaderHead);
end;
{$ENDREGION}

{$REGION TD2Dictionary----------------------------------------------------------}
constructor TD2Dictionary.Create;
var
  Value: string;
begin
  for Value in D2Kw do
    addEntry(Value);
end;

destructor TD2Dictionary.Destroy;
begin
end;

{$IFDEF DEBUG}{$R-}{$ENDIF}
function TD2Dictionary.toHash(const aValue: string): Byte;
var
  i: Integer;
begin
  Result := 0;
  for i := 1 to length(aValue) do
    Result +=
      (Byte(aValue[i]) shl (4 and (1 - i))) xor 25;
end;

{$IFDEF DEBUG}{$R+}{$ENDIF}

procedure TD2Dictionary.addEntry(const aValue: string);
var
  hash: Byte;
begin
  if find(aValue) then
    exit;
  hash := toHash(aValue);
  fEntries[hash].filled := True;
  setLength(fEntries[hash].values, length(fEntries[hash].values) + 1);
  fEntries[hash].values[high(fEntries[hash].values)] := aValue;
  if fLongest <= length(aValue) then
    fLongest := length(aValue);
  if fShortest >= length(aValue) then
    fShortest := length(aValue);
end;

function TD2Dictionary.find(const aValue: string): boolean;
var
  hash: Byte;
  i: NativeInt;
begin
  Result := False;
  if length(aValue) > fLongest then
    exit;
  if length(aValue) < fShortest then
    exit;
  hash := toHash(aValue);
  if (not fEntries[hash].filled) then
    exit(False);
  for i := 0 to high(fEntries[hash].values) do
    if fEntries[hash].values[i] = aValue then
      exit(True);
end;

{$ENDREGION}

{$REGION Lexing-----------------------------------------------------------------}
function TLexTokenList.getToken(index: integer): TLexToken;
begin
  Result := PLexToken(Items[index])^;
end;

procedure TLexTokenList.Clear;
begin
  while Count > 0 do
  begin
    Dispose(PLexToken(Items[Count - 1]));
    Delete(Count - 1);
  end;
end;

procedure TLexTokenList.addToken(aValue: PLexToken);
begin
  add(Pointer(aValue));
end;

function TLexTokenEnumerator.GetCurrent: TLexToken;
begin
  exit(fList.token[fIndex]);
end;

function TLexTokenEnumerator.MoveNext: Boolean;
begin
  Inc(fIndex);
  exit(fIndex < fList.Count);
end;

operator enumerator(aTokenList: TLexTokenList): TLexTokenEnumerator;
begin
  Result := TLexTokenEnumerator.Create;
  Result.fList := aTokenList;
  Result.fIndex := -1;
end;

{$BOOLEVAL ON}
procedure lex(const aText: string; aList: TLexTokenList; aCallBack: TLexFoundEvent = nil);
var
  reader: TReaderHead;
  identifier: string;
  nestedCom: integer;

  function isOutOfBound: boolean;
  begin
    exit(reader.AbsoluteIndex >= length(aText))
  end;

  procedure addToken(aTk: TLexTokenKind);
  var
    ptk: PLexToken;
  begin
    ptk := new(PLexToken);
    ptk^.kind := aTk;
    ptk^.position := reader.LineAnColumn;
    ptk^.position.X -= length(identifier);
    ptk^.Data := identifier;
    aList.Add(ptk);
  end;

  function callBackDoStop: boolean;
  begin
    Result := False;
    if aCallBack <> nil then
      aCallBack(PLexToken(aList.Items[aList.Count - 1]), Result);
  end;

begin

  if aText = '' then exit;

  reader.Create(@aText[1], Point(0, 0));
  while (True) do
  begin

    if isOutOfBound then
      exit;

    identifier := '';

    // skip blanks
    while isWhite(reader.head^) do
    begin
      if isOutOfBound then
        exit;
      reader.Next;
    end;

    // line comment
    if (reader.head^ = '/') then
    begin
      if (reader.Next^ = '/') then
      begin
        if isOutOfBound then
          exit;
        while (reader.head^ <> #10) do
        begin
          reader.Next;
          identifier += reader.head^;
          if isOutOfBound then
            exit;
        end;
        reader.Next;
        addToken(ltkComment);
        if callBackDoStop then
          exit;
        continue;
      end
      else
        reader.previous;
    end;

    // block comments 1
    if (reader.head^ = '/') then
    begin
      if (reader.Next^ = '*') then
      begin
        if isOutOfBound then
          exit;
        while (reader.head^ <> '*') or (reader.Next^ <> '/') do
          if isOutOfBound then
            exit;
        reader.Next;
        addToken(ltkComment);
        if callBackDoStop then
          exit;
        continue;
      end
      else
        reader.previous;
    end;

    // block comments 2
    if (reader.head^ = '/') then
    begin
      if (reader.Next^ = '+') then
      begin
        nestedCom := 1;
        if isOutOfBound then
          exit;
        repeat
          while ((reader.head^ <> '+') or (reader.head^ <> '/')) or
                ((reader.next^ <> '/') or (reader.head^ <> '+')) do
          begin
            if isOutOfBound then
              exit;
            if ((reader.head-1)^ = '/') and (reader.head^ = '+') then
            begin
              nestedCom += 1;
              break;
            end;
            if ((reader.head-1)^ = '+') and (reader.head^ = '/') then
            begin
              nestedCom -= 1;
              break;
            end;
            if isOutOfBound then
              exit;
          end;
        until nestedCom = 0;
        reader.Next;
        addToken(ltkComment);
        if callBackDoStop then
          exit;
        continue;
      end
      else
        reader.previous;
    end;

    // string 1, note: same escape error as in SynD2Syn
    if (reader.head^ in ['r', 'x']) then
    begin
      if not (reader.Next^ = '"') then
        reader.previous;
    end;
    if (reader.head^ = '"') then
    begin
      reader.Next;
      if isOutOfBound then
        exit;
      if (reader.head^ = '"') then
      begin
        reader.Next;
        addToken(ltkString);
        if callBackDoStop then
          exit;
        continue;
      end;
      while (True) do
      begin
        if reader.head^ = '\' then
        begin
          reader.Next;
          if (reader.head^ = '"') then
          begin
            reader.Next;
            continue;
          end;
        end;
        if (reader.head^ = '"') then
          break;
        identifier += reader.head^;
        reader.Next;
        if isOutOfBound then
          exit;
      end;
      if isStringPostfix(reader.Next^) then
        reader.Next;
      addToken(ltkString);
      if callBackDoStop then
        exit;
      continue;
    end;

    // string 2
    if (reader.head^ = '`') then
    begin
      reader.Next;
      if isOutOfBound then
        exit;
      while (reader.head^ <> '`') do
      begin
        identifier += reader.head^;
        reader.Next;
        if isOutOfBound then
          exit;
      end;
      if isStringPostfix(reader.Next^) then
        reader.Next;
      if isOutOfBound then
        exit;
      addToken(ltkString);
      if callBackDoStop then
        exit;
      continue;
    end;

    // token string
    if (reader.head^ = 'q') and (reader.Next^ = '{') then
    begin
      reader.Next;
      if isOutOfBound then
        exit;
      while (reader.head^ <> '}') do
      begin
        identifier += reader.head^;
        reader.Next;
        if isOutOfBound then
          exit;
      end;
      reader.Next;
      addToken(ltkString);
      if callBackDoStop then
        exit;
      continue;
    end
    else
      reader.previous;

    //chars, note: same escape error as in SynD2Syn
    if (reader.head^ = #39) then
    begin
      reader.Next;
      if isOutOfBound then
        exit;
      if (reader.head^ = #39) then
      begin
        reader.Next;
        addToken(ltkString);
        if callBackDoStop then
          exit;
        continue;
      end;
      while (True) do
      begin
        if reader.head^ = '\' then
        begin
          reader.Next;
          if (reader.head^ = #39) then
          begin
            reader.Next;
            continue;
          end;
        end;
        if (reader.head^ = #39) then
          break;
        identifier += reader.head^;
        reader.Next;
        if isOutOfBound then
          exit;
      end;
      reader.Next;
      addToken(ltkChar);
      if callBackDoStop then
        exit;
      continue;
    end;

    // check negative float '-0.'
    if (reader.head^ = '-') then
    begin
      identifier += reader.head^;
      if reader.Next^ = '0' then
      begin
        if reader.Next^ = '.' then
          reader.previous // back to 0, get into "binary/hex numbr/float"
        else
        begin
          reader.previous;
          reader.previous; // back to -
          identifier := '';
        end;
      end
      else
      begin
        reader.previous; // back to -
        identifier := '';
      end;
    end;

    // + suffixes
    // + exponent
    // float .xxxx

    // binary/hex numbr/float
    if (reader.head^ = '0') then
    begin
      identifier += reader.head^;
      if (reader.Next^ in ['b', 'B']) then
      begin
        identifier += reader.head^;
        while isBit(reader.Next^) or (reader.head^ = '_') do
        begin
          if isOutOfBound then
            exit;
          identifier += reader.head^;
        end;
        addToken(ltkNumber);
        if callBackDoStop then
          exit;
        continue;
      end
      else
        reader.previous;
      if (reader.Next^ in ['x', 'X']) then
      begin
        identifier += reader.head^;
        while isHex(reader.Next^) or (reader.head^ = '_') do
        begin
          if isOutOfBound then
            exit;
          identifier += reader.head^;
        end;
        addToken(ltkNumber);
        if callBackDoStop then
          exit;
        continue;
      end
      else
        reader.previous;
      if (reader.Next^ = '.') then
      begin
        identifier += reader.head^;
        while isNumber(reader.Next^) do
        begin
          if isOutOfBound then
            exit;
          identifier += reader.head^;
        end;
        addToken(ltkNumber);
        if callBackDoStop then
          exit;
        continue;
      end
      else
        reader.previous;
      identifier := '';
    end;

    // check negative float/int '-xxx'
    if (reader.head^ = '-') then
    begin
      identifier += reader.head^;
      if not isNumber(reader.Next^) then
      begin
        reader.previous; // back to '-'
        identifier := '';
      end;
    end;

    // numbers
    if isNumber(reader.head^) then
    begin
      identifier += reader.head^;
      while isNumber(reader.Next^) or (reader.head^ = '_') do
      begin
        if isOutOfBound then
          exit;
        identifier += reader.head^;
      end;
      addToken(ltkNumber);
      if callBackDoStop then
        exit;
      continue;
    end;

    // symbChars
    if isSymbol(reader.head^) then
    begin
      identifier += reader.head^;
      reader.Next;
      addToken(ltkSymbol);
      if callBackDoStop then
        exit;
      if isOutOfBound then
        exit;
      continue;
    end;

    // operators
    if isOperator1(reader.head^) then
    begin
      identifier += reader.head^;
      while isOperator1(reader.Next^) do
      begin
        if isOutOfBound then
          exit;
        identifier += reader.head^;
      end;
      case length(identifier) of
        4:
        begin
          if (not isOperator1(reader.head^)) and
            isOperator4(identifier) then
          begin
            addToken(ltkOperator);
            if callBackDoStop then
              exit;
            continue;
          end;
        end;
        3:
        begin
          if (not isOperator1(reader.head^)) and
            isOperator3(identifier) then
          begin
            addToken(ltkOperator);
            if callBackDoStop then
              exit;
            continue;
          end;
        end;
        2:
        begin
          if (not isOperator1(reader.head^)) and
            isOperator2(identifier) then
          begin
            addToken(ltkOperator);
            if callBackDoStop then
              exit;
            continue;
          end;
        end;
        1:
        begin
          if not isOperator1(reader.head^) then
          begin
            addToken(ltkOperator);
            if callBackDoStop then
              exit;
            continue;
          end;
        end;
      end;
    end;

    // identifier accum
    if isFirstIdentifier(reader.head^) then
    begin
      while isIdentifier(reader.head^) do
      begin
        identifier += reader.head^;
        reader.Next;
        if isOutOfBound then
          exit;
      end;
      if D2Dictionary.find(identifier) then
        addToken(ltkKeyword)
      else
        addToken(ltkIdentifier);
      if callBackDoStop then
        exit;
      continue;
    end;

    // error
    identifier += ' (unrecognized lexer input)';
    addToken(ltkIllegal);

  end;
end;

{$BOOLEVAL OFF}
{$ENDREGION}

{$REGION Syntactic errors}
function TLexErrorList.getError(index: integer): TLexError;
begin
  Result := PLexError(Items[index])^;
end;

procedure TLexErrorList.Clear;
begin
  while Count > 0 do
  begin
    Dispose(PLexError(Items[Count - 1]));
    Delete(Count - 1);
  end;
end;

procedure TLexErrorList.addError(aValue: PLexError);
begin
  add(Pointer(aValue));
end;

function TLexErrorEnumerator.GetCurrent: TLexError;
begin
  exit(fList.error[fIndex]);
end;

function TLexErrorEnumerator.MoveNext: Boolean;
begin
  Inc(fIndex);
  exit(fIndex < fList.Count);
end;

operator enumerator(anErrorList: TLexErrorList): TLexErrorEnumerator;
begin
  Result := TLexErrorEnumerator.Create;
  Result.fList := anErrorList;
  Result.fIndex := -1;
end;

procedure checkSyntacticErrors(const aTokenList: TLexTokenList; const anErrorList: TLexErrorList);
const
  errPrefix = 'syntactic error: ';
var
  tk, old1, old2, lastSignifiant: TLexToken;
  err: PLexError;
  tkIndex: NativeInt;
  pareCnt, curlCnt, squaCnt: NativeInt;
  pareLeft, curlLeft, squaLeft: boolean;

  procedure addError(const aMsg: string);
  begin
    err := new(PLexError);
    err^.msg := errPrefix + aMsg;
    err^.position := aTokenList.token[tkIndex].position;
    anErrorList.addError(err);
  end;

label
  _preSeq;
begin

  tkIndex := -1;
  pareCnt := 0;
  curlCnt := 0;
  squaCnt := 0;
  pareLeft := False;
  curlLeft := False;
  squaLeft := False;
  FillByte(old1, sizeOf(TLexToken), 0);
  FillByte(old2, sizeOf(TLexToken), 0);
  FillByte(lastSignifiant, sizeOf(TLexToken), 0);

  for tk in aTokenList do
  begin
    Inc(tkIndex);

    // brackets count
    if tk.kind = ltkSymbol then
    begin
      case tk.Data of
        '(': Inc(pareCnt);
        '{': Inc(curlCnt);
        '[': Inc(squaCnt);
        ')': Dec(pareCnt);
        '}': Dec(curlCnt);
        ']': Dec(squaCnt);
      end;

      // only for the first occurence
      if not pareLeft then
        if pareCnt = -1 then
        begin
          addError('a left parenthesis is missing');
          pareLeft := True;
        end;
      if not curlLeft then
        if curlCnt = -1 then
        begin
          addError('a left curly bracket is missing');
          curlLeft := True;
        end;
      if not squaLeft then
        if squaCnt = -1 then
        begin
          addError('a left square bracket is missing');
          squaLeft := True;
        end;

      // at the end
      if (tkIndex = aTokenList.Count - 1) then
      begin
        if pareCnt > 0 then
          addError('a right parenthesis is missing');
        if curlCnt > 0 then
          addError('a right curly bracket is missing');
        if squaCnt > 0 then
          addError('a right square bracket is missing');
      end;

      goto _preSeq;
    end;

    // lexer invalid token
    if tk.kind = ltkIllegal then
    begin
      addError(tk.Data);
      goto _preSeq;
    end;

    _preSeq:

      // invalid sequences
      if tkIndex > 0 then
      begin
        // empty statements:
        if (tk.kind = ltkSymbol) and (tk.Data = ';') then
          if (lastSignifiant.kind = ltkSymbol) and (lastSignifiant.Data = ';') then
            addError('invalid syntax for empty statement');
        if tk.kind <> ltkComment then
          lastSignifiant := tk;

        // suspicious double keywords
        if (old1.kind = ltkKeyword) and (tk.kind = ltkKeyword) then
          if old1.Data = tk.Data then
            addError('keyword is duplicated');

        // suspicious double numbers
        if (old1.kind = ltkNumber) and (tk.kind = ltkNumber) then
          addError('symbol or operator expected after number');
      end;
    if tkIndex > 1 then
    begin
    end;

    old1 := tk;
    old2 := old1;
  end;


end;

function getModuleName(const aTokenList: TLexTokenList): string;
var
  ltk: TLexToken;
  mtok: boolean;
begin
  Result := '';
  mtok := False;
  for ltk in aTokenList do
  begin
    if mtok then
    begin
      case ltk.kind of
        ltkIdentifier, ltkKeyword:
          Result += ltk.Data;
        ltkSymbol:
          case ltk.Data of
            '.': Result += ltk.Data;
            ';': exit;
          end;
      end;
    end
    else
    if ltk.kind = ltkKeyword then
      if ltk.Data = 'module' then
        mtok := True;
  end;
end;

{$ENDREGION}

initialization
  D2Dictionary.Create;

finalization
  D2Dictionary.Destroy;
end.
