REPORT ztest_auth_agr.

START-OF-SELECTION.

  WRITE: / '=== TEST AUTH ==='.
  WRITE: / 'User:', sy-uname.
  WRITE: /.

  " Lấy roles
  DATA(lt_roles) = zcl_odata_auth_helper=>get_user_roles( ).
  WRITE: / 'Current roles:'.
  IF lt_roles IS INITIAL.
    WRITE: / '  No roles assigned'.
  ELSE.
    LOOP AT lt_roles ASSIGNING FIELD-SYMBOL(<r>).
      WRITE: / ' ', <r>.
    ENDLOOP.
  ENDIF.
  WRITE: /.

  " Check createVersion permission
  WRITE: / 'Check createVersion (DEV or TEAM_LEAD):'.
  DATA lt_check TYPE string_table.
  APPEND zcl_odata_auth_helper=>gc_role_dev       TO lt_check.
  APPEND zcl_odata_auth_helper=>gc_role_team_lead TO lt_check.

  DATA(lv_allowed) = zcl_odata_auth_helper=>check_roles( lt_check ).
  IF lv_allowed = abap_true.
    WRITE: / '  [OK] Allowed'.
  ELSE.
    WRITE: / '  [DENIED] Not allowed'.
  ENDIF.

  WRITE: / '=== DONE ==='.
