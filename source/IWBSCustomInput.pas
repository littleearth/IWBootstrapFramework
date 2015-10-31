unit IWBSCustomInput;

interface

uses
  System.Classes, System.SysUtils, System.StrUtils, Vcl.Controls, Data.db,
  IWBSCustomControl,
  IWTypes, IWHTMLTag,
  IWXMLTag, IWRenderContext, IWBaseInterfaces, IWHTML40Interfaces,
  IWBSCommon;

type
  TIWBSInputType = (bsitText, bsitPassword, bsitDateTimeLocal, bsitDate, bsitMonth, bsitTime, bsitWeek, bsitNumber, bsitEmail, bsitUrl, bsitSearch, bsitTel, bsitColor, bsitHidden, bsitFile);

const
  aIWBSInputType: array[bsitText..bsitFile] of string = ('text', 'password', 'datetime-local', 'date', 'month', 'time', 'week', 'number', 'email', 'url', 'search', 'tel', 'color', 'hidden', 'file');

type
  TIWBSCustomInput = class(TIWBSCustomDbControl, IIWInputControl, IIWSubmitControl, IIWInputControl40, IIWAutoEditableControl)
  private
    FAutoEditable: Boolean;
    FAutoFocus: boolean;
    FDbEditable: boolean;
    FCaption: string;
    FInputType: TIWBSInputType;
    FOnSubmit: TNotifyEvent;
    FReadOnly: Boolean;
    FRequired: Boolean;
    FSubmitParam : string;
    procedure EditingChanged;
  protected
    FIsStatic: boolean;
    FSupportReadOnly: boolean;
    FText: TCaption;

    FOldText: string;

    procedure CheckData(AContext: TIWCompContext); override;
    procedure DoSubmit;
    procedure SetCaption(const AValue: string);
    procedure SetReadOnly(const AValue:boolean);
    procedure SetRequired(const AValue:boolean);
    procedure SetValue(const AValue: string);
    procedure Submit(const AValue: string); override;
    function FormHasOnDefaultActionSet:boolean;
    function get_ShouldRenderTabOrder: boolean;override;

    procedure GetInputControlNames(ANames: TStringList); override;
    function IsForThisControl(AName: string): boolean; override;

    procedure InternalRenderHTML(const AHTMLName: string; AContext: TIWCompContext; var AHTMLTag: TIWHTMLTag); override;
    procedure InternalSetValue(const ASubmitValue: string; var ATextValue: string; var ASetFieldValue: boolean); virtual;

    function IsReadOnly: boolean; override;
    function IsDisabled: boolean; override;

    function getText: TCaption; override;

    property ReadOnly: boolean read FReadOnly write SetReadOnly;
    property BSInputType: TIWBSInputType read FInputType write FInputType;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Invalidate; override;
    function GetSubmitParam : String;
    procedure SetText(const AValue: TCaption); override;
  published
    property AutoEditable: Boolean read FAutoEditable write FAutoEditable default True;
    property AutoFocus: boolean read FAutoFocus write FAutoFocus default False;
    property Caption: string read FCaption write SetCaption;
    property DoSubmitValidation;
    property Editable default True;
    property Enabled default True;
    property ExtraTagParams;
    property FriendlyName;
    property NonEditableAsLabel default False;
    property Required: Boolean read FRequired write SetRequired default False;
    property ScriptEvents;
    property SubmitOnAsyncEvent default True;
    property TabStop default True;
    property Text: TCaption read GetText write SetText;

    property OnSubmit: TNotifyEvent read FOnSubmit write FOnSubmit;
  end;

  TIWBSCustomTextInput = class(TIWBSCustomInput)
  private
    FPlaceHolder: string;
    FTextAlignment: TIWBSTextAlignment;
    FTextCase: TIWBSTextCase;
  protected
    procedure InternalRenderAsync(const AHTMLName: string; AContext: TIWCompContext); override;
    procedure InternalRenderCss(var ACss: string); override;
  published
    constructor Create(AOwner: TComponent); override;
    property BSTextAlignment: TIWBSTextAlignment read FTextAlignment write FTextAlignment default bstaDefault;
    property BSTextCase: TIWBSTextCase read FTextCase write FTextCase default bstcDefault;
    property MaxLength default 0;
    property PlaceHolder: string read FPlaceHolder write FPlaceHolder;
    property ReadOnly default False;
  end;

  TIWBSCustomSelectInput = class(TIWBSCustomInput)
  private
    FItems: TStringList;
    FItemsHaveValues: boolean;
    procedure SetItems(AValue: TStringList);
    procedure SetItemsHaveValues(AValue: boolean);
  protected
    FItemIndex: integer;

    procedure InternalRenderCss(var ACss: string); override;
    procedure InternalSetValue(const ASubmitValue: string; var ATextValue: string; var ASetFieldValue: boolean); override;
    function FindValue(const AValue: string): integer;
    procedure Loaded; override;
    procedure OnItemsChange(ASender : TObject); virtual;
    procedure SetItemIndex(AValue: integer); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetText(const AValue: TCaption); override;
  published
    property ItemIndex: integer read FItemIndex write SetItemIndex default -1;
    property Items: TStringList read FItems write SetItems;
    property ItemsHaveValues: boolean read FItemsHaveValues write SetItemsHaveValues default False;
  end;

