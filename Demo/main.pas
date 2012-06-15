unit main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls,
  icqapilite, Vcl.Menus, Vcl.ExtCtrls, Vcl.ImgList, System.TypInfo, JvComponentBase, JvThreadTimer, httptools;

type
  TFMain = class(TForm)
    re_log: TRichEdit;
    mmo_msg: TMemo;
    edt_sendtouin: TEdit;
    btn_send: TButton;
    edt_login: TEdit;
    lbl_uin: TLabel;
    lbl_pass: TLabel;
    edt_pass: TEdit;
    btn_login: TButton;
    btn_logout: TButton;
    mm: TMainMenu;
    mm_menu: TMenuItem;
    mm_send: TMenuItem;
    mm_exit: TMenuItem;
    ICQ: TWebICQClient;
    lv_contacts: TListView;
    il1: TImageList;
    btn1: TButton;
    jvthrdtmr1: TJvThreadTimer;
    procedure btn_loginClick(Sender: TObject);
    procedure btn_logoutClick(Sender: TObject);
    procedure btn_sendClick(Sender: TObject);
    procedure mm_exitClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure tmr1Timer(Sender: TObject);
    procedure ICQUpdateContactList(Sender: TObject);
    procedure ICQMessageRecive(Sender: TObject; Msg: TICQMessage);
    procedure lv_contactsDblClick(Sender: TObject);
    procedure btn1Click(Sender: TObject);
    procedure jvthrdtmr1Timer(Sender: TObject);
    procedure FormCreate(Sender: TObject);
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
var
  t: tstringlist;
begin
  with re_log do begin
    SelStart := Length(Text);
    SelAttributes.Color := AColor;
    SelAttributes.Size := 8;
    if Time then Lines.Add(timetostr(now) + ': ' + AText)
    else Lines.Add(AText);
  end;
end;

procedure TFMain.btn1Click(Sender: TObject);
begin
  ICQ.CheckEvents;
end;

procedure TFMain.btn_loginClick(Sender: TObject);
begin
  btn_login.Enabled := false;
  if ICQ.Connected then btn_logout.Click;
  ICQ.Login(edt_login.Text, edt_pass.Text);
  if ICQ.Connected then AddColoredLine('Logged In!', clGreen)
  else AddColoredLine('Loggin Error!', clRed);
  btn_login.Enabled := true;
end;

procedure TFMain.btn_logoutClick(Sender: TObject);
begin
  if not ICQ.Connected then begin
    AddColoredLine('Not Logged in!', clRed);
    exit;
  end;
  btn_logout.Enabled := false;
  ICQ.LogOut;
  if not ICQ.Connected then AddColoredLine('Logged Out', clGreen)
  else AddColoredLine('Logging Out Error!', clRed);
  btn_logout.Enabled := true;
end;

procedure TFMain.btn_sendClick(Sender: TObject);
var
  TextToSend: String;
begin
  if not ICQ.Connected then begin
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
    AddColoredLine('From you to ' + edt_sendtouin.Text, clTeal);
    AddColoredLine(TextToSend, clBlack, false);
  end else begin
    AddColoredLine('Sending Error!', clRed);
    mmo_msg.Text := TextToSend;
  end;
  btn_send.Enabled := true;
end;

procedure TFMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if ICQ.Connected then btn_logout.Click;
end;

procedure TFMain.FormCreate(Sender: TObject);
begin
  IsMultiThread := true;
end;

procedure TFMain.ICQMessageRecive(Sender: TObject; Msg: TICQMessage);
begin
  AddColoredLine('From ' + Msg.Contact.DisplayID + ' to you', clHighlight);
  Delete(Msg.MsgText, 1, 5);
  Delete(Msg.MsgText, Length(Msg.MsgText) - 5, 6);
  AddColoredLine(Msg.MsgText, clBlack, false);
end;

procedure TFMain.ICQUpdateContactList(Sender: TObject);
var
  i: integer;
begin
  lv_contacts.Items.Clear;
  for i := 0 to ICQ.ContactsCount - 1 do
    with lv_contacts.Items.Add do begin
      Caption := ICQ.Contacts[i].DisplayID + ' - ' + ICQ.Contacts[i].Friendly;
      if ICQ.Contacts[i].State <> 'offline' then ImageIndex := 1
      else ImageIndex := 0;
    end;
end;

procedure TFMain.jvthrdtmr1Timer(Sender: TObject);
begin
  // Http_Get('http://ya.ru/');
  sleep(1000);
end;

procedure TFMain.lv_contactsDblClick(Sender: TObject);
var
  ListViewCursosPos: TPoint;
  selectedItem: TListItem;
  hts: THitTests;
  ht: THitTest;
  sht: string;
begin
  // double click where?
  hts := lv_contacts.GetHitTestInfoAt(ListViewCursosPos.X, ListViewCursosPos.Y);

  // "debug" hit test
  Caption := '';
  for ht in hts do begin
    sht := GetEnumName(TypeInfo(THitTest), integer(ht));
    Caption := Format('%s %s | ', [Caption, sht]);
  end;

  // locate the double-clicked item
  if hts <= [htOnIcon, htOnItem, htOnLabel, htOnStateIcon] then begin
    selectedItem := lv_contacts.Selected;
    edt_sendtouin.Text := Copy(selectedItem.Caption, 1, pos(' - ', selectedItem.Caption));
  end;
end;

procedure TFMain.mm_exitClick(Sender: TObject);
begin
  halt;
end;

procedure TFMain.tmr1Timer(Sender: TObject);
begin
  Application.ProcessMessages;
end;

end.
