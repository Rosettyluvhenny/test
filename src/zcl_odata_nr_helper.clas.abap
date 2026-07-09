CLASS zcl_odata_nr_helper DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-METHODS get_next_version_id
      RETURNING VALUE(rv_id) TYPE zodata_ver
      RAISING   cx_number_ranges.

    CLASS-METHODS get_next_log_id
      RETURNING VALUE(rv_id) TYPE zodata_ver
      RAISING   cx_number_ranges.

  PRIVATE SECTION.

    CLASS-METHODS get_next_number
      IMPORTING iv_object      TYPE char10
                iv_range_nr    TYPE char02 DEFAULT '01'
      RETURNING VALUE(rv_id)   TYPE zodata_ver
      RAISING   cx_number_ranges.

ENDCLASS.


CLASS zcl_odata_nr_helper IMPLEMENTATION.

  METHOD get_next_version_id.
    rv_id = get_next_number(
      iv_object   = 'ZODATA_VER'
      iv_range_nr = '01' ).
  ENDMETHOD.

  METHOD get_next_log_id.
    rv_id = get_next_number(
      iv_object   = 'ZODATA_LOG'
      iv_range_nr = '01' ).
  ENDMETHOD.

  METHOD get_next_number.
    DATA lv_number TYPE char20.

    CALL FUNCTION 'NUMBER_GET_NEXT'
      EXPORTING
        nr_range_nr             = iv_range_nr
        object                  = iv_object
      IMPORTING
        number                  = lv_number
      EXCEPTIONS
        interval_not_found      = 1
        number_range_not_intern = 2
        object_not_found        = 3
        quantity_is_0           = 4
        quantity_is_not_1       = 5
        interval_overflow       = 6
        buffer_overflow         = 7
        OTHERS                  = 8.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE cx_number_ranges
        MESSAGE e001(00) WITH iv_object sy-subrc.
    ENDIF.

    rv_id = lv_number.
  ENDMETHOD.

ENDCLASS.
