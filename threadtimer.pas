unit threadtimer;
{ -----------------------------------------------------------------------------

  The contents of this file are subject to the Mozilla Public License
  Version 1.1 (the "License"); you may not use this file except in compliance
  with the License. You may obtain a copy of the License at
  http://www.mozilla.org/MPL/MPL-1.1.html

  Software distributed under the License is distributed on an "AS IS" basis,
  WITHOUT WARRANTY OF ANY KIND, either expressed or implied. See the License for
  the specific language governing rights and limitations under the License.

  The Original Code is: JvThreadTimer.PAS, released on 2001-02-28.

  The Initial Developer of the Original Code is S?stien Buysse [sbuysse att buypin dott com]
  Portions created by S?stien Buysse are Copyright (C) 2001 S?stien Buysse.
  All Rights Reserved.

  Contributor(s):
  Michael Beck [mbeck att bigfoot dott com].
  Peter Thrnqvist
  Ivo Bauer

  You may retrieve the latest version of this file at the Project JEDI's JVCL home page,
  located at http://jvcl.delphi-jedi.org

  Known Issues:

  History:
  2003-07-24 (p3)
  * Changed Active->Enabled and Delay->Interval to make property names match TTimer
  * Changed implementation so that setting Enabled := false, frees the thread instead
  of suspending it. This makes it possible to restart the timer interval.
  2003-07-25 (ivobauer)
  * Rewritten almost everything.

  ----------------------------------------------------------------------------- }
// $Id: JvThreadTimer.pas 13102 2011-09-07 05:46:34Z obones $

interface

uses
  Windows, SysUtils, Classes;

type
  // TThreadPriority has been marked platform and we don't want the warning
{$IFDEF RTL230_UP}{$IFDEF MSWINDOWS}{$WARNINGS OFF}TThreadPriority = Classes.TThreadPriority;
{$WARNINGS ON}{$ENDIF RTL230_UP}{$ENDIF MSWINDOWS}
{$IFDEF RTL230_UP}
  [ComponentPlatformsAttribute(pidWin32 or pidWin64 or pidOSX32)]
{$ENDIF RTL230_UP}

  TThreadTimer = class(TComponent)
  private
    FEnabled: Boolean;
    FInterval: Cardinal;
    FKeepAlive: Boolean;
    FOnTimer: TNotifyEvent;
{$IFDEF MSWINDOWS}
    FPriority: TThreadPriority;
{$ENDIF MSWINDOWS}
    FStreamedEnabled: Boolean;
    FThread: TThread;
    procedure SetEnabled(const Value: Boolean);
    procedure SetInterval(const Value: Cardinal);
    procedure SetOnTimer(const Value: TNotifyEvent);
{$IFDEF MSWINDOWS}
    procedure SetPriority(const Value: TThreadPriority);
{$ENDIF MSWINDOWS}
    procedure SetKeepAlive(const Value: Boolean);
  protected
    procedure DoOnTimer;
    procedure Loaded; override;
    procedure StopTimer;
    procedure UpdateTimer;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Thread: TThread read FThread;
  published
    // (p3) renamed Active->Enabled, Delay->Interval to make it compatible with TTimer
    property Enabled: Boolean read FEnabled write SetEnabled default False;
    property Interval: Cardinal read FInterval write SetInterval default 1000;
    property KeepAlive: Boolean read FKeepAlive write SetKeepAlive default False;
    property OnTimer: TNotifyEvent read FOnTimer write SetOnTimer;
{$IFDEF MSWINDOWS}
    property Priority: TThreadPriority read FPriority write SetPriority default tpNormal;
{$ENDIF MSWINDOWS}
  end;

implementation

uses
  Messages;

type
  TCustomThread = class(TThread)
  private
    FThreadName: String;
    function GetThreadName: String; virtual;
    procedure SetThreadName(const Value: String); virtual;
  public
{$IFNDEF DELPHI2010_UP}
    procedure NameThreadForDebugging(AThreadName: AnsiString; AThreadID: LongWord = $FFFFFFFF);
{$ENDIF}
    procedure NameThread(AThreadName: AnsiString; AThreadID: LongWord = $FFFFFFFF);
{$IFDEF SUPPORTS_UNICODE_STRING} overload; {$ENDIF} virtual;
{$IFDEF SUPPORTS_UNICODE_STRING}
    procedure NameThread(AThreadName: String; AThreadID: LongWord = $FFFFFFFF); overload;
{$ENDIF}
    property ThreadName: String read GetThreadName write SetThreadName;
  end;

