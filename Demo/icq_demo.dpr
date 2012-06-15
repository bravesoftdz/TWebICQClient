program icq_demo;

uses
  Vcl.Forms,
  main in 'main.pas' {FMain},
  Vcl.Themes,
  Vcl.Styles,
  icqapilite in '..\icqapilite.pas',
  httptools in '..\httptools.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('Metro Blue');
  Application.CreateForm(TFMain, FMain);
  Application.Run;
end.
