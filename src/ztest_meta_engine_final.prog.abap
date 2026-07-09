REPORT ztest_meta_engine_final.

START-OF-SELECTION.

  WRITE: / '=== TEST ZCL_ODATA_META_ENGINE ==='.
  WRITE: /.

  " ── Test V4: ZC_SALESDATA (đã verify URL hoạt động) ──
  WRITE: / 'Test V4: ZC_SALESDATA'.
  TRY.
      DATA(lv_v4_xml) = zcl_odata_meta_engine=>fetch_v4_metadata(
        iv_service_name    = 'ZC_SALESDATA'
        iv_service_version = '0001' ).

      DATA(lv_len) = strlen( lv_v4_xml ).
      WRITE: / '  [OK] XML length:', lv_len.
      WRITE: / '  Preview:'.
      DATA lv_preview TYPE string.
      lv_preview = lv_v4_xml(300).
      WRITE: / lv_preview.

    CATCH cx_sy_conversion_codepage INTO DATA(lx_v4).
      WRITE: / '  [ERR]', lx_v4->get_text( ).
  ENDTRY.

  WRITE: /.

  " ── Test V2: dùng tên service nếu có ─────────────────
  WRITE: / 'Test V2: (thay SERVICE_NAME nếu có V2 service)'.
  TRY.
      DATA(lv_v2_xml) = zcl_odata_meta_engine=>fetch_v2_metadata(
        iv_service_name    = 'ZGSU26_METADATA_SRV'
        iv_service_version = '0001' ).

      DATA(lv_v2_len) = strlen( lv_v2_xml ).
      WRITE: / '  [OK] V2 XML length:', lv_v2_len.

    CATCH cx_sy_conversion_codepage INTO DATA(lx_v2).
      WRITE: / '  [ERR]', lx_v2->get_text( ).
  ENDTRY.

  WRITE: /.
  WRITE: / '=== DONE ==='.
