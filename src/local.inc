struct H5aHandle
  x  dq ?
  y  dq ?
ends

struct H5aVector
  data      dq ?
  size      dd ?
  capacity  dd ?
ends

struct H5aString
  data      dq ?
  size      dd ?
  capacity  dd ?
ends

struct H5aStringView
  data  dq ?
  size  dq ?
ends

struct H5aCharacterQueue
  data dq ?
  size dd ?
  capacity dd ?
  front_idx dd ?
  back_idx dd ?
ends

struct DoctypeToken
  name               rb sizeof.H5aString
  public_id          rb sizeof.H5aString
  system_id          rb sizeof.H5aString
  have_public_id     db ?
  have_system_id     db ?
  force_quirks_flag  db ?
  pad0               rb 5
ends

struct Attribute
  name   rb sizeof.H5aString
  value  rb sizeof.H5aString
ends

struct H5aAttributeView
  name   rb sizeof.H5aStringView
  value  rb sizeof.H5aStringView
ends

struct TagToken
  name                            rb sizeof.H5aString
  attributes                      rb sizeof.H5aVector
  tag_index                       dd ?
  self_closing_flag               db ?
  acknowledged_self_closing_flag  db ?
ends

struct H5aParser
  input_stream.get_char_cb    dq ?
  input_stream.user_data      dq ?
  sink.vtable                 dq ?
  sink.user_data              dq ?

  tokenizer.char_ref          dq ?
  tokenizer.cur_attr          dq ?
  tokenizer.input_buffer      rb sizeof.H5aCharacterQueue
  tokenizer.temp_buffer       rb sizeof.H5aCharacterQueue
  tokenizer.attr_views        rb sizeof.H5aVector

  treebuilder.template_modes  rb sizeof.H5aVector
  treebuilder.element_stack   rb sizeof.H5aVector

  tokenizer.comment           rb sizeof.H5aString
  tokenizer.doctype           rb sizeof.DoctypeToken

  tokenizer.tag               rb sizeof.TagToken
  tokenizer.newline_count     dw ?

  tokenizer.state             db ?
  tokenizer.return_state      db ?
  treebuilder.mode            db ?
  treebuilder.original_mode   db ?
  tokenizer.tag_type          db ?

  flags.foster_parenting      db ?
  flags.scripting             db ?

  tokenizer.saw_cr            db ?
  tokenizer.saw_eof           db ?
ends

enum
  DATA_STATE = 0
  RCDATA_STATE
  RAWTEXT_STATE
  SCRIPT_DATA_STATE
  PLAINTEXT_STATE
  TAG_OPEN_STATE
  END_TAG_OPEN_STATE
  TAG_NAME_STATE
  RCDATA_LESS_THAN_SIGN_STATE
  RCDATA_END_TAG_OPEN_STATE
  RCDATA_END_TAG_NAME_STATE
  RAWTEXT_LESS_THAN_SIGN_STATE
  RAWTEXT_END_TAG_OPEN_STATE
  RAWTEXT_END_TAG_NAME_STATE
  SCRIPT_DATA_LESS_THAN_SIGN_STATE
  SCRIPT_DATA_END_TAG_OPEN_STATE
  SCRIPT_DATA_END_TAG_NAME_STATE
  SCRIPT_DATA_ESCAPE_START_STATE
  SCRIPT_DATA_ESCAPE_START_DASH_STATE
  SCRIPT_DATA_ESCAPED_STATE
  SCRIPT_DATA_ESCAPED_DASH_STATE
  SCRIPT_DATA_ESCAPED_DASH_DASH_STATE
  SCRIPT_DATA_ESCAPED_LESS_THAN_SIGN_STATE
  SCRIPT_DATA_ESCAPED_END_TAG_OPEN_STATE
  SCRIPT_DATA_ESCAPED_END_TAG_NAME_STATE
  SCRIPT_DATA_DOUBLE_ESCAPE_START_STATE
  SCRIPT_DATA_DOUBLE_ESCAPE_START_DASH_STATE
  SCRIPT_DATA_DOUBLE_ESCAPED_STATE
  SCRIPT_DATA_DOUBLE_ESCAPED_DASH_STATE
  SCRIPT_DATA_DOUBLE_ESCAPED_DASH_DASH_STATE
  SCRIPT_DATA_DOUBLE_ESCAPED_LESS_THAN_SIGN_STATE
  SCRIPT_DATA_DOUBLE_ESCAPE_END_STATE
  BEFORE_ATTRIBUTE_NAME_STATE
  ATTRIBUTE_NAME_STATE
  AFTER_ATTRIBUTE_NAME_STATE
  BEFORE_ATTRIBUTE_VALUE_STATE
  ATTRIBUTE_VALUE_DOUBLE_QUOTED_STATE
  ATTRIBUTE_VALUE_SINGLE_QUOTED_STATE
  ATTRIBUTE_VALUE_UNQUOTED_STATE
  AFTER_ATTRIBUTE_VALUE_QUOTED_STATE
  SELF_CLOSING_START_TAG_STATE
  BOGUS_COMMENT_STATE
  MARKUP_DECLARATION_OPEN_STATE
  COMMENT_START_STATE
  COMMENT_START_DASH_STATE
  COMMENT_STATE
  COMMENT_LESS_THAN_SIGN_STATE
  COMMENT_LESS_THAN_SIGN_BANG_STATE
  COMMENT_LESS_THAN_SIGN_BANG_DASH_STATE
  COMMENT_LESS_THAN_SIGN_BANG_DASH_DASH_STATE
  COMMENT_END_DASH_STATE
  COMMENT_END_STATE
  COMMENT_END_BANG_STATE
  DOCTYPE_STATE
  BEFORE_DOCTYPE_NAME_STATE
  DOCTYPE_NAME_STATE
  AFTER_DOCTYPE_NAME_STATE
  AFTER_DOCTYPE_PUBLIC_KEYWORD_STATE
  BEFORE_DOCTYPE_PUBLIC_IDENTIFIER_STATE
  DOCTYPE_PUBLIC_IDENTIFIER_DOUBLE_QUOTED_STATE
  DOCTYPE_PUBLIC_IDENTIFIER_SINGLE_QUOTED_STATE
  AFTER_DOCTYPE_PUBLIC_IDENTIFIER_STATE
  BETWEEN_DOCTYPE_PUBLIC_AND_SYSTEM_IDENTIFIERS_STATE
  AFTER_DOCTYPE_SYSTEM_KEYWORD_STATE
  BEFORE_DOCTYPE_SYSTEM_IDENTIFIER_STATE
  DOCTYPE_SYSTEM_IDENTIFIER_DOUBLE_QUOTED_STATE
  DOCTYPE_SYSTEM_IDENTIFIER_SINGLE_QUOTED_STATE
  AFTER_DOCTYPE_SYSTEM_IDENTIFIER_STATE
  BOGUS_DOCTYPE_STATE
  CDATA_SECTION_STATE
  CDATA_SECTION_BRACKET_STATE
  CDATA_SECTION_END_STATE
  CHARACTER_REFERENCE_STATE
  NAMED_CHARACTER_REFERENCE_STATE
  AMBIGUOUS_AMPERSAND_STATE
  NUMERIC_CHARACTER_REFERENCE_STATE
  HEXADECIMAL_CHARACTER_REFERENCE_START_STATE
  DECIMAL_CHARACTER_REFERENCE_START_STATE
  HEXADECIMAL_CHARACTER_REFERENCE_STATE
  DECIMAL_CHARACTER_REFERENCE_STATE
  NUMERIC_CHARACTER_REFERENCE_END_STATE
  NUM_STATES
