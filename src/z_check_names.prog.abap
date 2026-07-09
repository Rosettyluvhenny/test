REPORT z_check_names.

" Kiểm tra tên table versions
SELECT SINGLE * FROM dd02l
  WHERE tabname LIKE 'Z%VERSION%'
    AND as4local = 'A'
  INTO @DATA(ls_tab).
WRITE: / 'Table versions:', ls_tab-tabname.

" Kiểm tra fields của table đó
SELECT * FROM dd03l
  WHERE tabname = @ls_tab-tabname
    AND as4local = 'A'
  INTO TABLE @DATA(lt_fields).
LOOP AT lt_fields INTO DATA(ls_f).
  WRITE: / '  Field:', ls_f-fieldname, 'Type:', ls_f-domname.
ENDLOOP.

" Kiểm tra method signature của ZCL_ODATA_META_ENGINE
SELECT * FROM seocompo
  WHERE clsname = 'ZCL_ODATA_META_ENGINE'
  INTO TABLE @DATA(lt_methods).
LOOP AT lt_methods INTO DATA(ls_m).
  WRITE: / '  Method:', ls_m-cmpname.
ENDLOOP.
