@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'User Role Value Help'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_ROLE_VH as select from zodata_role
{
    key role_id as RoleId123,
    description as Description
}
