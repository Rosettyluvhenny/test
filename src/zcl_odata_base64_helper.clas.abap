CLASS zcl_odata_base64_helper DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-METHODS xml_to_base64
      IMPORTING iv_xml            TYPE string
      RETURNING VALUE(rv_base64)  TYPE string
      RAISING   cx_sy_conversion_codepage.

    CLASS-METHODS base64_to_xml
      IMPORTING iv_base64       TYPE string
      RETURNING VALUE(rv_xml)   TYPE string
      RAISING   cx_sy_conversion_codepage.

ENDCLASS.


CLASS zcl_odata_base64_helper IMPLEMENTATION.

  METHOD xml_to_base64.
    DATA lv_xstring TYPE xstring.

    " Bước 1: string → XSTRING (UTF-8)
    TRY.
        lv_xstring = cl_abap_codepage=>convert_to(
          source   = iv_xml
          codepage = `UTF-8` ).
      CATCH cx_parameter_invalid_range
            cx_sy_codepage_converter_init
            cx_sy_conversion_codepage.
        RAISE EXCEPTION NEW cx_sy_conversion_codepage( ).
    ENDTRY.

    " Bước 2: XSTRING → Base64
    rv_base64 = cl_http_utility=>encode_x_base64( lv_xstring ).

    " Bỏ newline SAP tự thêm
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline
      IN rv_base64 WITH ''.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf
      IN rv_base64 WITH ''.
    rv_base64 = condense( val = rv_base64 ).
  ENDMETHOD.


  METHOD base64_to_xml.
    DATA lv_xstring TYPE xstring.
    DATA lv_base64  TYPE string.

    " Normalize Base64 input
    lv_base64 = iv_base64.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>newline
      IN lv_base64 WITH ''.
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf
      IN lv_base64 WITH ''.
    lv_base64 = condense( val = lv_base64 ).

    " Bước 1: Base64 → XSTRING
    lv_xstring = cl_http_utility=>decode_x_base64( lv_base64 ).

    IF lv_xstring IS INITIAL.
      RAISE EXCEPTION NEW cx_sy_conversion_codepage( ).
    ENDIF.

    " Bước 2: XSTRING → string (UTF-8)
    TRY.
        rv_xml = cl_abap_codepage=>convert_from(
          source   = lv_xstring
          codepage = `UTF-8` ).
      CATCH cx_parameter_invalid_range
            cx_sy_codepage_converter_init
            cx_sy_conversion_codepage.
        RAISE EXCEPTION NEW cx_sy_conversion_codepage( ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
