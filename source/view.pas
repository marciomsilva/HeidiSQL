unit view;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ComCtrls, SynEdit, SynMemo, ExtCtrls, mysql_connection, SynRegExpr,
  helpers, mysql_api;

type
  TfrmView = class(TDBObjectEditor)
    editName: TEdit;
    lblName: TLabel;
    rgAlgorithm: TRadioGroup;
    SynMemoSelect: TSynMemo;
    lblSelect: TLabel;
    btnDiscard: TButton;
    btnSave: TButton;
    rgCheck: TRadioGroup;
    btnHelp: TButton;
    procedure btnHelpClick(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure editNameChange(Sender: TObject);
    procedure btnDiscardClick(Sender: TObject);
    procedure Modification(Sender: TObject);
  private
    { Private declarations }
    FEditViewName: WideString;
  public
    { Public declarations }
    constructor Create(AOwner: TComponent); override;
    procedure Init(ObjectName: WideString=''; ObjectType: TListNodeType=lntNone); override;
  end;

  
implementation

uses main;

{$R *.dfm}


{**
  Create: Restore GUI setup
}
constructor TfrmView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Align := alClient;
  SynMemoSelect.Highlighter := Mainform.SynSQLSyn1;
  Mainform.SynCompletionProposal.AddEditor(SynMemoSelect);
  InheritFont(Font);
  editName.MaxLength := NAME_LEN;
end;


{**
  FormShow: Fill controls with content in edit mode
}
procedure TfrmView.Init(ObjectName: WideString=''; ObjectType: TListNodeType=lntNone);
var
  Results: TMySQLQuery;
  db: WideString;
  rx: TRegExpr;
begin
	FEditViewName := ObjectName;
  if FEditViewName <> '' then begin
    // Edit mode
    editName.Text := FEditViewName;
    Mainform.SetEditorTabCaption(Self, FEditViewName);
    db := Mainform.ActiveDatabase;
    Results := Mainform.Connection.GetResults('SELECT * FROM '+Mainform.mask(DBNAME_INFORMATION_SCHEMA)+'.VIEWS ' +
      'WHERE TABLE_SCHEMA = '+esc(db)+' AND TABLE_NAME = '+esc(FEditViewName));
    if Results.RecordCount = 0 then
      raise Exception.Create('Can''t find view definition for "'+FEditViewName+'" in '+DBNAME_INFORMATION_SCHEMA);
    // Algorithm is not changeable as we cannot look up its current state!
    rgAlgorithm.Enabled := False;
    rgAlgorithm.ItemIndex := 0;
    rgCheck.ItemIndex := rgCheck.Items.IndexOf(Results.Col('CHECK_OPTION'));
    rgCheck.Enabled := Results.Col('IS_UPDATABLE') = 'YES';

    rx := TRegExpr.Create;
    rx.ModifierG := True;
    rx.ModifierI := True;
    rx.Expression := '\s+WITH\s+\w+\s+CHECK\s+OPTION$';
    SynMemoSelect.Text := rx.Replace(Results.Col('VIEW_DEFINITION'), '');
    rx.Free;
  end else begin
    // Create mode
    Mainform.SetEditorTabCaption(Self, '');
    editName.Text := 'Enter view name';
    rgAlgorithm.Enabled := True;
    rgAlgorithm.ItemIndex := 0;
    rgCheck.Enabled := True;
    rgCheck.ItemIndex := 0;
    SynMemoSelect.Text := 'SELECT ';
  end;
  // Ensure name is validated
  editNameChange(Self);
  MainForm.SetupSynEditors;
  Modified := False;
  btnSave.Enabled := Modified;
  btnDiscard.Enabled := Modified;
end;


{**
  View name has changed: Check for valid naming
}
procedure TfrmView.editNameChange(Sender: TObject);
begin
  try
    ensureValidIdentifier( editName.Text );
    editName.Font.Color := clWindowText;
    editName.Color := clWindow;
  except
    editName.Font.Color := clRed;
    editName.Color := clYellow;
  end;
  Modification(Sender);
end;


{**
  Lookup "Create|Alter View" in SQL help
}
procedure TfrmView.btnHelpClick(Sender: TObject);
var
  keyword: String;
begin
  if FEditViewName = '' then
    keyword := 'CREATE VIEW'
  else
    keyword := 'ALTER VIEW';
  Mainform.CallSQLHelpWithKeyword(keyword);
end;


procedure TfrmView.btnDiscardClick(Sender: TObject);
begin
  // Reinit editor, discarding changes
  Init(FEditViewName);
end;


{**
  Apply changes: Compose and execute SQL
}
procedure TfrmView.btnSaveClick(Sender: TObject);
var
  sql, viewname, renamed: String;
begin
  // Compose CREATE or ALTER statement
  if FEditViewName = '' then begin
    sql := 'CREATE ';
    viewname := editName.Text;
  end else begin
    sql := 'ALTER ';
    viewname := FEditViewName;
  end;
  viewname := Mainform.mask(viewname);
  if rgAlgorithm.Enabled and (rgAlgorithm.ItemIndex > -1) then
    sql := sql + 'ALGORITHM = '+Uppercase(rgAlgorithm.Items[rgAlgorithm.ItemIndex])+' ';
  sql := sql + 'VIEW ' + viewname+' AS '+SynMemoSelect.Text+' ';
  if rgCheck.Enabled and (rgCheck.ItemIndex > 0) then
    sql := sql + 'WITH '+Uppercase(rgCheck.Items[rgCheck.ItemIndex])+' CHECK OPTION';

  try
    Mainform.Connection.Query(sql);
    // Probably rename view
    if (FEditViewName <> '') and (FEditViewName <> editName.Text) then begin
      renamed := Mainform.mask(editName.Text);
      Mainform.Connection.Query('RENAME TABLE '+viewname + ' TO '+renamed);
    end;
    Mainform.RefreshTreeDB(Mainform.ActiveDatabase);
  except
    on E:Exception do
      MessageDlg(E.Message, mtError, [mbOk], 0);
  end;
end;


procedure TfrmView.Modification(Sender: TObject);
begin
  Modified := True;
  btnSave.Enabled := Modified;
  btnDiscard.Enabled := Modified;
end;


end.
