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

#if __STDC_VERSION__ >= 202000
typedef enum : uint32_t {
#else
typedef enum {
#endif
  H5A_SUCCESS = 0,
  H5A_FAILURE = 1,
  H5A_PAUSED  = 2,
} H5aResult;

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

