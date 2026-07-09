@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Action Value Help'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_ACTION_VH as select from zodata_action
{
    key action_id as ActionId,
    description as Description
}
