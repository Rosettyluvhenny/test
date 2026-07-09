CLASS zcx_gsu26gsp09 DEFINITION
PUBLIC
INHERITING FROM cx_static_check
FINAL
CREATE PUBLIC.

PUBLIC SECTION.


DATA mv_service_id   TYPE string READ-ONLY.
DATA mv_service_name TYPE string READ-ONLY.
DATA mv_odata_type   TYPE string READ-ONLY.
DATA mv_field        TYPE string READ-ONLY.
DATA mv_version_id   TYPE string READ-ONLY.
DATA mv_detail       TYPE string READ-ONLY.

METHODS constructor
  IMPORTING
    iv_service_id   TYPE string OPTIONAL
    iv_service_name TYPE string OPTIONAL
    iv_odata_type   TYPE string OPTIONAL
    iv_field        TYPE string OPTIONAL
    iv_version_id   TYPE string OPTIONAL
    iv_detail       TYPE string OPTIONAL.

CLASS-METHODS raise_no_permission
  RAISING zcx_gsu26gsp09.

CLASS-METHODS raise_invalid_input
  IMPORTING iv_field TYPE string
  RAISING zcx_gsu26gsp09.

CLASS-METHODS raise_service_not_active
  IMPORTING iv_service_id TYPE string
  RAISING zcx_gsu26gsp09.

CLASS-METHODS raise_service_not_found
  IMPORTING
    iv_service_name TYPE string
    iv_odata_type   TYPE string
  RAISING zcx_gsu26gsp09.

CLASS-METHODS raise_insert_version_failed
  IMPORTING iv_version_id TYPE string
  RAISING zcx_gsu26gsp09.

CLASS-METHODS raise_update_registry_failed
  IMPORTING iv_service_id TYPE string
  RAISING zcx_gsu26gsp09.

CLASS-METHODS raise_meta_fetch_failed
  IMPORTING
    iv_service_name TYPE string
    iv_odata_type   TYPE string
    iv_detail       TYPE string
  RAISING zcx_gsu26gsp09.

CLASS-METHODS raise_base64_failed
  IMPORTING
    iv_direction TYPE string
    iv_context   TYPE string
  RAISING zcx_gsu26gsp09.

CLASS-METHODS raise_audit_log_failed
  IMPORTING iv_service_id TYPE string
  RAISING zcx_gsu26gsp09.

CLASS-METHODS raise_version_not_found
  IMPORTING iv_version_id TYPE string
  RAISING zcx_gsu26gsp09.

CLASS-METHODS raise_compare_failed
  IMPORTING
    iv_base_version    TYPE string
    iv_compare_version TYPE string
  RAISING zcx_gsu26gsp09.

CLASS-METHODS raise_nr_exhausted
  IMPORTING iv_nr_object TYPE string
  RAISING zcx_gsu26gsp09.

CLASS-METHODS raise_scheduler_failed
  IMPORTING
    iv_service_id TYPE string
    iv_reason     TYPE string
  RAISING zcx_gsu26gsp09.


ENDCLASS.

CLASS zcx_gsu26gsp09 IMPLEMENTATION.

METHOD constructor ##ADT_SUPPRESS_GENERATION.


super->constructor( ).

mv_service_id   = iv_service_id.
mv_service_name = iv_service_name.
mv_odata_type   = iv_odata_type.
mv_field        = iv_field.
mv_version_id   = iv_version_id.
mv_detail       = iv_detail.


ENDMETHOD.

METHOD raise_no_permission.


RAISE EXCEPTION TYPE zcx_gsu26gsp09
  EXPORTING
    iv_detail = |User { sy-uname } is not authorized (no active role)|.


ENDMETHOD.

METHOD raise_invalid_input.


RAISE EXCEPTION TYPE zcx_gsu26gsp09
  EXPORTING
    iv_field  = iv_field
    iv_detail = |Invalid input: { iv_field }|.


ENDMETHOD.

METHOD raise_service_not_active.


RAISE EXCEPTION TYPE zcx_gsu26gsp09
  EXPORTING
    iv_service_id = iv_service_id
    iv_detail     = |Service { iv_service_id } is not ACTIVE|.


ENDMETHOD.

METHOD raise_service_not_found.


RAISE EXCEPTION TYPE zcx_gsu26gsp09
  EXPORTING
    iv_service_name = iv_service_name
    iv_odata_type   = iv_odata_type
    iv_detail       = |Service { iv_service_name } (type { iv_odata_type }) not found|.


ENDMETHOD.

METHOD raise_insert_version_failed.


RAISE EXCEPTION TYPE zcx_gsu26gsp09
  EXPORTING
    iv_version_id = iv_version_id
    iv_detail     = |Failed to insert version { iv_version_id }|.


ENDMETHOD.

METHOD raise_update_registry_failed.


RAISE EXCEPTION TYPE zcx_gsu26gsp09
  EXPORTING
    iv_service_id = iv_service_id
    iv_detail     = |Failed to update registry for service { iv_service_id }|.


ENDMETHOD.

METHOD raise_meta_fetch_failed.


RAISE EXCEPTION TYPE zcx_gsu26gsp09
  EXPORTING
    iv_service_name = iv_service_name
    iv_odata_type   = iv_odata_type
    iv_detail       = iv_detail.


ENDMETHOD.

METHOD raise_base64_failed.

RAISE EXCEPTION TYPE zcx_gsu26gsp09
  EXPORTING
    iv_detail = |{ iv_direction } failed: { iv_context }|.


ENDMETHOD.

METHOD raise_audit_log_failed.


RAISE EXCEPTION TYPE zcx_gsu26gsp09
  EXPORTING
    iv_service_id = iv_service_id
    iv_detail     = |Failed to write audit log|.


ENDMETHOD.

METHOD raise_version_not_found.


RAISE EXCEPTION TYPE zcx_gsu26gsp09
  EXPORTING
    iv_version_id = iv_version_id
    iv_detail     = |Version { iv_version_id } not found|.


ENDMETHOD.

METHOD raise_compare_failed.


RAISE EXCEPTION TYPE zcx_gsu26gsp09
  EXPORTING
    iv_detail =
      |Comparison between version { iv_base_version } and { iv_compare_version } failed|.


ENDMETHOD.

METHOD raise_nr_exhausted.


RAISE EXCEPTION TYPE zcx_gsu26gsp09
  EXPORTING
    iv_detail = |Number range { iv_nr_object } exhausted|.


ENDMETHOD.

METHOD raise_scheduler_failed.


RAISE EXCEPTION TYPE zcx_gsu26gsp09
  EXPORTING
    iv_service_id = iv_service_id
    iv_detail     = |Auto scheduler failed: { iv_reason }|.


ENDMETHOD.

ENDCLASS.

