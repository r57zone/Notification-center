unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, OleCtrls, SHDocVw, MSHTML, ShellAPI, StdCtrls, ExtCtrls, XPMan,
  Menus, ImgList, IniFiles;

type
  TMain = class(TForm)
    WebView: TWebBrowser;
    XPManifest: TXPManifest;
    PopupMenu: TPopupMenu;
    AboutBtn: TMenuItem;
    LineItem: TMenuItem;
    ExitBtn: TMenuItem;
    Icons: TImageList;
    procedure FormCreate(Sender: TObject);
    procedure WebViewBeforeNavigate2(Sender: TObject;
      const pDisp: IDispatch; var URL, Flags, TargetFrameName, PostData,
      Headers: OleVariant; var Cancel: WordBool);
    procedure WebViewDocumentComplete(Sender: TObject;
      const pDisp: IDispatch; var URL: OleVariant);
    procedure FormDestroy(Sender: TObject);
    procedure AboutBtnClick(Sender: TObject);
    procedure ExitBtnClick(Sender: TObject);
  private
    procedure WMCopyData(var Msg: TWMCopyData); message WM_COPYDATA;
    procedure WMNCHITTEST(var Msg: TMessage); message WM_NCHITTEST;
    procedure DefaultHandler(var Message); override;
    procedure AddNotification(NotifyTitle, NotifyDesc, NotifyTimeHM, NotifyDate, NotifyIconPath, NotifyColor: string);
    procedure LoadNotifications;
    procedure MyShow;
    procedure MyHide;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure IconMouse(var Msg: TMessage); message WM_USER + 1;
    procedure WMActivate(var Msg: TMessage); message WM_ACTIVATE;
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Main: TMain;
  Notifications, ExcludeList: TStringList;
  WM_TaskBarCreated: Cardinal;
  IconIndex: byte;
  IconFull: TIcon;
  ID_NOTIFICATIONS, ID_DELETE_ALL, ID_UNKNOWN_APP, ID_LAST_UPDATE: string;
  RunOnce: boolean;

implementation

{$R *.dfm}

procedure TMain.MyShow;
begin
  if RunOnce = false then begin
    Main.AlphaBlendValue:=255;
    RunOnce:=true;
  end;
  Top:=Screen.Height - Main.Height - 54;
  Left:=Screen.Width - Main.Width - 8;
  if WebView.Document <> nil then
    (WebView.Document as IHTMLDocument2).ParentWindow.Focus;
  ShowWindow(Handle, SW_SHOW);
end;

procedure TMain.MyHide;
begin
  ShowWindow(Handle, SW_HIDE);
end;

procedure Tray(ActInd: integer); //1 - ��������, 2 - �������, 3 -  ��������
var
  nim: TNotifyIconData;
begin
  with NIM do begin
    cbSize:=SizeOf(nim);
    Wnd:=Main.Handle;
    uId:=1;
    uFlags:=NIF_MESSAGE or NIF_ICON or NIF_TIP;

    if IconIndex = 0 then
      hIcon:=SendMessage(Application.Handle, WM_GETICON, ICON_SMALL2, 0)
    else
      hIcon:=IconFull.Handle;

    uCallBackMessage:=WM_USER + 1;
    StrCopy(szTip, PChar(Application.Title));
  end;
  case ActInd of
    1: Shell_NotifyIcon(NIM_ADD, @nim);
    2: Shell_NotifyIcon(NIM_DELETE, @nim);
    3: Shell_NotifyIcon(NIM_MODIFY, @nim);
  end;
end;

procedure TMain.IconMouse(var Msg: TMessage);
begin
  case Msg.LParam of
    WM_LBUTTONDOWN:
      begin
        MyShow;
        IconIndex:=0;
        Tray(3);
      end;

    WM_LBUTTONDBLCLK:
      MyHide;

    WM_RBUTTONDOWN:
      PopupMenu.Popup(Mouse.CursorPos.X, Mouse.CursorPos.Y);
  end;
end;

procedure TMain.CreateParams(var Params: TCreateParams);
begin
  inherited;
  Params.Style:=WS_POPUP or WS_THICKFRAME;
end;

function GetLocaleInformation(flag: integer): string;
var
  pcLCA: array [0..20] of Char;
begin
  if GetLocaleInfo(LOCALE_SYSTEM_DEFAULT, flag, pcLCA, 19)<=0 then
    pcLCA[0]:=#0;
  Result:=pcLCA;
end;

procedure TMain.AddNotification(NotifyTitle, NotifyDesc, NotifyTimeHM, NotifyDate, NotifyIconPath, NotifyColor: string);
begin
  WebView.OleObject.Document.getElementById('items').innerHTML:='<div id="item"><div id="icon" style="background-color:' +
    NotifyColor + ';"><img src="' + NotifyIconPath + '" /></div><div id="context"><div id="title">' +
    NotifyTitle + '</div><div id="clear"></div><div id="description">' + NotifyDesc +' </div></div><div id="time">' + NotifyTimeHM + '<br>' +
    NotifyDate + '</div></div>' + WebView.OleObject.Document.getElementById('items').innerHTML;
