CLASS zcl_odata_auth_helper DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      gc_role_team_lead TYPE agr_name VALUE 'Z_ODATA_TEAM_LEAD',
      gc_role_dev       TYPE agr_name VALUE 'Z_ODATA_DEV',
      gc_role_auditor   TYPE agr_name VALUE 'Z_ODATA_AUDITOR',
      gc_role_viewer    TYPE agr_name VALUE 'Z_ODATA_VIEWER'.

    " Check user có 1 trong các roles không
    CLASS-METHODS check_roles
      IMPORTING it_roles          TYPE string_table
      RETURNING VALUE(rv_allowed) TYPE abap_bool.

    " Check và raise exception nếu không có quyền
    CLASS-METHODS check_or_raise
      IMPORTING it_roles TYPE string_table
      RAISING   zcx_gsu26gsp09.

    " Lấy tất cả roles của current user
    CLASS-METHODS get_user_roles
      RETURNING VALUE(rt_roles) TYPE string_table.

ENDCLASS.


CLASS zcl_odata_auth_helper IMPLEMENTATION.

  METHOD check_roles.
    rv_allowed = abap_false.

    LOOP AT it_roles ASSIGNING FIELD-SYMBOL(<role>).
      DATA(lv_role) = CONV agr_name( <role> ).

      SELECT SINGLE uname
        FROM agr_users
        WHERE uname    = @sy-uname
          AND agr_name = @lv_role
          AND from_dat <= @sy-datum
          AND to_dat   >= @sy-datum
        INTO @DATA(lv_found).

      IF sy-subrc = 0.
        rv_allowed = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD check_or_raise.
    IF check_roles( it_roles ) = abap_false.
      zcx_gsu26gsp09=>raise_no_permission( ).
    ENDIF.
  ENDMETHOD.


  METHOD get_user_roles.
    SELECT agr_name
      FROM agr_users
      WHERE uname    = @sy-uname
        AND from_dat <= @sy-datum
        AND to_dat   >= @sy-datum
      INTO TABLE @DATA(lt_agr).

    LOOP AT lt_agr ASSIGNING FIELD-SYMBOL(<agr>).
      APPEND CONV string( <agr>-agr_name ) TO rt_roles.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
