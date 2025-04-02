#include <stddef.h>
#include <uchar.h>
#include <stdarg.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <stdlib.h>
#include <stdio.h>

#include <grapheme.h>
#include <h5a.h>

typedef struct CharacterQueue_s {
  char32_t *data;
  uint32_t size;
  uint32_t capacity;
  int32_t front_idx;
  int32_t back_idx;
} CharacterQueue;

extern void _CharacterQueueConstruct (CharacterQueue *cqueue);
extern void _CharacterQueueDestroy (CharacterQueue *cqueue);
extern char32_t _CharacterQueuePushBack (CharacterQueue *cqueue, char32_t c);

struct PopResult {
  char32_t c;
  bool was_popped;
};

extern struct PopResult _CharacterQueuePopFront (CharacterQueue *queue);


typedef struct {
  char *p;
  char *end;

  char *file_data;
  char const *file_name;
  size_t file_size;

  size_t read_counter;
} UserBuffer;


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
  die("usage: %s [file]\n", argv0);
}

static void
createUserBuffer (UserBuffer *buffer, char const *file_name)
{
  int fd = open(file_name, O_RDONLY);
  if (fd == -1)
    die("error: couldn't open file '%s'\n", file_name);

  struct stat st;
  if (fstat(fd, &st) == -1)
    die("error: couldn't stat file'%s'\n", file_name);

  size_t file_size = st.st_size;
  char *file_data = mmap(NULL, file_size, PROT_READ, MAP_PRIVATE, fd, 0);

  if (file_data == (char *)(MAP_FAILED))
    die("error: couldn't map file '%s'\n", file_name);

  close(fd);
  // madvise(file_data, file_size, MADV_SEQUENTIAL);

  (*buffer) = (UserBuffer) {
    .p = file_data,
    .end = file_data + file_size,
    .file_data = file_data,
    .file_size = file_size,
    .file_name = file_name,
  };

}


static void
destroyUserBuffer (UserBuffer *buffer)
{
  if (munmap(buffer->file_data, buffer->file_size) == -1)
    die("error: couldn't unmap file '%s'\n", buffer->file_name);
}


static char32_t
getChar (void *user_data)
{
  static const char32_t eof = ~(char32_t)(0);

  UserBuffer *buffer = user_data;

  size_t left = (buffer->end - buffer->p);
  size_t read;
  char32_t c = {0xFFFD};

  if (left > 0 && *buffer->p == '\0')
    return (char32_t)(*buffer->p++);

  if (!left || !(read = grapheme_decode_utf8(buffer->p,
                         left, (uint_least32_t *)(&c)))) {
    return eof;
  }

  buffer->read_counter += 1;
  buffer->p += read;
  return c;
}


int
main (int argc, char *argv[])
{
  if (argc != 2)
    usage(argv[0]);

  char const *file_name = argv[1];
  UserBuffer user_buffer = { 0 };
  uint8_t parser_mem[k_h5a_parserSize];
  H5aParser *parser = (H5aParser *)(parser_mem);

  const H5aParserCreateInfo create_info = {
    .get_char = getChar,
    .user_data = &user_buffer,
  };

  createUserBuffer(&user_buffer, file_name);

#if 0
  h5aCreateParser(&create_info, parser);
    h5aResumeParser(parser);
  h5aDestroyParser(parser);
#else
  CharacterQueue cqueue = { 0 };
  _CharacterQueueConstruct(&cqueue);

  _CharacterQueuePushBack(&cqueue, U'y');
  _CharacterQueuePushBack(&cqueue, U'e');
  _CharacterQueuePushBack(&cqueue, U's');

  struct PopResult res = _CharacterQueuePopFront(&cqueue);

  _CharacterQueueDestroy(&cqueue);
#endif

  destroyUserBuffer(&user_buffer);

  return 0;
}

