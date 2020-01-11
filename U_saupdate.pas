unit U_saupdate;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs,StrUtils,IdStrings, StdCtrls, Buttons, ComCtrls,IdHTTP,IniFiles,
  IdBaseComponent, IdComponent, IdTCPConnection, IdTCPClient,ShellAPI,
  Gauges, ExtCtrls, TFlatGaugeUnit;

type
  Tfrm_main = class(TForm)
    mmo_txt: TMemo;
    stat1: TStatusBar;
    idhtp_download: TIdHTTP;
    idhtp_temp: TIdHTTP;
    pnl1: TPanel;
    btn_update: TBitBtn;
    btn_pause: TBitBtn;
    fltg_down: TFlatGauge;
    lbl1: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure idhtp_downloadWork(Sender: TObject; AWorkMode: TWorkMode;
      const AWorkCount: Integer);
    procedure idhtp_downloadWorkBegin(Sender: TObject;
      AWorkMode: TWorkMode; const AWorkCountMax: Integer);
    procedure btn_updateClick(Sender: TObject);
    procedure btn_pauseClick(Sender: TObject);
  private
    { Private declarations }
    isdown:Boolean;         //�Ƿ������ļ�
    sa_exe:string;          //��ִ���ļ���
    sa_updatefile:string;   //������ʱ�ļ���
    sa_updateurl:string;    //����URL��ַ
    sa_version:string;      //�汾��
    sa_pubdate:string;      //��������
    sa_pubtxt:string;       //������־
    sa_filesize:Longword;   //�ļ���С
    downloadsize:Integer;    //�������ֽ�
    StartTime,AllStartTime: Longword;
    Duration, BytesSec, ByteCount: integer;
    function URLGetFileSize(aURL: string): integer;
  public
    { Public declarations }
  end;

var
  frm_main: Tfrm_main;

implementation

{$R *.dfm}

function Tfrm_main.URLGetFileSize(aURL: string): integer;
var
FileSize: integer;
begin
      try
            //ʹ��indy��ȡ�ļ���С
            idhtp_temp.Head(aURL);
            FileSize := idhtp_temp.Response.ContentLength;
            idhtp_temp.Disconnect;
            Result := FileSize;  
      except
            Result:=0;
      end;
end;


procedure Tfrm_main.FormCreate(Sender: TObject);
var configurl,fullname,temp,l,r:string;
    downhttp:TIdHTTP;
    MyStream:TMemoryStream;
    myinifile:TIniFile;
begin
    fltg_down.Progress:=0;
    isdown:=true;
    //�������������ļ�
    configurl:='http://172.24.0.15:82/UpdateConfig.ini';
    fullname:=ExtractFilePath(paramstr(0))+'UpdateConfig.ini';
    try
        downhttp:=TIdHTTP.Create(nil);
        MyStream:=TMemoryStream.Create;
       // downhttp.ReadTimeout:=2000;
        downhttp.Get(configurl,MyStream);
        if FileExists(fullname) then DeleteFile(fullname);
        MyStream.SaveToFile(fullname);
        downhttp.Free;
        MyStream.Free;
    except
        Application.MessageBox('��ȡ���������ļ�������������������ļ���',
          '��ʾ', MB_OK + MB_ICONSTOP);
        Application.Terminate;
        Exit;
    end;

    //������������ļ��Ƿ����
    if not FileExists(fullname) then
    begin
        Application.MessageBox('���������ļ������ڣ������ļ���',
          '��ʾ', MB_OK + MB_ICONSTOP);
        Application.Terminate;
        Exit;
    end;

    try
        myinifile:=TIniFile.Create(fullname);
        sa_exe:=Trim(myinifile.ReadString('setting','sa_exe',''));
        sa_updatefile:=Trim(myinifile.ReadString('setting','sa_updatefile',''));
        sa_updateurl:=Trim(myinifile.ReadString('setting','sa_updateurl',''));
        sa_version:=Trim(myinifile.ReadString('setting','sa_version',''));
        sa_pubdate:=Trim(myinifile.ReadString('setting','sa_pubdate',''));
        sa_filesize:=myinifile.ReadInteger('setting','sa_filesize',0);
        temp:=Trim(myinifile.ReadString('setting','sa_pubtxt',''));
        sa_pubtxt:='';
        while True do
        begin
              if Pos('#',temp)>0 then
              begin
                  SplitString(temp,'#',l,r);
                  sa_pubtxt:=sa_pubtxt+l+#13#10;
                  temp:=r;
              end
              else
              begin
                  sa_pubtxt:=sa_pubtxt+temp+#13#10;
                  Break;
              end;
        end;

        mmo_txt.Clear;
        mmo_txt.Lines.Add('�汾�ţ�'+sa_version);
        mmo_txt.Lines.Add('�������ڣ�'+sa_pubdate);
        mmo_txt.Lines.Add('');
        mmo_txt.Lines.Add('�������ݣ�');
        mmo_txt.Lines.Add(sa_pubtxt);

        stat1.Panels[0].Text:='�����°汾������������ť�������......';

    finally
        myinifile.free;
    end;
