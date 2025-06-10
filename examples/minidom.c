/*
 * Copyright 2025 rshadr
 * See LICENSE for details
 */

#include <stddef.h>
#include <inttypes.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <stdarg.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <grapheme.h>
#include <h5a.h>


typedef struct MdInputStream_s {
  char const *p;
  char const *end;

  char *file_data;
  char const *file_name;
  size_t file_size;

  size_t read_counter;

  /* infos for tracing */
  size_t line;
  size_t col;
} MdInputStream;

typedef struct MdControlBlock_s {
  void (*dtor) (void *instance);
  _Atomic uint32_t ref_count;
  uint32_t _pad0;
} MdControlBlock;

#define MD_ALLOC(t_base) \
  mdInstanceAllocate(sizeof(Md##t_base), md##t_base##_dtor)

typedef enum MdNodeType_e {
  MD_NODETYPE_DOCTYPE,
  MD_NODETYPE_DOCUMENT,
  MD_NODETYPE_COMMENT,
  MD_NODETYPE_TEXT,
  MD_NODETYPE_ELEMENT,
} MdNodeType;

typedef struct MdHandle_s MdHandle;

typedef struct MdVector_s {
  MdHandle *  data;
  size_t      size;
  size_t      capacity;
} MdHandleVector;
#define MdHandleVector(t) \
  MdHandleVector

/*
 * A regular handle like this is a strong reference in reference-counting
 * sense. Note that we could also just have one member for the handle,
 * the control block, since it's just before the instance in memory,
 * but we keep this approach in case we were to scale it in the future
 * for more complex memory management.
 */
struct MdHandle_s {
  void *instance;
  MdControlBlock *control_block;
};
#define MdHandle(t) \
  MdHandle

/*
 * Weak handles need to be locked into a strong handle before use
 */
typedef struct MdWeakHandle_s {
  void *instance;
  MdControlBlock *control_block;
} MdWeakHandle;
#define MdWeakHandle(t) \
  MdWeakHandle

typedef struct MdNode_s {
  MdHandleVector(MdNode) child_nodes;
  MdWeakHandle(MdNode) parent_node;
  MdNodeType node_type;
} MdNode;

typedef struct MdComment_s {
  MdNode node;
  char *content;
} MdComment;

typedef struct MdDoctype_s {
  MdNode node;

  char *name;
  char *system_id;
  char *public_id;
} MdDoctype;

typedef struct MdDocument_s {
  MdNode node;

  H5aQuirksMode quirks_mode;
} MdDocument;

typedef struct MdAttribute_s {
  char *name;
  char *value;
} MdAttribute;

typedef struct MdElement_s {
  MdNode element;

  void *qualname;
  MdHandleVector(MdAttribute) attributes;
} MdElement;

typedef struct MdTemplateElement_s {
  MdElement element;

  MdHandle(MdNode) template_contents;
} MdTemplateElement;

typedef struct MdSink_s {
  // H5aQuirksMode quirks_mode;
  MdHandle document;
} MdSink;


static void die (char const *fmt, ...);
static void usage (char const *argv0);

static void mdInputStreamCreate (MdInputStream *stream, char const *file_name);
static void mdInputStreamDestroy (MdInputStream *stream);
static char32_t mdInputStreamGetChar (void *user_data);

[[nodiscard]] static inline H5aHandle mdMdHandleToH5a (MdHandle handle);
[[nodiscard]] static inline MdHandle mdH5aHandleToMd (H5aHandle handle);
[[nodiscard]] static inline MdHandle mdHandleClone (MdHandle handle);
[[nodiscard]] static inline MdWeakHandle mdHandleWeakClone (MdHandle handle);
static void mdHandleDestroy (MdHandle handle);

[[nodiscard]] static MdHandle mdInstanceAllocate (size_t size, void (*dtor) (void *));

static void mdHandleVectorCreate (MdHandleVector *vec);
static void mdHandleVectorDestroy (MdHandleVector *vec);

static void mdSinkCreate (MdSink *sink);
static void mdSinkDestroy (MdSink *sink);

static void *mdSinkFinish (H5aSink *self);
static void mdSinkParseError (H5aSink *self, char const *msg);
[[nodiscard]] static H5aHandle mdSinkGetTemplateContents (H5aSink *self, H5aHandle target);
[[nodiscard]] static H5aHandle mdSinkGetDocument (H5aSink *self);
static void mdSinkSetQuirksMode (H5aSink *self, H5aQuirksMode mode);
static bool mdSinkSameNode (H5aSink *self, H5aHandle x, H5aHandle y);
static H5aHandle mdSinkCreateComment (H5aSink *self, H5aStringView text);
static void mdSinkAppend (H5aSink *self, H5aHandle parent, H5A_NODE_OR_TEXT_HANDLE(child));
static void mdSinkAppendDoctypeToDocument (H5aSink *self, H5aStringView name,
  H5aStringView public_id, H5aStringView system_id);
static void mdSinkRemoveFromParent (H5aSink *self, H5aHandle target);
static void mdSinkReparentChildren (H5aSink *self, H5aHandle node, H5aHandle new_parent);
static H5aTag mdSinkGetTagByName (H5aSink *self, H5aStringView name);
static void mdSinkDestroyHandle (H5aSink *self, H5aHandle handle);
[[nodiscard]] static H5aHandle mdSinkCloneHandle (H5aSink *self, H5aHandle handle);

static char const *k_html_tags_table[NUM_H5A_TAGS] = {
  [H5A_TAG_HTML] = "html",

  [H5A_TAG_HEAD]  = "head",
  [H5A_TAG_TITLE] = "title",
  [H5A_TAG_BASE]  = "base",
  [H5A_TAG_LINK]  = "link",
  [H5A_TAG_META]  = "meta",
  [H5A_TAG_STYLE] = "style",

  [H5A_TAG_BODY]    = "body",
  [H5A_TAG_ARTICLE] = "article",
  [H5A_TAG_SECTION] = "section",
  [H5A_TAG_NAV]     = "nav",
  [H5A_TAG_ASIDE]   = "aside",
  [H5A_TAG_H1]      = "h1",
  [H5A_TAG_H2]      = "h2",
  [H5A_TAG_H3]      = "h3",
  [H5A_TAG_H4]      = "h4",
  [H5A_TAG_H5]      = "h5",
  [H5A_TAG_H6]      = "h6",
  [H5A_TAG_HGROUP]  = "hgroup",
  [H5A_TAG_HEADER]  = "header",
  [H5A_TAG_FOOTER]  = "footer",
  [H5A_TAG_ADDRESS] = "address",

  [H5A_TAG_P] = "p",
  [H5A_TAG_HR] = "hr",
  [H5A_TAG_PRE] = "pre",
  [H5A_TAG_BLOCKQUOTE] = "blockquote",
  [H5A_TAG_OL] = "ol",
  [H5A_TAG_UL] = "ul",
  [H5A_TAG_MENU] = "menu",
  [H5A_TAG_LI] = "li",
  [H5A_TAG_DL] = "dl",
  [H5A_TAG_DT] = "dt",
  [H5A_TAG_DD] = "dd",
  [H5A_TAG_FIGURE] = "figure",
  [H5A_TAG_FIGCAPTION] = "figcaption",
  [H5A_TAG_MAIN] = "main",
  [H5A_TAG_SEARCH] = "search",
  [H5A_TAG_DIV] = "div",

  [H5A_TAG_A] = "a",
  [H5A_TAG_EM] = "em",
  [H5A_TAG_STRONG] = "strong",
  [H5A_TAG_SMALL] = "small",
  [H5A_TAG_S] = "s",
  [H5A_TAG_CITE] = "cite",
  [H5A_TAG_Q] = "q",
  [H5A_TAG_DFN] = "dfn",
  [H5A_TAG_ABBR] = "abbr",
  [H5A_TAG_RUBY] = "ruby",
  [H5A_TAG_RT] = "rt",
  [H5A_TAG_RP] = "rp",
  [H5A_TAG_DATA] = "data",
  [H5A_TAG_TIME] = "time",
  [H5A_TAG_CODE] = "code",
  [H5A_TAG_VAR] = "var",
  [H5A_TAG_SAMP] = "samp",
  [H5A_TAG_KBD] = "kbd",
  [H5A_TAG_SUB] = "sub",
  [H5A_TAG_SUP] = "sup",
  [H5A_TAG_I] = "i",
  [H5A_TAG_B] = "b",
  [H5A_TAG_U] = "u",
  [H5A_TAG_MARK] = "mark",
  [H5A_TAG_BDI] = "bdi",
  [H5A_TAG_BDO] = "bdo",
  [H5A_TAG_SPAN] = "span",
  [H5A_TAG_BR] = "br",
  [H5A_TAG_WBR] = "wbr",

  /* ... */

  

  [H5A_TAG_SCRIPT]   = "script",
  [H5A_TAG_NOSCRIPT] = "noscript",
  [H5A_TAG_TEMPLATE] = "template",
  [H5A_TAG_SLOT]     = "slot",
  [H5A_TAG_CANVAS]   = "canvas",

  [H5A_TAG_APPLET]   = "applet",
  [H5A_TAG_ACRONYM]  = "acronym",
  [H5A_TAG_BGSOUND]  = "bgsound",
  [H5A_TAG_DIR]      = "dir",
  [H5A_TAG_FRAME]    = "frame",
  [H5A_TAG_FRAMESET] = "frameset",
  [H5A_TAG_NOFRAMES] = "noframes",
  [H5A_TAG_ISINDEX]  = "isindex",
  [H5A_TAG_KEYGEN]   = "keygen",
  [H5A_TAG_LISTING]  = "listing",
  [H5A_TAG_MENUITEM] = "menuitem",
  [H5A_TAG_NEXTID]    = "nextid",
  [H5A_TAG_NOEMBED]   = "noembed",
  [H5A_TAG_PARAM]     = "param",
  [H5A_TAG_PLAINTEXT] = "plaintext",
  [H5A_TAG_RB]        = "rb",
  [H5A_TAG_RTC]       = "rtc",
  [H5A_TAG_STRIKE]    = "strike",
  [H5A_TAG_XMP]       = "xmp",
  [H5A_TAG_BASEFONT]  = "basefont",
  [H5A_TAG_BIG]       = "big",
  [H5A_TAG_BLINK]     = "blink",
  [H5A_TAG_CENTER]    = "center",
  [H5A_TAG_FONT]      = "font",
  [H5A_TAG_MARQUEE]   = "marquee",
  [H5A_TAG_MULTICOL]  = "multicol",
  [H5A_TAG_NOBR]      = "nobr",
  [H5A_TAG_SPACER]    = "spacer",
  [H5A_TAG_TT]        = "tt",
};

static const H5aSinkVTable k_minidom_sink_vtable = {
  .finish = mdSinkFinish,
  .parse_error = mdSinkParseError,
  .get_document = mdSinkGetDocument,
  .get_template_contents = mdSinkGetTemplateContents,
  .set_quirks_mode = mdSinkSetQuirksMode,
  .same_node = mdSinkSameNode,
  .elem_name = NULL,
  .create_element = NULL,
  .create_comment = mdSinkCreateComment,
  .append = mdSinkAppend,
  .append_before_sibling = NULL,
  .append_doctype_to_document = mdSinkAppendDoctypeToDocument,
  .add_attrs_if_missing = NULL,
  .remove_from_parent = mdSinkRemoveFromParent,
  .reparent_children = mdSinkReparentChildren,
  .mark_script_already_started = NULL,
  .complete_script = NULL,
  .is_mathml_annotation_xml_integration_point = NULL,

  .get_tag_by_name = mdSinkGetTagByName,
  .destroy_handle = mdSinkDestroyHandle,
  .clone_handle = mdSinkCloneHandle,
};


[[noreturn]]
__attribute__(( format(printf, 1, 2) ))
static void
die (char const *fmt, ...)
{
  va_list ap;

  va_start(ap, fmt);
  vfprintf(stderr, fmt, ap);
  va_end(ap);

  exit(EXIT_FAILURE);
}


[[noreturn]]
static void
usage (char const *argv0)
{
  die("usage: %s <filename>\n", argv0);
}


static void
mdInputStreamCreate (MdInputStream *stream, char const *file_name)
{
  int fd = open(file_name, O_RDONLY);
  if (fd == -1)
    die("error: couldn't open file '%s'\n", file_name);

  struct stat st;
  if (fstat(fd, &st) == -1)
    die("error: couldn't stat file '%s'\n", file_name);

  size_t file_size = st.st_size;
  char *file_data = mmap(NULL, file_size, PROT_READ, MAP_PRIVATE, fd, 0);

  if (file_data == (char *)(MAP_FAILED))
    die("error: couldn't map file '%s'\n", file_name);

  close(fd);
  // madvise(file_data, file_size, MADV_SEQUENTIAL);

  (*stream) = (MdInputStream) {
    .p = file_data,
    .end = &file_data[file_size],
    .file_data = file_data,
    .file_size = file_size,
    .file_name = file_name,
    .line = 1,
    .col  = 1,
  };

}


static void
mdInputStreamDestroy (MdInputStream *stream)
{
  if (munmap(stream->file_data, stream->file_size) == -1)
    die("error: couldn't unmap file '%s'\n", stream->file_name);

  *stream = (MdInputStream){0};
}


static char32_t
mdInputStreamGetChar (void *user_data)
{
  static const char32_t eof = (char32_t)(~0);

  MdInputStream *stream = user_data;

  size_t left = (stream->end - stream->p);
  size_t read;
  char32_t c = {0xFFFD};

  if (left > 0 && *stream->p == '\0')
    return (char32_t)(*stream->p++);

  if ((left == 0)
   || !(read = grapheme_decode_utf8(stream->p,
                left, (uint_least32_t *)(&c))))
    return eof;

  // XXX: windows
  if (c == '\n') {
    stream->line += 1;
    stream->col = 1;
    printf("reached line %zu\n", stream->line);
  }

  stream->read_counter += 1;
  stream->p += read;
  return c;
}


[[nodiscard]]
static inline H5aHandle
mdMdHandleToH5a (MdHandle handle)
{
  return (H5aHandle) {
    .x = handle.instance,
    .y = handle.control_block,
  };
}


[[nodiscard]]
static inline MdHandle
mdH5aHandleToMd (H5aHandle handle)
{
  return (MdHandle) {
    .instance = handle.x,
    .control_block = handle.y,
  };
}


[[nodiscard]]
static inline MdHandle
mdHandleClone (MdHandle handle)
{
  ++handle.control_block->ref_count;
  return handle;
}


[[nodiscard]]
static inline MdWeakHandle
mdHandleWeakClone (MdHandle handle)
{
  return (MdWeakHandle) {
    .instance = handle.instance,
    .control_block = handle.control_block
  };
}


static inline void
mdHandleDestroy (MdHandle handle)
{
  if (--handle.control_block->ref_count == 0) {
    handle.control_block->dtor(handle.instance);
    free(handle.control_block);
  }
}


[[nodiscard]]
static MdHandle
mdInstanceAllocate (size_t size, void (*dtor) (void *user_data))
{
  MdControlBlock *control_block = calloc(1, sizeof(*control_block) + size);
  void *instance = (void *)((uintptr_t)(control_block) + sizeof(*control_block));

  control_block->dtor = dtor;
  control_block->ref_count = 1;

  return (MdHandle) {
    .control_block = control_block,
    .instance = instance,
  };
}


static void
mdHandleVectorCreate (MdHandleVector *vec)
{
  static const size_t init_capacity = 8;
  vec->data = calloc(init_capacity, sizeof(vec->data[0]));
  vec->capacity = init_capacity;
  vec->size = 0;
}


static void
mdHandleVectorDestroy (MdHandleVector *vec)
{
  for (size_t i = 0; i < vec->size; ++i)
    mdHandleDestroy(vec->data[i]);
  free(vec->data);
  vec->data = NULL;
  vec->size = 0;
  vec->capacity = 0;
}


static void
mdHandleVectorPush (MdHandleVector *vec, MdHandle item)
{
  if (vec->size == vec->capacity) {
    size_t new_capacity = vec->capacity * 2;
    MdHandle *new_data = calloc(new_capacity, sizeof(new_data[0]));

    memcpy(new_data, vec->data, vec->size * sizeof(vec->data[0]));
    free(vec->data);

    vec->capacity = new_capacity;
    vec->data = new_data;
  }

  vec->data[vec->size++] = mdHandleClone(item);
}


[[nodiscard]]
static MdHandle
mdHandleVectorPop (MdHandleVector *vec)
{
  if (vec->size == 0)
    return (MdHandle){0};

  return mdHandleClone(vec->data[vec->size - 1]);
}


static void
mdNode_ctor (MdNode *node, MdNodeType node_type)
{
  node->node_type = node_type;
  mdHandleVectorCreate(&node->child_nodes);
}

static void
mdNode_dtor (void *user_data)
{
  MdNode *node = user_data;
  mdHandleVectorDestroy(&node->child_nodes);
}

static void
mdComment_dtor (void *user_data)
{
  MdComment *comment = user_data;
  free(comment->content);
  mdNode_dtor(user_data);
}


static void
mdDoctype_ctor (MdDoctype *doctype,
								H5aStringView name,
								H5aStringView public_id,
								H5aStringView system_id)
{
	mdNode_ctor((MdNode *)(doctype), MD_NODETYPE_DOCTYPE);

	/* name shouldn't be null? */
	doctype->name = strndup(name.data, name.size);

	if (public_id.data != NULL)
		doctype->public_id = strndup(public_id.data, public_id.size);

	if (system_id.data != NULL)
		doctype->system_id = strndup(system_id.data, system_id.size);
}


static void
mdDoctype_dtor (void *user_data)
{
	MdDoctype *doctype = user_data;

	if (doctype->name != NULL)
		free(doctype->name);

	if (doctype->public_id != NULL)
		free(doctype->public_id);

	if (doctype->system_id != NULL)
		free(doctype->system_id);

  mdNode_dtor(user_data);
}


static void
mdDocument_ctor (MdDocument *document)
{
  mdNode_ctor((MdNode *)(document), MD_NODETYPE_DOCUMENT);

  document->quirks_mode = H5A_QUIRKS_MODE_NO_QUIRKS;
}

static void
mdDocument_dtor (void *user_data)
{
  // MdDocument *document = user_data;

  mdNode_dtor(user_data);
}


static void
mdSinkCreate (MdSink *sink)
{
  sink->document = MD_ALLOC(Document);
  mdDocument_ctor(sink->document.instance);
}


static void
mdSinkDestroy (MdSink *sink)
{
  mdHandleDestroy(sink->document);
}


H5A_SINK_CALLBACK_ATTR
static void *
mdSinkFinish (H5aSink *self)
{
  abort();
  (void) self;
  return NULL;
}


H5A_SINK_CALLBACK_ATTR
static void
mdSinkParseError (H5aSink *self, char const *msg)
{
  (void) self;
  fprintf(stderr, "parse error: %s\n", msg);
}


H5A_SINK_CALLBACK_ATTR
[[nodiscard]]
static H5aHandle
mdSinkGetDocument (H5aSink *self)
{
  MdSink *sink = (MdSink *)(self);
  return mdMdHandleToH5a( mdHandleClone(sink->document) );
}


H5A_SINK_CALLBACK_ATTR
[[nodiscard]]
static H5aHandle
mdSinkGetTemplateContents (H5aSink *self, H5aHandle target)
{
  abort();
  /* XXX */
  (void) self;
  (void) target;
  return (H5aHandle){0};
}


H5A_SINK_CALLBACK_ATTR
static void
mdSinkSetQuirksMode (H5aSink *self, H5aQuirksMode mode)
{
  MdSink *sink = (MdSink *)(self);
  ((MdDocument *)(sink->document.instance))->quirks_mode = mode;
}


H5A_SINK_CALLBACK_ATTR
static bool
mdSinkSameNode (H5aSink *self, H5aHandle x, H5aHandle y)
{
  (void) self;

  auto a = mdH5aHandleToMd(x);
  auto b = mdH5aHandleToMd(y);

  return (a.instance == b.instance);
}


H5A_SINK_CALLBACK_ATTR
static H5aHandle
mdSinkCreateComment (H5aSink *self, H5aStringView text)
{
  (void) self;

  auto handle = MD_ALLOC(Comment);
  MdComment *comment = handle.instance;

  printf("i'm commenting it rn\n");

  mdNode_ctor((MdNode *)(comment), MD_NODETYPE_COMMENT);
  comment->content = strndup(text.data, text.size);

  return mdMdHandleToH5a(handle);
}


H5A_SINK_CALLBACK_ATTR
static void
mdSinkAppend (H5aSink *self, H5aHandle parent, H5A_NODE_OR_TEXT_HANDLE(child))
{
  if (child_is_string)
    abort();

  auto parent_handle = mdH5aHandleToMd(parent);
  auto child_handle  = mdH5aHandleToMd(child.handle);
  MdNode *parent_node = parent_handle.instance;
  MdNode *child_node  = child_handle.instance;

  child_node->parent_node = mdHandleWeakClone(parent_handle);
  mdHandleVectorPush(&parent_node->child_nodes, child_handle);
}


H5A_SINK_CALLBACK_ATTR
static void
mdSinkAppendDoctypeToDocument (H5aSink *self, 
                               H5aStringView name,
                               H5aStringView public_id,
                               H5aStringView system_id)
{
	MdSink *sink = (MdSink *)(self);
  printf("name (%zu bytes): %s\n", name.size, name.data);
  printf("public_id (%zu bytes): %s\n", public_id.size, public_id.data);
  printf("system_id (%zu bytes): %s\n", system_id.size, system_id.data);

	auto document_handle = mdHandleClone(sink->document);
	auto document = (MdDocument *)(document_handle.instance);

	auto doctype_handle = MD_ALLOC(Doctype);
  MdDoctype *doctype = doctype_handle.instance;
  mdDoctype_ctor(doctype, name, public_id, system_id);

  ((MdNode *)(doctype))->parent_node = mdHandleWeakClone(document_handle);
	mdHandleVectorPush(&((MdNode *)document)->child_nodes, doctype_handle);

	mdHandleDestroy(doctype_handle);
	mdHandleDestroy(document_handle);
}


H5A_SINK_CALLBACK_ATTR
static void
mdSinkRemoveFromParent (H5aSink *self, H5aHandle target)
{
  (void) self;
  (void) target;
}


H5A_SINK_CALLBACK_ATTR
static void
mdSinkReparentChildren (H5aSink *self, H5aHandle node, H5aHandle new_parent)
{
  (void) self;
  (void) node;
  (void) new_parent;
}


H5A_SINK_CALLBACK_ATTR
static H5aTag
mdSinkGetTagByName (H5aSink *self, H5aStringView name)
{
  (void) self;

  for (H5aTag t = 0; t < NUM_H5A_TAGS; ++t)
    if (k_html_tags_table[t] != NULL
     && strcmp(k_html_tags_table[t], name.data) == 0)
      return t;

  return H5A_PLACEHOLDER_TAG;
}


H5A_SINK_CALLBACK_ATTR
static void
mdSinkDestroyHandle (H5aSink *self, H5aHandle handle)
{
  (void) self;

  mdHandleDestroy( mdH5aHandleToMd(handle) );
}


H5A_SINK_CALLBACK_ATTR
[[nodiscard]]
static H5aHandle
mdSinkCloneHandle (H5aSink *self, H5aHandle handle)
{
  (void) self;
  return mdMdHandleToH5a( mdHandleClone( mdH5aHandleToMd(handle) ) );
}


int
main (int argc, char *argv[])
{
  if (argc != 2)
    usage(argv[0]);

  char const *file_name = argv[1];
  MdInputStream stream = { 0 };
  alignas(size_t) uint8_t parser_mem[k_h5a_parserSize];
  H5aParser *parser = (H5aParser *)(parser_mem);

  MdSink sink = { 0 };
  mdSinkCreate(&sink);

  mdInputStreamCreate(&stream, file_name);

  H5aParserCreateInfo parser_create_info = {
    .input_get_char = mdInputStreamGetChar,
    .input_user_data = (void *)(&stream),
    .sink_vtable = &k_minidom_sink_vtable,
    .sink_user_data = (H5aSink *)(&sink),
  };

  h5aCreateParser(&parser_create_info, parser);
    h5aResumeParser(parser);
  h5aDestroyParser(parser);

  mdInputStreamDestroy(&stream);
  mdSinkDestroy(&sink);

  return EXIT_SUCCESS;
}

