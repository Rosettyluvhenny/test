REPORT ztest_meta_engine.

START-OF-SELECTION.

  WRITE: / '=== TEST METADATA ENGINE AVAILABILITY ==='.
  WRITE: /.

  DATA lt_classes TYPE string_table.
  APPEND '/IWFND/CL_SODATA_EDM_PROVIDER'    TO lt_classes.
  APPEND '/IWFND/CL_MED_SRV_RUNTIME'        TO lt_classes.
  APPEND '/IWFND/CL_SODATA_SERV_RUNTIME'    TO lt_classes.
  APPEND '/IWXBE/CL_V4_METADATA_FACTORY'    TO lt_classes.
  APPEND '/IWNGW/CL_MED_CORE_FACTORY'       TO lt_classes.
  APPEND '/IWFND/CL_V4_MED_ENG_FACAD'       TO lt_classes.
  APPEND '/IWFND/CL_SODATA_EDM_V4_PROVIDER' TO lt_classes.
  APPEND '/IWBEP/CL_V4_PM_MODEL_PROVIDER'   TO lt_classes.
  APPEND '/IWBEP/CL_CP_MGW_MED_ENGINE'      TO lt_classes.

  LOOP AT lt_classes ASSIGNING FIELD-SYMBOL(<cls>).

    " Dùng seoclsname type — đúng với field clsname trong seoclass
    DATA lv_clsname TYPE seoclsname.
    lv_clsname = <cls>.

    SELECT SINGLE clsname
      FROM seoclass
      WHERE clsname = @lv_clsname
      INTO @DATA(lv_result).

    IF sy-subrc = 0.
      WRITE: / '  [OK]', <cls>.
    ELSE.
      WRITE: / '  [--]', <cls>.
    ENDIF.

  ENDLOOP.

  WRITE: /.
  WRITE: / '=== CHECK COMPLETE ==='.