implementation

uses
  IWBaseForm, IWDBCommon, IWDBStdCtrls, IWForm, IWMarkupLanguageTag, Dialogs;

var
  LFormatSettings: TFormatSettings;

{$region 'TIWBSCustomInput'}
constructor TIWBSCustomInput.Create(AOwner: TComponent);
begin
  inherited;
  FAutoEditable := True;
  FAutoFocus := False;
  FCaption := '';
  FInputType := bsitText;
  FNonEditableAsLabel := False;
  FReadOnly := False;
  FRequired := False;

  FCanReceiveFocus := True;
  FNeedsFormTag := True;
  FIsStatic := False;
  FSupportReadOnly := False;

  Height := 25;
  Width := 121;
  TabStop := True;
end;

procedure TIWBSCustomInput.Invalidate;
begin
  DoRefreshControl := true;
  inherited;
end;

procedure TIWBSCustomInput.GetInputControlNames(ANames: TStringList);
begin
  ANames.Text := HTMLName+InputSuffix;
end;

function TIWBSCustomInput.IsForThisControl(AName: string): boolean;
begin
  Result := SameText(HTMLName+InputSuffix, AName);
end;

function TIWBSCustomInput.GetText: TCaption;
begin
  Result := FText;
end;

procedure TIWBSCustomInput.SetText(const AValue: TCaption);
begin
  FText := AValue;
  invalidate;
end;

procedure TIWBSCustomInput.CheckData(AContext: TIWCompContext);
var
  LField: TField;
begin
  if DataSource <> nil then
    begin
      if CheckDataSource(DataSource, DataField, LField) then
        begin
          if AutoEditable then
            FDbEditable := InEditMode(DataSource.Dataset) and FieldIsEditable(DataSource, DataField);
          if Assigned(LField.OnGetText) then
            Text := LField.Text
          else if (FInputType = bsitNumber) and (LField.DataType in [ftFloat, ftCurrency, ftBCD, ftFMTBCD, ftExtended]) then
            Text := FloatToStr(LField.AsExtended, LFormatSettings)

          // aca agregar todos los tipos fecha que hay

          else if (FInputType = bsitDateTimeLocal) and (LField.DataType in [ftDate, ftTime, ftDateTime, ftTimeStamp, ftOraTimeStamp]) then
            Text := FormatDateTime('yyyy-mm-dd"T"hh:nn',LField.AsDateTime)
          else
            Text := LField.AsString;
        end
      else
        begin
          Text := '';
          if AutoEditable then
            FDbEditable := True;
        end;
    end
  else
    FDbEditable := true;
end;

procedure TIWBSCustomInput.SetValue(const AValue: string);
var
  LField: TField;
  LText: string;
  LSave: boolean;
