object FMain: TFMain
  Left = 0
  Top = 0
  Caption = 'TWebICQClient Demo | http://zt.am/'
  ClientHeight = 289
  ClientWidth = 622
  Color = clBtnFace
  Constraints.MinHeight = 248
  Constraints.MinWidth = 554
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  Menu = mm
  OldCreateOrder = False
  Position = poScreenCenter
  OnCloseQuery = FormCloseQuery
  DesignSize = (
    622
    289)
  PixelsPerInch = 96
  TextHeight = 13
  object lbl_sendtouin: TLabel
    Left = 506
    Top = 205
    Width = 62
    Height = 13
    Anchors = [akRight, akBottom]
    Caption = 'Send to UIN:'
  end
  object lbl_uin: TLabel
    Left = 8
    Top = 8
    Width = 22
    Height = 13
    Caption = 'UIN:'
  end
  object lbl_pass: TLabel
    Left = 175
    Top = 8
    Width = 50
    Height = 13
    Caption = 'Password:'
  end
  object re_log: TRichEdit
    Left = 8
    Top = 32
    Width = 606
    Height = 166
    Anchors = [akLeft, akTop, akRight, akBottom]
    Font.Charset = RUSSIAN_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 0
    ExplicitWidth = 619
    ExplicitHeight = 177
  end
  object mmo_msg: TMemo
    Left = 8
    Top = 204
    Width = 492
    Height = 80
    Anchors = [akLeft, akRight, akBottom]
    ScrollBars = ssVertical
    TabOrder = 1
    ExplicitTop = 215
    ExplicitWidth = 505
  end
  object edt_sendtouin: TEdit
    Left = 506
    Top = 224
    Width = 108
    Height = 21
    Anchors = [akRight, akBottom]
    TabOrder = 2
    ExplicitLeft = 519
    ExplicitTop = 235
  end
  object btn_send: TButton
    Left = 506
    Top = 251
    Width = 108
    Height = 33
    Anchors = [akRight, akBottom]
    Caption = 'Send (Ctrl+Enter)'
    TabOrder = 3
    OnClick = btn_sendClick
    ExplicitLeft = 519
    ExplicitTop = 262
  end
  object edt_login: TEdit
    Left = 36
    Top = 5
    Width = 133
    Height = 21
    TabOrder = 4
  end
  object edt_pass: TEdit
    Left = 231
    Top = 5
    Width = 138
    Height = 21
    PasswordChar = '*'
    TabOrder = 5
  end
  object btn_login: TButton
    Left = 375
    Top = 3
    Width = 75
    Height = 25
    Caption = 'Login'
    TabOrder = 6
    OnClick = btn_loginClick
  end
  object btn_logout: TButton
    Left = 456
    Top = 3
    Width = 75
    Height = 25
    Caption = 'Logout'
    TabOrder = 7
    OnClick = btn_logoutClick
  end
  object idntfrz1: TIdAntiFreeze
    ApplicationHasPriority = False
    IdleTimeOut = 80
    OnlyWhenIdle = False
    Left = 32
    Top = 80
  end
  object ICQ: TWebICQClient
    CheckTimeOut = 800
    UserAgent = 'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.0)'
    OnMessageRecive = ICQMessageRecive
    Left = 80
    Top = 80
  end
  object mm: TMainMenu
    Left = 568
    Top = 8
    object mm_menu: TMenuItem
      Caption = 'Menu'
      object mm_send: TMenuItem
        Caption = 'Send'
        ShortCut = 16397
        OnClick = btn_sendClick
      end
      object mm_exit: TMenuItem
        Caption = 'Exit'
        OnClick = mm_exitClick
      end
    end
  end
end
