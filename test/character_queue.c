#include <inttypes.h>
#include <uchar.h>
#include <stdlib.h>
#include <stdio.h>


typedef struct H5aCharacterQueue_s {
  char32_t *data;
  uint32_t size;
  uint32_t capacity;
  uint32_t front_idx;
  uint32_t back_idx;
} H5aCharacterQueue;

extern void _h5aCharacterQueueConstruct (H5aCharacterQueue *queue);
extern void _h5aCharacterQueueDestroy (H5aCharacterQueue *queue);
extern void _h5aCharacterQueueGrow (H5aCharacterQueue *queue);
extern char32_t _h5aCharacterQueuePushFront (H5aCharacterQueue *queue, char32_t c);
extern char32_t _h5aCharacterQueuePushBack (H5aCharacterQueue *queue, char32_t c);
extern char32_t _h5aCharacterQueuePopFront (H5aCharacterQueue *queue);
extern char32_t *_h5aCharacterQueueSubscript (H5aCharacterQueue *queue, uint32_t index);


static void
run_test (void)
{
  H5aCharacterQueue queue;
  _h5aCharacterQueueConstruct(&queue);

  for (char32_t c = U'A'; c <= U'Z'; ++c)
    _h5aCharacterQueuePushBack(&queue, c);

  for (uint32_t i = 0; i <= U'J' - U'A'; ++i)
    _h5aCharacterQueuePopFront(&queue);

  for (char32_t c = U'A'; c <= U'Z'; ++c)
    _h5aCharacterQueuePushBack(&queue, c);

  _h5aCharacterQueueDestroy(&queue);
}


int
main (int argc, char *argv[])
{
  (void) argc;
  (void) argv;

  run_test();

  return EXIT_SUCCESS;
}

