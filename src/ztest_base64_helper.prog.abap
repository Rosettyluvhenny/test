REPORT ztest_base64_helper.

START-OF-SELECTION.

  WRITE: / '=== TEST ZCL_ODATA_BASE64_HELPER ==='.
  WRITE: /.

  " Mock XML để test
  DATA lv_xml TYPE string.
  lv_xml = '<EntityType Name="SalesOrderSet">' &&
           '<Property Name="SoId" Type="Edm.String"/>' &&
           '</EntityType>'.

  WRITE: / 'Original XML:'.
  WRITE: / lv_xml.
  WRITE: /.

  " ── Test 1: xml_to_base64 ──────────────────────────
  WRITE: / 'Test 1: xml_to_base64'.
  DATA lv_base64 TYPE string.
  TRY.
      lv_base64 = zcl_odata_base64_helper=>xml_to_base64( lv_xml ).
      WRITE: / '  [OK] Base64:', lv_base64.
    CATCH cx_static_check INTO DATA(lx_enc).
      WRITE: / '  [ERR]', lx_enc->get_text( ).
  ENDTRY.
  WRITE: /.

  " ── Test 2: base64_to_xml ──────────────────────────
  WRITE: / 'Test 2: base64_to_xml'.
  DATA lv_decoded TYPE string.
  TRY.
      lv_decoded = zcl_odata_base64_helper=>base64_to_xml( lv_base64 ).
      WRITE: / '  [OK] Decoded XML:', lv_decoded.
    CATCH cx_static_check INTO DATA(lx_dec).
      WRITE: / '  [ERR]', lx_dec->get_text( ).
  ENDTRY.
  WRITE: /.

  " ── Test 3: Round-trip verify ───────────────────────
  WRITE: / 'Test 3: Round-trip verify (Original = Decoded?)'.
  IF lv_xml = lv_decoded.
    WRITE: / '  [OK] Round-trip SUCCESS - XML matches after encode/decode'.
  ELSE.
    WRITE: / '  [FAIL] Round-trip FAILED - XML does not match'.
    WRITE: / '  Expected:', lv_xml.
    WRITE: / '  Got     :', lv_decoded.
  ENDIF.
  WRITE: /.

  " ── Test 4: Empty string handling ───────────────────
  WRITE: / 'Test 4: Empty string handling'.
  TRY.
      DATA(lv_empty) = zcl_odata_base64_helper=>xml_to_base64( '' ).
      WRITE: / '  [OK] Empty Base64:', lv_empty.
    CATCH cx_static_check INTO DATA(lx_empty).
      WRITE: / '  [OK] Exception caught for empty:', lx_empty->get_text( ).
  ENDTRY.

  WRITE: /.
  WRITE: / '=== TEST COMPLETE ==='.
