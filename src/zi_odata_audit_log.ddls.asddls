@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'OData Audit Log Interface View'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_ODATA_AUDIT_LOG as select from zodata_audit_log
  association [1..1] to ZI_ODATA_REGISTRY as _Registry on $projection.ServiceId = _Registry.ServiceId
  association [0..1] to ZI_ODATA_VERSION as _Version on $projection.SnapshotId = _Version.SnapshotId
  and $projection.ServiceId = _Version.ServiceId
{
    key log_id as LogId,
    key service_id as ServiceId,
    snapshot_id as SnapshotId,
    action_type as ActionType,
    actor as Actor,
    actor_role as ActorRole,
    action_at as ActionAt,
    ip_address as IpAddress,
    remarks as Remarks,
    _Registry,
    _Version
}
