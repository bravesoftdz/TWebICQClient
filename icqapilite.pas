unit icqapilite;

{ Z.Razor 2012 | zt.am | WebICQClient }
interface

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  Vcl.Dialogs,
  Vcl.ExtCtrls,
  Data.DBXJSON,
  Data.DBXJSONCommon,
  Data.DBXJSONReflect,
  idHttp,
  idsslopenssl,
  idSocks,
  HTTPApp;

type
  TReciveMessageEvent = procedure(Sender: TObject; UIN, Text: String) of object;

type
  TICQContact = record
    UIN: String;
    Name: String;
    Status: String;
  end;

type
  TWebICQClient = class(TComponent)
  private
    FUIN: String;
    FPassword: String;
    FLoggedIn: Boolean;
    FStatus: String;
    FCheckEvents: Boolean;
    FOnMessageRecive: TReciveMessageEvent;
    FOnDisconnect: TNotifyEvent;
    FCheckTimeOut: Integer;
    AimSid: String;
    fetchBaseUrl: String;
    keyA: String;
    keyK: String;
    sessionKey: String;
    jQuery: String;
    HTTP: TidHTTP;
    SSL: TIdSSLIOHandlerSocketOpenSSL;
    SOCK: TIdSocksInfo;
    CheckEventsTimer: TTimer;
    function ReadSockHost: String;
    function ReadSockVersion: TSocksVersion; // idSocks
    function ReadSockPort: Word;
    function ReadAbout: String;
    function ReadUserAgent: String;
    function GenerateRandomjQuery(Prev: String = ''): string;
    function GenerateRandomRequestId: String;
    function GenerateTimeNow: string;
    function GenerateRandom_: string;
    function CreateHTTP(useSSL: Boolean = false): TidHTTP;
    procedure WriteSockPort(const Value: Word);
    procedure WriteSockHost(const Value: String);
    procedure WriteSockVersion(const Value: TSocksVersion);
    procedure DoCheckEvents;
    procedure OnEventsTimer(Sender: TObject);
    procedure SetCheckTimeout(Value: Integer);
    procedure WriteUserAgent(Value: String);
  public
    property LoggedIn: Boolean read FLoggedIn;
    property Status: string read FStatus;
    function SendMessage(aUIN: String; Text: string): Boolean;
    procedure Logout;
    procedure Login; overload;
    procedure Login(ACheckEvents: Boolean); overload;
    procedure Login(aUIN, APassword: string); overload;
    procedure Login(aUIN, APassword: string; ACheckEvents: Boolean); overload;
    procedure Free;
    procedure Clear;
    constructor Create(AOwner: TComponent); override;
  published
    property UIN: String read FUIN write FUIN;
    property Password: String read FPassword write FPassword;
    property CheckTimeOut: Integer read FCheckTimeOut write SetCheckTimeout;
    property CheckEvents: Boolean read FCheckEvents write FCheckEvents default true;
    property UserAgent: String read ReadUserAgent write WriteUserAgent;
    property SockHost: string read ReadSockHost write WriteSockHost;
    property SockPort: Word read ReadSockPort write WriteSockPort default 1080;
    property SockVerion: TSocksVersion read ReadSockVersion write WriteSockVersion default svNoSocks;
    property About: String read ReadAbout;
    property OnMessageRecive: TReciveMessageEvent read FOnMessageRecive write FOnMessageRecive default nil;
    property OnDisconnect: TNotifyEvent read FOnDisconnect write FOnDisconnect default nil;
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

procedure TWebICQClient.Clear;
begin
  CheckEventsTimer.Enabled := false;
  FLoggedIn := false;
  AimSid := '';
  fetchBaseUrl := '';
  keyA := '';
  sessionKey := '';
  jQuery := '';
  FStatus := 'offline'
end;

constructor TWebICQClient.Create(AOwner: TComponent);
begin
  inherited;
  HTTP := TidHTTP.Create;
  HTTP.HandleRedirects := true;
  HTTP.Request.UserAgent := 'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.0)';
  // HTTP.Request.AcceptEncoding := 'gzip, deflate';
  // HTTP.Request.Referer := 'http://wlogin.icq.com/siteim/icqbar///js/partners/html/icqManager_ru.html';
  HTTP.ReadTimeout := HTTP_TIMEOUT;
  HTTP.ConnectTimeout := HTTP_TIMEOUT;
  SSL := TIdSSLIOHandlerSocketOpenSSL.Create;
  SSL.ssloptions.method := sslvSSLv23;
  SSL.ReadTimeout := HTTP_TIMEOUT;
  SSL.ConnectTimeout := HTTP_TIMEOUT;
  SSL.Port := 443;
  HTTP.iohandler := SSL;
  SOCK := TIdSocksInfo.Create;
  SOCK.authentication := sanoauthentication;
  SOCK.version := svNoSocks;
  SSL.transparentproxy := SOCK;
  FCheckTimeOut := 1000;
  FCheckEvents := true;
  CheckEventsTimer := TTimer.Create(nil);
  CheckEventsTimer.Interval := FCheckTimeOut;
  CheckEventsTimer.OnTimer := OnEventsTimer;
  Clear;
  GenerateTimeNow;
