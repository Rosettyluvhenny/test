REPORT ztest_xml_parser.

START-OF-SELECTION.

  WRITE: / '=== TEST ZCL_ODATA_XML_PARSER ==='.
  WRITE: /.

  " Fetch V4 metadata thực tế từ ZC_SALESDATA
  DATA lv_xml TYPE string.
  TRY.
      lv_xml = zcl_odata_meta_engine=>fetch_v4_metadata(
        iv_service_name    = 'ZC_SALESDATA'
        iv_service_version = '0001' ).
      WRITE: / 'XML fetched, length:', strlen( lv_xml ).
    CATCH cx_sy_conversion_codepage INTO DATA(lx).
      WRITE: / '[ERR] Fetch failed:', lx->get_text( ).
      RETURN.
  ENDTRY.

  " Parse XML
  DATA ls_result TYPE zcl_odata_xml_parser=>ty_parse_result.
  TRY.
      ls_result = zcl_odata_xml_parser=>parse_metadata( lv_xml ).
    CATCH zcx_gsu26gsp09 INTO DATA(lx_parse).
      WRITE: / '[ERR] Parse failed:', lx_parse->get_text( ).
      RETURN.
  ENDTRY.

  " In KPI dashboard
  WRITE: / '=== STRUCTURAL ANALYSIS ==='.
  WRITE: / 'EntityTypes      :', lines( ls_result-entity_types ).
  WRITE: / 'EntitySets       :', lines( ls_result-entity_sets ).
  WRITE: / 'Properties       :', lines( ls_result-properties ).
  WRITE: / 'Associations     :', lines( ls_result-associations ).
  WRITE: / 'NavigationProps  :', lines( ls_result-nav_properties ).
  WRITE: / 'ComplexTypes     :', lines( ls_result-complex_types ).
  WRITE: / 'FunctionImports  :', lines( ls_result-function_imports ).
  WRITE: / 'Actions          :', lines( ls_result-actions ).
  WRITE: / 'Annotations      :', lines( ls_result-annotations ).
  WRITE: /.

  " Chi tiết EntityTypes
  WRITE: / '=== ENTITY TYPES ==='.
  LOOP AT ls_result-entity_types ASSIGNING FIELD-SYMBOL(<et>).
    WRITE: / '  EntityType:', <et>-element_name.

    " Properties của entity này
    LOOP AT ls_result-properties ASSIGNING FIELD-SYMBOL(<prop>)
      WHERE parent_name = <et>-element_name.
      WRITE: / '    +- Property:', <prop>-element_name,
               '|', <prop>-attributes.
    ENDLOOP.

    " Navigation Properties
    LOOP AT ls_result-nav_properties ASSIGNING FIELD-SYMBOL(<nav>)
      WHERE parent_name = <et>-element_name.
      WRITE: / '    +- NavProp:', <nav>-element_name.
    ENDLOOP.
  ENDLOOP.

  WRITE: /.
  WRITE: / '=== TEST COMPLETE ==='.
