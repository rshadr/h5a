#ifndef __h5a_h__
#define __h5a_h__

#include <stddef.h>
#include <stdint.h>
#include <uchar.h>

#ifdef __cplusplus
extern "C" {
#endif


#if __STDC_VERSION__ >= 202000 || defined(__cplusplus)
typedef enum : uint32_t {
#else
typedef enum {
#endif
  H5A_SUCCESS = 0,
  H5A_FAILURE = 1,
  H5A_PAUSED  = 2,
} H5aResult;


// XXX: not in asm yet
#if __STDC_VERSION__ >= 202000 || defined(__cplusplus)
typedef enum : uint8_t {
#else
typedef enum {
#endif
  H5A_QUIRKS_MODE_NO_QUIRKS = 0,
  H5A_QUIRKS_MODE_LIMITED_QUIRKS,
  H5A_QUIRKS_MODE_QUIRKS,
} H5aQuirksMode;


/* WARNING: Must be manually synced with "src/tags.inc" */
#if __STDC_VERSION__ >= 202000 || defined (__cplusplus)
typedef enum : uint32_t {
#else
typedef enum {
#endif
  H5A_TAG_HTML = 0,

  H5A_TAG_HEAD,
  H5A_TAG_TITLE,
  H5A_TAG_BASE,
  H5A_TAG_LINK,
  H5A_TAG_META,
  H5A_TAG_STYLE,

  H5A_TAG_BODY,
  H5A_TAG_ARTICLE,
  H5A_TAG_SECTION,
  H5A_TAG_NAV,
  H5A_TAG_ASIDE,
  H5A_TAG_H1,
  H5A_TAG_H2,
  H5A_TAG_H3,
  H5A_TAG_H4,
  H5A_TAG_H5,
  H5A_TAG_H6,
  H5A_TAG_HGROUP,
  H5A_TAG_HEADER,
  H5A_TAG_FOOTER,
  H5A_TAG_ADDRESS,

  H5A_TAG_P,
  H5A_TAG_HR,
  H5A_TAG_PRE,
  H5A_TAG_BLOCKQUOTE,
  H5A_TAG_OL,
  H5A_TAG_UL,
  H5A_TAG_MENU,
  H5A_TAG_LI,
  H5A_TAG_DL,
  H5A_TAG_DT,
  H5A_TAG_DD,
  H5A_TAG_FIGURE,
  H5A_TAG_FIGCAPTION,
  H5A_TAG_MAIN,
  H5A_TAG_SEARCH,
  H5A_TAG_DIV,

  H5A_TAG_A,
  H5A_TAG_EM,
  H5A_TAG_STRONG,
  H5A_TAG_SMALL,
  H5A_TAG_S,
  H5A_TAG_CITE,
  H5A_TAG_Q,
  H5A_TAG_DFN,
  H5A_TAG_ABBR,
  H5A_TAG_RUBY,
  H5A_TAG_RT,
  H5A_TAG_RP,
  H5A_TAG_DATA,
  H5A_TAG_TIME,
  H5A_TAG_CODE,
  H5A_TAG_VAR,
  H5A_TAG_SAMP,
  H5A_TAG_KBD,
  H5A_TAG_SUB,
  H5A_TAG_SUP,
  H5A_TAG_I,
  H5A_TAG_B,
  H5A_TAG_U,
  H5A_TAG_MARK,
  H5A_TAG_BDI,
  H5A_TAG_BDO,
  H5A_TAG_SPAN,
  H5A_TAG_BR,
  H5A_TAG_WBR,

  H5A_TAG_INS,
  H5A_TAG_DEL,

  H5A_TAG_PICTURE,
  H5A_TAG_SOURCE,
  H5A_TAG_IMG,
  H5A_TAG_IFRAME,
  H5A_TAG_EMBED,
  H5A_TAG_OBJECT,
  H5A_TAG_VIDEO,
  H5A_TAG_AUDIO,
  H5A_TAG_TRACK,
  H5A_TAG_MAP,
  H5A_TAG_AREA,

  H5A_TAG_TABLE,
  H5A_TAG_CAPTION,
  H5A_TAG_COLGROUP,
  H5A_TAG_COL,
  H5A_TAG_TBODY,
  H5A_TAG_THEAD,
  H5A_TAG_TFOOT,
  H5A_TAG_TR,
  H5A_TAG_TD,
  H5A_TAG_TH,

  H5A_TAG_FORM,
  H5A_TAG_LABEL,
  H5A_TAG_INPUT,
  H5A_TAG_BUTTON,
  H5A_TAG_SELECT,
  H5A_TAG_DATALIST,
  H5A_TAG_OPTGROUP,
  H5A_TAG_OPTION,
  H5A_TAG_TEXTAREA,
  H5A_TAG_OUTPUT,
  H5A_TAG_PROGRESS,
  H5A_TAG_METER,
  H5A_TAG_FIELDSET,
  H5A_TAG_LEGEND,

  H5A_TAG_DETAILS,
  H5A_TAG_SUMMARY,
  H5A_TAG_DIALOG,

  H5A_TAG_SCRIPT,
  H5A_TAG_NOSCRIPT,
  H5A_TAG_TEMPLATE,
  H5A_TAG_SLOT,
  H5A_TAG_CANVAS,

  /* Obsolete tags */
  H5A_TAG_APPLET,
  H5A_TAG_ACRONYM,
  H5A_TAG_BGSOUND,
  H5A_TAG_DIR,
  H5A_TAG_FRAME,
  H5A_TAG_FRAMESET,
  H5A_TAG_NOFRAMES,
  H5A_TAG_ISINDEX,
  H5A_TAG_KEYGEN,
  H5A_TAG_LISTING,
  H5A_TAG_MENUITEM,
  H5A_TAG_NEXTID,
  H5A_TAG_NOEMBED,
  H5A_TAG_PARAM,
  H5A_TAG_PLAINTEXT,
  H5A_TAG_RB,
  H5A_TAG_RTC,
  H5A_TAG_STRIKE,
  H5A_TAG_XMP,
  H5A_TAG_BASEFONT,
  H5A_TAG_BIG,
  H5A_TAG_BLINK,
  H5A_TAG_CENTER,
  H5A_TAG_FONT,
  H5A_TAG_MARQUEE,
  H5A_TAG_MULTICOL,
  H5A_TAG_NOBR,
  H5A_TAG_SPACER,
  H5A_TAG_TT,

  NUM_H5A_TAGS,

  H5A_PLACEHOLDER_TAG = (uint32_t)(~0),
} H5aTag;


/*
 * Sinks are not implemented by the lib itself
 */
typedef struct H5aSink_s H5aSink;
typedef struct H5aHandle_s {
  /*
   * Intended as std::shared_ptr like block-object tuple
   */
  void *x;
  void *y;
} H5aHandle;

typedef struct H5aStringView_s {
  uint8_t const *data;
  size_t size;
} H5aStringView;

/*
 * Hack to avoid stack-based parameter passing.
 * Handing in the handle like this is slightly
 * more efficient and costs nothing in maintenance/readability.
 */
#define H5A_NODE_OR_TEXT_HANDLE(pref) \
  H5aHandle pref, bool pref##_is_text

typedef struct H5aSinkVTable_s {

  /*
   * The following block of methods is taken from html5ever's sink
   * implementation
   */
  void *(*finish)
    (H5aSink *self);
  void (*parse_error)
    (H5aSink *self, char const *msg);
  H5aHandle (*get_document)
    (H5aSink *self);
  H5aHandle (*get_template_contents)
    (H5aSink *self, H5aHandle target);
  void (*set_quirks_mode)
    (H5aSink *self, H5aQuirksMode mode);
  bool (*same_node)
    (H5aSink *self, H5aHandle x, H5aHandle y);
  void* (*elem_name)
    (H5aSink *self, H5aHandle target);
  H5aHandle (*create_element)
    (H5aSink *self, void *name, void *attrs);
  H5aHandle (*create_comment)
    (H5aSink *self, H5aStringView text);
  void (*append)
    (H5aSink *self, H5aHandle parent, H5A_NODE_OR_TEXT_HANDLE(child));
  void* (*append_before_sibling)
    (H5aSink *self, H5A_NODE_OR_TEXT_HANDLE(child));
  void (*append_doctype_to_document)
    (H5aSink *self, H5aStringView name, H5aStringView public_id, H5aStringView system_id);
  void (*add_attrs_if_missing)
    (H5aSink *self, H5aHandle target);
  void (*remove_from_parent)
    (H5aSink *self, H5aHandle target);
  void (*reparent_children)
    (H5aSink *self, H5aHandle node, H5aHandle new_parent);
  void (*mark_script_already_started)
    (H5aSink *self, H5aHandle node);
  void* (*complete_script)
    (H5aSink *self, H5aHandle _node);
  bool (*is_mathml_annotation_xml_integration_point)
    (H5aSink *self, H5aHandle handle);

  /*
   * These are unique to h5a
   */
  H5aTag (*get_tag_by_name)
    (H5aSink *self, H5aStringView name);
  void (*destroy_handle)
    (H5aSink *self, H5aHandle handle);
} H5aSinkVTable;

typedef struct H5aSinkCreateInfo_s {
  union {
    H5aSink *sink;
    void *p;
  } user_data;
  const H5aSinkVTable *vtable;
} H5aSinkCreateInfo;

/* opaque */
typedef struct H5aParser_s H5aParser;

extern const size_t k_h5a_parserSize;

typedef struct H5aParserCreateInfo_s {
  char32_t (*input_get_char) (void *user_data);
  void *input_user_data;
  const H5aSinkVTable *sink_vtable;
  void *sink_user_data;
} H5aParserCreateInfo;

H5aResult h5aCreateParser (H5aParserCreateInfo const *create_info,
                           H5aParser *parser);
H5aResult h5aDestroyParser (H5aParser *parser);
H5aResult h5aResumeParser (H5aParser *parser);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* !defined(__h5a_h__) */

