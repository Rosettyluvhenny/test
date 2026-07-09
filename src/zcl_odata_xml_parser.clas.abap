CLASS zcl_odata_xml_parser DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    " Result structure cho từng element
    TYPES:
      BEGIN OF ty_element,
        element_type TYPE string,   " EntityType/Property/Association...
        element_name TYPE string,   " Name attribute
        parent_name  TYPE string,   " Parent entity name
        attributes   TYPE string,   " Raw attributes string
      END OF ty_element,
      tt_elements TYPE STANDARD TABLE OF ty_element WITH DEFAULT KEY.

    " Kết quả parse tổng hợp
    TYPES:
      BEGIN OF ty_parse_result,
        entity_types       TYPE tt_elements,
        entity_sets        TYPE tt_elements,
        properties         TYPE tt_elements,
        associations       TYPE tt_elements,
        nav_properties     TYPE tt_elements,
        complex_types      TYPE tt_elements,
        function_imports   TYPE tt_elements,
        actions            TYPE tt_elements,
        annotations        TYPE tt_elements,
      END OF ty_parse_result.

    " Main method — parse XML string → structured result
    CLASS-METHODS parse_metadata
      IMPORTING iv_xml              TYPE string
      RETURNING VALUE(rs_result)    TYPE ty_parse_result
      RAISING   zcx_gsu26gsp09.

    " Parse từ Base64 (dùng trong createVersion flow)
    CLASS-METHODS parse_from_base64
      IMPORTING iv_base64           TYPE string
      RETURNING VALUE(rs_result)    TYPE ty_parse_result
      RAISING   zcx_gsu26gsp09.

  PRIVATE SECTION.

    " Extract attribute value từ XML element string
    CLASS-METHODS get_attribute
      IMPORTING iv_xml_line     TYPE string
                iv_attr_name    TYPE string
      RETURNING VALUE(rv_value) TYPE string.

    " Parse children của EntityType
    CLASS-METHODS parse_entity_children
      IMPORTING io_entity_node  TYPE REF TO if_ixml_node
                iv_entity_name  TYPE string
      CHANGING  ct_properties   TYPE tt_elements
                ct_nav_props    TYPE tt_elements.

ENDCLASS.


