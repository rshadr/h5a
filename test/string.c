#include <stddef.h>
#include <uchar.h>
#include <stdint.h>
#include <stdarg.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <stdlib.h>
#include <stdio.h>

#include <grapheme.h>
#include <h5a.h>

struct hstring {
  char *data;
  uint32_t size;
  uint32_t capacity;
};

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
extern void _h5aStringCreate (struct hstring *);
extern void _h5aStringDestroy (struct hstring *);
extern void _h5aStringMaybeGrow (struct hstring *);
extern void _h5aStringPushBackAscii (struct hstring *, char8_t c);
extern void _h5aStringPushBackUnicode (struct hstring *, char32_t c);


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
  (void) argc;
  (void) argv;

  struct hstring s = { 0 };
  _h5aStringCreate(&s);
  _h5aStringPushBackUnicode(&s, U'€');
  _h5aStringPushBackUnicode(&s, U'€');
  _h5aStringPushBackUnicode(&s, U'€');
  _h5aStringPushBackAscii(&s, 'a');
  _h5aStringPushBackAscii(&s, 'a');
  _h5aStringPushBackAscii(&s, 'a');
  _h5aStringPushBackAscii(&s, 'a');
  _h5aStringPushBackAscii(&s, 'a');
  _h5aStringPushBackAscii(&s, 'a');

  printf("string value: %s\n", s.data);
  _h5aStringDestroy(&s);

  return 0;
}

