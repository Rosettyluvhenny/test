
CLASS zcl_odata_registry_helper DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      " ── V2 lookup key ──────────────────────────────────────
      BEGIN OF ty_v2_key,
        object_name     TYPE /iwfnd/med_mdl_srg_name,
        service_version TYPE /iwfnd/med_mdl_version,
      END OF ty_v2_key,
      tt_v2_keys TYPE STANDARD TABLE OF ty_v2_key
                      WITH DEFAULT KEY,

      " ── V4 lookup key ──────────────────────────────────────
      BEGIN OF ty_v4_key,
        group_id TYPE /iwfnd/v4_med_group_id,
      END OF ty_v4_key,
      tt_v4_keys TYPE STANDARD TABLE OF ty_v4_key
                      WITH DEFAULT KEY,

      " ── V2 enrichment result ───────────────────────────────
      BEGIN OF ty_v2_metadata,
        object_name     TYPE /iwfnd/med_mdl_srg_name,
        service_version TYPE /iwfnd/med_mdl_version,
        namespace       TYPE /iwfnd/med_mdl_namespace,
        service_name    TYPE /iwfnd/med_mdl_service_grp_id,
      END OF ty_v2_metadata,
      tt_v2_metadata TYPE STANDARD TABLE OF ty_v2_metadata
                          WITH KEY object_name service_version,

      " ── V4 enrichment result ───────────────────────────────
      " service_name = group_id intentionally (V4 has no separate display name)
      " namespace    = derived from TADIR → TDEVC join
      BEGIN OF ty_v4_metadata,
        group_id      TYPE /iwfnd/v4_med_group_id,
        service_name  TYPE /iwfnd/v4_med_group_id,   " same as group_id, by design
        namespace     TYPE namespace,             " from tdevc-namespace via tadir
      END OF ty_v4_metadata,
      tt_v4_metadata TYPE STANDARD TABLE OF ty_v4_metadata
                          WITH KEY group_id.

    CLASS-METHODS fetch_v2_metadata
      IMPORTING it_keys          TYPE tt_v2_keys
      RETURNING VALUE(rt_result) TYPE tt_v2_metadata.

    CLASS-METHODS fetch_v4_metadata
      IMPORTING it_keys          TYPE tt_v4_keys
      RETURNING VALUE(rt_result) TYPE tt_v4_metadata.

    CLASS-METHODS fetch_existing_v2
      IMPORTING it_keys        TYPE tt_v2_keys
      RETURNING VALUE(rt_hits) TYPE tt_v2_keys.

    CLASS-METHODS fetch_existing_v4
      IMPORTING it_keys        TYPE tt_v4_keys
      RETURNING VALUE(rt_hits) TYPE tt_v4_keys.

    CLASS-METHODS is_v2_found
      IMPORTING iv_service_id    TYPE /iwfnd/v4_med_group_id
                iv_version_no    TYPE /iwfnd/med_mdl_version
                it_hits          TYPE tt_v2_keys
      RETURNING VALUE(rv_result) TYPE abap_bool.

    CLASS-METHODS is_v4_found
      IMPORTING iv_service_id    TYPE /iwfnd/v4_med_group_id
                it_hits          TYPE tt_v4_keys
      RETURNING VALUE(rv_result) TYPE abap_bool.

ENDCLASS.

CLASS zcl_odata_registry_helper IMPLEMENTATION.

  METHOD fetch_v2_metadata.
    CHECK it_keys IS NOT INITIAL.
    SELECT object_name,
           service_version,
           namespace,
           service_name
      FROM /iwfnd/i_med_srh
      FOR ALL ENTRIES IN @it_keys
      WHERE object_name     = @it_keys-object_name
        AND service_version = @it_keys-service_version
      INTO TABLE @rt_result.
  ENDMETHOD.

  METHOD fetch_v4_metadata.
    CHECK it_keys IS NOT INITIAL.

    " Loop is unavoidable here — TADIR join needs one obj_name at a time
    " and FAE cannot be used with a JOIN. Cost is acceptable because:
    "   1. This only runs during determination (on save, create only)
    "   2. Bulk creates of V4 services are rare in practice
    LOOP AT it_keys ASSIGNING FIELD-SYMBOL(<ls_key>).

      " Namespace comes from TADIR → TDEVC, not /IWFND/C_V4_MSGR
      SELECT SINGLE b~namespace
        FROM tadir AS a
        INNER JOIN tdevc AS b ON a~devclass = b~devclass
        WHERE a~pgmid    = 'R3TR'
          AND a~object   = 'SRVB'
          AND a~obj_name = @<ls_key>-group_id
        INTO @DATA(lv_namespace).

      " V4: service_name is intentionally the same value as group_id —
      " there is no separate display name in the V4 registry
      APPEND VALUE #(
        group_id     = <ls_key>-group_id
        service_name = <ls_key>-group_id   " by design, not a bug
        namespace    = COND #(
                         WHEN sy-subrc = 0
                         THEN lv_namespace
                         ELSE space )      " not found in TADIR → leave blank,
                                           " validation will catch missing service
      ) TO rt_result.

    ENDLOOP.
  ENDMETHOD.

  METHOD fetch_existing_v4.
    CHECK it_keys IS NOT INITIAL.

    " Existence check: service must be registered in /IWFND/C_V4_MSGR
    " Namespace derivation is separate — done only in fetch_v4_metadata
    SELECT group_id
      FROM /iwfnd/c_v4_msgr
      FOR ALL ENTRIES IN @it_keys
      WHERE group_id = @it_keys-group_id
      INTO TABLE @rt_hits.
  ENDMETHOD.

  METHOD fetch_existing_v2.
    CHECK it_keys IS NOT INITIAL.
    SELECT object_name,
           service_version
      FROM /iwfnd/i_med_srh
      FOR ALL ENTRIES IN @it_keys
      WHERE object_name     = @it_keys-object_name
        AND service_version = @it_keys-service_version
      INTO TABLE @rt_hits.
  ENDMETHOD.

  METHOD is_v2_found.
    rv_result = xsdbool(
      line_exists(
        it_hits[ object_name     = iv_service_id
                 service_version = iv_version_no ] ) ).
  ENDMETHOD.

  METHOD is_v4_found.
    rv_result = xsdbool(
      line_exists(
        it_hits[ group_id = iv_service_id ] ) ).
  ENDMETHOD.

ENDCLASS.
