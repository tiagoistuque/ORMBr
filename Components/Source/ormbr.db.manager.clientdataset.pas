{
      ORM Brasil � um ORM simples e descomplicado para quem utiliza Delphi

                   Copyright (c) 2016, Isaque Pinheiro
                          All rights reserved.

                    GNU Lesser General Public License
                      Vers�o 3, 29 de junho de 2007

       Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
       A todos � permitido copiar e distribuir c�pias deste documento de
       licen�a, mas mud�-lo n�o � permitido.

       Esta vers�o da GNU Lesser General Public License incorpora
       os termos e condi��es da vers�o 3 da GNU General Public License
       Licen�a, complementado pelas permiss�es adicionais listadas no
       arquivo LICENSE na pasta principal.
}

{ @abstract(ORMBr Framework.)
  @created(20 Jul 2016)
  @author(Isaque Pinheiro <isaquepsp@gmail.com>)
  @author(Skype : ispinheiro)

  ORM Brasil � um ORM simples e descomplicado para quem utiliza Delphi.
}

unit ormbr.db.manager.clientdataset;

interface

uses
  DB,
  Rtti,
  DBClient,
  Classes,
  SysUtils,
  Variants,
  Generics.Collections,
  dbebr.factory.interfaces,
  ormbr.dataset.base.adapter,
  ormbr.dataset.clientdataset;

type
  TManagerClientDataSet = class
  private
    FNestedList: TDictionary<String, TObjectList<TObject>>;
    FOwnerNestedList: Boolean;
    FConnection: IDBConnection;
    FRepository: TDictionary<String, TObject>;
    function Resolver<T: class, constructor>: TDataSetBaseAdapter<T>;
  public
    constructor Create(const AConnection: IDBConnection);
    destructor Destroy; override;
    function AddAdapter<T: class, constructor>(const ADataSet: TDataSet;
      const APageSize: Integer = -1): TManagerClientDataSet; overload;
    function AddAdapter<T, M: class, constructor>(const ADataSet: TDataSet): TManagerClientDataSet; overload;
    function AddLookupField<T, M: class, constructor>(const AFieldName: String;
                                                      const AKeyFields: String;
                                                      const ALookupKeyFields: String;
                                                      const ALookupResultField: String;
                                                      const ADisplayLabel: String = ''): TManagerClientDataSet;
    procedure RemoveAdapter<T: class>;
    procedure Open<T: class, constructor>; overload;
    procedure Open<T: class, constructor>(const AID: Integer); overload;
    procedure Open<T: class, constructor>(const AID: String); overload;
    procedure OpenWhere<T: class, constructor>(const AWhere: String; const AOrderBy: String = '');
    procedure Close<T: class, constructor>;
    procedure LoadLazy<T: class, constructor>(const AOwner: T);
    procedure RefreshRecord<T: class, constructor>;
    procedure EmptyDataSet<T: class, constructor>;
    procedure CancelUpdates<T: class, constructor>;
    procedure ApplyUpdates<T: class, constructor>(const MaxErros: Integer);
    procedure Save<T: class, constructor>(AObject: T);
    function Current<T: class, constructor>: T;
    function DataSet<T: class, constructor>: TDataSet;
    /// ObjectSet
    function Find<T: class, constructor>: TObjectList<T>; overload;
    function Find<T: class, constructor>(const AID: TValue): T; overload;
    function FindWhere<T: class, constructor>(const AWhere: String;
                                              const AOrderBy: String = ''): TObjectList<T>;
    function NestedList<T: class>: TObjectList<T>;
    function AutoNextPacket<T: class, constructor>(const AValue: Boolean): TManagerClientDataSet;
    property OwnerNestedList: Boolean read FOwnerNestedList write FOwnerNestedList;
  end;

implementation

{ TManagerClientDataSet }


constructor TManagerClientDataSet.Create(const AConnection: IDBConnection);
begin
  FConnection := AConnection;
  FRepository := TObjectDictionary<String, TObject>.Create([doOwnsValues]);
  FNestedList := TObjectDictionary<String, TObjectList<TObject>>.Create([doOwnsValues]);
  FOwnerNestedList := False;
end;

destructor TManagerClientDataSet.Destroy;
begin
  FNestedList.Free;
  FRepository.Free;
  inherited;
end;

function TManagerClientDataSet.Current<T>: T;
begin
  Result := Resolver<T>.Current;
end;

function TManagerClientDataSet.NestedList<T>: TObjectList<T>;
var
  LClassName: String;
begin
  Result := nil;
  LClassName := TClass(T).ClassName;
  if FNestedList.ContainsKey(LClassName) then
    Result := TObjectList<T>(FNestedList.Items[LClassName]);
end;

function TManagerClientDataSet.DataSet<T>: TDataSet;
begin
  Result := Resolver<T>.FOrmDataSet;
end;

procedure TManagerClientDataSet.EmptyDataSet<T>;
begin
  Resolver<T>.EmptyDataSet;
end;

function TManagerClientDataSet.Find<T>(const AID: TValue): T;
begin
  if AID.IsType<integer> then
    Result := Resolver<T>.Find(AID.AsType<integer>)
  else
  if AID.IsType<String> then
    Result := Resolver<T>.Find(AID.AsType<String>)
end;

function TManagerClientDataSet.Find<T>: TObjectList<T>;
var
  LObjectList: TObjectList<T>;
