@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'OData Service Registry Interface View'
@ObjectModel.writeActivePersistence: 'ZODATA_REGISTRY'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_ODATA_REGISTRY
  as select from zodata_registry
  composition [0..*] of ZI_ODATA_VERSION as _Version
  association [0..*] to ZI_ODATA_AUDIT_LOG as _Log on $projection.ServiceId = _Log.ServiceId
  association [0..1] to ZI_ODATA_SERVICE_TYPE_VH as _ServiceType on $projection.ServiceType = _ServiceType.TypeId
  association [0..1] to ZI_STATUS_VH             as _Status      on $projection.Status      = _Status.StatusId
{
    key service_id as ServiceId,
    service_name as ServiceName,
    @ObjectModel.text.association: '_ServiceType'
    service_type as ServiceType,
    _ServiceType.Description as ServiceTypeText,
    namespace as Namespace,
    version_no as VersionNo,
    @ObjectModel.text.association: '_Status'
    status as Status,
    _Status.Description as StatusText,
    @Semantics.user.createdBy: true
    registered_by as RegisteredBy,
    @Semantics.systemDateTime.createdAt: true
    registered_at as RegisteredAt,
    @Semantics.systemDateTime.localInstanceLastChangedAt: true
    last_change_at as LastChangeAt,
    description as Description,
    _Version,
    _ServiceType,
    _Status,
    _Log
}
