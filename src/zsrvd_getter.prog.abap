*&---------------------------------------------------------------------*
*& Report zsrvd_getter
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zsrvd_getter.

*DATA(lv_srvb_name) = CONV sxco_srvb_object_name( 'ZSB_ODATA_REGISTRY_A4' ).
DATA(lv_srvb_name) = CONV sxco_srvb_object_name( 'ZSB_ODATA_REGISTRY_A4' ).

DATA : lv_host        TYPE string,
       lv_port        TYPE string,
       lv_protocol    TYPE string,
       lv_path        TYPE string,
       lv_srvd_string TYPE string.



CALL FUNCTION 'TH_GET_VIRT_HOST_DATA'
  EXPORTING
    protocol = 2    "http protocol
    virt_idx = 0
  IMPORTING
    hostname = lv_host
    port     = lv_port
  EXCEPTIONS
    OTHERS   = 99.

IF sy-subrc = 0.
  lv_protocol = 'https'.

ENDIF.


CONCATENATE lv_protocol '://' lv_host ':' lv_port '/sap/opu/odata4/sap/' lv_srvb_name   INTO lv_path.
DATA : mv_system_alias      TYPE /iwfnd/if_v4_routing_types=>ty_e_system_alias,
       mv_group_id          TYPE /iwfnd/v4_med_group_id VALUE 'ZUI_FLIGHT_257_V4',
       mo_routing_config    TYPE REF TO  /iwfnd/cl_v4_routing_config,
       mo_publishing_config TYPE REF TO /iwfnd/cl_v4_publishing_config.

TYPES BEGIN OF ty_s_service_detail.
INCLUDE TYPE /iwfnd/if_v4_publishing_types=>ty_s_bep_service_info.
TYPES   change_date  TYPE d.
TYPES   change_time  TYPE t.
TYPES   line_no      TYPE i.
TYPES END OF ty_s_service_detail.
TYPES:
  ty_t_service_detail TYPE STANDARD TABLE OF ty_s_service_detail WITH DEFAULT KEY.

DATA mt_service_detail    TYPE ty_t_service_detail.

DATA: lv_line_no        TYPE i,
      lt_bep_group_info TYPE /iwfnd/if_v4_publishing_types=>ty_t_bep_group_info,
      ls_service_detail TYPE ty_s_service_detail,
      lx_gateway        TYPE REF TO /iwfnd/cx_gateway.

FIELD-SYMBOLS: <ls_bep_group_info>   TYPE /iwfnd/if_v4_publishing_types=>ty_s_bep_group_info,
               <ls_bep_service_info> TYPE /iwfnd/if_v4_publishing_types=>ty_s_bep_service_info.