end;

procedure TMain.LoadNotifications;
var
  NotifyTitle, NotifyDesc, NotifyTimeHM, NotifyDate, NotifyIconPath, NotifyColor: string;
  i: integer;
  NotifyStr: string;
begin
  for i:=0 to Notifications.Count - 1 do begin
    NotifyStr:=Notifications.Strings[i];

    NotifyTitle:=Copy(NotifyStr, 1, Pos(#9, NotifyStr) - 1);
    Delete(NotifyStr, 1, Pos(#9, NotifyStr));

    NotifyDesc:=Copy(NotifyStr, 1, Pos(#9, NotifyStr) - 1);
    Delete(NotifyStr, 1, Pos(#9, NotifyStr));

    NotifyTimeHM:=Copy(NotifyStr, 1, Pos(#9, NotifyStr) - 1);
    Delete(NotifyStr, 1, Pos(#9, NotifyStr));

    NotifyDate:=Copy(NotifyStr, 1, Pos(#9, NotifyStr) - 1);
    Delete(NotifyStr, 1, Pos(#9, NotifyStr));

    NotifyIconPath:=Copy(NotifyStr, 1, Pos(#9, NotifyStr) - 1);
    Delete(NotifyStr, 1, Pos(#9, NotifyStr));

    NotifyColor:=NotifyStr;

    AddNotification(NotifyTitle, NotifyDesc, NotifyTimeHM, NotifyDate, NotifyIconPath, NotifyColor);
  end;
end;

procedure TMain.FormCreate(Sender: TObject);
var
  Ini: TIniFile;
begin
  Ini:=TIniFile.Create(ExtractFilePath(ParamStr(0)) + 'Config.ini');
  IconIndex:=Ini.ReadInteger('Main', 'NewMessages', 0);
  Ini.Free;
  IconFull:=TIcon.Create;
  Icons.GetIcon(0, IconFull);

  //������� / Translate
  if FileExists(ExtractFilePath(ParamStr(0)) + 'Languages\' + GetLocaleInformation(LOCALE_SENGLANGUAGE) + '.ini') then
    Ini:=TIniFile.Create(ExtractFilePath(ParamStr(0)) + 'Languages\' + GetLocaleInformation(LOCALE_SENGLANGUAGE) + '.ini')
  else
    Ini:=TIniFile.Create(ExtractFilePath(ParamStr(0)) + 'Languages\English.ini');

  Application.Title:=Ini.ReadString('Main', 'ID_TITLE', '');
  ID_NOTIFICATIONS:=Ini.ReadString('Main', 'ID_NOTIFICATIONS', '');
  ID_DELETE_ALL:=Ini.ReadString('Main', 'ID_DELETE_ALL', '');
  ID_UNKNOWN_APP:=Ini.ReadString('Main', 'ID_UNKNOWN_APP', '');
  AboutBtn.Caption:=Ini.ReadString('Main', 'ID_ABOUT_TITLE', '');
  ID_LAST_UPDATE:=Ini.ReadString('Main', 'ID_LAST_UPDATE', '');
  ExitBtn.Caption:=Ini.ReadString('Main', 'ID_EXIT', '');
  
  Ini.Free;
  //

  WM_TaskBarCreated:=RegisterWindowMessage('TaskbarCreated');

  WebView.Silent:=true;
  WebView.Navigate(ExtractFilePath(ParamStr(0)) + 'main.htm');
  Tray(1);
  SetWindowLong(Application.Handle, GWL_EXSTYLE, GetWindowLong(Application.Handle, GWL_EXSTYLE) or WS_EX_TOOLWINDOW);
  MyHide;
  Notifications:=TStringList.Create;
  if FileExists(ExtractFilePath(ParamStr(0)) + 'Notifications.txt') then
    Notifications.LoadFromFile(ExtractFilePath(ParamStr(0)) + 'Notifications.txt');
  ExcludeList:=TStringList.Create;
  if FileExists(ExtractFilePath(ParamStr(0)) + 'Exclude.txt') then
    ExcludeList.LoadFromFile(ExtractFilePath(ParamStr(0)) + 'Exclude.txt');
end;

procedure TMain.WebViewBeforeNavigate2(Sender: TObject;
  const pDisp: IDispatch; var URL, Flags, TargetFrameName, PostData,
  Headers: OleVariant; var Cancel: WordBool);
var
  sUrl: string;
  NotifyTitle, NotifyDesciption: string;
begin
  sUrl:=ExtractFileName(StringReplace(url, '/', '\', [rfReplaceAll]));
  if Pos('main.htm', sUrl) = 0 then Cancel:=true;

  if sUrl = 'main.htm#rm' then begin
    WebView.OleObject.Document.getElementById('items').innerHTML:='';
    Notifications.Clear;
    Notifications.SaveToFile(ExtractFilePath(ParamStr(0)) + 'Notifications.txt');
  end;
end;

procedure TMain.WebViewDocumentComplete(Sender: TObject;
  const pDisp: IDispatch; var URL: OleVariant);
var
  sUrl:string;
begin
  if pDisp = (Sender as TWebBrowser).Application then begin
    sUrl:=ExtractFileName(StringReplace(url, '/', '\', [rfReplaceAll]));
    if sUrl = 'main.htm' then begin
      Application.ProcessMessages;
      if WebView.Document <> nil then begin
        LoadNotifications;
        WebView.OleObject.Document.getElementById('title').innerHTML:=ID_NOTIFICATIONS;
        WebView.OleObject.Document.getElementById('clear_btn').innerHTML:='<a onclick="document.location=''#rm'';">' + ID_DELETE_ALL + '</a>';
      end;
      Caption:='Notification center';
    end;
  end;
end;

function CurrentTimeHM: string;
begin
  Result:=Copy(TimeToStr(Time), 1, 5);
  if Result[Length(Result)] = ':' then
    Result:=Copy(Result, 1, Length(Result) - 1);
end;

procedure TMain.WMCopyData(var Msg: TWMCopyData);
var
  NotifyTitle, NotifyDesc, DescSub, BigIcon, SmallIcon, NotifyColor: string;
  NotifyMsg: TStringList;
  i: integer;
begin
  if Copy(PChar(TWMCopyData(Msg).CopyDataStruct.lpData), 1, 8) = '{NOTIFY}' then begin

    NotifyMsg:=TStringList.Create;
    NotifyMsg.Text:=PChar(TWMCopyData(Msg).CopyDataStruct.lpData);
    NotifyMsg.Text:=StringReplace(NotifyMsg.Text, #9, #13#10, [rfReplaceAll]);
    NotifyMsg.Delete(0);

    NotifyTitle:=ID_UNKNOWN_APP;
    NotifyColor:='gray';
    BigIcon:='Sys.png';
    SmallIcon:='';

    for i:=0 to NotifyMsg.Count - 2 do begin
      if NotifyMsg.Strings[i] = '-t' then
        NotifyTitle:=NotifyMsg.Strings[i + 1];

      if NotifyMsg.Strings[i] = '-d' then
        NotifyDesc:=StringReplace(NotifyMsg.Strings[i + 1], '\n', ' - ', [rfReplaceAll]);

      if NotifyMsg.Strings[i] = '-b' then
        BigIcon:=NotifyMsg.Strings[i + 1];

      if NotifyMsg.Strings[i] = '-s' then
        SmallIcon:=NotifyMsg.Strings[i + 1];

      if NotifyMsg.Strings[i] = '-c' then
        NotifyColor:=NotifyMsg.Strings[i + 1];
    end;

    if (SmallIcon <> '') and (BigIcon = 'Sys.png') then
      BigIcon:=SmallIcon;

    case NotifyColor[1] of
      '0': NotifyColor:='#00acee';
      '1': NotifyColor:='#235d82';
      '2': NotifyColor:='#018399';
      '3': NotifyColor:='#008a00';
      '4': NotifyColor:='#5133ab';
      '5': NotifyColor:='#8b0094';
      '6': NotifyColor:='#ac193d';
      '7': NotifyColor:='#222222';
    end;

    //��������� ����������� ���������
    if Pos(NotifyTitle, ExcludeList.Text) = 0 then begin
      AddNotification(NotifyTitle, NotifyDesc, CurrentTimeHM, DateToStr(Date), BigIcon, NotifyColor);
      Notifications.Add(NotifyTitle + #9 + NotifyDesc + #9 + CurrentTimeHM + #9 + DateToStr(Date) + #9 + BigIcon + #9 + NotifyColor);
      Notifications.SaveToFile(ExtractFilePath(ParamStr(0)) + 'Notifications.txt');
    end else begin
      IconIndex:=1;
      Tray(3);
    end;

    NotifyMsg.Free;
  end;
  Msg.Result:=Integer(True);
end;

procedure TMain.WMActivate(var Msg: TMessage);
begin
  if Msg.WParam = WA_INACTIVE then
    MyHide;
  inherited;
end;

procedure TMain.FormDestroy(Sender: TObject);
var
  Ini: TIniFile;
begin
  Ini:=TIniFile.Create(ExtractFilePath(ParamStr(0)) + 'Config.ini');
  Ini.WriteInteger('Main', 'NewMessages', IconIndex);
  Ini.Free;
  Notifications.Free;
  ExcludeList.Free;
  Tray(2);
  IconFull.Free;
end;

procedure TMain.DefaultHandler(var Message);
begin
  if TMessage(Message).Msg = WM_TASKBARCREATED then
    Tray(1);
  inherited;
end;

procedure TMain.AboutBtnClick(Sender: TObject);
begin
  Application.MessageBox(PChar(Application.Title + ' 0.7' + #13#10
    + ID_LAST_UPDATE + ' 13.03.2019' + #13#10
    + 'http://r57zone.github.io' + #13#10 + 'r57zone@gmail.com'),
    PChar(AboutBtn.Caption), MB_ICONINFORMATION);
end;

procedure TMain.ExitBtnClick(Sender: TObject);
begin
  Close;
end;

procedure TMain.WMNCHITTEST(var Msg: TMessage);
begin
  Msg.Result:=HTCLIENT;
end;

end.
