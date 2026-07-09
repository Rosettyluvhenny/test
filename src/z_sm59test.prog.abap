*&---------------------------------------------------------------------*
*& Report z_sm59test
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT z_sm59test.
DATA:
  lv_v2_url   TYPE string,
  lv_path     TYPE string,
  lv_dummy    TYPE string,
  lv_offset   TYPE i,
  lo_client   TYPE REF TO if_http_client,
  lv_response TYPE string,
  lv_code     TYPE i,
  lv_reason   TYPE string,
  lv_err_msg  TYPE string,
  lv_guid    TYPE icfparguid,
  lv_package TYPE /iwfnd/med_mdl_namespace.

*------------------------------------------------------------
* Step 1: Resolve Metadata URL
*------------------------------------------------------------
lv_guid = /iwfnd/cl_icf_access=>gcs_icf_node_ids-lib_10.
TRY.
    /iwfnd/cl_med_utils=>get_meta_data_doc_url_local(
      EXPORTING
        iv_icf_root_node_guid        = lv_guid
        iv_external_service_doc_name = 'ZUI_FLIGHT_257_V4'
        iv_namespace                 = lv_package
        iv_version                   = 1
      RECEIVING
        rv_metadata_url              = lv_v2_url
    ).

  CATCH /iwfnd/cx_med_mdl_access INTO DATA(lo_url_ex).
    WRITE: / '[ERROR] Failed to resolve metadata URL:'.
    WRITE: / lo_url_ex->get_text( ).
    RETURN.
ENDTRY.

WRITE: / '[DEBUG] Raw URL:'.
WRITE: / lv_v2_url.

IF lv_v2_url IS INITIAL.
  WRITE: / '[ERROR] lv_v2_url is empty - check lv_guid and lv_package'.
  RETURN.
ENDIF.

*------------------------------------------------------------
* Step 2: Build Clean Path  (your original string style)
*------------------------------------------------------------

" Remove query string
SPLIT lv_v2_url AT '?' INTO lv_v2_url lv_dummy.

" Append $metadata
CONCATENATE lv_v2_url '$metadata' INTO lv_v2_url.

" Extract path only (strip host)
FIND '/sap/' IN lv_v2_url MATCH OFFSET lv_offset.
IF sy-subrc = 0.
  lv_path = lv_v2_url+lv_offset.
ELSE.
  lv_path = lv_v2_url.
ENDIF.

WRITE: / '[DEBUG] Path to call:'.
WRITE: / lv_path.

*------------------------------------------------------------
* Step 3: Create SM59 HTTP Client
*------------------------------------------------------------
cl_http_client=>create_by_destination(
  EXPORTING
    destination              = 'Z_ODATA_2'
  IMPORTING
    client                   = lo_client
  EXCEPTIONS
    argument_not_found       = 1
    destination_not_found    = 2
    destination_no_authority = 3
    plugin_not_active        = 4
    internal_error           = 5
    OTHERS                   = 6
).
IF sy-subrc <> 0.
  WRITE: / '[ERROR] SM59 destination creation failed, sy-subrc:'.
  WRITE: sy-subrc.
  RETURN.
ENDIF.

WRITE: / '[DEBUG] SM59 client created OK'.
*------------------------------------------------------------
* Step 4A: Set Header
*------------------------------------------------------------
DATA lv_auth TYPE string.
DATA lv_base64 TYPE string.

" Encode credentials separately first
*lv_base64 = cl_http_utility=>encode_base64( 'USERNAME:PASSWORD' ).
*
*CONCATENATE 'Basic ' lv_base64 INTO lv_auth.
*CONCATENATE lv_path '?sap-client=324' INTO lv_path.
*lo_client->request->set_header_field(
*  name  = 'Authorization'
*  value = lv_auth
*).

*------------------------------------------------------------
* Step 4: Set Request
*------------------------------------------------------------
lo_client->request->set_method(
  if_http_request=>co_request_method_get
).

cl_http_utility=>set_request_uri(
  request = lo_client->request
  uri     = lv_path
).


*------------------------------------------------------------
* Step 5: Send
*------------------------------------------------------------
lo_client->send(
  EXCEPTIONS
    http_communication_failure = 1
    http_invalid_state         = 2
    OTHERS                     = 3
).
IF sy-subrc <> 0.
  lo_client->get_last_error(
    IMPORTING
      message = lv_err_msg
  ).
  WRITE: / '[ERROR] Send failed:'.
  WRITE: / lv_err_msg.
  lo_client->close( ).
  RETURN.
ENDIF.

WRITE: / '[DEBUG] Request sent OK'.

*------------------------------------------------------------
* Step 6: Receive
*------------------------------------------------------------
lo_client->receive(
  EXCEPTIONS
    http_communication_failure = 1
    http_invalid_state         = 2
    http_processing_failed     = 3
    OTHERS                     = 4
).
IF sy-subrc <> 0.
  lo_client->get_last_error(
    IMPORTING
      message = lv_err_msg
  ).
  WRITE: / '[ERROR] Receive failed:'.
  WRITE: / lv_err_msg.
  lo_client->close( ).
  RETURN.
ENDIF.

*------------------------------------------------------------
* Step 7: Read Response
*------------------------------------------------------------
lo_client->response->get_status(
  IMPORTING
    code   = lv_code
    reason = lv_reason
).

lv_response = lo_client->response->get_cdata( ).

WRITE: / '[RESULT] HTTP Status:'.
WRITE: lv_code.
WRITE: lv_reason.

IF lv_code = 200.
  WRITE: / '[OK] Metadata fetched successfully.'.
  WRITE: / lv_response.
ELSEIF lv_code = 401.
  WRITE: / '[ERROR] 401 Unauthorized - check user/password in SM59 Logon tab'.
ELSEIF lv_code = 404.
  WRITE: / '[ERROR] 404 Not Found - check the path and service name'.
ELSE.
  WRITE: / '[ERROR] Unexpected status. Response:'.
  WRITE: / lv_response.
ENDIF.
    cl_demo_output=>write( lv_response ).
    cl_demo_output=>display( ).
lo_client->close( ).
