@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'OData Snapshot Metadata Interface View'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_ODATA_VERSION
  as select from zodata_version
  composition [0..1] of ZI_ODATA_ANALYZE as _Analyze
  association        to parent ZI_ODATA_REGISTRY as _Registry on $projection.ServiceId = _Registry.ServiceId
  association [0..1] to ZI_TRIGGER_VH as _Trigger on $projection.TriggerType = _Trigger.TriggerId
{
    key service_id as ServiceId,
    key snapshot_id as SnapshotId,
    snapshot_version as SnapshotVersion,
    metadata_hash as MetadataHash,
    metadata_xml as MetadataXml,
    snapshot_by as SnapshotBy,
    snapshot_at as SnapshotAt,
    trigger_type as TriggerType,
    is_changed as IsChanged,
    _Analyze,
    _Registry,
    _Trigger
}
