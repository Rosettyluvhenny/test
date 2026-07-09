*CLASS zcl_test_parser DEFINITION
*  PUBLIC
*  FINAL
*  CREATE PUBLIC.
*
*  PUBLIC SECTION.
*
*    TYPES:
*      BEGIN OF ty_attr,
*        name  TYPE string,
*        value TYPE string,
*      END OF ty_attr,
*      tt_attr TYPE STANDARD TABLE OF ty_attr WITH DEFAULT KEY,
*
*      " ── Canonical, LOSSLESS metadata node ───────────────────────
*      " Every element in the source XML gets a node, regardless of
*      " tag name or whether it carries a Name/Alias attribute.
*      " node_path is positional (index chain), not semantic - it's
*      " only for debugging/traceability, NOT identity.
*      BEGIN OF ty_node,
*        node_id    TYPE string,
*        parent_id  TYPE string,
*        node_path  TYPE string,      " positional, e.g. "0/2/1"
*        node_type  TYPE string,      " raw tag name
*        node_name  TYPE string,      " Name attr if present, else blank
*        node_alias TYPE string,      " Alias attr if present, else blank
*        seq        TYPE i,           " global document order
*        depth      TYPE i,
*        children   TYPE string_table,
*        attributes TYPE tt_attr,
*      END OF ty_node,
*      tt_node TYPE STANDARD TABLE OF ty_node WITH DEFAULT KEY,
*
*      BEGIN OF ty_tree,
*        nodes         TYPE tt_node,
*        root_ids      TYPE string_table,
*        odata_version TYPE string,
*      END OF ty_tree,
*
*      " Internal recursion result: the id assigned to the element
*      " itself, plus the flat list of itself + all its descendants,
*      " in document order. Used only to avoid a CHANGING parameter.
*      BEGIN OF ty_build_result,
*        node_id TYPE string,
*        nodes   TYPE tt_node,
*      END OF ty_build_result.
*
*    "! Builds the COMPLETE tree - no tag whitelist, no Name requirement.
*    CLASS-METHODS parse
*      IMPORTING iv_xml           TYPE string
*                iv_odata_version TYPE string DEFAULT 'V2'
*      RETURNING VALUE(rs_tree)   TYPE ty_tree
*      RAISING   zcx_gsu26gsp09.
*
*    "! Separate, explicit filtering step - operates on an already
*    "! parsed tree. Pass empty string for a criterion to skip it.
*    CLASS-METHODS filter_by
*      IMPORTING is_tree          TYPE ty_tree
*                iv_name          TYPE string OPTIONAL
*                iv_alias         TYPE string OPTIONAL
*                iv_node_type     TYPE string OPTIONAL
*      RETURNING VALUE(rt_nodes)  TYPE tt_node.
*
*    CLASS-METHODS get_attr_value
*      IMPORTING is_node         TYPE ty_node
*                iv_attr_name    TYPE string
*      RETURNING VALUE(rv_value) TYPE string.
*
*    CLASS-METHODS get_children
*      IMPORTING is_tree         TYPE ty_tree
*                iv_node_id      TYPE string
*      RETURNING VALUE(rt_nodes) TYPE tt_node.
*
*    CLASS-METHODS serialize_attrs
*      IMPORTING it_attrs       TYPE tt_attr
*      RETURNING VALUE(rv_str)  TYPE string.
*
*    CLASS-METHODS render_node_json
*      IMPORTING is_tree        TYPE ty_tree
*                iv_node_id     TYPE string
*      RETURNING VALUE(rv_json) TYPE string.
*  PRIVATE SECTION.
*
*    CLASS-DATA gv_seq TYPE i.
*
*    CLASS-METHODS xml_to_xstring
*      IMPORTING iv_xml         TYPE string
*      RETURNING VALUE(rv_xstr) TYPE xstring.
*
*    CLASS-METHODS read_all_attributes
*      IMPORTING io_el            TYPE REF TO if_ixml_element
*      RETURNING VALUE(rt_attrs)  TYPE tt_attr.
*
*    "! Recursively builds the node for io_el and all its descendants.
*    "! Returns io_el's own node_id plus the flat, document-ordered
*    "! list of [self + every descendant] - no CHANGING parameter,
*    "! caller/recursion composes results by simple concatenation.
*    CLASS-METHODS build_node
*      IMPORTING io_el          TYPE REF TO if_ixml_element
*                iv_parent_id   TYPE string
*                iv_parent_path TYPE string
*                iv_depth       TYPE i
*      RETURNING VALUE(rs_result) TYPE ty_build_result.
*
*    CLASS-METHODS next_node_id
*      RETURNING VALUE(rv_id) TYPE string.
*
*      CLASS-METHODS serialize_attrs_json
*  IMPORTING it_attrs       TYPE tt_attr
*  RETURNING VALUE(rv_json) TYPE string.
*
*ENDCLASS.
*
*
*CLASS zcl_test_parser IMPLEMENTATION.
*
*  METHOD parse.
*    rs_tree-odata_version = iv_odata_version.
*
*    DATA(lv_xstr) = xml_to_xstring( iv_xml ).
*    IF lv_xstr IS INITIAL.
*      RAISE EXCEPTION TYPE zcx_gsu26gsp09
*        EXPORTING iv_detail = 'XML content is empty'.
*    ENDIF.
*
*    DATA(lo_ixml)   = cl_ixml=>create( ).
*    DATA(lo_doc)    = lo_ixml->create_document( ).
*    DATA(lo_sf)     = lo_ixml->create_stream_factory( ).
*    DATA(lo_in)     = lo_sf->create_istream_xstring( string = lv_xstr ).
*    DATA(lo_parser) = lo_ixml->create_parser(
*      stream_factory = lo_sf
*      istream        = lo_in
*      document       = lo_doc ).
*
*    IF lo_parser->parse( ) <> 0.
*      DATA(lv_detail) = |XML parse error in zcl_xml_parser_n|.
*      IF lo_parser->num_errors( ) > 0.
*        DATA(lo_err) = lo_parser->get_error( 0 ).
*        lv_detail = |{ lv_detail }: { lo_err->get_reason( ) }| &&
*                    | (Line { lo_err->get_line( ) }, Col { lo_err->get_column( ) })|.
*      ENDIF.
*      RAISE EXCEPTION TYPE zcx_gsu26gsp09
*        EXPORTING iv_detail = lv_detail.
*    ENDIF.
*
*    CLEAR gv_seq.
*
*    DATA(lo_root) = lo_doc->get_root_element( ).
*    IF lo_root IS NOT INITIAL.
*      DATA(ls_result) = build_node(
*        io_el          = lo_root
*        iv_parent_id   = ''
*        iv_parent_path = ''
*        iv_depth       = 0 ).
*
*      rs_tree-nodes = ls_result-nodes.
*      APPEND ls_result-node_id TO rs_tree-root_ids.
*    ENDIF.
*  ENDMETHOD.
*
*
*  METHOD build_node.
*    DATA(lv_own_id)  = next_node_id( ).
*    DATA(lv_ntype)   = io_el->get_name( ).
*    DATA(lv_ename)   = io_el->get_attribute( 'Name' ).
*    DATA(lv_ealias)  = io_el->get_attribute( 'Alias' ).
*    DATA(lv_own_seq) = gv_seq.
*
*    DATA(lv_own_path) = COND string(
*      WHEN iv_parent_path IS NOT INITIAL
*      THEN |{ iv_parent_path }/{ lv_own_seq }|
*      ELSE |{ lv_own_seq }| ).
*
*    DATA(ls_own_node) = VALUE ty_node(
*      node_id    = lv_own_id
*      parent_id  = iv_parent_id
*      node_path  = lv_own_path
*      node_type  = lv_ntype
*      node_name  = lv_ename
*      node_alias = lv_ealias
*      seq        = lv_own_seq
*      depth      = iv_depth
*      attributes = read_all_attributes( io_el ) ).
*
*    " Recurse into every child ELEMENT, collecting each subtree's
*    " flat node list and wiring child ids into our own node -
*    " everything composed locally, then returned as one flat table.
*    DATA lt_descendant_nodes TYPE tt_node.
*
*    DATA(lo_child) = io_el->get_first_child( ).
*    WHILE lo_child IS NOT INITIAL.
*      IF lo_child->get_type( ) = if_ixml_node=>co_node_element.
*        DATA(ls_child_result) = build_node(
*          io_el          = CAST if_ixml_element( lo_child )
*          iv_parent_id   = lv_own_id
*          iv_parent_path = lv_own_path
*          iv_depth       = iv_depth + 1 ).
*
*        APPEND ls_child_result-node_id TO ls_own_node-children.
*        APPEND LINES OF ls_child_result-nodes TO lt_descendant_nodes.
*      ENDIF.
*      lo_child = lo_child->get_next( ).
*    ENDWHILE.
*
*    " Own node first, then all descendants - keeps rs_result-nodes
*    " in document order (parent always precedes its children).
*    APPEND ls_own_node TO rs_result-nodes.
*    APPEND LINES OF lt_descendant_nodes TO rs_result-nodes.
*
*    rs_result-node_id = lv_own_id.
*  ENDMETHOD.
*
*
*METHOD filter_by.
*  LOOP AT is_tree-nodes INTO DATA(ls_node).
*    IF iv_name IS NOT INITIAL AND ls_node-node_name <> iv_name.
*      CONTINUE.
*    ENDIF.
*    IF iv_alias IS NOT INITIAL AND ls_node-node_alias <> iv_alias.
*      CONTINUE.
*    ENDIF.
*    IF iv_node_type IS NOT INITIAL AND ls_node-node_type <> iv_node_type.
*      CONTINUE.
*    ENDIF.
*    APPEND ls_node TO rt_nodes.
*  ENDLOOP.
*ENDMETHOD.
*
*
*  METHOD get_attr_value.
*    READ TABLE is_node-attributes WITH KEY name = iv_attr_name INTO DATA(ls_attr).
*    IF sy-subrc = 0.
*      rv_value = ls_attr-value.
*    ENDIF.
*  ENDMETHOD.
*
*
*  METHOD get_children.
*    READ TABLE is_tree-nodes WITH KEY node_id = iv_node_id INTO DATA(ls_node).
*    IF sy-subrc = 0.
*      LOOP AT ls_node-children INTO DATA(lv_child_id).
*        READ TABLE is_tree-nodes WITH KEY node_id = lv_child_id INTO DATA(ls_child).
*        IF sy-subrc = 0.
*          APPEND ls_child TO rt_nodes.
*        ENDIF.
*      ENDLOOP.
*    ENDIF.
*  ENDMETHOD.
*
*
*  METHOD next_node_id.
*    gv_seq += 1.
*    rv_id = |N{ gv_seq WIDTH = 5 PAD = '0' ALIGN = RIGHT }|.
*  ENDMETHOD.
*
*
*  METHOD read_all_attributes.
*    DATA(lo_attrs) = io_el->get_attributes( ).
*    IF lo_attrs IS INITIAL.
*      RETURN.
*    ENDIF.
*    DATA(lv_count) = lo_attrs->get_length( ).
*    DO lv_count TIMES.
*      DATA(lo_attr) = lo_attrs->get_item( sy-index - 1 ).
*      IF lo_attr IS NOT INITIAL.
*        APPEND VALUE ty_attr(
*          name  = lo_attr->get_name( )
*          value = lo_attr->get_value( )
*        ) TO rt_attrs.
*      ENDIF.
*    ENDDO.
*  ENDMETHOD.
*
*
*  METHOD xml_to_xstring.
*    TRY.
*        rv_xstr = cl_abap_codepage=>convert_to( source = iv_xml ).
*      CATCH cx_sy_conversion_error.
*        CLEAR rv_xstr.
*    ENDTRY.
*  ENDMETHOD.
*
*METHOD serialize_attrs.
*  DATA(lt_sorted) = it_attrs.
*  SORT lt_sorted BY name ASCENDING.
*
*  LOOP AT lt_sorted INTO DATA(ls_attr).
*    IF rv_str IS NOT INITIAL.
*      rv_str = |{ rv_str } |.
*    ENDIF.
*    rv_str = |{ rv_str }{ ls_attr-name }="{ ls_attr-value }"|.
*  ENDLOOP.
*ENDMETHOD.
*METHOD render_node_json.
*  READ TABLE is_tree-nodes WITH KEY node_id = iv_node_id INTO DATA(ls_node).
*  IF sy-subrc <> 0.
*    RETURN.
*  ENDIF.
*
*  DATA(lv_attrs_json) = serialize_attrs_json( ls_node-attributes ).
*
*  " Recurse into every child, building a JSON array in document order
*  DATA lv_children_json TYPE string.
*  LOOP AT ls_node-children INTO DATA(lv_child_id).
*    DATA(lv_child_json) = render_node_json(
*      is_tree    = is_tree
*      iv_node_id = lv_child_id ).
*
*    IF lv_children_json IS NOT INITIAL.
*      lv_children_json = |{ lv_children_json },|.
*    ENDIF.
*    lv_children_json = |{ lv_children_json }{ lv_child_json }|.
*  ENDLOOP.
*
*  rv_json = |\{| &&
*            |"tag":"{ ls_node-node_type }",| &&
*            |"name":"{ ls_node-node_name }",| &&
*            |"alias":"{ ls_node-node_alias }",| &&
*            |"attributes":\{ { lv_attrs_json } \},| &&
*            |"children":[ { lv_children_json } ]| &&
*            |\}|.
*ENDMETHOD.
*
*METHOD serialize_attrs_json.
*  LOOP AT it_attrs INTO DATA(ls_attr).
*    IF rv_json IS NOT INITIAL.
*      rv_json = |{ rv_json },|.
*    ENDIF.
*    rv_json = |{ rv_json }"{ ls_attr-name }":"{ ls_attr-value }"|.
*  ENDLOOP.
*ENDMETHOD.
*ENDCLASS.

