REPORT zodata_test_comparator.

" ════════════════════════════════════════════════════════════════
" CONFIG — chỉnh trước khi chạy
" ════════════════════════════════════════════════════════════════
DATA(gv_service_name) = CONV string( 'ZGSM_ODATA_SRV' ).  " tên service thực tế
DATA(gv_odata_type)   = CONV string( 'V2' ).               " V2 hoặc V4
DATA(gv_service_ver)  = CONV string( '0001' ).
DATA(gv_service_id)   = CONV zodata_service_id_de( '0000000001' ). " SERVICE_ID thực tế

" ── Selection screen ────────────────────────────────────────────
PARAMETERS:
  p_base   TYPE n LENGTH 6 DEFAULT '000001',   " SNAPSHOT_VERSION base
  p_cmp    TYPE n LENGTH 6 DEFAULT '000002',   " SNAPSHOT_VERSION compare
  p_live   TYPE abap_bool  DEFAULT abap_true,  " X = fetch live từ Gateway
  p_show_u TYPE abap_bool  DEFAULT abap_false. " X = show unchanged nodes

START-OF-SELECTION.

  WRITE: / '=== ZODATA Metadata Comparator Test ==='.
  WRITE: / '  Service  :', gv_service_name.
  WRITE: / '  Type     :', gv_odata_type.
  SKIP.

  DATA lv_xml_base    TYPE string.
  DATA lv_xml_compare TYPE string.
  DATA lv_id_base     TYPE string.
  DATA lv_id_compare  TYPE string.

  " ════════════════════════════════════════════════════════════════
  " CÁCH 1: So sánh 2 versions từ DB (ZODATA_VERSION)
  " ════════════════════════════════════════════════════════════════
  IF p_live = abap_false.

    WRITE: / '[MODE] So sánh DB version', p_base, 'vs', p_cmp.
    SKIP.

    " Đọc base version
    SELECT SINGLE snapshot_id, metadata_xml
      FROM zodata_version
      WHERE service_id       = @gv_service_id
        AND snapshot_version = @p_base
      INTO @DATA(ls_base_db).

    IF sy-subrc <> 0.
      WRITE: / '!! Snapshot version', p_base, 'không tìm thấy.'.
      STOP.
    ENDIF.

    " Đọc compare version
    SELECT SINGLE snapshot_id, metadata_xml
      FROM zodata_version
      WHERE service_id       = @gv_service_id
        AND snapshot_version = @p_cmp
      INTO @DATA(ls_cmp_db).

    IF sy-subrc <> 0.
      WRITE: / '!! Snapshot version', p_cmp, 'không tìm thấy.'.
      STOP.
    ENDIF.

    " rawstring → string (UTF-8)
    TRY.
        lv_xml_base = cl_abap_codepage=>convert_from(
          source   = ls_base_db-metadata_xml
          codepage = `UTF-8` ).
        lv_xml_compare = cl_abap_codepage=>convert_from(
          source   = ls_cmp_db-metadata_xml
          codepage = `UTF-8` ).
    CATCH cx_root INTO DATA(lx_conv1).
        WRITE: / '!! Convert rawstring failed:', lx_conv1->get_text( ).
        STOP.
    ENDTRY.

    lv_id_base    = |DB SNAP-{ p_base } [{ ls_base_db-snapshot_id }]|.
    lv_id_compare = |DB SNAP-{ p_cmp }  [{ ls_cmp_db-snapshot_id }]|.

  " ════════════════════════════════════════════════════════════════
  " CÁCH 2: Fetch LIVE từ Gateway, so với snapshot mới nhất trong DB
  " ════════════════════════════════════════════════════════════════
  ELSE.

    WRITE: / '[MODE] Fetch LIVE từ Gateway, so với snapshot mới nhất trong DB'.
    SKIP.

    " Fetch live XML
    TRY.
        IF gv_odata_type = 'V2'.
          lv_xml_compare = zcl_odata_meta_engine=>fetch_v2_metadata(
                             iv_service_name    = gv_service_name
                             iv_service_version = gv_service_ver ).
        ELSE.
          lv_xml_compare = zcl_odata_meta_engine=>fetch_v4_metadata(
                             iv_service_name    = gv_service_name
                             iv_service_version = gv_service_ver ).
        ENDIF.
        WRITE: / '  [OK] Fetched live XML,', strlen( lv_xml_compare ), 'chars'.

    CATCH cx_sy_conversion_codepage INTO DATA(lx_fetch).
        WRITE: / '!! Fetch metadata failed:', lx_fetch->get_text( ).
        WRITE: / '   Kiểm tra: service name đúng chưa? Port HTTP đúng chưa?'.
        STOP.
    ENDTRY.