CLASS zcl_odata_xml_parser IMPLEMENTATION.

  METHOD parse_metadata.
    " ── Convert XML string → XSTRING ───────────────────
    DATA lv_xstr TYPE xstring.
    TRY.
        lv_xstr = cl_abap_codepage=>convert_to(
          source   = iv_xml
          codepage = `UTF-8` ).
      CATCH cx_root.
        zcx_gsu26gsp09=>raise_invalid_input( iv_field = 'XML' ).
    ENDTRY.

    " ── Setup iXML parser ───────────────────────────────
    DATA lo_ixml   TYPE REF TO if_ixml.
    DATA lo_doc    TYPE REF TO if_ixml_document.
    DATA lo_parser TYPE REF TO if_ixml_parser.
    DATA lo_sf     TYPE REF TO if_ixml_stream_factory.

    lo_ixml = cl_ixml=>create( ).
    lo_doc  = lo_ixml->create_document( ).
    lo_sf   = lo_ixml->create_stream_factory( ).

    DATA(lo_in) = lo_sf->create_istream_xstring( string = lv_xstr ).
    lo_parser = lo_ixml->create_parser(
      stream_factory = lo_sf
      istream        = lo_in
      document       = lo_doc ).

    IF lo_parser->parse( ) <> 0.
      zcx_gsu26gsp09=>raise_invalid_input( iv_field = 'XML_PARSE' ).
    ENDIF.

    " ── Duyệt tất cả nodes ──────────────────────────────
    DATA lo_iter TYPE REF TO if_ixml_node_iterator.
    DATA lo_node TYPE REF TO if_ixml_node.

    lo_iter = lo_doc->create_iterator( ).
    lo_node = lo_iter->get_next( ).

    WHILE lo_node IS NOT INITIAL.
      IF lo_node->get_type( ) <> if_ixml_node=>co_node_element.
        lo_node = lo_iter->get_next( ).
        CONTINUE.
      ENDIF.

      DATA(lo_el)    = CAST if_ixml_element( lo_node ).
      DATA(lv_nname) = lo_node->get_name( ).
      DATA(lv_name)  = lo_el->get_attribute( 'Name' ).

      CASE lv_nname.

        WHEN 'EntityType'.
          IF lv_name IS NOT INITIAL.
            APPEND VALUE ty_element(
              element_type = 'EntityType'
              element_name = lv_name ) TO rs_result-entity_types.

            " Parse children: Property + NavigationProperty
            parse_entity_children(
              EXPORTING
                io_entity_node = lo_node
                iv_entity_name = lv_name
              CHANGING
                ct_properties  = rs_result-properties
                ct_nav_props   = rs_result-nav_properties ).
          ENDIF.

        WHEN 'EntitySet'.
          IF lv_name IS NOT INITIAL.
            DATA(lv_entity_type) = lo_el->get_attribute( 'EntityType' ).
            APPEND VALUE ty_element(
              element_type = 'EntitySet'
              element_name = lv_name
              attributes   = lv_entity_type ) TO rs_result-entity_sets.
          ENDIF.

        WHEN 'Association'.
          IF lv_name IS NOT INITIAL.
            APPEND VALUE ty_element(
              element_type = 'Association'
              element_name = lv_name ) TO rs_result-associations.
          ENDIF.

        WHEN 'ComplexType'.
          IF lv_name IS NOT INITIAL.
            APPEND VALUE ty_element(
              element_type = 'ComplexType'
              element_name = lv_name ) TO rs_result-complex_types.
          ENDIF.

        WHEN 'FunctionImport'.
          IF lv_name IS NOT INITIAL.
            DATA(lv_return) = lo_el->get_attribute( 'ReturnType' ).
            APPEND VALUE ty_element(
              element_type = 'FunctionImport'
              element_name = lv_name
              attributes   = lv_return ) TO rs_result-function_imports.
          ENDIF.

        WHEN 'Action'.
          IF lv_name IS NOT INITIAL.
            APPEND VALUE ty_element(
              element_type = 'Action'
              element_name = lv_name ) TO rs_result-actions.
          ENDIF.

        WHEN 'Annotation' OR 'Annotations'.
          DATA(lv_target) = lo_el->get_attribute( 'Target' ).
          IF lv_target IS NOT INITIAL.
            APPEND VALUE ty_element(
              element_type = 'Annotation'
              element_name = lv_target ) TO rs_result-annotations.
          ENDIF.

      ENDCASE.

      lo_node = lo_iter->get_next( ).
    ENDWHILE.
  ENDMETHOD.


  METHOD parse_from_base64.
    " Decode Base64 → XML string → parse
    DATA lv_xml TYPE string.
    TRY.
        lv_xml = zcl_odata_base64_helper=>base64_to_xml( iv_base64 ).
      CATCH cx_sy_conversion_codepage.
        zcx_gsu26gsp09=>raise_invalid_input( iv_field = 'BASE64' ).
    ENDTRY.

    rs_result = parse_metadata( lv_xml ).
  ENDMETHOD.


  METHOD parse_entity_children.
    " Duyệt children của EntityType node
    DATA lo_ci TYPE REF TO if_ixml_node_iterator.
    DATA lo_ch TYPE REF TO if_ixml_node.

    lo_ci = io_entity_node->create_iterator( ).
    lo_ch = lo_ci->get_next( ).

    WHILE lo_ch IS NOT INITIAL.
      IF lo_ch->get_type( ) <> if_ixml_node=>co_node_element.
        lo_ch = lo_ci->get_next( ).
        CONTINUE.
      ENDIF.

      DATA(lo_child) = CAST if_ixml_element( lo_ch ).
      DATA(lv_cname) = lo_ch->get_name( ).
      DATA(lv_pname) = lo_child->get_attribute( 'Name' ).

      IF lv_cname = 'Property' AND lv_pname IS NOT INITIAL.
        DATA(lv_type)      = lo_child->get_attribute( 'Type' ).
        DATA(lv_maxlen)    = lo_child->get_attribute( 'MaxLength' ).
        DATA(lv_precision) = lo_child->get_attribute( 'Precision' ).

        DATA lv_attrs TYPE string.
        IF lv_maxlen IS NOT INITIAL.
          lv_attrs = |Type:{ lv_type } MaxLength:{ lv_maxlen }|.
        ELSEIF lv_precision IS NOT INITIAL.
          lv_attrs = |Type:{ lv_type } Precision:{ lv_precision }|.
        ELSE.
          lv_attrs = |Type:{ lv_type }|.
        ENDIF.

        APPEND VALUE ty_element(
          element_type = 'Property'
          element_name = lv_pname
          parent_name  = iv_entity_name
          attributes   = lv_attrs ) TO ct_properties.

      ELSEIF lv_cname = 'NavigationProperty' AND lv_pname IS NOT INITIAL.
        DATA(lv_to_type) = lo_child->get_attribute( 'Type' ).
        APPEND VALUE ty_element(
          element_type = 'NavigationProperty'
          element_name = lv_pname
          parent_name  = iv_entity_name
          attributes   = lv_to_type ) TO ct_nav_props.
      ENDIF.

      lo_ch = lo_ci->get_next( ).
    ENDWHILE.
  ENDMETHOD.


  METHOD get_attribute.
    " Extract attribute value từ XML line string
    DATA lv_search TYPE string.
    DATA lv_pos    TYPE i.

    lv_search = |{ iv_attr_name }="|.
    FIND lv_search IN iv_xml_line MATCH OFFSET lv_pos.
    IF sy-subrc <> 0. RETURN. ENDIF.

    lv_pos = lv_pos + strlen( lv_search ).
    DATA lv_rest TYPE string.
    lv_rest = iv_xml_line+lv_pos.

    DATA lv_j TYPE i VALUE 0.
    DATA lv_len TYPE i.
    lv_len = strlen( lv_rest ).
    WHILE lv_j < lv_len.
      IF lv_rest+lv_j(1) = '"'. EXIT. ENDIF.
      lv_j += 1.
    ENDWHILE.

    IF lv_j > 0.
      rv_value = lv_rest(lv_j).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
