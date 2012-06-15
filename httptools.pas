unit httptools;

interface

uses
  System.SysUtils,
  System.Classes,
  Winapi.WinInet,
  Winapi.Windows;

function Https_Get(const ServerName, Resource: string; Var Response: AnsiString): Integer;
function GetServerFromUrl(s: string): string;
function GetResourceFromUrl(s: string): string;
function Http_Get(const Url: string): string; overload;
procedure Http_Get(const Url: string; Stream: TStream); overload;

implementation

const
  sUserAgent = 'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.0)';

function GetServerFromUrl(s: string): string;
begin
  Delete(s, 1, pos('//', s) + 1);
  s := Copy(s, 1, pos('/', s) - 1);
  Result := s;
end;

function GetResourceFromUrl(s: string): string;
begin
  Delete(s, 1, pos('//', s) + 1);
  Delete(s, 1, pos('/', s) - 1);
  Result := s;
end;

// this function translate a WinInet Error Code to a description of the error.
function GetWinInetError(ErrorCode: Cardinal): string;
const
  winetdll = 'wininet.dll';
var
  Len: Integer;
  Buffer: PChar;
begin
  Len := FormatMessage(FORMAT_MESSAGE_FROM_HMODULE or FORMAT_MESSAGE_FROM_SYSTEM or FORMAT_MESSAGE_ALLOCATE_BUFFER or
    FORMAT_MESSAGE_IGNORE_INSERTS or FORMAT_MESSAGE_ARGUMENT_ARRAY, Pointer(GetModuleHandle(winetdll)), ErrorCode, 0,
    @Buffer, SizeOf(Buffer), nil);
  try
    while (Len > 0) and {$IFDEF UNICODE}(CharInSet(Buffer[Len - 1], [#0 .. #32, '.']))
{$ELSE}(Buffer[Len - 1] in [#0 .. #32, '.']) {$ENDIF} do Dec(Len);
    SetString(Result, Buffer, Len);
  finally
    LocalFree(HLOCAL(Buffer));
  end;
end;

// make a GET request using the WinInet functions
function Https_Get(const ServerName, Resource: string; Var Response: AnsiString): Integer;
const
  BufferSize = 1024 * 64;
var
  hInet: HINTERNET;
  hConnect: HINTERNET;
  hRequest: HINTERNET;
  ErrorCode: Integer;
  lpvBuffer: PAnsiChar;
  lpdwBufferLength: DWORD;
  lpdwReserved: DWORD;
  dwBytesRead: DWORD;
  lpdwNumberOfBytesAvailable: DWORD;
begin
  Result := 0;
  Response := '';
  hInet := InternetOpen(PChar(sUserAgent), INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);

  if hInet = nil then begin
    ErrorCode := GetLastError;
    raise Exception.Create(Format('InternetOpen Error %d Description %s', [ErrorCode, GetWinInetError(ErrorCode)]));
  end;

  try
    hConnect := InternetConnect(hInet, PChar(ServerName), INTERNET_DEFAULT_HTTPS_PORT, nil, nil,
      INTERNET_SERVICE_HTTP, 0, 0);
    if hConnect = nil then begin
      ErrorCode := GetLastError;
      raise Exception.Create(Format('InternetConnect Error %d Description %s',
        [ErrorCode, GetWinInetError(ErrorCode)]));
    end;

    try
      // make the request
      hRequest := HttpOpenRequest(hConnect, 'GET', PChar(Resource), HTTP_VERSION, '', nil, INTERNET_FLAG_SECURE, 0);
      if hRequest = nil then begin
        ErrorCode := GetLastError;
        raise Exception.Create(Format('HttpOpenRequest Error %d Description %s',
          [ErrorCode, GetWinInetError(ErrorCode)]));
      end;

      try
        // send the GET request
        if not HttpSendRequest(hRequest, nil, 0, nil, 0) then begin
          ErrorCode := GetLastError;
          raise Exception.Create(Format('HttpSendRequest Error %d Description %s',
            [ErrorCode, GetWinInetError(ErrorCode)]));
        end;

        lpdwBufferLength := SizeOf(Result);
        lpdwReserved := 0;
        // get the status code
        if not HttpQueryInfo(hRequest, HTTP_QUERY_STATUS_CODE or HTTP_QUERY_FLAG_NUMBER, @Result, lpdwBufferLength,
          lpdwReserved) then begin
          ErrorCode := GetLastError;
          raise Exception.Create(Format('HttpQueryInfo Error %d Description %s',
            [ErrorCode, GetWinInetError(ErrorCode)]));
        end;

        if Result = 200 then // read the body response in case which the status code is 200
          if InternetQueryDataAvailable(hRequest, lpdwNumberOfBytesAvailable, 0, 0) then begin
            GetMem(lpvBuffer, lpdwBufferLength);
            try
              SetLength(Response, lpdwNumberOfBytesAvailable);
              InternetReadFile(hRequest, @Response[1], lpdwNumberOfBytesAvailable, dwBytesRead);
            finally
              FreeMem(lpvBuffer);
            end;
          end else begin
            ErrorCode := GetLastError;
            raise Exception.Create(Format('InternetQueryDataAvailable Error %d Description %s',
              [ErrorCode, GetWinInetError(ErrorCode)]));
          end;

      finally
        InternetCloseHandle(hRequest);
      end;
    finally
      InternetCloseHandle(hConnect);
    end;
  finally
    InternetCloseHandle(hInet);
  end;
end;

procedure Http_Get(const Url: string; Stream: TStream); overload;
const
  BuffSize = 1024 * 1024;
var
  hInter: HINTERNET;
  UrlHandle: HINTERNET;
  BytesRead: DWORD;
  Buffer: Pointer;
begin
  hInter := InternetOpen('', INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
  if Assigned(hInter) then
    try
      Stream.Seek(0, 0);
      GetMem(Buffer, BuffSize);
      try
        UrlHandle := InternetOpenUrl(hInter, PChar(Url), nil, 0, INTERNET_FLAG_RELOAD, 0);
        if Assigned(UrlHandle) then begin
          repeat
            InternetReadFile(UrlHandle, Buffer, BuffSize, BytesRead);
            if BytesRead > 0 then Stream.WriteBuffer(Buffer^, BytesRead);
          until BytesRead = 0;
          InternetCloseHandle(UrlHandle);
        end;
      finally
        FreeMem(Buffer);
      end;
    finally
      InternetCloseHandle(hInter);
    end;
end;

function Http_Get(const Url: string): string; overload;
Var
  StringStream: TStringStream;
begin
  Result := '';
  StringStream := TStringStream.Create('', TEncoding.UTF8);
  try
    Http_Get(Url, StringStream);
    if StringStream.Size > 0 then begin
      StringStream.Seek(0, 0);
      Result := StringStream.ReadString(StringStream.Size);
    end;
  finally
    StringStream.Free;
  end;
end;

// encode a Url
function URLEncode(const Url: string): string;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Length(Url) do begin
    case Url[i] of
      'A' .. 'Z', 'a' .. 'z', '0' .. '9', '-', '_', '.': Result := Result + Url[i];
    else Result := Result + '%' + IntToHex(Ord(Url[i]), 2);
    end;
  end;
end;

end.
