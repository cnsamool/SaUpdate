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
    isdown:Boolean;         //是否下载文件
    sa_exe:string;          //可执行文件名
    sa_updatefile:string;   //升级临时文件名
    sa_updateurl:string;    //升级URL地址
    sa_version:string;      //版本号
    sa_pubdate:string;      //发布日期
    sa_pubtxt:string;       //升级日志
    sa_filesize:Longword;   //文件大小
    downloadsize:Integer;    //已下载字节
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
            //使用indy获取文件大小
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
    //下载升级配置文件
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
        Application.MessageBox('获取升级配置文件出错，请检查网络或配置文件！',
          '提示', MB_OK + MB_ICONSTOP);
        Application.Terminate;
        Exit;
    end;

    //检查升级配置文件是否存在
    if not FileExists(fullname) then
    begin
        Application.MessageBox('升级配置文件不存在，请检查文件！',
          '提示', MB_OK + MB_ICONSTOP);
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
        mmo_txt.Lines.Add('版本号：'+sa_version);
        mmo_txt.Lines.Add('发布日期：'+sa_pubdate);
        mmo_txt.Lines.Add('');
        mmo_txt.Lines.Add('更新内容：');
        mmo_txt.Lines.Add(sa_pubtxt);

        stat1.Panels[0].Text:='发现新版本，请点击升级按钮升级软件......';

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

    stat1.Panels[0].Text:='正在下载文件，文件大小:' + FloatToStr(sa_filesize div 1024) +'K' +'   已下载:' + FloatToStr(AWorkCount div 1024) +'K'
           + '   已完成:' + inttostr((AWorkCount*100) div sa_filesize) +'%'
           + '   耗时:' + IntToStr(Duration div 1000)+'秒';
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
        stat1.Panels[0].Text:='用户中止下载，请重新开始';
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
    stat1.Panels[0].Text:='开始升级.............';
    stat1.Update;

    isdown:=True;
    btn_update.Enabled:=False;
    btn_pause.Enabled:=true;
    
    targetfile:=ExtractFilePath(paramstr(0))+sa_exe;
    tempfilename:=ExtractFilePath(paramstr(0))+sa_updatefile;
    //如果文件存在，则删除
    if FileExists(tempfilename) then
    DeleteFile(tempfilename);

    AllStartTime:=GetTickCount;  //总耗时统计
    MyStream:=TMemoryStream.Create;
    try
        //开始下载文件
        StartTime:=GetTickCount;
        //idhtp_download.ReadTimeout:=5000;
        idhtp_download.Get(sa_updateurl,MyStream);
        //保存文件
        MyStream.SaveToFile(tempfilename);
        MyStream.Free;
    except
        MyStream.Free;
        Application.MessageBox(PChar('文件下载失败！！'+#13#10#13#10+trim(idhtp_download.ResponseText)),
          '提示', MB_OK + MB_ICONSTOP);
        exit;
    end;

    if isdown then
    begin
          if  FileExists(targetfile) then
          DeleteFile(targetfile);

          if RenameFile(tempfilename,targetfile) then
          begin
              Application.MessageBox('恭喜您，更新成功！', '提示', MB_OK +
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
