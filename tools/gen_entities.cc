#include <vector>
#include <string>

#include <stdarg.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <stdlib.h>
#include <stdio.h>
#include "jsmn.h"


static const int MAX_TOKENS = 100000;


static void
die (char const *fmt, ...)
{
  va_list ap;

  va_start(ap, fmt);
  vfprintf(stderr, fmt, ap);
  va_end(ap);

  exit(1);
}


static void
usage (char const *argv0)
{
  die("usage: %s <entities.json>\n", argv0);
}


static bool
is_entity_name (char const *src, jsmntok_t *tok)
{
  return (tok->type == JSMN_STRING
       && (tok->end - tok->start) > 2
       && (src + tok->start)[0] == '&');
}


static bool
is_expanded_entity (char const *src, jsmntok_t *tok)
{
  return (tok->type == JSMN_STRING
       && (tok->end - tok->start) >= 6
       && (src + tok->start)[0] == '\\'
       && (src + tok->start)[1] == 'u');
}


static void
process (char const *src, size_t srclen)
{
  int r;
  jsmn_parser p;
  jsmntok_t *tp;

  jsmn_init(&p);
  tp = (jsmntok_t *)(calloc(MAX_TOKENS, sizeof(jsmntok_t)));

  r = jsmn_parse(&p, src, srclen, tp, MAX_TOKENS);

  if (r < 0)
    die("failed to parse JSON\n");

  if (r < 1 || tp[0].type != JSMN_OBJECT)
    die("object expected\n");

  int entity_count = 0;
  std::vector<std::string> names;
  std::vector<int> sizes;

  printf(";;;;\n"
         ";;;; Autogenerated file. Do not change if clueless!\n"
         ";;;;\n"
         "\n"
         "format ELF64\n\n");

  printf("section '.rodata'\n\n");

  printf("public _k_h5a_entityValues\n");
  printf("label _k_h5a_entityValues\n");
  for (int i = 1; i < r; ++i)
  {
    jsmntok_t *tname = NULL;
    jsmntok_t *tval = NULL;

    while (i < r && !is_entity_name(src, &tp[i]))
      ++i;
    tname = &tp[i];
    
    while (i < r && !is_expanded_entity(src, &tp[i]))
      ++i;
    tval = &tp[i];

    if (! tname && tval )
      break;

    ++entity_count;

    char entname[128] = { 0 };
    size_t entname_len = tname->end - tname->start - 1;
    memcpy((void *)(entname), src + tname->start + 1, entname_len);
    //printf("entity: %s\n", entname);
    names.push_back(entname);

    int cplen = (tval->end - tval->start) / 6; // \uXXXX
    sizes.push_back(cplen);

    printf("  ; &%s\n", entname);

    for (int cidx = 0; cidx < cplen; ++cidx) {
      char ucval[5] = { 0 };
      for (int j = 0; j < 4; ++j)
        ucval[j] = (src + tval->start + cidx*6 + 2)[j];
      printf("  dw 0x%s\n", ucval);
    }

    for (int j = 0; j < 2 - cplen; ++j)
      printf("  dw 0x0000\n");
  }
  printf("\n\n");

  printf("public _k_h5a_entityTable\n");
  printf("label _k_h5a_entityTable\n");
  for (int ent_idx = 0; ent_idx < entity_count; ++ent_idx)
  {
    printf("  ; &%s\n", names[ent_idx].c_str());
    printf("  dq _k_h5a_entity%d_key\n", ent_idx);
    printf("  dd %d\n", (int)(names[ent_idx].size()));
    printf("  dd %d\n", sizes[ent_idx]);
  }
  printf("\n\n");
  printf(";;;;\n"
         ";;;; Entity keys\n"
         ";;;;\n");
  printf("\n");

  for (int ent_idx = 0; ent_idx < entity_count; ++ent_idx)
  {
    printf("label _k_h5a_entity%d_key\n", ent_idx);
    printf("db ");
    for (char c : names[ent_idx])
      printf("0x%02x, ", (int)(c));
    printf("0x00\n");
  }

  printf("public _k_h5a_numEntities\n");
  printf("label _k_h5a_numEntities\n");
  printf("dd %d\n", entity_count);

  free(tp);
}


int
main (int argc, char *argv[])
{
  if (argc != 2)
    usage(argv[0]);

  char const *file_name = argv[1];
  int fd = open(file_name, O_RDONLY);
  if (fd == -1)
    die("error: couldn't open file '%s'\n", file_name);

  struct stat st;
  if (fstat(fd, &st) == -1)
    die("error: couldn't stat file '%s'\n", file_name);

  size_t file_size = st.st_size;
  char *file_data = (char *)(mmap(NULL, file_size, PROT_READ, MAP_PRIVATE, fd, 0));

  if (file_data == (char *)(MAP_FAILED))
    die("error: couldn't map file contents '%s'\n", file_name);

  process(file_data, file_size);

  close(fd);
  //madvise(file_data, file_size, MADV_SEQUENTIAL);
  munmap(file_data, file_size);

  return 0;
}

