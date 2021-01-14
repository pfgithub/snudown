#include <stdarg.h>
#include <stddef.h>
#include <string.h>

// must support %c (char) and %d (number). others can panic.

void debugprints(char *s, int len);
void debugprinti(int i);
void debugprintc(char c);

void debugprint(char *s);

int va_get_int(va_list *arg) { return va_arg(*arg, int); }

int vsnprintf_zig(char *s, size_t n, const char *format, va_list *arg);
int vsnprintf(char *s, size_t n, const char *format, va_list arg) {
  return vsnprintf_zig(s, n, format, &arg);
}
// int vsnprintf(char *s, size_t n, const char *format, va_list arg) {
//   // int vsnprintf (char * s, size_t n, const char * format, va_list arg );
//   for (int i = 0; i < n; i++) {
//     s[n] = 0;
//   }
//   int i = -1;
//   for (int j = 0; j < n; j++) {
//     i++;
//     s[j] = format[i];
//     if (format[i] == '\0') {
//       break;
//     }
//     debugprint("Printing");
//     debugprintc(format[i]);
//     if (format[i] == '%') {
//       i++;
//       if (format[i] == 'c') {
//         s[j] = va_arg(arg, int);
//       } else if (format[i] == 'd') {
//         debugprint("Note: is %d");
//         int argval = va_arg(arg, int);
//         debugprinti(argval);
//         debugprintc(argval + '0');
//         s[j] = argval + '0';
//       } else {
//         i--;
//         s[j] = format[i];
//       }
//     }
//   }
//   debugprint("Emitted string:");
//   debugprint(s);
// }