" Lấy snapshot mới nhất từ DB làm base
    DATA ls_latest TYPE zodata_version.

    SELECT snapshot_id, snapshot_version, metadata_xml
      FROM zodata_version
      WHERE service_id = @gv_service_id
      ORDER BY snapshot_version DESCENDING
      INTO CORRESPONDING FIELDS OF @ls_latest
      UP TO 1 ROWS.
    ENDSELECT.

    IF sy-subrc <> 0.
      WRITE: / '!! Không có snapshot nào trong DB.'.
      WRITE: / '   Chạy createVersion trước để có dữ liệu so sánh.'.
      STOP.
    ENDIF.

    TRY.
        lv_xml_base = cl_abap_codepage=>convert_from(
          source   = ls_latest-metadata_xml
          codepage = `UTF-8` ).
    CATCH cx_root INTO DATA(lx_conv2).
        WRITE: / '!! Convert DB rawstring failed:', lx_conv2->get_text( ).
        STOP.
    ENDTRY.

    lv_id_base    = |DB SNAP-{ ls_latest-snapshot_version } [{ ls_latest-snapshot_id }]|.
    lv_id_compare = |LIVE (Gateway fetch)|.

  ENDIF.

  " ════════════════════════════════════════════════════════════════
  " VALIDATE XML không rỗng
  " ════════════════════════════════════════════════════════════════
  IF lv_xml_base IS INITIAL.
    WRITE: / '!! XML base rỗng — abort.'. STOP.
  ENDIF.
  IF lv_xml_compare IS INITIAL.
    WRITE: / '!! XML compare rỗng — abort.'. STOP.
  ENDIF.

  WRITE: / '  Base    :', strlen( lv_xml_base ),    'chars —', lv_id_base.
  WRITE: / '  Compare :', strlen( lv_xml_compare ), 'chars —', lv_id_compare.
  SKIP.

  " ════════════════════════════════════════════════════════════════
  " CHẠY COMPARE
  " ════════════════════════════════════════════════════════════════
  WRITE: / '--- Running compare...'.

  DATA(ls_result) = zcl_gsu26_metadata_comparator=>compare(
    iv_base_xml      = lv_xml_base
    iv_compare_xml   = lv_xml_compare
    iv_base_id       = lv_id_base
    iv_compare_id    = lv_id_compare
    iv_odata_version = gv_odata_type
  ).

  " ════════════════════════════════════════════════════════════════
  " IN KẾT QUẢ
  " ════════════════════════════════════════════════════════════════
  zcl_gsu26_metadata_comparator=>print(
    is_result         = ls_result
    iv_show_unchanged = p_show_u
  ).

  " ════════════════════════════════════════════════════════════════
  " QUICK ASSESSMENT
  " ════════════════════════════════════════════════════════════════
  SKIP.
  WRITE: / '┌─ Quick Assessment ───────────────────────────────────'.

  IF ls_result-parse_error IS NOT INITIAL.
    WRITE: / '│  !! Parse error:', ls_result-parse_error.
    WRITE: / '│     Kiểm tra XML hợp lệ không (dùng SE80 hoặc online XML validator).'.

  ELSEIF ls_result-added    = 0 AND ls_result-removed  = 0
     AND ls_result-changed  = 0 AND ls_result-moved    = 0
     AND ls_result-renamed  = 0 AND ls_result-type_changed = 0
     AND ls_result-deprecated = 0 AND ls_result-promoted  = 0.
    WRITE: / '│  ✓  Metadata KHÔNG thay đổi — không cần tạo snapshot mới.'.

  ELSE.
    WRITE: / '│  ✓  Metadata CÓ thay đổi — nên tạo snapshot mới.'.

    IF ls_result-removed > 0 OR ls_result-type_changed > 0.
      WRITE: / '│  ⚠  BREAKING CHANGE: có field/entity bị xóa hoặc đổi type!'.
    ENDIF.
    IF ls_result-deprecated > 0.
      WRITE: / '│  ⚠  Field bị deprecated (Nullable thay đổi sang true).'.
    ENDIF.
    IF ls_result-promoted > 0.
      WRITE: / '│  ⚠  Field promoted thành required (Nullable → false).'.
    ENDIF.
    IF ls_result-renamed > 0.
      WRITE: / '│  ℹ  Có rename — kiểm tra client compatibility.'.
    ENDIF.
    IF ls_result-moved > 0.
      WRITE: / '│  ℹ  Có thay đổi thứ tự field/entity.'.
    ENDIF.
  ENDIF.

  WRITE: / '└──────────────────────────────────────────────────────'.
