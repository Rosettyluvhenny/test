@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'OData Structural Analysis Interface View'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_ODATA_ANALYZE
  as select from zodata_analyze
  association to parent ZI_ODATA_VERSION as _Version on  $projection.SnapshotId = _Version.SnapshotId
                                                  and $projection.ServiceId  = _Version.ServiceId
                                                  
{
    key snapshot_id as SnapshotId,
    key service_id as ServiceId,
    entity_count as EntityCount,
    assoc_count as AssocCount,
    navprop_count as NavpropCount,
    action_count as ActionCount,
    prop_count as PropCount,
    entity_names as EntityNames,
    analyzed_at as AnalyzedAt,
    analyzed_by as AnalyzedBy,
    semantic_summary as SemanticSummary,
    _Version
}