CLEAR mt_service_detail.
mo_publishing_config = /iwfnd/cl_v4_publishing_config=>get_instance( ).
mo_routing_config = /iwfnd/cl_v4_routing_config=>get_instance( ).
TRY.
    DATA(lt_assignments) = mo_routing_config->get_group_assignments( iv_group_id = CONV #( lv_srvb_name ) ).
    mv_system_alias = lt_assignments[ 1 ]-system_alias.
  CATCH  /iwfnd/cx_v4_routing INTO DATA(ex).
    WRITE: / ex->get_exception_text( ).
ENDTRY.
IF mv_system_alias IS INITIAL OR mv_group_id IS INITIAL. RETURN. ENDIF.

TRY.
    mo_publishing_config->get_bep_groups(
      EXPORTING
        iv_system_alias   = mv_system_alias
        iv_group_id       = CONV #( lv_srvb_name )
      IMPORTING
        et_bep_group_info = lt_bep_group_info
    ).
  CATCH /iwfnd/cx_gateway INTO lx_gateway.
    MESSAGE lx_gateway->get_text_of_root( ) TYPE 'I' DISPLAY LIKE 'E'.
    RETURN.
ENDTRY.

READ TABLE lt_bep_group_info ASSIGNING <ls_bep_group_info> INDEX 1.
IF sy-subrc <> 0. RETURN. ENDIF.

LOOP AT <ls_bep_group_info>-t_service_info ASSIGNING <ls_bep_service_info>.
  MOVE-CORRESPONDING <ls_bep_service_info> TO ls_service_detail.
  /iwfnd/cl_v4_config_utils=>convert_to_local_time(
    EXPORTING
      iv_timestamp  = ls_service_detail-changed_ts
    IMPORTING
      ev_local_date = ls_service_detail-change_date
      ev_local_time = ls_service_detail-change_time
  ).
  ls_service_detail-line_no = lv_line_no = lv_line_no + 1.
  APPEND ls_service_detail TO mt_service_detail.
ENDLOOP.

LOOP AT mt_service_detail INTO DATA(ls_detail).
  TYPES ty_s_assignment_detail TYPE /iwfnd/if_v4_routing_types=>ty_s_system_alias_assign_group.
  DATA: lv_group_id          TYPE /iwfnd/v4_med_group_id,
        lv_service_id        TYPE /iwfnd/v4_med_service_id,
        lv_repository_id     TYPE /iwfnd/v4_med_repository_id,
        lv_system_alias      TYPE /iwfnd/if_v4_routing_types=>ty_e_system_alias,
        lv_status_code       TYPE i,
        lv_request_uri       TYPE string,
        lv_status_text       TYPE string,
        lv_content_type      TYPE string,
        lv_error_text        TYPE string,
        lv_response_body     TYPE xstring,
        ls_assignment_detail TYPE ty_s_assignment_detail,
        ls_request_header    TYPE /iwfnd/sutil_property,
        lt_request_header    TYPE /iwfnd/sutil_property_t,
         mo_client_proxy        TYPE REF TO /iwfnd/cl_sutil_client_proxy.

  lv_group_id = lv_srvb_name.
  TRANSLATE lv_group_id TO LOWER CASE.
  IF lv_group_id(1) <> '/'.
    CONCATENATE '/sap/'
                lv_group_id
      INTO lv_group_id.
  ENDIF.

  lv_service_id = ls_detail-service_id.
  TRANSLATE lv_service_id TO LOWER CASE.
  IF lv_service_id(1) <> '/'.
    CONCATENATE '/sap/'
                lv_service_id
      INTO lv_service_id.
  ENDIF.

  lv_repository_id = ls_detail-repository_id.
  TRANSLATE lv_repository_id TO LOWER CASE.


  IF lv_system_alias IS INITIAL.
    CONCATENATE '/sap/opu/odata4'
                lv_group_id
                '/'
                lv_repository_id
                lv_service_id
                '/'
                ls_detail-service_version
                '/$metadata'
      INTO lv_request_uri.
  ELSE.
    CONCATENATE '/sap/opu/odata4'
                lv_group_id
                '/'
                lv_repository_id
                lv_service_id
                '/'
                ls_detail-service_version
                ';o='
                lv_system_alias
                '/$metadata'
      INTO lv_request_uri.
  ENDIF.

* Set Request Method and URI
  ls_request_header-name  = if_http_header_fields_sap=>request_method.
  ls_request_header-value = 'GET'.
  APPEND ls_request_header TO lt_request_header.
  ls_request_header-name  = if_http_header_fields_sap=>request_uri.
  ls_request_header-value = lv_request_uri.
  APPEND ls_request_header TO lt_request_header.

* Get Service Metadata
  IF mo_client_proxy IS NOT BOUND.
    mo_client_proxy = /iwfnd/cl_sutil_client_proxy=>get_instance( ).
  ENDIF.
  mo_client_proxy->web_request(
    EXPORTING
      it_request_header   = lt_request_header
    IMPORTING
      ev_status_code      = lv_status_code
      ev_status_text      = lv_status_text
      ev_content_type     = lv_content_type
      ev_response_body    = lv_response_body
      ev_error_text       = lv_error_text
  ).

* Error Handling
  IF lv_response_body IS INITIAL.
    IF lv_error_text IS NOT INITIAL.
      MESSAGE lv_error_text TYPE 'I' DISPLAY LIKE 'E'.
      RETURN.
    ELSEIF lv_status_code <> 200.
      MESSAGE lv_status_text TYPE 'I' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
  ENDIF.

* Show Metadata response by Browser
  /iwfnd/cl_sutil_xml_helper=>xml_display_by_browser(
    EXPORTING
      iv_xdoc         = lv_response_body
      iv_content_type = lv_content_type
    IMPORTING
      ev_error_text   = lv_error_text
  ).
  IF lv_error_text IS NOT INITIAL.
    MESSAGE lv_error_text TYPE 'I' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.
ENDLOOP.


*DATA: lo_client   TYPE REF TO if_http_client,
*      lv_response TYPE string.
*
*" Create HTTP client via SM59 destination
*cl_http_client=>create_by_destination(
*  EXPORTING
*    destination = 'Z_ODATA_2'
*  IMPORTING
*    client      = lo_client
*).
*
*" Set metadata path only
*lo_client->request->set_method(
*  if_http_request=>co_request_method_get
*).
*
*cl_http_utility=>set_request_uri(
*  request = lo_client->request
*  uri     = lv_path
*).
*
*" Send request
*lo_client->send( ).
*lo_client->receive( ).
**
**" Get response XML
*lv_response = lo_client->response->get_cdata( ).
*
*cl_demo_output=>display( lv_response ).
*cl_demo_output=>display( ).
*DATA:
*  lv_code   TYPE i,
*  lv_reason TYPE string.
*
*lo_client->response->get_status(
*  IMPORTING
*    code   = lv_code
*    reason = lv_reason
*).
*
*WRITE: |lv_code: { lv_code }| .
*WRITE: |lv_reason: { lv_reason }|.