CLASS zcl_test_parser DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_attr,
        name  TYPE string,
        value TYPE string,
      END OF ty_attr,
      tt_attr TYPE STANDARD TABLE OF ty_attr WITH DEFAULT KEY,

      " ── Canonical, LOSSLESS metadata node ───────────────────────
      " Every element in the source XML gets a node, regardless of
      " tag name or whether it carries a Name/Alias/Target attribute.
      "
      " node_id     - technical id (N00001...), used only for
      "               parent/child wiring inside this run.
      " node_path   - positional index chain, debugging only.
      " semantic_id - the STABLE, human-readable route from the
      "               document root, built from Name/Target/Alias.
      "               Two nodes never share the same semantic_id
      "               (see assign_semantic_routes).
      " offset_start/offset_end - character offsets (0-based) into
      "               the ORIGINAL iv_xml string, spanning from the
      "               '<' of the opening tag to the '>' of the
      "               matching closing tag (or of the self-closing
      "               tag itself).
      BEGIN OF ty_node,
        node_id      TYPE string,
        semantic_id  TYPE string,
        parent_id    TYPE string,
        node_path    TYPE string,      " positional, e.g. "0/2/1"
        node_type    TYPE string,      " raw tag name
        node_name    TYPE string,      " Name attr if present, else blank
        node_alias   TYPE string,      " Alias attr if present, else blank
        offset_start TYPE i,
        offset_end   TYPE i,
        seq          TYPE i,           " global document order
        depth        TYPE i,
        children     TYPE string_table,
        attributes   TYPE tt_attr,
      END OF ty_node,
      tt_node TYPE STANDARD TABLE OF ty_node WITH DEFAULT KEY,

      BEGIN OF ty_tree,
        nodes         TYPE tt_node,
        root_ids      TYPE string_table,
        odata_version TYPE string,
      END OF ty_tree,

      " Internal recursion result: the id assigned to the element
      " itself, plus the flat list of itself + all its descendants,
      " in document order. Used only to avoid a CHANGING parameter.
      BEGIN OF ty_build_result,
        node_id TYPE string,
        nodes   TYPE tt_node,
      END OF ty_build_result.

    "! Builds the COMPLETE tree - no tag whitelist, no Name requirement.
    "! Also assigns semantic_id (root-based, de-duplicated) and
    "! offset_start/offset_end (character locator into iv_xml) to
    "! every node.
    CLASS-METHODS parse
      IMPORTING iv_xml           TYPE string
                iv_odata_version TYPE string DEFAULT 'V2'
      RETURNING VALUE(rs_tree)   TYPE ty_tree
      RAISING   zcx_gsu26gsp09.

    "! Separate, explicit filtering step - operates on an already
    "! parsed tree. Pass empty string for a criterion to skip it.
    CLASS-METHODS filter_by
      IMPORTING is_tree          TYPE ty_tree
                iv_name          TYPE string OPTIONAL
                iv_alias         TYPE string OPTIONAL
                iv_node_type     TYPE string OPTIONAL
      RETURNING VALUE(rt_nodes)  TYPE tt_node.

    "! Look a node up by its stable semantic_id, e.g.
    "! '/EntityType[Name=Product]/Property[Name=ID]'
    CLASS-METHODS find_by_semantic_id
      IMPORTING is_tree         TYPE ty_tree
                iv_semantic_id  TYPE string
      RETURNING VALUE(rs_node)  TYPE ty_node.

    CLASS-METHODS get_attr_value
      IMPORTING is_node         TYPE ty_node
                iv_attr_name    TYPE string
      RETURNING VALUE(rv_value) TYPE string.

    CLASS-METHODS get_children
      IMPORTING is_tree         TYPE ty_tree
                iv_node_id      TYPE string
      RETURNING VALUE(rt_nodes) TYPE tt_node.

    CLASS-METHODS serialize_attrs
      IMPORTING it_attrs       TYPE tt_attr
      RETURNING VALUE(rv_str)  TYPE string.

    CLASS-METHODS render_node_json
      IMPORTING is_tree        TYPE ty_tree
                iv_node_id     TYPE string
      RETURNING VALUE(rv_json) TYPE string.

    CLASS-METHODS serialize_attrs_json
      IMPORTING it_attrs       TYPE tt_attr
      RETURNING VALUE(rv_json) TYPE string.
  PRIVATE SECTION.

    CLASS-DATA gv_seq TYPE i.

    " Used only during assign_semantic_routes to guarantee global
    " uniqueness of semantic_id across the whole tree.
    CLASS-DATA gt_used_routes TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.

    CLASS-METHODS xml_to_xstring
      IMPORTING iv_xml         TYPE string
      RETURNING VALUE(rv_xstr) TYPE xstring.

    CLASS-METHODS read_all_attributes
      IMPORTING io_el            TYPE REF TO if_ixml_element
      RETURNING VALUE(rt_attrs)  TYPE tt_attr.

    "! Recursively builds the node for io_el and all its descendants.
    "! Returns io_el's own node_id plus the flat, document-ordered
    "! list of [self + every descendant] - no CHANGING parameter,
    "! caller/recursion composes results by simple concatenation.
    CLASS-METHODS build_node
      IMPORTING io_el          TYPE REF TO if_ixml_element
                iv_parent_id   TYPE string
                iv_parent_path TYPE string
                iv_depth       TYPE i
      RETURNING VALUE(rs_result) TYPE ty_build_result.

    CLASS-METHODS next_node_id
      RETURNING VALUE(rv_id) TYPE string.

    "! Second pass over the already-built flat node list. Because
    "! the list is in document order and a parent always precedes
    "! its children, a single top-to-bottom loop is enough: by the
    "! time we reach a child, its parent's semantic_id is already
    "! set.
    "!
    "! Segment for a node = Tag[Name=x] / Tag[Target=x] / Tag[Alias=x]
    "! (first attribute found wins), or Tag(#n) - an ordinal scoped
    "! to key-less siblings of the same tag under the same parent -
    "! when none of those attributes are present.
    "!
    "! semantic_id = parent's semantic_id & '/' & segment, computed
    "! from the ROOT down, so it is the full absolute route, not a
    "! relative delta. A global de-dup guard (gt_used_routes) then
    "! appends '~2', '~3', ... in the rare case two different nodes
    "! would otherwise compute the exact same route (e.g. duplicate
    "! Name values under the same parent).
    CLASS-METHODS assign_semantic_routes
      CHANGING ct_nodes TYPE tt_node.

    "! Walks the raw XML text once (respecting quoted attribute
    "! values, comments, CDATA and processing instructions) and
    "! fills offset_start/offset_end on every node, matching tags
    "! to nodes via document order (nodes sorted by seq == the
    "! order start-tags appear in the text).
    CLASS-METHODS compute_offsets
      IMPORTING iv_xml    TYPE string
      CHANGING  ct_nodes  TYPE tt_node.

    "! Finds the offset of the next unquoted '>' starting the scan
    "! at iv_from (used for opening/self-closing tags, where '>'
    "! inside a quoted attribute value must be skipped).
    CLASS-METHODS find_tag_end
      IMPORTING iv_xml        TYPE string
                iv_from       TYPE i
      RETURNING VALUE(rv_pos) TYPE i.

