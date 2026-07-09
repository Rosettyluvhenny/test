CLASS zcl_odata_audit_helper DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    " Action type constants
CONSTANTS:
  gc_action_register       TYPE char10 VALUE 'REGISTER',
  gc_action_create_version TYPE char10 VALUE 'CREATE_VER',
  gc_action_download       TYPE char10 VALUE 'DOWNLOAD',
  gc_action_view           TYPE char10 VALUE 'VIEW',
  gc_action_compare        TYPE char10 VALUE 'COMPARE'.

    " Result — dùng actor_role để phân biệt
CONSTANTS:
  gc_result_success TYPE int1 VALUE 1,
  gc_result_error   TYPE int1 VALUE 2,
  gc_result_warning TYPE int1 VALUE 3.

CLASS-METHODS write_log
  IMPORTING iv_service_id  TYPE zodata_service_id_de
            iv_snapshot_id TYPE char32  DEFAULT ''
            iv_action_type TYPE char10
            iv_result      TYPE int1    DEFAULT 1
            iv_remarks     TYPE char255 DEFAULT ''.

ENDCLASS.


CLASS zcl_odata_audit_helper IMPLEMENTATION.

  METHOD write_log.

    " ── Sinh LOG_ID dạng UUID ───────────────────────────
    DATA lv_log_id TYPE char32.
    TRY.
        DATA(lv_guid) = cl_system_uuid=>create_uuid_c32_static( ).
        lv_log_id = lv_guid.
      CATCH cx_uuid_error.
        " Fallback: dùng timestamp
        DATA lv_ts TYPE timestamp.
        GET TIME STAMP FIELD lv_ts.
        lv_log_id = lv_ts.
    ENDTRY.

    " ── Build log record ────────────────────────────────
    DATA ls_log TYPE zodata_audit_log.
    ls_log-log_id      = lv_log_id.
    ls_log-service_id  = iv_service_id.
    ls_log-snapshot_id = iv_snapshot_id.
    ls_log-action_type = iv_action_type.
    ls_log-actor       = sy-uname.
    ls_log-actor_role  = iv_result.
    ls_log-ip_address  = ''.
    ls_log-remarks     = iv_remarks.

    " Set timestamp
    GET TIME STAMP FIELD ls_log-action_at.

    " ── INSERT — không block main flow nếu lỗi ──────────
    INSERT zodata_audit_log FROM @ls_log.

  ENDMETHOD.

ENDCLASS.
