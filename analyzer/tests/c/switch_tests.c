#include "mopsa.h"


void test_int_condition() {
  int i = 2;
  int j;
  switch (i * 2) {
  case 0: j = 10; break;
  case 2: j = 20; break;
  case 4: j = 30; break;
  case 6: j = 40; break;
  default: j = 40;
  }
  _mopsa_assert_true(j == 30);
}

void test_char_condition() {
  char *s = "abcd";
  int i = 2, j;
  switch (s[i]) {
  case 'a': j = 0; break;
  case 'b': j = 10; break;
  case 'c': j = 20; break;
  case 'd': j = 30; break;
  default: j = 40;
  }
  _mopsa_assert_true(j == 20);
}

void test_default_case() {
  int i = 2, j;
  switch (i * 5) {
  case 0: j = 10; break;
  case 1: j = 20; break;
  case 2: j = 30; break;
  case 3: j = 40; break;
  default: j = 50;
  }
  _mopsa_assert_true(j == 50);
}

void test_case_with_no_break() {
  int i = 2, j = 0;
  switch (i * 5) {
  case 0: j = j + 1; 
  case 5: j = j + 2;
  case 10: j = j + 3;
  case 15: j = j + 4; break;
  default: j = -1;
  }
  _mopsa_assert_true(j == 7);
}

void test_no_default() {
  int i = 2, j = 0;
  switch (i * 5) {
  case 0: j = 10; break; 
  case 1: j = 20; break;
  case 2: j = 30; break;
  case 3: j = 40; break;
  }
  _mopsa_assert_true(j == 0);
}