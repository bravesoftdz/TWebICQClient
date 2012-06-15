unit icqapilite;

{ Z.Razor 2012 | zt.am | WebICQClient }

interface

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  Data.DBXJSON,
  HTTPApp,
  httptools,
  icqtimer;

type
  TICQGroup = record
    Name: String;
    ID: String;
  end;

  TICQContact = record
    AimID: String;
    DisplayID: String;
    Friendly: String;
    State: String;
    UserType: String;
    StatusMsg: String;
    Group: TICQGroup;
  end;

  TICQMessage = record
    MsgText: String;
    MsgId: String;
    TimeStamp: String;
    Contact: TICQContact;
  end;

  TArrayOfICQContact = array of TICQContact;
  TArrayOfICQGroup = array of TICQGroup;

type
  TReciveMessageEvent = procedure(Sender: TObject; Msg: TICQMessage) of object;
  TLoginEvent = procedure(Sender: TObject; Connected: Boolean) of object;

type
  TWebICQClient = class(TComponent)
  private
    FUIN: String;
    FPassword: String;
    FConnected: Boolean;
    FStatus: String;
    FAutoCheckEvents: Boolean;
    FOnMessageRecive: TReciveMessageEvent;
    FOnDisconnect: TNotifyEvent;
    FOnLogin: TLoginEvent;
    FOnUpdateContactList: TNotifyEvent;
    FCheckTimeOut: Integer;
    AimSid: String;
    FetchBaseUrl: String;
    KeyA: String;
    KeyK: String;
    SessionKey: String;
    jQuery: String;
    CheckEventsTimer: TICQTimer;
    FContacts: TArrayOfICQContact;
    FGroups: TArrayOfICQGroup;
    FMyInfo: TICQContact;
    CheckEventsInProgress: Boolean;
    function ReadAbout: String;
    function GenerateRandomjQuery(Prev: String = ''): string;
    function GenerateRandomRequestId: String;
    function GenerateTimeNow: string;
    function GenerateRandom_: string;
    function AddContact(AContact: TICQContact; AGroup: TICQGroup): Integer;
    function AddGroup(AGroup: TICQGroup): Integer;
    function DeleteContact(Index: Integer): Boolean; overload;
    function DeleteContact(ADisplayID: String): Boolean; overload;
    function GetContact(Index: Integer): TICQContact;
    function GetGroup(Index: Integer): TICQGroup;
    function GetContactsCount: Integer;
    function GetGroupsCount: Integer;
    function ExtractICQContact(json: TJSONValue): TICQContact;
    procedure ClearContacts;
    procedure DoCheckEvents;
    procedure OnCheckEventsTimer(Sender: TObject);
    procedure SetCheckTimeout(Value: Integer);
  public
    property MyInfo: TICQContact read FMyInfo;
    property Connected: Boolean read FConnected;
    property Status: string read FStatus;
    property Contacts[Index: Integer]: TICQContact read GetContact;
    property ContactsCount: Integer read GetContactsCount;
    property Groups[Index: Integer]: TICQGroup read GetGroup;
    property GroupsCount: Integer read GetGroupsCount;
    function SendMessage(AUIN: String; Text: string): Boolean;
    function Logout: Boolean;
    function Login: Boolean; overload;
    function Login(AAutoCheckEvents: Boolean): Boolean; overload;
    function Login(AUIN, APassword: string): Boolean; overload;
    function Login(AUIN, APassword: string; AAutoCheckEvents: Boolean): Boolean; overload;
    procedure Free;
    procedure Clear;
    procedure CheckEvents;
    constructor Create(AOwner: TComponent); override;
  published
    property UIN: String read FUIN write FUIN;
    property Password: String read FPassword write FPassword;
    property CheckTimeOut: Integer read FCheckTimeOut write SetCheckTimeout default 1000;
    property AutoCheckEvents: Boolean read FAutoCheckEvents write FAutoCheckEvents default true;
    property About: String read ReadAbout;
    property OnMessageRecive: TReciveMessageEvent read FOnMessageRecive write FOnMessageRecive;
    property OnDisconnect: TNotifyEvent read FOnDisconnect write FOnDisconnect;
    property OnLogin: TLoginEvent read FOnLogin write FOnLogin;
    property OnUpdateContactList: TNotifyEvent read FOnUpdateContactList write FOnUpdateContactList;
  end;

