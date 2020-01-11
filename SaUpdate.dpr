program SaUpdate;

uses
  Forms,
  U_saupdate in 'U_saupdate.pas' {frm_main};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(Tfrm_main, frm_main);
  Application.Run;
end.
