@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Trigger Type Value Help'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_TRIGGER_VH as select from zgp9_trgr_ty
{
   @ObjectModel.text.element: ['Description']
    key trigger_id as TriggerId,
     @Semantics.text: true
    description as Description
}
