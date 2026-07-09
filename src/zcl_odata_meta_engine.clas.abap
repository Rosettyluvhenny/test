CLASS zcl_odata_meta_engine DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-METHODS fetch_v2_metadata
      IMPORTING iv_service_name    TYPE string
                iv_service_version TYPE string DEFAULT '0001'
      RETURNING VALUE(rv_xml)      TYPE string
      RAISING   cx_sy_conversion_codepage.

    CLASS-METHODS fetch_v4_metadata
      IMPORTING iv_service_name    TYPE string
                iv_service_version TYPE string DEFAULT '0001'
      RETURNING VALUE(rv_xml)      TYPE string
      RAISING   cx_sy_conversion_codepage.

  PRIVATE SECTION.

    CLASS-METHODS call_http_get
      IMPORTING iv_path        TYPE string
      RETURNING VALUE(rv_body) TYPE string
      RAISING   cx_sy_conversion_codepage.

ENDCLASS.


CLASS zcl_odata_meta_engine IMPLEMENTATION.

  METHOD fetch_v2_metadata.
    DATA lv_path TYPE string.
    lv_path = |/sap/opu/odata/{ iv_service_name }| &&
              |/{ iv_service_name }/$metadata|.
    rv_xml = call_http_get( lv_path ).
  ENDMETHOD.

  METHOD fetch_v4_metadata.
    DATA lv_service TYPE string.
    lv_service = to_lower( iv_service_name ).
    DATA lv_path TYPE string.
    lv_path = |/sap/opu/odata4/sap/{ lv_service }| &&
              |/srvd/sap/{ lv_service }| &&
              |/{ iv_service_version }/$metadata|.
    rv_xml = call_http_get( lv_path ).
  ENDMETHOD.

  METHOD call_http_get.
    DATA lo_client  TYPE REF TO if_http_client.
    DATA lv_host    TYPE string.
    DATA lv_port    TYPE string.
    DATA lv_status  TYPE i.
    DATA lv_reason  TYPE string.
    DATA lv_xstr    TYPE xstring.

    " Lấy host/port từ system info
    lv_host = sy-host.

    " Tạo HTTP client với host local
    cl_http_client=>create(
      EXPORTING
        host               = lv_host
        service            = '8000'     " HTTP port mặc định SAP
      IMPORTING
        client             = lo_client
      EXCEPTIONS
        argument_not_found = 1
        plugin_not_active  = 2
        internal_error     = 3
        OTHERS             = 4 ).

    IF sy-subrc <> 0.
      " Thử port khác
      cl_http_client=>create(
        EXPORTING
          host               = lv_host
          service            = '443'    " HTTPS
          ssl_id             = 'ANONYM'
        IMPORTING
          client             = lo_client
        EXCEPTIONS
          OTHERS             = 4 ).

      IF sy-subrc <> 0.
        RAISE EXCEPTION NEW cx_sy_conversion_codepage( ).
      ENDIF.
    ENDIF.

    " Set path
    lo_client->request->set_method( 'GET' ).
    lo_client->request->set_header_field(
      name  = '~request_uri'
      value = iv_path ).
    lo_client->request->set_header_field(
      name  = 'Accept'
      value = 'application/xml' ).

    " Set basic auth — dùng current user
    DATA lv_uname TYPE string.
  lv_uname = sy-uname.
  lo_client->authenticate(
  username = lv_uname
  password = '' ).

    lo_client->send( EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc <> 0.
      lo_client->close( ).
      RAISE EXCEPTION NEW cx_sy_conversion_codepage( ).
    ENDIF.

    lo_client->receive( EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc <> 0.
      lo_client->close( ).
      RAISE EXCEPTION NEW cx_sy_conversion_codepage( ).
    ENDIF.

    lo_client->response->get_status(
      IMPORTING code = lv_status reason = lv_reason ).

    IF lv_status <> 200.
      lo_client->close( ).
      RAISE EXCEPTION NEW cx_sy_conversion_codepage( ).
    ENDIF.

    " Lấy raw bytes
    lv_xstr = lo_client->response->get_data( ).
    lo_client->close( ).

    IF lv_xstr IS INITIAL.
      RAISE EXCEPTION NEW cx_sy_conversion_codepage( ).
    ENDIF.

    " Strip BOM nếu có (EF BB BF = UTF-8 BOM)
    DATA lv_bom TYPE xstring.
    lv_bom = 'EFBBBF'.
    IF lv_xstr(3) = lv_bom.
      DATA lv_len TYPE i.
      lv_len = xstrlen( lv_xstr ) - 3.
      lv_xstr = lv_xstr+3(lv_len).
    ENDIF.

    " Convert XSTRING → string
    TRY.
        rv_body = cl_abap_codepage=>convert_from(
          source   = lv_xstr
          codepage = `UTF-8` ).
      CATCH cx_parameter_invalid_range
            cx_sy_codepage_converter_init
            cx_sy_conversion_codepage.
        " Thử ISO-8859-1 nếu UTF-8 fail
        TRY.
            rv_body = cl_abap_codepage=>convert_from(
              source   = lv_xstr
              codepage = `iso-8859-1` ).
          CATCH cx_root.
            RAISE EXCEPTION NEW cx_sy_conversion_codepage( ).
        ENDTRY.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
