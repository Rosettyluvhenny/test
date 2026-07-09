CLASS zcl_odata_v2_registry_service DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_input,
        service_id   TYPE zodata_registry-service_id,
        service_type TYPE zodata_registry-service_type,
        version_no   TYPE zodata_registry-version_no,
      END OF ty_input,
      tt_input TYPE STANDARD TABLE OF ty_input WITH EMPTY KEY,

      BEGIN OF ty_snapshot,
        service_id       TYPE zodata_version-service_id,
        snapshot_id      TYPE zodata_version-snapshot_id,
        snapshot_version TYPE zodata_version-snapshot_version,
        metadata_hash    TYPE zodata_version-metadata_hash,
        metadata_xml     TYPE zodata_version-metadata_xml,
        snapshot_by      TYPE zodata_version-snapshot_by,
        snapshot_at      TYPE zodata_version-snapshot_at,
        trigger_type     TYPE zodata_version-trigger_type,
        is_changed       TYPE zodata_version-is_changed,
      END OF ty_snapshot,

      BEGIN OF ty_result,
        service_id      TYPE zodata_registry-service_id,
        service_name    TYPE zodata_registry-service_name,
        namespace       TYPE zodata_registry-namespace,
        version_no      TYPE zodata_registry-version_no,
        status          TYPE zodata_registry-status,
        is_v2_found     TYPE abap_bool,
        snapshot_create TYPE abap_bool,
        snapshot        TYPE ty_snapshot,
      END OF ty_result,
      tt_result TYPE STANDARD TABLE OF ty_result WITH EMPTY KEY.

    CLASS-METHODS process_v2_registry
      IMPORTING it_registry      TYPE tt_input
      RETURNING VALUE(rt_result) TYPE tt_result.

  PRIVATE SECTION.

    CONSTANTS:
      gc_service_type_v2 TYPE zodata_registry-service_type VALUE '001',
      gc_status_active   TYPE zodata_registry-status VALUE 'A',
      gc_status_inactive TYPE zodata_registry-status VALUE 'I',
      gc_trigger_create  TYPE zodata_version-trigger_type VALUE 'C',
      gc_changed_yes     TYPE zodata_version-is_changed VALUE 'X'.

    TYPES:
      BEGIN OF ty_existing_snapshot,
        snapshot_version TYPE zodata_version-snapshot_version,
        metadata_hash    TYPE zodata_version-metadata_hash,
      END OF ty_existing_snapshot.

    CLASS-METHODS build_metadata_url
      IMPORTING iv_service_id TYPE /iwfnd/med_mdl_service_grp_id
                iv_namespace  TYPE /iwfnd/med_mdl_namespace
                iv_version    TYPE /iwfnd/med_mdl_version
      RETURNING VALUE(rv_url) TYPE string.

    CLASS-METHODS fetch_metadata_body
      IMPORTING iv_url        TYPE string
      RETURNING VALUE(rv_body) TYPE string.

    CLASS-METHODS calculate_hash
      IMPORTING iv_metadata_b64 TYPE string
      RETURNING VALUE(rv_hash)   TYPE string.

    CLASS-METHODS get_latest_snapshot
      IMPORTING iv_service_id TYPE zodata_version-service_id
      RETURNING VALUE(rs_snapshot) TYPE ty_existing_snapshot.

    CLASS-METHODS get_uuid
      RETURNING VALUE(rv_uuid) TYPE char32.

ENDCLASS.