type
  TTimerThread = class(TCustomThread)
  private
    FEvent: THandle;
    FHasBeenSuspended: Boolean;
    FInterval: Cardinal;
    FTimer: TThreadTimer;
{$IFDEF MSWINDOWS}
    FPriority: TThreadPriority;
{$ENDIF MSWINDOWS}
    FSynchronizing: Boolean;
  protected
    procedure DoSuspend;
    procedure Execute; override;
  public
    constructor Create(ATimer: TThreadTimer);
    destructor Destroy; override;
    procedure Stop;
    property Interval: Cardinal read FInterval;
    property Timer: TThreadTimer read FTimer;
    property Synchronizing: Boolean read FSynchronizing;
  end;

var
  JvCustomThreadNamingProc: procedure(AThreadName: AnsiString; AThreadID: LongWord);

function SubtractMin0(const Big, Small: Cardinal): Cardinal;
begin
  if Big <= Small then Result := 0
  else Result := Big - Small;
end;

{$IFNDEF DELPHI2010_UP}

procedure TCustomThread.NameThreadForDebugging(AThreadName: AnsiString; AThreadID: LongWord = $FFFFFFFF);
type
  TThreadNameInfo = record
    FType: LongWord; // must be 0x1000
    FName: PAnsiChar; // pointer to name (in user address space)
    FThreadID: LongWord; // thread ID (-1 indicates caller thread)
    FFlags: LongWord; // reserved for future use, must be zero
  end;
var
  ThreadNameInfo: TThreadNameInfo;
begin
  // if IsDebuggerPresent then
  begin
    ThreadNameInfo.FType := $1000;
    ThreadNameInfo.FName := PAnsiChar(AThreadName);
    ThreadNameInfo.FThreadID := AThreadID;
    ThreadNameInfo.FFlags := 0;

    try
      RaiseException($406D1388, 0, sizeof(ThreadNameInfo) div sizeof(LongWord), @ThreadNameInfo);
    except
    end;
  end;
end;
{$ENDIF DELPHI2010_UP}

function TCustomThread.GetThreadName: String;
begin
  if FThreadName = '' then Result := ClassName
  else Result := FThreadName + ' {' + ClassName + '}';
end;

procedure TCustomThread.NameThread(AThreadName: AnsiString; AThreadID: LongWord = $FFFFFFFF);
begin
  if AThreadID = $FFFFFFFF then AThreadID := ThreadID;
  NameThreadForDebugging(AThreadName, AThreadID);
  if Assigned(JvCustomThreadNamingProc) then JvCustomThreadNamingProc(AThreadName, AThreadID);
end;

{$IFDEF SUPPORTS_UNICODE_STRING}

procedure TCustomThread.NameThread(AThreadName: String; AThreadID: LongWord = $FFFFFFFF);
begin
  NameThread(AnsiString(AThreadName), AThreadID);
end;
{$ENDIF}

procedure TCustomThread.SetThreadName(const Value: String);
begin
  FThreadName := Value;
end;
// === { TJvTimerThread } =====================================================

constructor TTimerThread.Create(ATimer: TThreadTimer);
begin
  inherited Create(False);

  { Manually reset = false; Initial State = false }
  FEvent := CreateEvent(nil, False, False, nil);
  if FEvent = 0 then RaiseLastOSError;
  FInterval := ATimer.FInterval;
  FTimer := ATimer;
{$IFDEF MSWINDOWS}
  FPriority := ATimer.Priority; // setting the priority is deferred to Execute()
{$ENDIF MSWINDOWS}
  ThreadName := Format('%s: %s', [ClassName, ATimer.Name]);
end;

destructor TTimerThread.Destroy;
begin
  Stop;
  inherited Destroy;
  if FEvent <> 0 then CloseHandle(FEvent);
end;

procedure TTimerThread.DoSuspend;
begin
  FHasBeenSuspended := True;
  Suspended := True;
end;

procedure TTimerThread.Execute;
var
  Offset, TickCount: Cardinal;
