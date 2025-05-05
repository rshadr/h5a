#ifndef __h5a_h__
#define __h5a_h__

#include <stddef.h>
#include <stdint.h>
#include <uchar.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct H5aParserCreateInfo_s {
  char32_t (*get_char) (void *user_data);
  void *user_data;
} H5aParserCreateInfo;

#if __STDC_VERSION__ >= 202000 || defined(__cplusplus)
typedef enum : uint32_t {
#else
typedef enum {
#endif
  H5A_SUCCESS = 0,
  H5A_FAILURE = 1,
  H5A_PAUSED  = 2,
} H5aResult;


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

  /* ... */
} H5aTag;

/* opaque */
typedef struct H5aParser_s H5aParser;

extern const size_t k_h5a_parserSize;

H5aResult h5aCreateParser (H5aParserCreateInfo const *create_info,
                           H5aParser *parser);
H5aResult h5aDestroyParser (H5aParser *parser);
H5aResult h5aResumeParser (H5aParser *parser);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* !defined(__h5a_h__) */

