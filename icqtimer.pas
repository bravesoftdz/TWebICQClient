{ }
{ GT Delphi Components }
{ GT Threaded Timer }
{ }
{ Copyright (c) GT Delphi Components }
{ http://www.gtdelphicomponents.gr }
{ }
{ }

unit icqtimer;

interface

uses
  Classes;

type
  { ------------------------------------------------------------------------------ }
  TICQTimer = class;

  { ------------------------------------------------------------------------------ }
  TICQTimerThread = class(TThread)
  private
    { Private declarations }
    FTimer: TICQTimer;
  protected
    { Protected declarations }
    procedure DoTimer;
  public
    { Public declarations }
    constructor Create(ATimer: TICQTimer);
    destructor Destroy; override;
    procedure Execute; override;
  published
    { Published declarations }
  end;

  { ------------------------------------------------------------------------------ }
  TICQTimer = class(TObject)
  private
    FEnabled: Boolean;
    FInterval: Cardinal;
    FOnTimer: TNotifyEvent;
    procedure SetEnabled(const Value: Boolean);
    procedure SetInterval(const Value: Cardinal);
    { Private declarations }
  protected
    { Protected declarations }
    FTimerThread: TICQTimerThread;
    procedure UpdateTimer;
  public
    { Public declarations }
    destructor Destroy; override;
  published
    { Published declarations }
    property Enabled: Boolean read FEnabled write SetEnabled;
    property Interval: Cardinal read FInterval write SetInterval;
  published
    property OnTimer: TNotifyEvent read FOnTimer write FOnTimer;
  end;
  { ------------------------------------------------------------------------------ }

implementation

uses
  Windows, SysUtils;

{ TgtTimerThread }
{ ------------------------------------------------------------------------------ }
constructor TICQTimerThread.Create(ATimer: TICQTimer);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FTimer := ATimer;
end;

{ ------------------------------------------------------------------------------ }
destructor TICQTimerThread.Destroy;
begin
  inherited;
end;

{ ------------------------------------------------------------------------------ }
procedure TICQTimerThread.DoTimer;
begin
  if Assigned(FTimer.OnTimer) then FTimer.OnTimer(FTimer);
end;

{ ------------------------------------------------------------------------------ }
procedure TICQTimerThread.Execute;
begin
  while (not Self.Terminated) and (FTimer.Enabled) do begin
    WaitForSingleObject(Self.Handle, FTimer.Interval);
    Synchronize(DoTimer);
  end;
end;
{ ------------------------------------------------------------------------------ }

{ TgtTimer }
{ ------------------------------------------------------------------------------ }

{ ------------------------------------------------------------------------------ }
destructor TICQTimer.Destroy;
begin
  inherited;
end;

{ ------------------------------------------------------------------------------ }
procedure TICQTimer.UpdateTimer;
begin
  if Assigned(FTimerThread) then begin
    FTimerThread.Terminate;
    FTimerThread := nil;
  end;
  if Enabled then begin
    if FInterval > 0 then begin
      FTimerThread := TICQTimerThread.Create(Self);
      FTimerThread.Resume;
    end
    else Enabled := False;
  end;
end;
{ ------------------------------------------------------------------------------ }

// Getters - Setters\\
{ ------------------------------------------------------------------------------ }
procedure TICQTimer.SetEnabled(const Value: Boolean);
begin
  FEnabled := Value;
  UpdateTimer;
end;

{ ------------------------------------------------------------------------------ }
procedure TICQTimer.SetInterval(const Value: Cardinal);
begin
  if Value <> FInterval then begin
    FInterval := Value;
    UpdateTimer;
  end;
end;
{ ------------------------------------------------------------------------------ }

end.
