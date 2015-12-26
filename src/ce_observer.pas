unit ce_observer;

{$I ce_defines.inc}

interface

uses
  Classes, SysUtils, Contnrs;

type

  (**
   * interface for a single Coedit service (many to one relation).
   * A service is valid during the whole application life-time and
   * is mostly designed to avoid messy uses clauses or to limit
   * the visibility of the implementer methods.
   *)
  ICESingleService = interface
    function singleServiceName: string;
  end;

  (**
   * Manages the connections between the observers and their subjects in the
   * whole program.
   *)
  TCEEntitiesConnector = class
  private
    fObservers: TObjectList;
    fSubjects: TObjectList;
    fServices: TObjectList;
    fUpdatesCount: Integer;
    procedure tryUpdate;
    procedure updateEntities;
    function getIsUpdating: boolean;
  public
    constructor Create;
    destructor Destroy; override;
    // forces the update, fixes begin/add pair error or if immediate update is needed.
    procedure forceUpdate;
    // entities will be added in bulk, must be followed by an enUpdate().
    procedure beginUpdate;
    // entities has ben added in bulk
    procedure endUpdate;
    // add/remove entities, update is automatic
    procedure addObserver(anObserver: TObject);
    procedure addSubject(aSubject: TObject);
    procedure removeObserver(anObserver: TObject);
    procedure removeSubject(aSubject: TObject);
    // allow to register a single service provider.
    procedure addSingleService(aServiceProvider: TObject);
    // allow to retrieve a single service provider based on its interface name
    function getSingleService(const aName: string): TObject;
    // should be tested before forceUpdate()
    property isUpdating: boolean read getIsUpdating;
  end;



  (**
   * Interface for a Coedit subject. Basically designed to hold a list of observer
   *)
  ICESubject = interface
    // an observer is proposed. anObserver is not necessarly compatible.
    procedure addObserver(anObserver: TObject);
    // anObserver must be removed.
    procedure removeObserver(anObserver: TObject);
    // optionally implemented to trigger all the methods of the observer interface.
    procedure updateObservers;
  end;

  // Base type for an interface that contains the methods of a subject.
  ISubjectType = interface
  end;

  (**
   * Standard implementation of an ICESubject.
   * Any descendant adds itself to the global EntitiesConnector.
   *)
  generic TCECustomSubject<T:ISubjectType> = class(ICESubject)
  protected
    fObservers: TObjectList;
    // test for a specific interface when adding an observer.
    function acceptObserver(aObject: TObject): boolean;
    function getObserversCount: Integer;
    function getObserver(index: Integer): TObject;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    //
    procedure addObserver(anObserver: TObject);
    procedure removeObserver(anObserver: TObject);
    procedure updateObservers; virtual;
    //
    property observersCount: Integer read getObserversCount;
    property observers[index: Integer]: TObject read getObserver; default;
  end;

var
  EntitiesConnector: TCEEntitiesConnector = nil;

implementation

uses
  LCLProc;

{$REGION TCEEntitiesConnector --------------------------------------------------}
constructor TCEEntitiesConnector.Create;
begin
  fObservers := TObjectList.Create(False);
  fSubjects := TObjectList.Create(False);
  fServices := TObjectList.Create(False);
end;

destructor TCEEntitiesConnector.Destroy;
begin
  fObservers.Free;
  fSubjects.Free;
  fServices.Free;
  inherited;
end;

function TCEEntitiesConnector.getIsUpdating: boolean;
begin
  exit(fUpdatesCount > 0);
end;

procedure TCEEntitiesConnector.tryUpdate;
begin
  {$IFDEF DEBUG}
  if fUpdatesCount > 0 then
    DebugLn('saved uselless update in TCEEntitiesConnector')
  else
    DebugLn('efficient update in TCEEntitiesConnector');
  {$ENDIF}
  if fUpdatesCount <= 0 then
    updateEntities;
end;

