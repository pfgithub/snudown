#include <stdarg.h>
#include <stddef.h>
#include <string.h>

int va_get_int(va_list *arg) { return va_arg(*arg, int); }

// must support %c (char) and %d (number). others can panic.
int vsnprintf_zig(char *s, size_t n, const char *format, const va_list *arg);
int vsnprintf(char *s, size_t n, const char *format, va_list arg) {
  return vsnprintf_zig(s, n, format, (void*)&arg);
}