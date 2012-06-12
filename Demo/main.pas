unit main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls, IdBaseComponent, IdAntiFreezeBase, Vcl.IdAntiFreeze,
  icqapilite, Vcl.Menus;

type
  TFMain = class(TForm)
    re_log: TRichEdit;
    mmo_msg: TMemo;
    edt_sendtouin: TEdit;
    btn_send: TButton;
    lbl_sendtouin: TLabel;
    edt_login: TEdit;
    lbl_uin: TLabel;
    lbl_pass: TLabel;
    edt_pass: TEdit;
    btn_login: TButton;
    btn_logout: TButton;
    idntfrz1: TIdAntiFreeze;
    ICQ: TWebICQClient;
    mm: TMainMenu;
    mm_menu: TMenuItem;
    mm_send: TMenuItem;
    mm_exit: TMenuItem;
    procedure btn_loginClick(Sender: TObject);
    procedure btn_logoutClick(Sender: TObject);
    procedure btn_sendClick(Sender: TObject);
    procedure ICQMessageRecive(Sender: TObject; UIN, Text: string);
    procedure mm_exitClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    procedure AddColoredLine(AText: string; AColor: TColor; Time: Boolean = true);
  public
    { Public declarations }
  end;

var
  FMain: TFMain;

implementation

{$R *.dfm}

procedure TFMain.AddColoredLine(AText: string; AColor: TColor; Time: Boolean = true);
begin
  with re_log do begin
    SelStart := Length(Text);
    SelAttributes.Color := AColor;
    SelAttributes.Size := 8;
    if Time then Lines.Add(timetostr(now) + ': ' + AText)
    else Lines.Add(AText);
  end;
end;

procedure TFMain.btn_loginClick(Sender: TObject);
begin
  btn_login.Enabled := false;
  if ICQ.LoggedIn then btn_logout.Click;
  ICQ.Login(edt_login.Text, edt_pass.Text, true);
  if ICQ.LoggedIn then AddColoredLine('Logged In!', clGreen)
  else AddColoredLine('Loggin Error!', clRed);
  btn_login.Enabled := true;
end;

procedure TFMain.btn_logoutClick(Sender: TObject);
begin
  if not ICQ.LoggedIn then begin
    AddColoredLine('Not Logged in!', clRed);
    exit;
  end;
  btn_logout.Enabled := false;
  ICQ.LogOut;
  if not ICQ.LoggedIn then AddColoredLine('Logged Out', clGreen)
  else AddColoredLine('Logging Out Error!', clRed);
  btn_logout.Enabled := true;
end;

procedure TFMain.btn_sendClick(Sender: TObject);
var
  TextToSend: String;
begin
  if not ICQ.LoggedIn then begin
    AddColoredLine('Not Logged in!', clRed);
    exit;
  end;
  if (edt_sendtouin.Text = '') then begin
    AddColoredLine('Empty UIN!', clRed);
    exit;
  end;
  btn_send.Enabled := false;
  TextToSend := mmo_msg.Text;
  mmo_msg.Text := '';
  if ICQ.SendMessage(edt_sendtouin.Text, TextToSend) then begin
    AddColoredLine('From you to ' + edt_sendtouin.Text, clMoneyGreen);
    AddColoredLine(TextToSend, clWhite, false);
  end else begin
    AddColoredLine('Sending Error!', clRed);
    mmo_msg.Text := TextToSend;
  end;
  btn_send.Enabled := true;
end;

procedure TFMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if ICQ.LoggedIn then btn_logout.Click;
end;

procedure TFMain.ICQMessageRecive(Sender: TObject; UIN, Text: string);
begin
  AddColoredLine('From ' + UIN + ' to you', clHighlight);
  Delete(Text, 1, 5);
  Delete(Text, Length(Text) - 5, 6);
  AddColoredLine(Text, clWhite, false);
end;

procedure TFMain.mm_exitClick(Sender: TObject);
begin
  halt;
end;

end.