procedure TCEEntitiesConnector.forceUpdate;
begin
  updateEntities;
end;

procedure TCEEntitiesConnector.updateEntities;
var
  i, j: Integer;
begin
  fUpdatesCount := 0;
  for i := 0 to fSubjects.Count - 1 do
  begin
    if not (fSubjects[i] is ICESubject) then
      continue;
    for j := 0 to fObservers.Count - 1 do
    begin
      if fSubjects[i] <> fObservers[j] then
        (fSubjects[i] as ICESubject).addObserver(fObservers[j]);
    end;
  end;
end;

procedure TCEEntitiesConnector.beginUpdate;
begin
  fUpdatesCount += 1;
end;

procedure TCEEntitiesConnector.endUpdate;
begin
  fUpdatesCount -= 1;
  tryUpdate;
end;

procedure TCEEntitiesConnector.addObserver(anObserver: TObject);
begin
  if fObservers.IndexOf(anObserver) <> -1 then
    exit;
  fObservers.Add(anObserver);
  tryUpdate;
end;

procedure TCEEntitiesConnector.addSubject(aSubject: TObject);
begin
  if (aSubject as ICESubject) = nil then
    exit;
  if fSubjects.IndexOf(aSubject) <> -1 then
    exit;
  fSubjects.Add(aSubject);
  tryUpdate;
end;

procedure TCEEntitiesConnector.removeObserver(anObserver: TObject);
var
  i: Integer;
begin
  fObservers.Remove(anObserver);
  for i := 0 to fSubjects.Count - 1 do
    if fSubjects[i] <> nil then
      (fSubjects[i] as ICESubject).removeObserver(anObserver);
  tryUpdate;
end;

procedure TCEEntitiesConnector.removeSubject(aSubject: TObject);

begin
  fSubjects.Remove(aSubject);
  tryUpdate;
end;

procedure TCEEntitiesConnector.addSingleService(aServiceProvider: TObject);
begin
  if fServices.IndexOf(aServiceProvider) <> -1 then
    exit;
  if not (aServiceProvider is ICESingleService) then
    exit;
  fServices.Add(aServiceProvider);
end;

function TCEEntitiesConnector.getSingleService(const aName: string): TObject;
var
  i: Integer;
  serv: ICESingleService;
begin
  Result := nil;
  for i := 0 to fServices.Count - 1 do
  begin
    serv := fServices[i] as ICESingleService;
    if serv.singleServiceName = aName then
      exit(fServices[i]);
  end;
end;

{$ENDREGION}

{$REGION TCECustomSubject ------------------------------------------------------}
constructor TCECustomSubject.Create;
begin
  fObservers := TObjectList.Create(False);
  EntitiesConnector.addSubject(Self);
end;

destructor TCECustomSubject.Destroy;
begin
  EntitiesConnector.removeSubject(Self);
  fObservers.Free;
  Inherited;
end;

function TCECustomSubject.acceptObserver(aObject: TObject): boolean;
begin
  exit(aObject is T);
end;

function TCECustomSubject.getObserversCount: Integer;
begin
  exit(fObservers.Count);
end;

function TCECustomSubject.getObserver(index: Integer): TObject;
begin
  exit(fObservers.Items[index]);
end;

procedure TCECustomSubject.addObserver(anObserver: TObject);
begin
  if not acceptObserver(anObserver) then
    exit;
  if fObservers.IndexOf(anObserver) <> -1 then
    exit;
  fObservers.Add(anObserver);
end;

procedure TCECustomSubject.removeObserver(anObserver: TObject);
begin
  fObservers.Remove(anObserver);
end;

procedure TCECustomSubject.updateObservers;
begin
end;

{$ENDREGION}

initialization
  EntitiesConnector := TCEEntitiesConnector.Create;
  EntitiesConnector.beginUpdate;

finalization
  EntitiesConnector.Free;
  EntitiesConnector := nil;
end.