end;

function TWebICQClient.CreateHTTP(useSSL: Boolean = false): TidHTTP;
var
  aSSL: TIdSSLIOHandlerSocketOpenSSL;
  aSOCK: TIdSocksInfo;
begin
  Result := TidHTTP.Create;
  Result.HandleRedirects := true;
  Result.Request.UserAgent := HTTP.Request.UserAgent;
  Result.ReadTimeout := HTTP_TIMEOUT;
  Result.ConnectTimeout := HTTP_TIMEOUT;
  if not useSSL then Exit;
  aSSL := TIdSSLIOHandlerSocketOpenSSL.Create(Result);
  aSSL.ssloptions.method := sslvSSLv23;
  aSSL.ReadTimeout := HTTP_TIMEOUT;
  aSSL.ConnectTimeout := HTTP_TIMEOUT;
  aSSL.Port := 443;
  Result.iohandler := aSSL;
  if SOCK.version <> svNoSocks then begin
    aSOCK := TIdSocksInfo.Create(aSSL);
    aSOCK.authentication := sanoauthentication;
    aSOCK.version := SOCK.version;
    aSSL.transparentproxy := aSOCK;
  end;
end;

procedure TWebICQClient.Free;
begin
  FreeAndNil(SOCK);
  FreeAndNil(SSL);
  FreeAndNil(HTTP);
  FreeAndNil(CheckEventsTimer);
  inherited;
end;

function TWebICQClient.GenerateRandomjQuery(Prev: String = ''): string;
var
  val: longint;
begin
  if Result = '' then Exit('16203349351070702583_133' + inttostr(random(900000000) + 1000000000));
  val := strtoint(Copy(Result, Pos('_', Result), Length(Result) - Pos('_', Result) + 1));
  delete(Result, 1, Pos('_', Result));
  Result := Result + inttostr(val + 1);
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

procedure TWebICQClient.Login(ACheckEvents: Boolean);
begin
  FCheckEvents := ACheckEvents;
  Login;
end;

procedure TWebICQClient.Login(aUIN, APassword: string; ACheckEvents: Boolean);
begin
  FCheckEvents := ACheckEvents;
  Login(aUIN, APassword);
end;

procedure TWebICQClient.Logout;
var
  url, page: string;
  HTTP: TidHTTP;
begin
  jQuery := GenerateRandomjQuery(jQuery);
  url := Format(ICQ_LOGOUT_URL, [GenerateRandomRequestId, AimSid, jQuery, GenerateRandom_]);
  HTTP := CreateHTTP((SOCK.version <> svNoSocks));
  try
    page := HTTP.Get(url);
  except
    // on E: Exception do ShowMessage(E.Message);
  end;
  FreeAndNil(HTTP);
  Clear;
  // FOnDisconnect(Self);
end;

procedure TWebICQClient.OnEventsTimer(Sender: TObject);
begin
  DoCheckEvents;
end;

procedure TWebICQClient.Login(aUIN, APassword: string);
begin
  FUIN := aUIN;
  FPassword := APassword;
  Login;
end;

procedure TWebICQClient.Login;

var
  page, url: string;
  json: TJSONObject;
  HTTP: TidHTTP;