begin
  if RequiresUpdateNotification(Parent) then
    UpdateNotifiedInterface(Parent).NotifyUpdate(Self,AValue);
  LSave := True;
  InternalSetValue(AValue, LText, LSave);
  if (FOldText <> LText) or (FText <> LText) then begin
    FOldText := LText;
    FText := LText;
    if CheckDataSource(DataSource, DataField, LField) and LSave then
      if InEditMode(DataSource.DataSet) and LField.CanModify then
        begin
          if Assigned(LField.OnSetText) then
            LField.Text := LText
          else
            if FInputType = bsitNumber then
              LField.AsFloat := StrToFloat(AValue, LFormatSettings)
            else if FInputType = bsitDateTimeLocal then  // agregar todos los tipos fecha que hay
              LField.AsDateTime := StrToDateTime(ReplaceStr(AValue,'T',' '), LFormatSettings)
            else
              LField.AsString := LText;
        end
      else
        raise EIWDataSetNotEditingError.Create(DataSource);
    CheckData(nil);
    Invalidate;
  end;
end;

procedure TIWBSCustomInput.EditingChanged;
begin
  Invalidate;
end;

function TIWBSCustomInput.GetSubmitParam: String;
begin
  Result := FSubmitParam;
end;

function TIWBSCustomInput.get_ShouldRenderTabOrder: boolean;
begin
  result := Editable or (NonEditableAsLabel = false);
end;

function TIWBSCustomInput.FormHasOnDefaultActionSet:boolean;
var
  LForm: TIWBaseForm;
begin
  Result := false;
  LForm := OwnerForm;
  if Assigned(LForm) then
    if LForm is TIWForm then
      result := Assigned( TIWForm(LForm).OnDefaultAction );
end;

procedure TIWBSCustomInput.DoSubmit;
begin
  if Assigned(OnSubmit) then
    OnSubmit(Self)
  else if FormHasOnDefaultActionSet then
    TIWForm(OwnerForm).OnDefaultAction(Self);
end;

procedure TIWBSCustomInput.Submit(const AValue: string);
begin
  FSubmitParam := AValue;
  DoSubmit;
end;

procedure TIWBSCustomInput.InternalSetValue(const ASubmitValue: string; var ATextValue: string; var ASetFieldValue: boolean);
begin
  ATextValue := ASubmitValue;
end;

function TIWBSCustomInput.IsReadOnly: boolean;
begin
  Result := FSupportReadOnly and (FReadOnly or not FDbEditable);
end;

function TIWBSCustomInput.IsDisabled: boolean;
begin
  Result := not (Enabled and Editable and (FDbEditable or FSupportReadOnly));
end;

procedure TIWBSCustomInput.InternalRenderHTML(const AHTMLName: string; AContext: TIWCompContext; var AHTMLTag: TIWHTMLTag);
begin
  inherited;
  FOldText := FText;
end;

procedure TIWBSCustomInput.SetCaption(const AValue: string);
begin
  FCaption := AValue;
  Invalidate;
end;

procedure TIWBSCustomInput.SetReadOnly(const AValue:boolean);
begin
  if FReadOnly <> AValue then
  begin
    FReadOnly := AValue;
    Invalidate;
  end;
end;

procedure TIWBSCustomInput.SetRequired(const AValue:boolean);
begin
  if FRequired <> AValue then begin
    FRequired := AValue;
    Invalidate;
  end;
end;
{$endregion}

{$region 'TIWBSCustomTextInput'}
constructor TIWBSCustomTextInput.Create(AOwner: TComponent);
begin
  inherited;
  FSupportReadOnly := True;
  FTextAlignment := bstaDefault;
  FTextCase := bstcDefault;
end;

procedure TIWBSCustomTextInput.InternalRenderAsync(const AHTMLName: string; AContext: TIWCompContext);
begin
  inherited;
  if FIsStatic then
    SetAsyncHtml(AContext, AHTMLName, FText, FOldText)
  else
    SetAsyncText(AContext, AHTMLName, FText, FOldText);
