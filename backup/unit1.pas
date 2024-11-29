unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ComCtrls,
  ZMemTable, ZDataset, StrUtils, DB, fileutil;

type

  { TForm1 }

  TForm1 = class(TForm)
    btnPesquisar: TButton;
    edtPastaPadrao: TEdit;
    edtArquivoBase: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    memResultado: TMemo;
    stbPosicionamento: TStatusBar;
    procedure btnPesquisarClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
  private
     procedure ListUnitsInFile(FileName: String; PathDefault : String);
     function ListUnitsDependencies(UnitList: String; PathDefault: String): String;
     function RemoveCaracters(Line : String): String;
  public

  end;

var
  Form1: TForm1;
  PrincipalPath,
  StrFile : String;
  MemTable,
  MemTablePesquisados: TZMemTable;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.btnPesquisarClick(Sender: TObject);
begin
  if (trim(edtPastaPadrao.Text) = '') and (trim(edtArquivoBase.Text) = '') then
     ShowMessage('Pasta padrão ou arquivo base não informado !')
  else
     Begin
        memResultado.Clear;
        // Abrir o TZMemTable para manipulação de dados
        MemTable.Open;
        MemTable.Empty;
        MemTable.Open;
        MemTablePesquisados.Open;
        MemTablePesquisados.Empty;
        MemTablePesquisados.Open;
        PrincipalPath := trim(edtPastaPadrao.Text);
        ListUnitsInFile(trim(edtArquivoBase.Text),trim(edtPastaPadrao.Text));
        MemTable.First;
        while not MemTable.Eof do
           Begin
              MemResultado.Lines.Add(MemTable.FieldByName('Caminho').AsString);
              MemTable.Next;
           end;
     end;
end;

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  MemTable.Free;
  MemTablePesquisados.Free;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  MemTable := TZMemTable.Create(Self);
  MemTablePesquisados := TZMemTable.Create(Self);
  // Definir os campos da tabela
  MemTable.FieldDefs.Add('ID', ftAutoInc);  // Campo ID
  MemTable.FieldDefs.Add('Unit', ftString, 200);  // Campo Unit
  MemTable.FieldDefs.Add('Caminho', ftString, 200);  // Campo Caminho
  MemTable.IndexFieldNames:='ID';
  // Definir os campos da tabela
  MemTablePesquisados.FieldDefs.Add('ID', ftAutoInc);  // Campo ID
  MemTablePesquisados.FieldDefs.Add('Unit', ftString, 200);  // Campo Unit
  MemTablePesquisados.IndexFieldNames:='ID';

end;

procedure TForm1.ListUnitsInFile(FileName: String; PathDefault: String);
var
  FileContent,
  Units: TStringList;
  Line,
  UnitsLine,
  StrLine,
  UnitSearch,
  ResultSearch: String;
  i,
  j,
  x: integer;

