@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Audit log Comsumption'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZC_ODATA_AUDIT_LOG as select from ZI_ODATA_AUDIT_LOG
{
    key LogId,
    key ServiceId,
    SnapshotId,
    ActionType,
    Actor,
    ActorRole,
    ActionAt,
    IpAddress,
    Remarks,
    /* Associations */
    _Registry,
    _Version
}