end;

procedure TIWBSCustomTextInput.InternalRenderCss(var ACss: string);
begin
  inherited;
  FIsStatic := not Editable and NonEditableAsLabel;
  if FInputType <> bsitFile then
    if FIsStatic then
      AddCssClass(ACss, 'form-control-static')
    else
      AddCssClass(ACss, 'form-control');
  if FTextAlignment <> bstaDefault then
    AddCssClass(ACss, aIWBSTextAlignment[FTextAlignment]);
  if FTextCase <> bstcDefault then
    AddCssClass(ACss, aIWBSTextCase[FTextCase]);
end;
{$endregion}

{$region 'TIWBSCustomSelectInput'}
constructor TIWBSCustomSelectInput.Create(AOwner: TComponent);
begin
  inherited;
  FItemIndex := -1;
  FItems := TStringList.Create;
  FItems.OnChange := OnItemsChange;
  FItemsHaveValues := False;
  FSupportReadOnly := False;
end;

destructor TIWBSCustomSelectInput.Destroy;
begin
  FreeAndNil(FItems);
  inherited;
end;

procedure TIWBSCustomSelectInput.OnItemsChange(ASender : TObject);
begin
  Invalidate;
end;

procedure TIWBSCustomSelectInput.Loaded;
begin
  SetItemIndex(FItemIndex);
end;

procedure TIWBSCustomSelectInput.SetItemIndex(AValue: integer);
begin
  if csReading in ComponentState then
    FItemIndex := AValue
  else
    begin
      if (AValue >= -1) and (AValue < FItems.Count) then
        begin
          FItemIndex := AValue;
          if FItemIndex >= 0 then
            if FItemsHaveValues then
              FText := FItems.ValueFromIndex[AValue]
            else
              FText := FItems[AValue]
          else
            FText := '';
        end
      else
        begin
          FItemIndex := -1;
          FText := ''
        end;
      Invalidate;
    end;
end;

procedure TIWBSCustomSelectInput.SetItems(AValue: TStringList);
begin
  FItems.Assign(AValue);
end;

procedure TIWBSCustomSelectInput.SetItemsHaveValues(AValue: boolean);
begin
  FItemsHaveValues := AValue;
  Invalidate;
end;

function TIWBSCustomSelectInput.FindValue(const AValue: string): integer;
var
  i: integer;
begin
  Result := -1;
  for i := 0 to FItems.Count-1 do
    if AnsiSameStr(IfThen(FItemsHaveValues, FItems.ValueFromIndex[i], FItems[i]), AValue) then begin
      Result := i;
      Break;
    end;
end;

procedure TIWBSCustomSelectInput.SetText(const AValue: TCaption);
begin
  inherited;
  FItemIndex := FindValue(FText);
end;

procedure TIWBSCustomSelectInput.InternalRenderCss(var ACss: string);
begin
  AddCssClass(ACss, 'form-control');
  inherited;
end;

procedure TIWBSCustomSelectInput.InternalSetValue(const ASubmitValue: string; var ATextValue: string; var ASetFieldValue: boolean);
var
  i: integer;
begin
  if TryStrToInt(ASubmitValue, i) and (i >= 0) and (i < Items.Count) then
    begin
      if ItemsHaveValues then
        ATextValue := Items.ValueFromIndex[i]
      else
        ATextValue := Items[i];
      FItemIndex := i;
    end
  else
    begin
      ATextValue := '';
      FItemIndex := -1;
    end;
end;
{$endregion}

initialization
  LFormatSettings := TFormatSettings.Create('en-US'); // locale de us
  LFormatSettings.DateSeparator := '-';
  LFormatSettings.LongDateFormat := 'yyyy-mm-dd';
  LFormatSettings.ShortDateFormat := LFormatSettings.LongDateFormat;
  LFormatSettings.LongTimeFormat := 'hh:nn:ss';
  LFormatSettings.ShortTimeFormat := LFormatSettings.LongTimeFormat;

end.