end;

procedure Tfrm_main.idhtp_downloadWork(Sender: TObject;
  AWorkMode: TWorkMode; const AWorkCount: Integer);
var alltime:Integer;
begin
    Application.ProcessMessages;
    Duration:=GetTickCount - StartTime;

    stat1.Panels[0].Text:='���������ļ����ļ���С:' + FloatToStr(sa_filesize div 1024) +'K' +'   ������:' + FloatToStr(AWorkCount div 1024) +'K'
           + '   �����:' + inttostr((AWorkCount*100) div sa_filesize) +'%'
           + '   ��ʱ:' + IntToStr(Duration div 1000)+'��';
    stat1.Update;

    if ((AWorkCount*100) div sa_filesize)>0 then
    begin
        try
          fltg_down.Progress:=(AWorkCount*100) div sa_filesize;
        except
        end;
    end;

    if not isdown then
    begin
        idhtp_download.Disconnect;
        btn_update.Enabled:=true;
        btn_pause.Enabled:=False;
        fltg_down.Progress:=0;
        stat1.Panels[0].Text:='�û���ֹ���أ������¿�ʼ';
    end;
end;

procedure Tfrm_main.idhtp_downloadWorkBegin(Sender: TObject;
  AWorkMode: TWorkMode; const AWorkCountMax: Integer);
begin
    downloadsize:=0;
end;

procedure Tfrm_main.btn_updateClick(Sender: TObject);
var tempfilename,targetfile:string;
    MyStream:TMemoryStream;
begin
    Application.ProcessMessages;
    stat1.Panels[0].Text:='��ʼ����.............';
    stat1.Update;

    isdown:=True;
    btn_update.Enabled:=False;
    btn_pause.Enabled:=true;
    
    targetfile:=ExtractFilePath(paramstr(0))+sa_exe;
    tempfilename:=ExtractFilePath(paramstr(0))+sa_updatefile;
    //����ļ����ڣ���ɾ��
    if FileExists(tempfilename) then
    DeleteFile(tempfilename);

    AllStartTime:=GetTickCount;  //�ܺ�ʱͳ��
    MyStream:=TMemoryStream.Create;
    try
        //��ʼ�����ļ�
        StartTime:=GetTickCount;
        //idhtp_download.ReadTimeout:=5000;
        idhtp_download.Get(sa_updateurl,MyStream);
        //�����ļ�
        MyStream.SaveToFile(tempfilename);
        MyStream.Free;
    except
        MyStream.Free;
        Application.MessageBox(PChar('�ļ�����ʧ�ܣ���'+#13#10#13#10+trim(idhtp_download.ResponseText)),
          '��ʾ', MB_OK + MB_ICONSTOP);
        exit;
    end;

    if isdown then
    begin
          if  FileExists(targetfile) then
          DeleteFile(targetfile);

          if RenameFile(tempfilename,targetfile) then
          begin
              Application.MessageBox('��ϲ�������³ɹ���', '��ʾ', MB_OK +
                MB_ICONINFORMATION);
              ShellExecute(Application.Handle, nil, PChar(targetfile), nil, nil, SW_SHOWNORMAL);
          end;
          close;
    end
    else
    begin
         DeleteFile(ExtractFilePath(paramstr(0))+sa_updatefile);
    end;
end;

procedure Tfrm_main.btn_pauseClick(Sender: TObject);
begin
      isdown:=False;
end;

end.
