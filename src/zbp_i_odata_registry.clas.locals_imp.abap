CLASS lhc_OdataRegistry DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS setDerivedFields FOR DETERMINE ON SAVE
      IMPORTING keys FOR OdataRegistry~setDerivedFields.

    METHODS validateServiceType FOR VALIDATE ON SAVE
      IMPORTING keys FOR OdataRegistry~validateServiceType.

    METHODS takeSnapshot FOR MODIFY
      IMPORTING keys FOR ACTION OdataRegistry~TakeSnapshot RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR OdataRegistry RESULT result.
ENDCLASS.

CLASS lhc_OdataRegistry IMPLEMENTATION.

  METHOD setDerivedFields.
    DATA: lv_now TYPE timestamp,
          lv_registered_by TYPE syuname,
          lv_registered_at TYPE timestamp,
          lv_v2_found TYPE abap_bool,
          lv_version_no TYPE zodata_registry-version_no,
          lv_service_name TYPE zodata_registry-service_name,
          lv_namespace TYPE zodata_registry-namespace,
          lv_v4_found TYPE abap_bool,
          lv_dummy_group TYPE /iwfnd/c_v4_msgr-group_id,
          lv_v4_namespace TYPE zodata_registry-namespace.

    GET TIME STAMP FIELD lv_now.

    READ ENTITIES OF zi_odata_registry IN LOCAL MODE
      ENTITY OdataRegistry
      FIELDS ( ServiceId ServiceType VersionNo RegisteredBy RegisteredAt LastChangeAt )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_registry).

    LOOP AT lt_registry ASSIGNING FIELD-SYMBOL(<ls_registry>).
      lv_registered_by = <ls_registry>-RegisteredBy.
      IF lv_registered_by IS INITIAL.
        lv_registered_by = sy-uname.
      ENDIF.

      lv_registered_at = <ls_registry>-RegisteredAt.
      IF lv_registered_at IS INITIAL.
        lv_registered_at = lv_now.
      ENDIF.

      CLEAR: lv_v2_found, lv_v4_found, lv_service_name, lv_namespace,
             lv_version_no, lv_dummy_group, lv_v4_namespace.

      CASE <ls_registry>-ServiceType.
        WHEN '001'.
          lv_version_no = <ls_registry>-VersionNo.
          IF lv_version_no IS INITIAL.
            lv_version_no = '0001'.
          ENDIF.

          SELECT SINGLE service_name,
                         namespace
            FROM /iwfnd/i_med_srh
            WHERE object_name     = @<ls_registry>-ServiceId
              AND service_version = @lv_version_no
            INTO (@lv_service_name, @lv_namespace).

          IF sy-subrc = 0.
            lv_v2_found = abap_true.
          ENDIF.

          IF lv_v2_found = abap_true.
            MODIFY ENTITIES OF zi_odata_registry IN LOCAL MODE
              ENTITY OdataRegistry
              UPDATE FIELDS ( ServiceName VersionNo Namespace Status RegisteredBy RegisteredAt LastChangeAt )
              WITH VALUE #(
                ( %tky         = <ls_registry>-%tky
                  ServiceName  = lv_service_name
                  VersionNo    = lv_version_no
                  Namespace    = lv_namespace
                  Status       = 'A'
                  RegisteredBy = lv_registered_by
                  RegisteredAt = lv_registered_at
                  LastChangeAt = lv_now ) ).
          ELSE.
            MODIFY ENTITIES OF zi_odata_registry IN LOCAL MODE
              ENTITY OdataRegistry
              UPDATE FIELDS ( Status RegisteredBy RegisteredAt LastChangeAt )
              WITH VALUE #(
                ( %tky         = <ls_registry>-%tky
                  Status       = 'I'
                  RegisteredBy = lv_registered_by
                  RegisteredAt = lv_registered_at
                  LastChangeAt = lv_now ) ).
          ENDIF.

        WHEN '002'.
          SELECT SINGLE group_id
            FROM /iwfnd/c_v4_msgr
            WHERE group_id = @<ls_registry>-ServiceId
            INTO @lv_dummy_group.
          IF sy-subrc = 0.
            lv_v4_found = abap_true.
          ENDIF.

          IF lv_v4_found = abap_true.
            SELECT SINGLE b~namespace
              FROM tadir AS a
              INNER JOIN tdevc AS b ON a~devclass = b~devclass
              WHERE a~pgmid    = 'R3TR'
                AND a~object   = 'SRVB'
                AND a~obj_name = @<ls_registry>-ServiceId
              INTO @lv_v4_namespace.

            MODIFY ENTITIES OF zi_odata_registry IN LOCAL MODE
              ENTITY OdataRegistry
              UPDATE FIELDS ( ServiceName VersionNo Namespace Status RegisteredBy RegisteredAt LastChangeAt )
              WITH VALUE #(
                ( %tky         = <ls_registry>-%tky
                  ServiceName  = <ls_registry>-ServiceId
                  VersionNo    = COND #( WHEN <ls_registry>-VersionNo IS INITIAL THEN '0001' ELSE <ls_registry>-VersionNo )
                  Namespace    = lv_v4_namespace
                  Status       = 'A'
                  RegisteredBy = lv_registered_by
                  RegisteredAt = lv_registered_at
                  LastChangeAt = lv_now ) ).
          ELSE.
            MODIFY ENTITIES OF zi_odata_registry IN LOCAL MODE
              ENTITY OdataRegistry
              UPDATE FIELDS ( Status RegisteredBy RegisteredAt LastChangeAt )
              WITH VALUE #(
                ( %tky         = <ls_registry>-%tky
                  Status       = 'I'
                  RegisteredBy = lv_registered_by
                  RegisteredAt = lv_registered_at
                  LastChangeAt = lv_now ) ).
          ENDIF.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateServiceType.
    DATA: lv_v2_dummy TYPE /iwfnd/i_med_srh-object_name,
          lv_v4_dummy TYPE /iwfnd/c_v4_msgr-group_id.

    READ ENTITIES OF zi_odata_registry IN LOCAL MODE
      ENTITY OdataRegistry
      FIELDS ( ServiceId ServiceType VersionNo )
      WITH CORRESPONDING #( keys )
      RESULT DATA(lt_registry).

    LOOP AT lt_registry ASSIGNING FIELD-SYMBOL(<ls_registry>).
      CASE <ls_registry>-ServiceType.
        WHEN '001'.
          IF <ls_registry>-VersionNo IS INITIAL.
            APPEND VALUE #( %tky = <ls_registry>-%tky ) TO failed-odataregistry.
            APPEND VALUE #(
              %tky               = <ls_registry>-%tky
              %msg               = new_message_with_text(
                                     severity = if_abap_behv_message=>severity-error
                                     text     = 'VersionNo is required for OData V2 service type 001.' )
              %element-VersionNo = if_abap_behv=>mk-on ) TO reported-odataregistry.
            CONTINUE.
          ENDIF.

          CLEAR lv_v2_dummy.
          SELECT SINGLE object_name
            FROM /iwfnd/i_med_srh
            WHERE object_name     = @<ls_registry>-ServiceId
              AND service_version = @<ls_registry>-VersionNo
            INTO @lv_v2_dummy.

          IF sy-subrc <> 0.
            APPEND VALUE #( %tky = <ls_registry>-%tky ) TO failed-odataregistry.
            APPEND VALUE #(
              %tky                 = <ls_registry>-%tky
              %msg                 = new_message_with_text(
                                       severity = if_abap_behv_message=>severity-error
                                       text     = |404: OData V2 object { <ls_registry>-ServiceId } version { <ls_registry>-VersionNo } was not found in /IWFND/I_MED_SRH.| )
              %element-ServiceName = if_abap_behv=>mk-on
              %element-VersionNo   = if_abap_behv=>mk-on ) TO reported-odataregistry.
          ENDIF.

        WHEN '002'.
          CLEAR lv_v4_dummy.
          SELECT SINGLE group_id
            FROM /iwfnd/c_v4_msgr
            WHERE group_id = @<ls_registry>-ServiceId
            INTO @lv_v4_dummy.

          IF sy-subrc <> 0.
            APPEND VALUE #( %tky = <ls_registry>-%tky ) TO failed-odataregistry.
            APPEND VALUE #(
              %tky                 = <ls_registry>-%tky
              %msg                 = new_message_with_text(
                                       severity = if_abap_behv_message=>severity-error
                                       text     = |404: OData V4 group ID { <ls_registry>-ServiceId } was not found in /IWFND/C_V4_MSGR.| )
              %element-ServiceName = if_abap_behv=>mk-on ) TO reported-odataregistry.
          ENDIF.

        WHEN OTHERS.
          APPEND VALUE #( %tky = <ls_registry>-%tky ) TO failed-odataregistry.
          APPEND VALUE #(
            %tky                = <ls_registry>-%tky
            %msg                = new_message_with_text(
                                   severity = if_abap_behv_message=>severity-error
                                   text     = |Unsupported service type { <ls_registry>-ServiceType }. Use 001 for OData V2 or 002 for OData V4.| )
            %element-ServiceType = if_abap_behv=>mk-on ) TO reported-odataregistry.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

 METHOD takeSnapshot.

  DATA:
    lv_service_id TYPE zodata_registry-service_id,
    lv_version_no TYPE zodata_registry-version_no,
    ls_registry_db TYPE zodata_registry,
    lt_v2_input TYPE zcl_odata_v2_registry_service=>tt_input,
    lt_v2_result TYPE zcl_odata_v2_registry_service=>tt_result,
    ls_v2_result TYPE zcl_odata_v2_registry_service=>ty_result,
    ls_version TYPE zodata_version,
    lt_v2_keys TYPE zcl_odata_registry_helper=>tt_v2_keys,
    lt_v2_hits TYPE zcl_odata_registry_helper=>tt_v2_keys.

  READ ENTITIES OF zi_odata_registry IN LOCAL MODE
    ENTITY OdataRegistry
    FIELDS ( ServiceId VersionNo ServiceType )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_registry).

  LOOP AT lt_registry ASSIGNING FIELD-SYMBOL(<ls_registry>).

    CLEAR:
      lv_service_id,
      lv_version_no,
      ls_registry_db,
      lt_v2_input,
      lt_v2_result,
      ls_v2_result,
      ls_version,
      lt_v2_keys,
      lt_v2_hits.

    lv_service_id = <ls_registry>-ServiceId.
    lv_version_no = <ls_registry>-VersionNo.

    IF lv_service_id IS INITIAL.
      APPEND VALUE #(
        %tky = <ls_registry>-%tky
      ) TO failed-odataregistry.

      APPEND VALUE #(
        %tky = <ls_registry>-%tky
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-error
                 text     = 'ServiceId is initial.' )
      ) TO reported-odataregistry.

      CONTINUE.
    ENDIF.

    IF <ls_registry>-ServiceType <> '001'.

      APPEND VALUE #(
        %tky = <ls_registry>-%tky
      ) TO failed-odataregistry.

      APPEND VALUE #(
        %tky = <ls_registry>-%tky
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-error
                 text     = |Service { lv_service_id } is not an OData V2 service.| )
      ) TO reported-odataregistry.

      CONTINUE.

    ENDIF.

    SELECT SINGLE service_id,
                  service_type,
                  version_no,
                  status
      FROM zodata_registry
      WHERE service_id   = @lv_service_id
        AND service_type = '001'
      INTO @ls_registry_db.

    IF sy-subrc <> 0.

      APPEND VALUE #(
        %tky = <ls_registry>-%tky
      ) TO failed-odataregistry.

      APPEND VALUE #(
        %tky = <ls_registry>-%tky
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-error
                 text     = |Service ID { lv_service_id } is not registered as an OData V2 service in ZODATA_REGISTRY.| )
      ) TO reported-odataregistry.

      CONTINUE.

    ENDIF.

    lv_version_no = ls_registry_db-version_no.

    IF lv_version_no IS INITIAL.
      lv_version_no = '0001'.
    ENDIF.

    APPEND VALUE #(
      object_name     = CONV /iwfnd/med_mdl_srg_name( lv_service_id )
      service_version = CONV /iwfnd/med_mdl_version( lv_version_no )
    ) TO lt_v2_keys.

    lt_v2_hits = zcl_odata_registry_helper=>fetch_existing_v2( lt_v2_keys ).

    IF zcl_odata_registry_helper=>is_v2_found(
         iv_service_id = CONV /iwfnd/v4_med_group_id( lv_service_id )
         iv_version_no = lv_version_no
         it_hits       = lt_v2_hits ) = abap_false.

      APPEND VALUE #(
        %tky = <ls_registry>-%tky
      ) TO failed-odataregistry.

      APPEND VALUE #(
        %tky = <ls_registry>-%tky
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-error
                 text     = |OData V2 service ID { lv_service_id } version { lv_version_no } is not active in /IWFND/I_MED_SRH.| )
      ) TO reported-odataregistry.

      CONTINUE.

    ENDIF.

    APPEND VALUE zcl_odata_v2_registry_service=>ty_input(
      service_id   = lv_service_id
      service_type = '001'
      version_no   = lv_version_no
    ) TO lt_v2_input.

    lt_v2_result =
      zcl_odata_v2_registry_service=>process_v2_registry(
        lt_v2_input ).

    READ TABLE lt_v2_result INTO ls_v2_result INDEX 1.

    IF sy-subrc <> 0
       OR ls_v2_result-snapshot_create <> abap_true.
      CONTINUE.
    ENDIF.

    ls_version-service_id       = ls_v2_result-snapshot-service_id.
    ls_version-snapshot_id      = ls_v2_result-snapshot-snapshot_id.
    ls_version-snapshot_version = ls_v2_result-snapshot-snapshot_version.
    ls_version-metadata_hash    = ls_v2_result-snapshot-metadata_hash.
    ls_version-metadata_xml     = ls_v2_result-snapshot-metadata_xml.
    ls_version-snapshot_by      = ls_v2_result-snapshot-snapshot_by.
    ls_version-snapshot_at      = ls_v2_result-snapshot-snapshot_at.
    ls_version-trigger_type     = ls_v2_result-snapshot-trigger_type.
    ls_version-is_changed       = ls_v2_result-snapshot-is_changed.

    INSERT zodata_version FROM @ls_version.

    IF sy-subrc = 0.

      zcl_odata_audit_helper=>write_log(
        iv_service_id  = ls_version-service_id
        iv_snapshot_id = ls_version-snapshot_id
        iv_action_type = zcl_odata_audit_helper=>gc_action_create_version
        iv_result      = zcl_odata_audit_helper=>gc_result_success ).

    ENDIF.

  ENDLOOP.

ENDMETHOD.

  METHOD get_instance_authorizations.
    LOOP AT keys INTO DATA(key).
      APPEND VALUE #(
        %tky    = key-%tky
        %update = if_abap_behv=>auth-allowed
        %delete = if_abap_behv=>auth-allowed ) TO result.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