ENDCLASS.


CLASS zcl_test_parser IMPLEMENTATION.

  METHOD parse.
    rs_tree-odata_version = iv_odata_version.

    DATA(lv_xstr) = xml_to_xstring( iv_xml ).
    IF lv_xstr IS INITIAL.
      RAISE EXCEPTION TYPE zcx_gsu26gsp09
        EXPORTING iv_detail = 'XML content is empty'.
    ENDIF.

    DATA(lo_ixml)   = cl_ixml=>create( ).
    DATA(lo_doc)    = lo_ixml->create_document( ).
    DATA(lo_sf)     = lo_ixml->create_stream_factory( ).
    DATA(lo_in)     = lo_sf->create_istream_xstring( string = lv_xstr ).
    DATA(lo_parser) = lo_ixml->create_parser(
      stream_factory = lo_sf
      istream        = lo_in
      document       = lo_doc ).

    IF lo_parser->parse( ) <> 0.
      DATA(lv_detail) = |XML parse error in zcl_xml_parser_n|.
      IF lo_parser->num_errors( ) > 0.
        DATA(lo_err) = lo_parser->get_error( 0 ).
        lv_detail = |{ lv_detail }: { lo_err->get_reason( ) }| &&
                    | (Line { lo_err->get_line( ) }, Col { lo_err->get_column( ) })|.
      ENDIF.
      RAISE EXCEPTION TYPE zcx_gsu26gsp09
        EXPORTING iv_detail = lv_detail.
    ENDIF.

    CLEAR gv_seq.

    DATA(lo_root) = lo_doc->get_root_element( ).
    IF lo_root IS NOT INITIAL.
      DATA(ls_result) = build_node(
        io_el          = lo_root
        iv_parent_id   = ''
        iv_parent_path = ''
        iv_depth       = 0 ).

      rs_tree-nodes = ls_result-nodes.
      APPEND ls_result-node_id TO rs_tree-root_ids.
    ENDIF.

    assign_semantic_routes( CHANGING ct_nodes = rs_tree-nodes ).
    compute_offsets( EXPORTING iv_xml = iv_xml CHANGING ct_nodes = rs_tree-nodes ).
  ENDMETHOD.


  METHOD build_node.
    DATA(lv_own_id)  = next_node_id( ).
    DATA(lv_ntype)   = io_el->get_name( ).
    DATA(lv_ename)   = io_el->get_attribute( 'Name' ).
    DATA(lv_ealias)  = io_el->get_attribute( 'Alias' ).
    DATA(lv_own_seq) = gv_seq.

    DATA(lv_own_path) = COND string(
      WHEN iv_parent_path IS NOT INITIAL
      THEN |{ iv_parent_path }/{ lv_own_seq }|
      ELSE |{ lv_own_seq }| ).

    DATA(ls_own_node) = VALUE ty_node(
      node_id    = lv_own_id
      parent_id  = iv_parent_id
      node_path  = lv_own_path
      node_type  = lv_ntype
      node_name  = lv_ename
      node_alias = lv_ealias
      seq        = lv_own_seq
      depth      = iv_depth
      attributes = read_all_attributes( io_el ) ).

    " Recurse into every child ELEMENT, collecting each subtree's
    " flat node list and wiring child ids into our own node -
    " everything composed locally, then returned as one flat table.
    DATA lt_descendant_nodes TYPE tt_node.

    DATA(lo_child) = io_el->get_first_child( ).
    WHILE lo_child IS NOT INITIAL.
      IF lo_child->get_type( ) = if_ixml_node=>co_node_element.
        DATA(ls_child_result) = build_node(
          io_el          = CAST if_ixml_element( lo_child )
          iv_parent_id   = lv_own_id
          iv_parent_path = lv_own_path
          iv_depth       = iv_depth + 1 ).

        APPEND ls_child_result-node_id TO ls_own_node-children.
        APPEND LINES OF ls_child_result-nodes TO lt_descendant_nodes.
      ENDIF.
      lo_child = lo_child->get_next( ).
    ENDWHILE.

    " Own node first, then all descendants - keeps rs_result-nodes
    " in document order (parent always precedes its children).
    APPEND ls_own_node TO rs_result-nodes.
    APPEND LINES OF lt_descendant_nodes TO rs_result-nodes.

    rs_result-node_id = lv_own_id.
  ENDMETHOD.


  METHOD assign_semantic_routes.
    CLEAR gt_used_routes.

    " Ordinal fallback counter, scoped to (parent_id, tag) - only
    " incremented for nodes that have no Name/Target/Alias to key on.
    TYPES: BEGIN OF ty_counter,
             parent_id TYPE string,
             tag       TYPE string,
             cnt       TYPE i,
           END OF ty_counter.
    DATA lt_counters TYPE STANDARD TABLE OF ty_counter WITH KEY parent_id tag.

    LOOP AT ct_nodes ASSIGNING FIELD-SYMBOL(<ls_node>).

      " Parent is guaranteed to already have its semantic_id set,
      " because ct_nodes is in document order (parent before child).
      DATA(lv_parent_sem) = ``.
      IF <ls_node>-parent_id IS NOT INITIAL.
        READ TABLE ct_nodes WITH KEY node_id = <ls_node>-parent_id
          ASSIGNING FIELD-SYMBOL(<ls_parent>).
        IF sy-subrc = 0.
          lv_parent_sem = <ls_parent>-semantic_id.
        ENDIF.
      ENDIF.

      " Priority: Name > Target > Alias.
      DATA(lv_key_kind) = `Name`.
      DATA(lv_key_val)  = get_attr_value( is_node = <ls_node> iv_attr_name = 'Name' ).
      IF lv_key_val IS INITIAL.
        lv_key_kind = `Target`.
        lv_key_val  = get_attr_value( is_node = <ls_node> iv_attr_name = 'Target' ).
      ENDIF.
      IF lv_key_val IS INITIAL.
        lv_key_kind = `Alias`.
        lv_key_val  = get_attr_value( is_node = <ls_node> iv_attr_name = 'Alias' ).
      ENDIF.

      DATA(lv_segment) = ``.
      IF lv_key_val IS NOT INITIAL.
        lv_segment = |{ <ls_node>-node_type }[{ lv_key_kind }={ lv_key_val }]|.
      ELSE.
        READ TABLE lt_counters ASSIGNING FIELD-SYMBOL(<ls_cnt>)
          WITH KEY parent_id = <ls_node>-parent_id tag = <ls_node>-node_type.
        IF sy-subrc = 0.
          <ls_cnt>-cnt = <ls_cnt>-cnt + 1.
        ELSE.
          APPEND VALUE ty_counter(
            parent_id = <ls_node>-parent_id
            tag       = <ls_node>-node_type
            cnt       = 1 ) TO lt_counters.
          READ TABLE lt_counters ASSIGNING <ls_cnt>
            WITH KEY parent_id = <ls_node>-parent_id tag = <ls_node>-node_type.
        ENDIF.
        lv_segment = |{ <ls_node>-node_type }(#{ <ls_cnt>-cnt })|.
      ENDIF.

      " Full absolute route from the root - not a relative delta.
      DATA(lv_route) = COND string(
        WHEN lv_parent_sem IS NOT INITIAL THEN |{ lv_parent_sem }/{ lv_segment }|
        ELSE |/{ lv_segment }| ).

      " Global de-dup guard: guarantees no two nodes in the whole
      " tree ever end up with the same semantic_id, even if two
      " siblings genuinely share the same tag + key value.
      DATA(lv_final)   = lv_route.
      DATA(lv_dup_ctr) = 1.
      WHILE line_exists( gt_used_routes[ table_line = lv_final ] ).
        lv_dup_ctr = lv_dup_ctr + 1.
        lv_final   = |{ lv_route }~{ lv_dup_ctr }|.
      ENDWHILE.
      INSERT lv_final INTO TABLE gt_used_routes.

      <ls_node>-semantic_id = lv_final.
    ENDLOOP.
  ENDMETHOD.


  METHOD compute_offsets.
    DATA(lv_len) = strlen( iv_xml ).
    IF lv_len = 0.
      RETURN.
    ENDIF.

    " Queue of node_ids in document order == the order their
    " opening tags physically appear in iv_xml (seq is assigned in
    " that same order inside build_node).
    DATA(lt_sorted) = ct_nodes.
    SORT lt_sorted BY seq ASCENDING.

    DATA lt_queue TYPE string_table.
    LOOP AT lt_sorted INTO DATA(ls_s).
      APPEND ls_s-node_id TO lt_queue.
    ENDLOOP.

    DATA lt_stack TYPE string_table.
    DATA(lv_idx) = 1.
    DATA(lv_pos) = 0.

    WHILE lv_pos < lv_len.
      IF iv_xml+lv_pos(1) <> '<'.
        lv_pos = lv_pos + 1.
        CONTINUE.
      ENDIF.

      " Comments: <!-- ... -->
      IF lv_pos + 4 <= lv_len AND iv_xml+lv_pos(4) = '<!--'.
        DATA(lv_end) = find( val = iv_xml sub = '-->' off = lv_pos ).
        lv_pos = COND #( WHEN lv_end >= 0 THEN lv_end + 3 ELSE lv_len ).
        CONTINUE.
      ENDIF.

      " CDATA: <![CDATA[ ... ]]>
      IF lv_pos + 9 <= lv_len AND iv_xml+lv_pos(9) = '<![CDATA['.
        lv_end = find( val = iv_xml sub = ']]>' off = lv_pos ).
        lv_pos = COND #( WHEN lv_end >= 0 THEN lv_end + 3 ELSE lv_len ).
        CONTINUE.
      ENDIF.

      " Processing instructions: <? ... ?>
      IF lv_pos + 2 <= lv_len AND iv_xml+lv_pos(2) = '<?'.
        lv_end = find( val = iv_xml sub = '?>' off = lv_pos ).
        lv_pos = COND #( WHEN lv_end >= 0 THEN lv_end + 2 ELSE lv_len ).
        CONTINUE.
      ENDIF.

      " DOCTYPE / other markup declarations: <! ... > (naive - does
      " not handle a bracketed internal subset, acceptable for
      " OData/metadata style documents).
      IF lv_pos + 2 <= lv_len AND iv_xml+lv_pos(2) = '<!'.
        lv_end = find( val = iv_xml sub = '>' off = lv_pos ).
        lv_pos = COND #( WHEN lv_end >= 0 THEN lv_end + 1 ELSE lv_len ).
        CONTINUE.
      ENDIF.
      DATA(lv_next_pos) = lv_pos + 1.
      " Closing tag: </Tag>
      IF lv_next_pos < lv_len AND iv_xml+lv_next_pos(1) = '/'.
        lv_end = find( val = iv_xml sub = '>' off = lv_pos ).
        IF lv_end < 0.
          EXIT.
        ENDIF.
        IF lines( lt_stack ) > 0.
          DATA(lv_close_id) = lt_stack[ lines( lt_stack ) ].
          DELETE lt_stack INDEX lines( lt_stack ).
          READ TABLE ct_nodes ASSIGNING FIELD-SYMBOL(<ls_close>) WITH KEY node_id = lv_close_id.
          IF sy-subrc = 0.
            <ls_close>-offset_end = lv_end.
          ENDIF.
        ENDIF.
        lv_pos = lv_end + 1.
        CONTINUE.
      ENDIF.

      " Opening or self-closing tag: <Tag ...> or <Tag .../>
      " Scan for the matching unquoted '>'.
      lv_end = find_tag_end( iv_xml = iv_xml iv_from = lv_pos ).
      IF lv_end < 0.
        EXIT.
      ENDIF.

      DATA lv_last_pos TYPE i.

      lv_last_pos = lv_end - 1.

      DATA lv_self_closing TYPE abap_bool.
      lv_self_closing = xsdbool( iv_xml+lv_last_pos(1) = '/' ).

      IF lv_idx <= lines( lt_queue ).
        DATA(lv_node_id) = lt_queue[ lv_idx ].
        lv_idx = lv_idx + 1.

        READ TABLE ct_nodes ASSIGNING FIELD-SYMBOL(<ls_open>) WITH KEY node_id = lv_node_id.
        IF sy-subrc = 0.
          <ls_open>-offset_start = lv_pos.
          IF lv_self_closing = abap_true.
            <ls_open>-offset_end = lv_end.
          ELSE.
            APPEND lv_node_id TO lt_stack.
          ENDIF.
        ENDIF.
      ENDIF.

      lv_pos = lv_end + 1.
    ENDWHILE.
  ENDMETHOD.


  METHOD find_tag_end.
    DATA(lv_len)    = strlen( iv_xml ).
    DATA(lv_pos)    = iv_from.
    DATA(lv_quote)  = ``.

    WHILE lv_pos < lv_len.
      DATA(lv_char) = iv_xml+lv_pos(1).

      IF lv_quote IS NOT INITIAL.
        IF lv_char = lv_quote.
          CLEAR lv_quote.
        ENDIF.
      ELSE.
        IF lv_char = '"' OR lv_char = |'|.
          lv_quote = lv_char.
        ELSEIF lv_char = '>'.
          rv_pos = lv_pos.
          RETURN.
        ENDIF.
      ENDIF.

      lv_pos = lv_pos + 1.
    ENDWHILE.

    rv_pos = -1.
  ENDMETHOD.


  METHOD filter_by.
    LOOP AT is_tree-nodes INTO DATA(ls_node).
      IF iv_name IS NOT INITIAL AND ls_node-node_name <> iv_name.
        CONTINUE.
      ENDIF.
      IF iv_alias IS NOT INITIAL AND ls_node-node_alias <> iv_alias.
        CONTINUE.
      ENDIF.
      IF iv_node_type IS NOT INITIAL AND ls_node-node_type <> iv_node_type.
        CONTINUE.
      ENDIF.
      APPEND ls_node TO rt_nodes.
    ENDLOOP.
  ENDMETHOD.


  METHOD find_by_semantic_id.
    READ TABLE is_tree-nodes WITH KEY semantic_id = iv_semantic_id INTO rs_node.
  ENDMETHOD.


  METHOD get_attr_value.
    READ TABLE is_node-attributes WITH KEY name = iv_attr_name INTO DATA(ls_attr).
    IF sy-subrc = 0.
      rv_value = ls_attr-value.
    ENDIF.
  ENDMETHOD.


  METHOD get_children.
    READ TABLE is_tree-nodes WITH KEY node_id = iv_node_id INTO DATA(ls_node).
    IF sy-subrc = 0.
      LOOP AT ls_node-children INTO DATA(lv_child_id).
        READ TABLE is_tree-nodes WITH KEY node_id = lv_child_id INTO DATA(ls_child).
        IF sy-subrc = 0.
          APPEND ls_child TO rt_nodes.
        ENDIF.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.


  METHOD next_node_id.
    gv_seq = gv_seq + 1.
    rv_id = |N{ gv_seq WIDTH = 5 PAD = '0' ALIGN = RIGHT }|.
  ENDMETHOD.


  METHOD read_all_attributes.
    DATA(lo_attrs) = io_el->get_attributes( ).
    IF lo_attrs IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_count) = lo_attrs->get_length( ).
    DO lv_count TIMES.
      DATA(lo_attr) = lo_attrs->get_item( sy-index - 1 ).
      IF lo_attr IS NOT INITIAL.
        APPEND VALUE ty_attr(
          name  = lo_attr->get_name( )
          value = lo_attr->get_value( )
        ) TO rt_attrs.
      ENDIF.
    ENDDO.
  ENDMETHOD.


  METHOD xml_to_xstring.
    TRY.
        rv_xstr = cl_abap_codepage=>convert_to( source = iv_xml ).
      CATCH cx_sy_conversion_error.
        CLEAR rv_xstr.
    ENDTRY.
  ENDMETHOD.


  METHOD serialize_attrs.
    DATA(lt_sorted) = it_attrs.
    SORT lt_sorted BY name ASCENDING.

    LOOP AT lt_sorted INTO DATA(ls_attr).
      IF rv_str IS NOT INITIAL.
        rv_str = |{ rv_str } |.
      ENDIF.
      rv_str = |{ rv_str }{ ls_attr-name }="{ ls_attr-value }"|.
    ENDLOOP.
  ENDMETHOD.


  METHOD render_node_json.
    READ TABLE is_tree-nodes WITH KEY node_id = iv_node_id INTO DATA(ls_node).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    DATA(lv_attrs_json) = serialize_attrs_json( ls_node-attributes ).

    " Recurse into every child, building a JSON array in document order
    DATA lv_children_json TYPE string.
    LOOP AT ls_node-children INTO DATA(lv_child_id).
      DATA(lv_child_json) = render_node_json(
        is_tree    = is_tree
        iv_node_id = lv_child_id ).

      IF lv_children_json IS NOT INITIAL.
        lv_children_json = |{ lv_children_json },|.
      ENDIF.
      lv_children_json = |{ lv_children_json }{ lv_child_json }|.
    ENDLOOP.

    rv_json = |\{| &&
              |"tag":"{ ls_node-node_type }",| &&
              |"name":"{ ls_node-node_name }",| &&
              |"alias":"{ ls_node-node_alias }",| &&
              |"semantic_id":"{ ls_node-semantic_id }",| &&
              |"offset_start":{ ls_node-offset_start },| &&
              |"offset_end":{ ls_node-offset_end },| &&
              |"attributes":\{ { lv_attrs_json } \},| &&
              |"children":[ { lv_children_json } ]| &&
              |\}|.
  ENDMETHOD.


  METHOD serialize_attrs_json.
    LOOP AT it_attrs INTO DATA(ls_attr).
      IF rv_json IS NOT INITIAL.
        rv_json = |{ rv_json },|.
      ENDIF.
      rv_json = |{ rv_json }"{ ls_attr-name }":"{ ls_attr-value }"|.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

