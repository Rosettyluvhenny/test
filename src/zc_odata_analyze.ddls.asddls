@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'OData Structural Analysis'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZC_ODATA_ANALYZE
  as projection on ZI_ODATA_ANALYZE
{
    key SnapshotId,
    key ServiceId,

    @UI.identification: [{ position: 10 }]
    EntityCount,

    @UI.identification: [{ position: 20 }]
    AssocCount,

    @UI.identification: [{ position: 30 }]
    NavpropCount,

    @UI.identification: [{ position: 40 }]
    ActionCount,

    @UI.identification: [{ position: 50 }]
    PropCount,

    @UI.hidden: true
    EntityNames,

    @UI.hidden: true
    AnalyzedAt,

    @UI.hidden: true
    AnalyzedBy,

    @UI.multiLineText: true
    SemanticSummary,

    _Version: redirected to parent ZC_ODATA_VERSION
}
