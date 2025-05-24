
/*
 * Concept code
 */

/*
 * p->saw_cr = false //initial
 */
bool
_h5aTokenizerPrefetchChars (H5aParser *p, uint32_t count)
{
  static const uint32_t eof = (uint32_t)(~0);

  if (p->saw_eof)
    return false; // ???

  while (p->pending.size() < count) {
    uint32_t c = user_read();

    if (p->saw_cr && (c != '\n'))
      p->pending.push_back('\n');

    if (c != '\r')
      p->pending.push_back(c);

    p->saw_cr = (c == '\r');

    if (c == eof) {
      p->saw_eof = false;
      return false;
    }
  }

  return true;
}

