{
      ORM Brasil � um ORM simples e descomplicado para quem utiliza Delphi

                   Copyright (c) 2016, Isaque Pinheiro
                          All rights reserved.
}

{
  @abstract(REST Componentes)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)
  @abstract(Website : http://www.ormbr.com.br)
  @abstract(Telagram : https://t.me/ormbr)
}

unit ormbr.server.restobjectset.session;

interface

uses
  DB,
  Rtti,
  TypInfo,
  Generics.Collections,
  /// ORMBr
  dbcbr.rtti.helper,
  dbcbr.mapping.classes,
  dbcbr.mapping.attributes,
  dbcbr.mapping.explorer,
  dbcbr.mapping.popular,
  dbebr.factory.interfaces,
  ormbr.core.consts,
  ormbr.types.blob,
  ormbr.server.restobject.manager;

type
  TRESTObjectSetSession = class
  protected
    FConnection: IDBConnection;
    FPageSize: Integer;
    FPageNext: Integer;
    FModifiedFields: TDictionary<String, TDictionary<String, String>>;
    FDeleteList: TObjectList<TObject>;
    FManager: TRESTObjectManager;
    FResultParams: TParams;
    FFindWhereUsed: Boolean;
    FWhere: String;
    FOrderBy: String;
  public
    constructor Create(const AConnection: IDBConnection; const AClassType: TClass;
      const APageSize: Integer = -1); virtual;
    destructor Destroy; override;
    function ExistSequence: Boolean; virtual;
    function ModifiedFields: TDictionary<String, TDictionary<String, String>>; virtual;
    // ObjectSet
    procedure Insert(const AObject: TObject); overload; virtual;
    procedure Insert(const AObjectList: TObjectList<TObject>); overload; virtual; abstract;
    procedure Update(const AObject: TObject; const AKey: String); overload; virtual;
    procedure Update(const AObjectList: TObjectList<TObject>); overload; virtual; abstract;
    procedure Delete(const AObject: TObject); overload; virtual;
    procedure Delete(const AID: Integer); overload; virtual; abstract;
    procedure LoadLazy(const AOwner, AObject: TObject); virtual;
    procedure NextPacketList(const AObjectList: TObjectList<TObject>); overload; virtual;
    function NextPacketList: TObjectList<TObject>; overload; virtual;
    function NextPacketList(const APageSize, APageNext: Integer): TObjectList<TObject>; overload; virtual;
    function NextPacketList(const AWhere, AOrderBy: String; const APageSize, APageNext: Integer): TObjectList<TObject>; overload; virtual;
    function ResultParams: TParams;
    // DataSet e ObjectSet
    procedure ModifyFieldsCompare(const AKey: String; const AObjectSource,
      AObjectUpdate: TObject); virtual;
    function Find: TObjectList<TObject>; overload; virtual;
    function Find(const AID: Integer): TObject; overload; virtual;
    function Find(const AID: String): TObject; overload; virtual;
    function FindWhere(const AWhere: String; const AOrderBy: String): TObjectList<TObject>; virtual;
    function FindOne(const AWhere: String): TObject;
    function DeleteList: TObjectList<TObject>; virtual;
  end;

implementation

uses
  ormbr.objects.helper;

{ TRESTObjectSetSession<M> }

constructor TRESTObjectSetSession.Create(const AConnection: IDBConnection;
  const AClassType: TClass; const APageSize: Integer = -1);
begin
  FPageSize := APageSize;
  FModifiedFields := TObjectDictionary<String, TDictionary<String, String>>.Create([doOwnsValues]);
  FDeleteList := TObjectList<TObject>.Create;
  FResultParams := TParams.Create;
  FManager := TRESTObjectManager.Create(Self, AConnection, AClassType, APageSize);
  // Inicia uma lista interna para gerenciar campos alterados
  FModifiedFields.Clear;
  FModifiedFields.TrimExcess;
  FModifiedFields.Add(AClassType.ClassName, TDictionary<String, String>.Create);
end;

destructor TRESTObjectSetSession.Destroy;
begin
  FDeleteList.Clear;
  FDeleteList.Free;
  FModifiedFields.Clear;
  FModifiedFields.Free;
  FResultParams.Clear;
  FResultParams.Free;
  FManager.Free;
  inherited;
end;

function TRESTObjectSetSession.ModifiedFields: TDictionary<String, TDictionary<String, String>>;
begin
  Result := FModifiedFields;
end;

procedure TRESTObjectSetSession.Delete(const AObject: TObject);
begin
  FManager.DeleteInternal(AObject);
end;

function TRESTObjectSetSession.DeleteList: TObjectList<TObject>;
begin
  Result := FDeleteList;
end;

function TRESTObjectSetSession.ExistSequence: Boolean;
begin
  Result := FManager.ExistSequence;
end;

function TRESTObjectSetSession.Find(const AID: String): TObject;
begin
  FFindWhereUsed := False;
  Result := FManager.Find(AID);
end;

function TRESTObjectSetSession.FindOne(const AWhere: String): TObject;
begin
  Result := FManager.FindOne(AWhere);
end;

function TRESTObjectSetSession.FindWhere(const AWhere, AOrderBy: String): TObjectList<TObject>;
begin
  FFindWhereUsed := True;
  FWhere := AWhere;
  FOrderBy := AOrderBy;
  if FPageSize > -1 then
  begin
    Result := NextPacketList(FWhere, FOrderBy, FPageSize, FPageNext);
    Exit;
  end;
  Result := FManager.FindWhere(FWhere, FOrderBy);
end;

function TRESTObjectSetSession.Find(const AID: Integer): TObject;
begin
  FFindWhereUsed := False;
  Result := FManager.Find(AID);
end;

function TRESTObjectSetSession.Find: TObjectList<TObject>;
begin
  FFindWhereUsed := False;
  Result := FManager.Find;
end;

procedure TRESTObjectSetSession.Insert(const AObject: TObject);
begin
  FManager.InsertInternal(AObject);
end;

procedure TRESTObjectSetSession.ModifyFieldsCompare(const AKey: String;
  const AObjectSource, AObjectUpdate: TObject);
var
  LColumn: TColumnMapping;
  LColumns: TColumnMappingList;
  LProperty: TRttiProperty;
begin
  LColumns := TMappingExplorer
                  .GetMappingColumn(AObjectSource.ClassType);
  for LColumn in LColumns do
  begin
    LProperty := LColumn.ColumnProperty;
    if LProperty.IsNoUpdate then
      Continue;
    if LProperty.PropertyType.TypeKind in cPROPERTYTYPES_1 then
      Continue;
    if not FModifiedFields.ContainsKey(AKey) then
      FModifiedFields.Add(AKey, TDictionary<String, String>.Create);
    // Se o tipo da property for tkRecord provavelmente tem Nullable nela
    // Se n�o for tkRecord entra no ELSE e pega o valor de forma direta
    if LProperty.PropertyType.TypeKind in [tkRecord] then // Nullable ou TBlob
    begin
      if LProperty.IsBlob then
      begin
        if LProperty.GetValue(AObjectSource).AsType<TBlob>.ToSize <>
           LProperty.GetValue(AObjectUpdate).AsType<TBlob>.ToSize then
        begin
          FModifiedFields.Items[AKey].Add(LProperty.Name, LColumn.ColumnName);
        end;
      end
      else
      begin
        if LProperty.GetNullableValue(AObjectSource).AsType<Variant> <>
           LProperty.GetNullableValue(AObjectUpdate).AsType<Variant> then
        begin
          FModifiedFields.Items[AKey].Add(LProperty.Name, LColumn.ColumnName);
        end;
      end;
    end
    else
    begin
      if LProperty.GetValue(AObjectSource).AsType<Variant> <>
         LProperty.GetValue(AObjectUpdate).AsType<Variant> then
      begin
        FModifiedFields.Items[AKey].Add(LProperty.Name, LColumn.ColumnName);
      end;
    end;
  end;
end;

function TRESTObjectSetSession.NextPacketList(const AWhere, AOrderBy: String;
  const APageSize, APageNext: Integer): TObjectList<TObject>;
begin
  Result := nil;
  if not FManager.FetchingRecords then
    Result := FManager.NextPacketList(AWhere, AOrderBy, APageSize, APageNext);
end;

function TRESTObjectSetSession.NextPacketList: TObjectList<TObject>;
begin
  Result := nil;
  if FManager.FetchingRecords then
    Exit;

  FPageNext := FPageNext + FPageSize;
  if FFindWhereUsed then
    Result := FManager.NextPacketList(FWhere, FOrderBy, FPageSize, FPageNext)
  else
    Result := FManager.NextPacketList(FPageSize, FPageNext);
end;

procedure TRESTObjectSetSession.NextPacketList(const AObjectList: TObjectList<TObject>);
begin
  if FManager.FetchingRecords then
    Exit;

  FPageNext := FPageNext + FPageSize;
  if FFindWhereUsed then
    FManager.NextPacketList(AObjectList, FWhere, FOrderBy, FPageSize, FPageNext)
  else
    FManager.NextPacketList(AObjectList, FPageSize, FPageNext);
end;

function TRESTObjectSetSession.ResultParams: TParams;
begin
  Result := FResultParams;
end;

procedure TRESTObjectSetSession.Update(const AObject: TObject; const AKey: String);
begin
  FManager.UpdateInternal(AObject, FModifiedFields.Items[AKey]);
end;

procedure TRESTObjectSetSession.LoadLazy(const AOwner, AObject: TObject);
begin
//  FManager.LoadLazy(AOwner, AObject);
end;

function TRESTObjectSetSession.NextPacketList(const APageSize,
  APageNext: Integer): TObjectList<TObject>;
begin
  Result := nil;
  if not FManager.FetchingRecords then
    Result := FManager.NextPacketList(APageSize, APageNext);
end;

end.