begin
  Clear;
  page := '';
  jQuery := GenerateRandomjQuery;
  url := Format(ICQ_LOGIN_URL, [jQuery, FUIN, HTTPEncode(FPassword), GenerateRandom_]);
  HTTP := CreateHTTP(true);
  try
    page := HTTP.Get(url);
  except
    // on E: Exception do ShowMessage(E.Message);
  end;
  FreeAndNil(HTTP);
  FLoggedIn := (Pos('sessionKey', page) > 0);
  if not FLoggedIn then Exit;
  delete(page, 1, Pos('(', page)); // delete jQuery();
  delete(page, Length(page), 1);
  json := TJSONObject.ParseJSONValue(page) as TJSONObject;
  if not Assigned(json) then begin
    FLoggedIn := false;
    Exit;
  end;
  sessionKey := json.Get('sessionKey').JsonValue.Value;
  keyK := json.Get('k').JsonValue.Value;
  AimSid := json.Get('aimsid').JsonValue.Value;
  fetchBaseUrl := StringReplace(json.Get('fetchBaseURL').JsonValue.Value, '\', '', [rfReplaceAll]);
  keyA := json.Get('a').JsonString.Value;
  FStatus := TJSONObject(json.Get('myInfo').JsonValue).Get('state').JsonString.Value;
  if FCheckEvents then CheckEventsTimer.Enabled := true;
  FreeAndNil(json);
  // DoCheckEvents;
end;

procedure TWebICQClient.DoCheckEvents;
var
  url, page, msg, suin, newfetchurl: string;
  json, event: TJSONObject;
  events: TJSONArray;
  i: Integer;
begin
  CheckEventsTimer.Enabled := false;
  try
    page := '';
    jQuery := GenerateRandomjQuery(jQuery);
    url := Format(fetchBaseUrl + ICQ_FETCH_EVENT_URL, [GenerateRandomRequestId, jQuery, GenerateRandom_]);
    try
      page := HTTP.Get(url);
    except
      // on E: Exception do ShowMessage(E.Message);
    end;
    if Pos('"statusText":"Authentication Required"', page) > 0 then begin
      Clear;
      // FOnDisconnect(Self);
      Exit;
    end;
    if Pos('"statusText":"OK"', page) = 0 then Exit;
    delete(page, 1, Pos('(', page)); // delete jQuery();
    delete(page, Length(page), 1);
    json := TJSONObject.ParseJSONValue(page) as TJSONObject;
    if not Assigned(json) then Exit;
    events := TJSONArray(TJSONObject(TJSONObject(json.Get('response').JsonValue).Get('data').JsonValue).Get('events')
      .JsonValue);
    newfetchurl := TJSONObject(TJSONObject(json.Get('response').JsonValue).Get('data').JsonValue).Get('fetchBaseURL')
      .JsonValue.Value;
    if newfetchurl <> '' then fetchBaseUrl := newfetchurl;
    if not Assigned(events) then Exit;
    for i := 0 to events.Size - 1 do begin
      event := TJSONObject(events.Get(i));
      if not Assigned(event) then break;
      if event.Get('type').JsonValue.Value = 'im' then begin
        msg := TJSONObject(event.Get('eventData').JsonValue).Get('message').JsonValue.Value;
        suin := TJSONObject(TJSONObject(event.Get('eventData').JsonValue).Get('source').JsonValue).Get('aimId')
          .JsonValue.Value;
        OnMessageRecive(Self, suin, msg);
      end;
    end;
    FreeAndNil(json);
  finally
    CheckEventsTimer.Enabled := true;
  end;
end;

function TWebICQClient.SendMessage(aUIN, Text: string): Boolean;
var
  url, page: string;
  HTTP: TidHTTP;
begin
  Result := false;
  page := '';
  jQuery := GenerateRandomjQuery(jQuery);
  url := Format(ICQ_SENDIM_URL, [GenerateRandomRequestId, AimSid, jQuery, aUIN, HTTPEncode(AnsiToUtf8(Text)),
    GenerateTimeNow, GenerateRandom_]);
  HTTP := CreateHTTP((SOCK.version <> svNoSocks));
  try
    page := HTTP.Get(url);
  except
    // on E: Exception do ShowMessage(E.Message);
  end;
  FreeAndNil(HTTP);
  Result := (Pos('"statusCode":200', page) > 0);
end;

procedure TWebICQClient.SetCheckTimeout(Value: Integer);
begin
  FCheckTimeOut := Value;
  CheckEventsTimer.Interval := FCheckTimeOut;
end;

function TWebICQClient.ReadAbout: String;
begin
  Result := 'ZRazor - 2012 - ZerverTeam';
end;

function TWebICQClient.ReadSockHost: String;
begin
  Result := SOCK.Host;
end;

function TWebICQClient.ReadSockPort: Word;
begin
  Result := SOCK.Port;
end;

function TWebICQClient.ReadSockVersion: TSocksVersion;
begin
  Result := SOCK.version;
end;

function TWebICQClient.ReadUserAgent: String;
begin
  Result := HTTP.Request.UserAgent;
end;

procedure TWebICQClient.WriteSockHost(const Value: String);
begin
  SOCK.Host := Value;
end;

procedure TWebICQClient.WriteSockPort(const Value: Word);
begin
  SOCK.Port := Value;
end;

procedure TWebICQClient.WriteSockVersion(const Value: TSocksVersion);
begin
  SOCK.version := Value;
end;

procedure TWebICQClient.WriteUserAgent(Value: String);
begin
  HTTP.Request.UserAgent := Value;
end;

procedure Register;
begin
  RegisterComponents('ZerverTeam', [TWebICQClient]);
end;

end.
