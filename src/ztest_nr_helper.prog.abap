*&---------------------------------------------------------------------*
*& Report ZTEST_NR_HELPER
*& Test: ZCL_ODATA_NR_HELPER — Task 4.1
*&---------------------------------------------------------------------*
REPORT ztest_nr_helper.

START-OF-SELECTION.

  WRITE: / '=== TEST ZCL_ODATA_NR_HELPER ==='.
  WRITE: /.

  " ── Test 1: get_next_version_id ──────────────────────
  WRITE: / 'Test 1: get_next_version_id'.
  TRY.
      DATA(lv_ver_id) = zcl_odata_nr_helper=>get_next_version_id( ).
      WRITE: / '  [OK] Version ID generated:', lv_ver_id.
    CATCH cx_number_ranges INTO DATA(lx_ver).
      WRITE: / '  [ERR]', lx_ver->get_text( ).
    CATCH cx_root INTO DATA(lx_root1).
      WRITE: / '  [ERR] Unexpected:', lx_root1->get_text( ).
  ENDTRY.

  " ── Test 2: get_next_log_id ──────────────────────────
  WRITE: / 'Test 2: get_next_log_id'.
  TRY.
      DATA(lv_log_id) = zcl_odata_nr_helper=>get_next_log_id( ).
      WRITE: / '  [OK] Log ID generated   :', lv_log_id.
    CATCH cx_number_ranges INTO DATA(lx_log).
      WRITE: / '  [ERR]', lx_log->get_text( ).
    CATCH cx_root INTO DATA(lx_root2).
      WRITE: / '  [ERR] Unexpected:', lx_root2->get_text( ).
  ENDTRY.

  " ── Test 3: gọi liên tiếp để verify increment ────────
  WRITE: /.
  WRITE: / 'Test 3: Sequential IDs (verify increment)'.
  TRY.
      DATA(lv_id1) = zcl_odata_nr_helper=>get_next_version_id( ).
      DATA(lv_id2) = zcl_odata_nr_helper=>get_next_version_id( ).
      DATA(lv_id3) = zcl_odata_nr_helper=>get_next_version_id( ).
      WRITE: / '  ID 1:', lv_id1.
      WRITE: / '  ID 2:', lv_id2.
      WRITE: / '  ID 3:', lv_id3.
      IF lv_id2 > lv_id1 AND lv_id3 > lv_id2.
        WRITE: / '  [OK] IDs are incrementing correctly'.
      ELSE.
        WRITE: / '  [WARN] IDs not incrementing as expected'.
      ENDIF.
    CATCH cx_root INTO DATA(lx_root3).
      WRITE: / '  [ERR]', lx_root3->get_text( ).
  ENDTRY.

  WRITE: /.
  WRITE: / '=== TEST COMPLETE ==='.
