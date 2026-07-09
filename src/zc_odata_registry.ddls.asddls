@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'OData Service Registry'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true
define root view entity ZC_ODATA_REGISTRY
 provider contract transactional_query
  as projection on ZI_ODATA_REGISTRY
{
    @UI.lineItem: [{ position: 10 }]
    @UI.identification: [{ position: 10 }]
    @Search.defaultSearchElement: true
    key ServiceId,

    @UI.lineItem: [{ position: 20 }]
    @Search.defaultSearchElement: true
    ServiceName,

    @UI.lineItem: [{ position: 30 }]
    @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_ODATA_SERVICE_TYPE_VH', element: 'TypeId' } }]
    @ObjectModel.text.element: [ 'ServiceTypeText' ]
    ServiceType,
    _ServiceType.Description as ServiceTypeText,

    @UI.lineItem: [{ position: 40 }]
    @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_STATUS_VH', element: 'StatusId' } }]
    @ObjectModel.text.element: [ 'StatusText' ]
    Status,
    _Status.Description as StatusText,

    Namespace,
    VersionNo,

    @UI.hidden: true
    RegisteredBy,

    @UI.hidden: true
    RegisteredAt,

    @UI.hidden: true
    LastChangeAt,

    Description,

    _Version : redirected to composition child ZC_ODATA_VERSION,
    _ServiceType,
    _Status,
    _Log
}