procedure Register;

implementation

const
  ICQ_LOGIN_URL = // jQuery,username,password , _
    'https://wlogin.icq.com/siteim/icqbar/php/proxy_jsonp.php?sk=0.36625886284782827&callback=%s&username=%s&password=%s&time=1338211224&remember=1&_=%s';
  ICQ_SENDIM_URL = // requestId,aimsid,jQuery,toUIN,message, _
    'http://api.icq.net/im/sendIM?f=json&r=%s&aimsid=%s&c=%s&t=%s&message=%s&time=%s&offlineIM=true&autoResponse=false&id=18&_=%s';
  ICQ_LOGOUT_URL = // requestId,aimsid,jQuery , _
    'http://api.icq.net/aim/endSession?f=json&r=%s&aimsid=%s&c=%s&_=%s';
  ICQ_FETCH_EVENT_URL = // requestID,jQuery , _
    '&f=json&timeout=30000&r=%s&c=%s&_=%s';
  HTTP_TIMEOUT = 10000;

  { TWebICQClient }

function TWebICQClient.AddContact(AContact: TICQContact; AGroup: TICQGroup): Integer;
begin
  SetLength(FContacts, Length(FContacts) + 1);
  FContacts[High(FContacts)] := AContact;
  FContacts[High(FContacts)].Group := AGroup;
  Result := High(FContacts);
end;

function TWebICQClient.AddGroup(AGroup: TICQGroup): Integer;
begin
  SetLength(FGroups, Length(FGroups) + 1);
  FGroups[High(FGroups)] := AGroup;
  Result := High(FGroups);
end;

procedure TWebICQClient.CheckEvents;
begin
  if FConnected then DoCheckEvents;
end;

procedure TWebICQClient.Clear;
begin
  CheckEventsTimer.Enabled := false;
  FConnected := false;
  AimSid := '';
  FetchBaseUrl := '';
  KeyA := '';
  SessionKey := '';
  jQuery := '';
  FStatus := 'offline';
  ClearContacts; // !
end;

procedure TWebICQClient.ClearContacts;
begin
  SetLength(FContacts, 0);
end;

constructor TWebICQClient.Create(AOwner: TComponent);
begin
  inherited;
  FCheckTimeOut := 1000;
  FAutoCheckEvents := true;
  CheckEventsTimer := TICQTimer.Create;
  CheckEventsTimer.Interval := FCheckTimeOut;
  // CheckEventsTimer.Priority := tpIdle;
  // CheckEventsTimer.KeepAlive := true;
  CheckEventsTimer.OnTimer := OnCheckEventsTimer;
  Clear;
  GenerateTimeNow;
end;

procedure TWebICQClient.Free;
begin
  inherited;
end;

function TWebICQClient.GenerateRandomjQuery(Prev: String = ''): string;
var
  v: longint;
begin
  if Result = '' then Exit('16203349351070702583_133' + inttostr(random(900000000) + 1000000000));
  v := strtoint(Copy(Result, Pos('_', Result), Length(Result) - Pos('_', Result) + 1));
  delete(Result, 1, Pos('_', Result));
  Result := Result + inttostr(v + 1);
end;

function TWebICQClient.GenerateRandomRequestId: String;
begin
  Result := '0.' + inttostr(random(9000000) + 10000000) + inttostr(random(90000000) + 100000000);
end;

function TWebICQClient.GenerateRandom_: string;
begin
  Result := '13382' + inttostr(random(9000000) + 10000000);
end;

function TWebICQClient.GenerateTimeNow: string;
begin
  Result := StringReplace(DateToStr(now), ':', '/', [rfReplaceAll]);
  Result := StringReplace(Result, '.', '/', [rfReplaceAll]);
  Result := Result + '%20' + timetostr(now);
  delete(Result, Length(Result) - 3, 4);
end;

function TWebICQClient.GetContact(Index: Integer): TICQContact;
begin
  if (Index < 0) or (Index > High(FContacts)) then Exit;
  Result := FContacts[Index];
end;

function TWebICQClient.GetContactsCount: Integer;
begin
  Result := Length(FContacts);
end;

function TWebICQClient.GetGroup(Index: Integer): TICQGroup;
begin
  if (Index < 0) or (Index > High(FGroups)) then Exit;
  Result := FGroups[Index];
end;