begin
  NameThread(ThreadName);
{$IFDEF MSWINDOWS}
  Priority := FPriority;
{$ENDIF MSWINDOWS}
  if WaitForSingleObject(FEvent, Interval) <> WAIT_TIMEOUT then Exit;

  while not Terminated do begin
    FHasBeenSuspended := False;

    TickCount := GetTickCount;
    if not Terminated then begin
      FSynchronizing := True;
      try
        Synchronize(FTimer.DoOnTimer);
      finally
        FSynchronizing := False;
      end;
    end;

    // Determine how much time it took to execute OnTimer event handler. Take a care
    // of wrapping the value returned by GetTickCount API around zero if Windows is
    // run continuously for more than 49.7 days.
    if FHasBeenSuspended then Offset := 0
    else begin
      Offset := GetTickCount;
      if Offset >= TickCount then Dec(Offset, TickCount)
      else Inc(Offset, High(Cardinal) - TickCount);
    end;

    // Make sure Offset is less than or equal to FInterval.
    // (rb) Ensure it's atomic, because of KeepAlive
    if Terminated or (WaitForSingleObject(FEvent, SubtractMin0(Interval, Offset)) <> WAIT_TIMEOUT) then Exit;
  end;
end;

procedure TTimerThread.Stop;
begin
  Terminate;
  SetEvent(FEvent);
  if Suspended then Suspended := False;
end;

// === { TJvThreadTimer } =====================================================

constructor TThreadTimer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FInterval := 1000;
{$IFDEF MSWINDOWS}
  FPriority := tpNormal;
{$ENDIF MSWINDOWS}
end;

destructor TThreadTimer.Destroy;
begin
  StopTimer;
  inherited Destroy;
end;

procedure TThreadTimer.DoOnTimer;
begin
  if csDestroying in ComponentState then Exit;

  try
    if Assigned(FOnTimer) then FOnTimer(Self);
  except
    if Assigned(ApplicationHandleException) then ApplicationHandleException(Self);
  end;
end;

procedure TThreadTimer.Loaded;
begin
  inherited Loaded;
  SetEnabled(FStreamedEnabled);
end;

procedure TThreadTimer.SetEnabled(const Value: Boolean);
begin
  if csLoading in ComponentState then FStreamedEnabled := Value
  else if FEnabled <> Value then begin
    FEnabled := Value;
    UpdateTimer;
  end;
end;

procedure TThreadTimer.SetInterval(const Value: Cardinal);
begin
  if FInterval <> Value then begin
    FInterval := Value;
    UpdateTimer;
  end;
end;

procedure TThreadTimer.SetKeepAlive(const Value: Boolean);
begin
  if FKeepAlive <> Value then begin
    StopTimer;
    FKeepAlive := Value;
    UpdateTimer;
  end;
end;

procedure TThreadTimer.SetOnTimer(const Value: TNotifyEvent);
begin
  if @FOnTimer <> @Value then begin
    FOnTimer := Value;
    UpdateTimer;
  end;
end;

{$IFDEF MSWINDOWS}

procedure TThreadTimer.SetPriority(const Value: TThreadPriority);
begin
  if FPriority <> Value then begin
    FPriority := Value;
    if FThread <> nil then FThread.Priority := FPriority;
  end;
end;
{$ENDIF MSWINDOWS}

procedure TThreadTimer.StopTimer;
begin
  if FThread <> nil then begin
    TTimerThread(FThread).Stop;
    if not TTimerThread(FThread).Synchronizing then FreeAndNil(FThread)
    else begin
      // We can't destroy the thread because it called us through Synchronize()
      // and is waiting for our return. But we need to destroy it after it returned.
      TTimerThread(FThread).FreeOnTerminate := True;
      FThread := nil
    end;
  end;
end;

procedure TThreadTimer.UpdateTimer;
var
  DoEnable: Boolean;
begin
  if ComponentState * [csDesigning, csLoading] <> [] then Exit;

  DoEnable := FEnabled and Assigned(FOnTimer) and (FInterval > 0);

  if not KeepAlive then StopTimer;

  if DoEnable then begin
    if FThread <> nil then begin
      TTimerThread(FThread).FInterval := FInterval;
      if FThread.Suspended then FThread.Suspended := False;
    end
    else FThread := TTimerThread.Create(Self);
  end
  else if FThread <> nil then begin
    if not FThread.Suspended then TTimerThread(FThread).DoSuspend;

    TTimerThread(FThread).FInterval := FInterval;
  end;
end;

end.
