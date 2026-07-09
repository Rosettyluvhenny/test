*&---------------------------------------------------------------------*
*& Report z_test_class_tun
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT z_test_class_tun.

START-OF-SELECTION.
  DATA(lo_inspector) = NEW zcl_gp9_metadata_provider( ).
  lo_inspector->run(  ).