begin
  Result := nil;
  if not FOwnerNestedList then
  begin
    Result := Resolver<T>.Find;
    Exit;
  end;
  LObjectList := Resolver<T>.Find;
  /// <summary> Limpa a lista de objectos </summary>
  FNestedList.AddOrSetValue(TClass(T).ClassName, TObjectList<TObject>(LObjectList));
end;

procedure TManagerClientDataSet.CancelUpdates<T>;
begin
  Resolver<T>.CancelUpdates;
end;

procedure TManagerClientDataSet.Close<T>;
begin
  Resolver<T>.EmptyDataSet;
end;

procedure TManagerClientDataSet.LoadLazy<T>(const AOwner: T);
begin
  Resolver<T>.LoadLazy(AOwner);
end;

function TManagerClientDataSet.AddLookupField<T, M>(const AFieldName, AKeyFields: String;
  const ALookupKeyFields, ALookupResultField, ADisplayLabel: String): TManagerClientDataSet;
var
  LObject: TDataSetBaseAdapter<M>;
begin
  Result := Self;
  LObject := Resolver<M>;
  if LObject = nil then
    Exit;
  Resolver<T>.AddLookupField(AFieldName,
                             AKeyFields,
                             LObject,
                             ALookupKeyFields,
                             ALookupResultField,
                             ADisplayLabel);
end;

procedure TManagerClientDataSet.ApplyUpdates<T>(const MaxErros: Integer);
begin
  Resolver<T>.ApplyUpdates(MaxErros);
end;

function TManagerClientDataSet.AutoNextPacket<T>(const AValue: Boolean): TManagerClientDataSet;
begin
  Resolver<T>.AutoNextPacket := AValue;
end;

procedure TManagerClientDataSet.Open<T>(const AID: String);
begin
  Resolver<T>.OpenIDInternal(AID);
end;

procedure TManagerClientDataSet.OpenWhere<T>(const AWhere,
  AOrderBy: String);
begin
  Resolver<T>.OpenWhereInternal(AWhere, AOrderBy);
end;

procedure TManagerClientDataSet.Open<T>(const AID: Integer);
begin
  Resolver<T>.OpenIDInternal(AID);
end;

procedure TManagerClientDataSet.Open<T>;
begin
  Resolver<T>.OpenSQLInternal('');
end;

procedure TManagerClientDataSet.RefreshRecord<T>;
begin
  Resolver<T>.RefreshRecord;
end;

procedure TManagerClientDataSet.RemoveAdapter<T>;
var
  LClassName: String;
begin
  LClassName := TClass(T).ClassName;
  if not FRepository.ContainsKey(LClassName) then
    Exit;

  FRepository.Remove(LClassName);
  FRepository.TrimExcess;
end;

function TManagerClientDataSet.Resolver<T>: TDataSetBaseAdapter<T>;
var
  LClassName: String;
begin
  Result := nil;
  LClassName := TClass(T).ClassName;
  if FRepository.ContainsKey(LClassName) then
    Result := TDataSetBaseAdapter<T>(FRepository.Items[LClassName]);
end;

procedure TManagerClientDataSet.Save<T>(AObject: T);
begin
  Resolver<T>.Save(AObject);
end;

function TManagerClientDataSet.FindWhere<T>(const AWhere, AOrderBy: String): TObjectList<T>;
var
  LObjectList: TObjectList<T>;
begin
  Result := nil;
  if not FOwnerNestedList then
  begin
    Result := Resolver<T>.FindWhere(AWhere, AOrderBy);
    Exit;
  end;
  LObjectList := Resolver<T>.FindWhere(AWhere, AOrderBy);
  /// <summary> Limpa a lista de objectos </summary>
  FNestedList.AddOrSetValue(TClass(T).ClassName, TObjectList<TObject>(LObjectList));
end;

function TManagerClientDataSet.AddAdapter<T, M>(const ADataSet: TDataSet): TManagerClientDataSet;
var
  LDataSetAdapter: TDataSetBaseAdapter<T>;
  LMaster: TDataSetBaseAdapter<T>;
  LClassName: String;
  LMasterName: String;
begin
  Result := Self;
  LClassName := TClass(T).ClassName;
  LMasterName := TClass(M).ClassName;
  if FRepository.ContainsKey(LClassName) then
    Exit;
  if not FRepository.ContainsKey(LMasterName) then
    Exit;
  LMaster := TDataSetBaseAdapter<T>(FRepository.Items[LMasterName]);
  if LMaster = nil then
    Exit;
  /// <summary> Checagem do tipo do dataset definido para uso </summary>
  if ADataSet is TClientDataSet then
    LDataSetAdapter := TClientDataSetAdapter<T>.Create(FConnection, ADataSet, -1, LMaster)
  else
    raise Exception.Create('Is not TClientDataSet type');
  /// <summary> Adiciona o container ao reposit�rio </summary>
  FRepository.Add(LClassName, LDataSetAdapter);
end;

function TManagerClientDataSet.AddAdapter<T>(const ADataSet: TDataSet;
  const APageSize: Integer): TManagerClientDataSet;
var
  LDataSetAdapter: TDataSetBaseAdapter<T>;
  LClassName: String;
begin
  Result := Self;
  LClassName := TClass(T).ClassName;
  if FRepository.ContainsKey(LClassName) then
    Exit;
  if ADataSet is TClientDataSet then
    LDataSetAdapter := TClientDataSetAdapter<T>.Create(FConnection, ADataSet, APageSize, nil)
  else
    raise Exception.Create('Is not TClientDataSet type');
  /// <summary> Adiciona o container ao reposit�rio </summary>
  FRepository.Add(LClassName, LDataSetAdapter);
end;

end.
