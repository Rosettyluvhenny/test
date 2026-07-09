@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'OData Snapshot Metadata'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZC_ODATA_VERSION
  as projection on ZI_ODATA_VERSION
{
    key ServiceId,
    key SnapshotId,

    @UI.lineItem: [{ position: 10 }]
    SnapshotVersion,

    @UI.lineItem: [{ position: 20 }]
    SnapshotAt,

    @UI.lineItem: [{ position: 30 }]
    @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_TRIGGER_VH', element: 'TriggerId' } }]
    @ObjectModel.text.element: [ 'TriggerTypeText' ]
    TriggerType,
    _Trigger.Description as TriggerTypeText,

    @UI.lineItem: [{ position: 40 }]
    IsChanged,

    @UI.hidden: true
    MetadataHash,

    @UI.hidden: true
    MetadataXml,

    @UI.hidden: true
    SnapshotBy,

    _Registry: redirected to parent ZC_ODATA_REGISTRY,
    _Analyze: redirected to composition child ZC_ODATA_ANALYZE,
    _Trigger
}