function TWebICQClient.GetGroupsCount: Integer;
begin
  Result := Length(FGroups);
end;

function TWebICQClient.Logout: Boolean;
var
  URL: string;
  Response: AnsiString;
  ResponseCode: Integer;
begin
  Result := false;
  jQuery := GenerateRandomjQuery(jQuery);
  URL := Format(ICQ_LOGOUT_URL, [GenerateRandomRequestId, AimSid, jQuery, GenerateRandom_]);
  ResponseCode := Https_get(GetServerFromUrl(URL), GetResourceFromUrl(URL), Response);
  Clear;
  // FOnDisconnect(Self);
end;

procedure TWebICQClient.OnCheckEventsTimer(Sender: TObject);
begin
  // CheckEventsTimer.Enabled := false;
  DoCheckEvents;
  // CheckEventsTimer.Enabled := true;
end;

function TWebICQClient.Login(AUIN, APassword: string): Boolean;
begin
  FUIN := AUIN;
  FPassword := APassword;
  Login;
end;

function TWebICQClient.Login(AAutoCheckEvents: Boolean): Boolean;
begin
  FAutoCheckEvents := AAutoCheckEvents;
  Login;
end;

function TWebICQClient.Login(AUIN, APassword: string; AAutoCheckEvents: Boolean): Boolean;
begin
  FAutoCheckEvents := AAutoCheckEvents;
  Login(AUIN, APassword);
end;

function TWebICQClient.Login: Boolean;
var
  URL: string;
  Response: AnsiString;
  ResponseCode: Integer;
  json: TJSONObject;
