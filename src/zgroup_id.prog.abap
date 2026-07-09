*&---------------------------------------------------------------------*
*& Report zgroup_id
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zgroup_id.

 DATA :  mv_system_alias      TYPE /iwfnd/if_v4_routing_types=>ty_e_system_alias,
         mv_group_id type /iwfnd/v4_med_group_id value 'ZUI_FLIGHT_257_V4',
         mo_routing_config TYPE REF to  /iwfnd/cl_v4_routing_config,
         mo_publishing_config   TYPE REF TO /iwfnd/cl_v4_publishing_config.

TYPES BEGIN OF ty_s_service_detail.
INCLUDE TYPE /iwfnd/if_v4_publishing_types=>ty_s_bep_service_info.
TYPES   change_date  TYPE d.
TYPES   change_time  TYPE t.
TYPES   line_no      TYPE i.
TYPES END OF ty_s_service_detail.
TYPES:
  ty_t_service_detail TYPE STANDARD TABLE OF ty_s_service_detail WITH DEFAULT KEY.

DATA mt_service_detail    TYPE ty_t_service_detail.

  DATA: lv_line_no        TYPE i,
        lt_bep_group_info TYPE /iwfnd/if_v4_publishing_types=>ty_t_bep_group_info,
        ls_service_detail TYPE ty_s_service_detail,
        lx_gateway        TYPE REF TO /iwfnd/cx_gateway.

  FIELD-SYMBOLS: <ls_bep_group_info>   TYPE /iwfnd/if_v4_publishing_types=>ty_s_bep_group_info,
                 <ls_bep_service_info> TYPE /iwfnd/if_v4_publishing_types=>ty_s_bep_service_info.

  CLEAR mt_service_detail.
  mo_publishing_config = /iwfnd/cl_v4_publishing_config=>get_instance( ).
  mo_routing_config = /iwfnd/cl_v4_routing_config=>get_instance( ).
  TRY.
  DATA(lt_assignments) = mo_routing_config->get_group_assignments( iv_group_id = mv_group_id ).
  mv_system_alias = lt_assignments[ 1 ]-system_alias.
  CATCH  /IWFND/CX_V4_ROUTING INTO DATA(ex).
    WRITE: / ex->get_exception_text( ).
  ENDTRY.
  IF mv_system_alias IS INITIAL OR mv_group_id IS INITIAL. RETURN. ENDIF.

  TRY.
      mo_publishing_config->get_bep_groups(
        EXPORTING
          iv_system_alias   = mv_system_alias
          iv_group_id       = mv_group_id
        IMPORTING
          et_bep_group_info = lt_bep_group_info
      ).
    CATCH /iwfnd/cx_gateway INTO lx_gateway.
      MESSAGE lx_gateway->get_text_of_root( ) TYPE 'I' DISPLAY LIKE 'E'.
      RETURN.
  ENDTRY.

  READ TABLE lt_bep_group_info ASSIGNING <ls_bep_group_info> INDEX 1.
  IF sy-subrc <> 0. RETURN. ENDIF.

  LOOP AT <ls_bep_group_info>-t_service_info ASSIGNING <ls_bep_service_info>.
    MOVE-CORRESPONDING <ls_bep_service_info> TO ls_service_detail.
    /iwfnd/cl_v4_config_utils=>convert_to_local_time(
      EXPORTING
        iv_timestamp  = ls_service_detail-changed_ts
      IMPORTING
        ev_local_date = ls_service_detail-change_date
        ev_local_time = ls_service_detail-change_time
    ).
    ls_service_detail-line_no = lv_line_no = lv_line_no + 1.
    APPEND ls_service_detail TO mt_service_detail.
  ENDLOOP.

  LOOP AT mt_service_detail into DATA(ls_detail).
    WRITE:/ ls_detail-service_id , ls_detail-repository_id, ls_detail-service_version.
  ENDLOOP.