end enum

enum
  INITIAL_MODE = 0
  BEFORE_HTML_MODE
  BEFORE_HEAD_MODE
  IN_HEAD_MODE
  IN_HEAD_NOSCRIPT_MODE
  AFTER_HEAD_MODE
  IN_BODY_MODE
  TEXT_MODE
  IN_TABLE_MODE
  IN_TABLE_TEXT_MODE
  IN_CAPTION_MODE
  IN_COLUMN_GROUP_MODE
  IN_TABLE_BODY_MODE
  IN_ROW_MODE
  IN_CELL_MODE
  IN_SELECT_MODE
  IN_SELECT_IN_TABLE_MODE
  IN_TEMPLATE_MODE
  AFTER_BODY_MODE
  IN_FRAMESET_MODE
  AFTER_FRAMESET_MODE
  AFTER_AFTER_BODY_MODE
  AFTER_AFTER_FRAMESET_MODE

  IN_FOREIGN_CONTENT_MODE

  NUM_MODES
end enum

enum
  RESULT_BIT_AGAIN = (1 shl 1)
  RESULT_BIT_LEAVE = (1 shl 2)
  RESULT_BIT_CLEANUP = (1 shl 3)

  ; XXX: remove this?
  RESULT_BIT_PARTIAL = (1 shl 4) ;for special actions that "failed"
end enum

enum
  RESULT_OK          = (0x0)
  RESULT_IGNORE      = (0x0 + 0x1)
  RESULT_RECONSUME   = (RESULT_BIT_AGAIN + 0x0)
  RESULT_REPROCESS   = (RESULT_BIT_AGAIN + 0x1)
  RESULT_EOF_REACHED = ((RESULT_BIT_CLEANUP or RESULT_BIT_LEAVE) + 0x0)
  RESULT_STOP        = ((RESULT_BIT_CLEANUP or RESULT_BIT_LEAVE) + 0x1)

  ; only used internally
  RESULT_PARTIAL     = (RESULT_BIT_PARTIAL + 0x0)
end enum

enum
  STATE_BIT_SPC_ACTION = (1 shl 0)
  STATE_BIT_NO_GETCHAR = (1 shl 1)
end enum

enum
  TOKEN_CHARACTER
  TOKEN_WHITESPACE
  TOKEN_DOCTYPE
  TOKEN_START_TAG
  TOKEN_END_TAG
  TOKEN_COMMENT
  TOKEN_EOF
end enum

;;
;; Public
;;
struct H5aParserCreateInfo
  input_get_char   dq ?
  input_user_data  dq ?
  sink_vtable      dq ?
  sink_user_data   dq ?
ends

struct H5aSinkVTable
  finish dq ?
  parse_error dq ?
  get_document dq ?
  get_template_contents dq ?
  set_quirks_mode dq ?
  same_node dq ?
  elem_name dq ?
  create_element dq ?
  create_comment dq ?
  append dq ?
  append_before_sibling dq ?
  append_doctype_to_document dq ?
  add_attrs_if_missing dq ?
  remove_from_parent dq ?
  reparent_children dq ?
  mark_script_already_started dq ?
  complete_script dq ?
  is_mathml_annotation_xml_integration_point dq ?

  get_tag_by_name  dq ?
  destroy_handle   dq ?
  clone_handle     dq ?
ends

enum
  H5A_SUCCESS = 0
  H5A_FAILURE = 1
  H5A_PAUSED  = 2
end enum

enum
  H5A_QUIRKS_MODE_NO_QUIRKS = 0
  H5A_QUIRKS_MODE_LIMITED_QUIRKS
  H5A_QUIRKS_MODE_QUIRKS
end enum

