REPORT ztest_audit_helper.

START-OF-SELECTION.

  WRITE: / '=== TEST ZCL_ODATA_AUDIT_HELPER ==='.
  WRITE: /.

  " Test 1: REGISTER
  WRITE: / 'Test 1: REGISTER'.
  zcl_odata_audit_helper=>write_log(
    iv_service_id  = 'ZSALES_SRV'
    iv_action_type = zcl_odata_audit_helper=>gc_action_register
    iv_result      = zcl_odata_audit_helper=>gc_result_success
    iv_remarks     = 'Service registered successfully' ).
  WRITE: / '  [OK]'.

  " Test 2: CREATE_VERSION
  WRITE: / 'Test 2: CREATE_VERSION'.
  zcl_odata_audit_helper=>write_log(
    iv_service_id  = 'ZSALES_SRV'
    iv_snapshot_id = 'SNAP001'
    iv_action_type = zcl_odata_audit_helper=>gc_action_create_version
    iv_result      = zcl_odata_audit_helper=>gc_result_success
    iv_remarks     = 'Version created successfully' ).
  WRITE: / '  [OK]'.

  " Test 3: ERROR
  WRITE: / 'Test 3: ERROR'.
  zcl_odata_audit_helper=>write_log(
    iv_service_id  = 'ZSALES_SRV'
    iv_action_type = zcl_odata_audit_helper=>gc_action_create_version
    iv_result      = zcl_odata_audit_helper=>gc_result_error
    iv_remarks     = 'Metadata engine not available' ).
  WRITE: / '  [OK]'.

  " Verify từ DB
  WRITE: /.
  WRITE: / 'Verify from DB:'.
  SELECT log_id, action_type, actor, actor_role, remarks
    FROM zodata_audit_log
    WHERE service_id = 'ZSALES_SRV'
    ORDER BY action_at
    INTO TABLE @DATA(lt_logs).

  LOOP AT lt_logs ASSIGNING FIELD-SYMBOL(<log>).
    WRITE: / '  ID:', <log>-log_id(8),
             '| Action:', <log>-action_type,
             '| Actor:', <log>-actor,
             '| Result:', <log>-actor_role,
             '| Remarks:', <log>-remarks(30).
  ENDLOOP.

  WRITE: /.
  WRITE: / '=== TEST COMPLETE ==='.