begin
  FileContent := TStringList.Create;
  Units := TStringList.Create;

  i := 0;
  j := 0;
  try
    if PathDefault = '' then
       PathDefault := 'c:\';
    FileContent.LoadFromFile(FileName);
    UnitsLine := '';
    StrFile := FileName;
    if FileName = 'c:\softwared10\Mark_32\DlgRepre.pas' then
       UnitsLine := '';
    for Line in FileContent do
       Begin
         Inc(i);
         if StartsText('uses', Trim(Line)) then
            begin
               j := i;
               StrLine := Line;
               StrLine := RemoveCaracters(StrLine);
               if (trim(UnitsLine) = '') then
                  UnitsLine := UnitsLine + ' ' + StrLine
               else
                  UnitsLine := UnitsLine + ',' + StrLine;
               while not EndsText(';', Trim(UnitsLine)) do
                  begin
                    StrLine := FileContent[j];
                    StrLine := RemoveCaracters(StrLine);
                    UnitsLine := UnitsLine + ' ' + StrLine;
                    Inc(j);
                  end;
               // Remover a palavra 'uses' e o ponto e vírgula
               UnitsLine := Trim(StringReplace(UnitsLine, 'uses', '', [rfIgnoreCase]));
               UnitsLine := Trim(StringReplace(UnitsLine, ';', '', [rfReplaceAll]));

               // Separar as units
               Units.DelimitedText := StringReplace(UnitsLine, ',', ' ', [rfReplaceAll]);
            end;
       end;
    //MemResultado.Lines.Add(Units.Text);
    for x := 0 to Units.Count - 1 do
       Begin
         if not MemTablePesquisados.Locate('Unit',trim(Units[x]),[]) then
            Begin
               MemTablePesquisados.Append;
               MemTablePesquisados.FieldByName('Unit').AsString := trim(Units[x]);
               MemTablePesquisados.Post;
               if not MemTable.Locate('Unit',trim(Units[x]),[]) then
                  Begin
                    UnitSearch := Units[x];
                    UnitSearch := ListUnitsDependencies(Units[x],PathDefault);
                    if trim(UnitSearch) <> '' then
                       Begin
                          UnitSearch := StringReplace(UnitSearch , '\\',  '\' ,[rfReplaceAll, rfIgnoreCase]);
                          if (trim(UnitSearch) <> '') then
                             Begin
                                MemTable.Append;
                                MemTable.FieldByName('Caminho').AsString := trim(UnitSearch);
                                MemTable.FieldByName('Unit').AsString := trim(Units[x]);
                                MemTable.Post;
                                stbPosicionamento.SimpleText := 'Incluído ' + trim(UnitSearch);
                             end;
                       end;
                  end;
            end;
       end;
  finally
    FileContent.Free;
    Units.Free;
  end;

end;

function TForm1.ListUnitsDependencies(UnitList: String; PathDefault: String): String;
var
  i,
  j,
  x,
  y,
  k: integer;
  Units,
  UnitOrigin,
  Folders: TStringList;
  UnitSearch,
  ResultSearch: String;
  R,
  S:TSearchRec;
begin
  Units := TStringList.Create;
  UnitOrigin := TStringList.Create;
  UnitOrigin.Add(UnitList);
  if Pos('PluginManager',UnitList) > 0 then
     UnitSearch := '';
  try
     for i := 0 to UnitOrigin.Count - 1 do
        if trim(UnitOrigin[i]) <> '' then
           Begin
              j := FindFirst(IncludeTrailingPathDelimiter(PathDefault) + '*', faDirectory,R);
              while (j = 0) do
                 Begin
                    if (R.Name <> '.') and (R.Name <> '..') then
                       Begin
                          if (R.Attr = 16) then
                             Begin
                                UnitSearch := IncludeTrailingPathDelimiter(IncludeTrailingPathDelimiter(PathDefault) + R.Name) + UnitOrigin[i].Trim + '.pas';
                                x := FindFirst(UnitSearch,faAnyFile,S);
                                if x <> 0 then
                                   Begin
                                      UnitSearch := IncludeTrailingPathDelimiter(PathDefault) + R.Name;
                                      ResultSearch := ListUnitsDependencies(UnitOrigin[i].Trim,UnitSearch);
                                      if (trim(ResultSearch) <> '') then
                                         Units.Add(trim(ResultSearch));
                                   end
                                else
                                   Begin
                                      while (x = 0) do
                                         Begin
                                            if Pos(UnitOrigin[i].Trim,Units.Text) <= 0 then
                                               Begin
                                                  ResultSearch := PathDefault + '\' + R.Name;
                                                  ResultSearch := StringReplace(PathDefault + '\' + R.Name, PrincipalPath, '..', [rfReplaceAll]);
                                                  ResultSearch := UnitOrigin[i].Trim + ' in ' + ResultSearch + '\' + S.Name + ',';
                                                  ResultSearch := StringReplace(ResultSearch , '\\',  '\' ,[rfReplaceAll, rfIgnoreCase]);
                                                  if trim(ResultSearch) <> '' then
                                                     Units.Add(trim(ResultSearch));
                                                  if Pos('PluginManager',UnitList) > 0 then
                                                     k := 0;
                                                  ListUnitsInFile(PathDefault + '\' + R.Name + '\' + S.Name, PrincipalPath);
                                               end;
                                            x := FindNext(S);
                                         end;
                                   end;
                                FindClose(S);
                             end;
                       end;
                    j := FindNext(R);
                 end;
              FindClose(R);
           end;

  finally
  end;
  Result := Units.Text;
  Units.Free;
  UnitOrigin.Free;
end;

function TForm1.RemoveCaracters(Line: String): String;
var
  PosicaoFinal : integer;
begin
  if (trim(Line) <> '') then
     Begin
        while Pos('{',Line) > 0 do
           Begin
              PosicaoFinal := Pos('{',Line)-1;
              if PosicaoFinal < 0 then
                 PosicaoFinal := 0;
              Line := Copy(Line,0,PosicaoFinal) + ' ' + Copy(Line,Pos('}',Line)+1);
              if (trim(Line) = '') then
                 break;
           end;
        while Pos('(*',Line) > 0 do
           Begin
              PosicaoFinal := Pos('(*',Line)-1;
              if PosicaoFinal < 0 then
                 PosicaoFinal := 0;
              Line := Copy(Line,0,PosicaoFinal) + ' ' + Copy(Line,Pos('*)',Line)+2);
              if (trim(Line) = '') then
                 break;
           end;
        while Pos('//',Line) > 0 do
           Begin
              PosicaoFinal := Pos('//',Line)-1;
              if PosicaoFinal < 0 then
                 PosicaoFinal := 0;
              Line := Copy(Line,0,PosicaoFinal);
              if (trim(Line) = '') then
                 break;
           end;
     end;
  Result := trim(Line);
end;

end.