CLASS zcl_odata_v2_registry_service IMPLEMENTATION.

  METHOD process_v2_registry.
    DATA ls_registry TYPE ty_input.
    DATA ls_result TYPE ty_result.
    DATA ls_metadata TYPE zcl_odata_registry_helper=>ty_v2_metadata.
    DATA lt_keys TYPE zcl_odata_registry_helper=>tt_v2_keys.
    DATA lt_hits TYPE zcl_odata_registry_helper=>tt_v2_keys.
    DATA lt_metadata TYPE zcl_odata_registry_helper=>tt_v2_metadata.
    DATA lv_metadata_url TYPE string.
    DATA lv_metadata_xml TYPE string.
    DATA lv_metadata_b64 TYPE string.
    DATA ls_existing_snapshot TYPE ty_existing_snapshot.
    DATA lv_snapshot_version TYPE i.
    DATA lv_snapshot_at TYPE timestamp.

    CHECK it_registry IS NOT INITIAL.

    LOOP AT it_registry INTO ls_registry.
      IF ls_registry-service_type <> gc_service_type_v2.
        CONTINUE.
      ENDIF.

      CLEAR ls_result.
      ls_result-service_id = ls_registry-service_id.
      IF ls_registry-version_no IS INITIAL.
        ls_result-version_no = '0001'.
      ELSE.
        ls_result-version_no = ls_registry-version_no.
      ENDIF.

      CLEAR lt_keys.
      APPEND VALUE #( object_name = CONV /iwfnd/med_mdl_srg_name( ls_registry-service_id )
                      service_version = CONV /iwfnd/med_mdl_version( ls_result-version_no ) ) TO lt_keys.

      lt_hits = zcl_odata_registry_helper=>fetch_existing_v2( lt_keys ).
      ls_result-is_v2_found = zcl_odata_registry_helper=>is_v2_found(
        iv_service_id = CONV /iwfnd/v4_med_group_id( ls_registry-service_id )
        iv_version_no = ls_result-version_no
        it_hits       = lt_hits ).

      IF ls_result-is_v2_found IS INITIAL.
        ls_result-status = gc_status_inactive.
        APPEND ls_result TO rt_result.
        CONTINUE.
      ENDIF.

      lt_metadata = zcl_odata_registry_helper=>fetch_v2_metadata( lt_keys ).
      READ TABLE lt_metadata INTO ls_metadata INDEX 1.
      IF sy-subrc <> 0.
        ls_result-status = gc_status_inactive.
        APPEND ls_result TO rt_result.
        CONTINUE.
      ENDIF.

      ls_result-service_name = ls_metadata-service_name.
      ls_result-namespace = ls_metadata-namespace.
      ls_result-status = gc_status_active.

      lv_metadata_url = build_metadata_url(
        iv_service_id = CONV /iwfnd/med_mdl_service_grp_id( ls_registry-service_id )
        iv_namespace  = ls_metadata-namespace
        iv_version    = ls_result-version_no ).

      IF lv_metadata_url IS INITIAL.
        ls_result-status = gc_status_inactive.
        APPEND ls_result TO rt_result.
        CONTINUE.
      ENDIF.

      lv_metadata_xml = fetch_metadata_body( lv_metadata_url ).
      IF lv_metadata_xml IS INITIAL.
        ls_result-status = gc_status_inactive.
        APPEND ls_result TO rt_result.
        CONTINUE.
      ENDIF.

      TRY.
          lv_metadata_b64 = zcl_odata_base64_helper=>xml_to_base64( lv_metadata_xml ).
        CATCH cx_sy_conversion_codepage.
          ls_result-status = gc_status_inactive.
          APPEND ls_result TO rt_result.
          CONTINUE.
      ENDTRY.

      ls_result-snapshot-metadata_hash = calculate_hash( lv_metadata_b64 ).
      IF ls_result-snapshot-metadata_hash IS INITIAL.
        ls_result-status = gc_status_inactive.
        APPEND ls_result TO rt_result.
        CONTINUE.
      ENDIF.

      ls_existing_snapshot = get_latest_snapshot(  ls_registry-service_id ).
      CLEAR lv_snapshot_version.

      IF ls_existing_snapshot-snapshot_version IS INITIAL.
        lv_snapshot_version = 1.
        ls_result-snapshot_create = abap_true.
      ELSE.
        lv_snapshot_version = CONV i( ls_existing_snapshot-snapshot_version ).
        IF ls_existing_snapshot-metadata_hash = ls_result-snapshot-metadata_hash.
          ls_result-snapshot_create = abap_false.
        ELSE.
          lv_snapshot_version = lv_snapshot_version + 1.
          ls_result-snapshot_create = abap_true.
        ENDIF.
      ENDIF.

      ls_result-snapshot-service_id = CONV zodata_version-service_id( ls_registry-service_id ).
      ls_result-snapshot-snapshot_version = lv_snapshot_version.
      ls_result-snapshot-snapshot_id = get_uuid( ).
      GET TIME STAMP FIELD lv_snapshot_at.
      ls_result-snapshot-snapshot_at = lv_snapshot_at.
      ls_result-snapshot-snapshot_by = sy-uname.
      ls_result-snapshot-trigger_type = gc_trigger_create.
      IF ls_result-snapshot_create = abap_true.
        ls_result-snapshot-is_changed = gc_changed_yes.
      ELSE.
        CLEAR ls_result-snapshot-is_changed.
      ENDIF.
      ls_result-snapshot-metadata_xml = cl_abap_codepage=>convert_to(
        source   = lv_metadata_b64
        codepage = `UTF-8` ).

      APPEND ls_result TO rt_result.
    ENDLOOP.
  ENDMETHOD.

  METHOD build_metadata_url.
    DATA lv_v2_url TYPE string.
    DATA lv_guid TYPE icfparguid.
    DATA lv_dummy TYPE string.
    DATA lv_offset TYPE i.

    TRY.
        /iwfnd/cl_med_utils=>get_meta_data_doc_url_local(
          EXPORTING
            iv_icf_root_node_guid        = lv_guid
            iv_external_service_doc_name = iv_service_id
            iv_namespace                 = iv_namespace
            iv_version                   = iv_version
          RECEIVING
            rv_metadata_url              = lv_v2_url ).

        IF lv_v2_url IS NOT INITIAL.
          SPLIT lv_v2_url AT '?' INTO lv_v2_url lv_dummy.
          CONCATENATE lv_v2_url '$metadata' INTO lv_v2_url.

          FIND '/sap/' IN lv_v2_url MATCH OFFSET lv_offset.
          IF sy-subrc = 0.
            rv_url = lv_v2_url+lv_offset.
          ELSE.
            rv_url = lv_v2_url.
          ENDIF.
        ENDIF.
      CATCH /iwfnd/cx_med_mdl_access.
        CLEAR rv_url.
    ENDTRY.
  ENDMETHOD.

  METHOD fetch_metadata_body.
    DATA lo_client TYPE REF TO if_http_client.
    DATA lv_code TYPE i.
    DATA lv_reason TYPE string.

    IF iv_url IS INITIAL.
      RETURN.
    ENDIF.

    TRY.
        cl_http_client=>create_by_destination(
          EXPORTING
            destination = 'Z_ODATA_2'
          IMPORTING
            client      = lo_client ).

        lo_client->request->set_method( if_http_request=>co_request_method_get ).
        cl_http_utility=>set_request_uri(
          request = lo_client->request
          uri     = iv_url ).

        lo_client->send( ).
        lo_client->receive( ).

        lo_client->response->get_status(
          IMPORTING
            code   = lv_code
            reason = lv_reason ).

        IF lv_code <> 200.
          lo_client->close( ).
          RETURN.
        ENDIF.

        rv_body = lo_client->response->get_cdata( ).
        lo_client->close( ).
      CATCH cx_root.
        IF lo_client IS BOUND.
          lo_client->close( ).
        ENDIF.
        CLEAR rv_body.
    ENDTRY.
  ENDMETHOD.

  METHOD calculate_hash.
    TRY.
        cl_abap_message_digest=>calculate_hash_for_char(
          EXPORTING
            if_algorithm     = 'sha256'
            if_data          = iv_metadata_b64
          IMPORTING
            ef_hashb64string = rv_hash ).
      CATCH cx_abap_message_digest.
        CLEAR rv_hash.
    ENDTRY.
  ENDMETHOD.

  METHOD get_latest_snapshot.
    DATA lt_snapshot TYPE STANDARD TABLE OF ty_existing_snapshot WITH EMPTY KEY.

    SELECT snapshot_version,
           metadata_hash
      FROM zodata_version
      WHERE service_id = @iv_service_id
      INTO TABLE @lt_snapshot.

    SORT lt_snapshot BY snapshot_version DESCENDING.
    READ TABLE lt_snapshot INTO rs_snapshot INDEX 1.
  ENDMETHOD.

  METHOD get_uuid.
    TRY.
        rv_uuid = cl_system_uuid=>create_uuid_c32_static( ).
      CATCH cx_uuid_error.
        DATA lv_ts TYPE timestampl.
        GET TIME STAMP FIELD lv_ts.
        rv_uuid = lv_ts.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