begin
  Result := false;
  Clear;
  jQuery := GenerateRandomjQuery;
  URL := Format(ICQ_LOGIN_URL, [jQuery, HTTPEncode(FUIN), FPassword, GenerateRandom_]);
  ResponseCode := Https_get(GetServerFromUrl(URL), GetResourceFromUrl(URL), Response);
  FConnected := (Pos('sessionKey', Response) > 0);
  if not FConnected then Exit;
  delete(Response, 1, Pos('(', Response)); // delete jQuery();
  delete(Response, Length(Response), 1);
  json := TJSONObject.ParseJSONValue(Response) as TJSONObject;
  if not Assigned(json) then begin
    FConnected := false;
    // FOnLogin(self, true);
    Exit;
  end;
  SessionKey := json.Get('sessionKey').JsonValue.Value;
  KeyK := json.Get('k').JsonValue.Value;
  AimSid := json.Get('aimsid').JsonValue.Value;
  FetchBaseUrl := StringReplace(json.Get('fetchBaseURL').JsonValue.Value, '\', '', [rfReplaceAll]);
  KeyA := json.Get('a').JsonString.Value;
  FStatus := TJSONObject(json.Get('myInfo').JsonValue).Get('state').JsonString.Value;
  FreeAndNil(json);
  if FAutoCheckEvents then CheckEventsTimer.Enabled := true;
  Result := true;
  // DoCheckEvents;
end;

function TWebICQClient.DeleteContact(Index: Integer): Boolean;
var
  i: Integer;
begin
  Result := true;
  if (Index < 0) or (Index > High(FContacts)) then Exit(false);
  for i := Index to High(FContacts) - 1 do FContacts[i] := FContacts[i + 1];
  SetLength(FContacts, Length(FContacts) - 1);
end;

function TWebICQClient.DeleteContact(ADisplayID: String): Boolean;
var
  i: Integer;
begin
  Result := false;
  for i := 0 to High(FContacts) do
    if FContacts[i].DisplayID = ADisplayID then Exit(DeleteContact(i));
end;

procedure TWebICQClient.DoCheckEvents;
var
  URL, NewFetchUrl, EventType: string;
  NewMsg: TICQMessage;
  NewGroup: TICQGroup;
  NewContact: TICQContact;
  Response: String;
  json, Event, eventData, Group, Buddy: TJSONObject;
  Events, Groups, Buddies: TJSONArray;
  i, j, k: Integer;
  ContactsAdded: Boolean;
begin
  if not FConnected then Exit;
  if CheckEventsInProgress then Exit;
  try
    CheckEventsInProgress := true;
    ContactsAdded := false;
    jQuery := GenerateRandomjQuery(jQuery);
    URL := Format(FetchBaseUrl + ICQ_FETCH_EVENT_URL, [GenerateRandomRequestId, jQuery, GenerateRandom_]);
    Http_Get(URL, Response);
    if Pos('"statusText":"Authentication Required"', Response) > 0 then begin
      Clear;
      FOnDisconnect(self);
      Exit;
    end;
    if Pos('"statusText":"OK"', Response) = 0 then Exit;
    delete(Response, 1, Pos('(', Response)); // delete jQuery();
    delete(Response, Length(Response), 1);
    try
      json := TJSONObject.ParseJSONValue(Response) as TJSONObject;
    except
    end;
    if not Assigned(json) then Exit;
    Events := TJSONArray(TJSONObject(TJSONObject(json.Get('response').JsonValue).Get('data').JsonValue).Get('events')
      .JsonValue);
    NewFetchUrl := TJSONObject(TJSONObject(json.Get('response').JsonValue).Get('data').JsonValue).Get('fetchBaseURL')
      .JsonValue.Value;
    if NewFetchUrl <> '' then FetchBaseUrl := NewFetchUrl;
    if not Assigned(Events) then Exit;
    for i := 0 to Events.Size - 1 do begin
      Event := TJSONObject(Events.Get(i));
      EventType := Event.Get('type').JsonValue.Value;
      if EventType = 'im' then begin
        eventData := TJSONObject(Event.Get('eventData').JsonValue);
        NewMsg.MsgText := eventData.Get('message').JsonValue.Value;
        NewMsg.MsgId := eventData.Get('msgId').JsonValue.Value;
        NewMsg.TimeStamp := eventData.Get('timestamp').JsonValue.Value;
        NewMsg.Contact := ExtractICQContact(eventData.Get('source').JsonValue);
        FOnMessageRecive(self, NewMsg);
      end
      else if EventType = 'buddylist' then begin
        Groups := TJSONArray(TJSONObject(Event.Get('eventData').JsonValue).Get('groups').JsonValue);
        for j := 0 to Groups.Size - 1 do begin
          Group := TJSONObject(Groups.Get(j));
          NewGroup.Name := Group.Get('name').JsonValue.Value;
          NewGroup.ID := Group.Get('id').JsonValue.Value;
          AddGroup(NewGroup);
          Buddies := TJSONArray(Group.Get('buddies').JsonValue);
          if Buddies.Size > 0 then ContactsAdded := true;
          for k := 0 to Buddies.Size - 1 do AddContact(ExtractICQContact(Buddies.Get(k)), NewGroup);
        end;
      end
      else if EventType = 'myInfo' then begin
        FMyInfo := ExtractICQContact(Event.Get('eventData').JsonValue);
      end;
    end;
    FreeAndNil(json);
  finally
    CheckEventsInProgress := false;
    if ContactsAdded then FOnUpdateContactList(self);
  end;
end;

function TWebICQClient.ExtractICQContact(json: TJSONValue): TICQContact;
begin
  with Result, TJSONObject(json) do begin
    AimID := Get('aimId').JsonValue.Value;
    DisplayID := Get('displayId').JsonValue.Value;
    Friendly := Get('friendly').JsonValue.Value;
    State := Get('state').JsonValue.Value;
    UserType := Get('userType').JsonValue.Value;
    if Pos('statusMsg', json.Value) > 0 then StatusMsg := Get('statusMsg').JsonValue.Value;
  end;
end;

function TWebICQClient.SendMessage(AUIN, Text: string): Boolean;
var
  URL: string;
  Response: String;
begin
  Result := false;
  jQuery := GenerateRandomjQuery(jQuery);
  URL := Format(ICQ_SENDIM_URL, [GenerateRandomRequestId, AimSid, jQuery, HTTPEncode(AUIN),
    HTTPEncode(AnsiToUtf8(Text)), GenerateTimeNow, GenerateRandom_]);
  Http_Get(URL, Response);
  Result := (Pos('"statusCode":200', Response) > 0);
end;

procedure TWebICQClient.SetCheckTimeout(Value: Integer);
begin
  FCheckTimeOut := Value;
  CheckEventsTimer.Interval := FCheckTimeOut;
  CheckEventsTimer.Enabled := FAutoCheckEvents;
end;

function TWebICQClient.ReadAbout: String;
begin
  Result := 'ZRazor - 2012 - ZT.AM';
end;

procedure Register;
begin
  RegisterComponents('ZerverTeam', [TWebICQClient]);
end;

end.
