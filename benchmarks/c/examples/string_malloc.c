/*$
 * requires: n > 0;
 * local:    void *addr = new Memory;
 * ensures:  size(addr) == n;
 * ensures:  return == addr;
 */
void *malloc(unsigned int n);

/*$
 * requires: exists unsigned int k in [0, size(s) - 1]: s[k] == 0;
 *
 * case "empty string" {
 *   assumes: s[0] == 0;
 *   ensures: return == 0;
 * }
 *
 * case "non empty string" {
 *   assumes: s[0] != 0;
 *   ensures: return in [1, size(s) - 1];
 *   ensures: s[return] == 0;
 *   ensures: forall unsigned int k in [0, return - 1]: s[k] != 0;
 * }
 *
 */
unsigned int strlen(unsigned char*s);

void main() {
  unsigned char *s = (unsigned char *) malloc(10);
  unsigned int n = _mopsa_range_int(0, 9), i;

  for(i = 0; i < n; i ++) {
    s[i] = 'a';
  }
  s[i] = '\0';

  int l = strlen(s);
  _mopsa_print();
}
