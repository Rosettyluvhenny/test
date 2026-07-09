@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Service Type Value Help'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_ODATA_SERVICE_TYPE_VH as select from zodata_srv_type
{
    key type_id as TypeId,
    description as Description
}
