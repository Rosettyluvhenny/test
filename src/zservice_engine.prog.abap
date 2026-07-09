*&---------------------------------------------------------------------*
*& Report zservice_engine
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zservice_engine.

DATA: lv_v2_url  TYPE string,
      lv_guid    TYPE icfparguid,
      lv_package TYPE /iwfnd/med_mdl_namespace.

lv_guid = /iwfnd/cl_icf_access=>gcs_icf_node_ids-lib_10.
TRY.
    /iwfnd/cl_med_utils=>get_meta_data_doc_url_local(
      EXPORTING
        iv_icf_root_node_guid        = lv_guid
        iv_external_service_doc_name = 'ZUI_TRAVEL_257_V2'
        iv_namespace                 = lv_package
        iv_version                   = 1
      RECEIVING
        rv_metadata_url              = lv_v2_url
    ).

    IF lv_v2_url IS NOT INITIAL.

      " Remove query string
      SPLIT lv_v2_url AT '?' INTO lv_v2_url DATA(lv_dummy).

      " Append $metadata
      CONCATENATE lv_v2_url '$metadata'
        INTO lv_v2_url.


      DATA lv_path TYPE string.
        lv_path = lv_v2_url.
    ENDIF.

  CATCH /iwfnd/cx_med_mdl_access INTO DATA(lo_ex).
    cl_demo_output=>write( lo_ex->get_text( ) ).
ENDTRY.

WRITE: |Metadata URL: { lv_path }|.

DATA: lo_client   TYPE REF TO if_http_client,
      lv_response TYPE string.

" Create HTTP client via SM59 destination
cl_http_client=>create_by_destination(
  EXPORTING
    destination = 'Z_ODATA_2'
  IMPORTING
    client      = lo_client
).

" Set metadata path only
lo_client->request->set_method(
  if_http_request=>co_request_method_get
).

cl_http_utility=>set_request_uri(
  request = lo_client->request
  uri     = lv_path
).

" Send request
lo_client->send( ).
lo_client->receive( ).
*
*" Get response XML
lv_response = lo_client->response->get_cdata( ).

cl_demo_output=>display( lv_response ).
cl_demo_output=>display( ).
DATA:
  lv_code   TYPE i,
  lv_reason TYPE string.

lo_client->response->get_status(
  IMPORTING
    code   = lv_code
    reason = lv_reason
).

WRITE: |lv_code: { lv_code }| .
WRITE: |lv_reason: { lv_reason }|.
