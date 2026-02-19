#ifndef BridgingHeader_h
#define BridgingHeader_h

#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

// Error codes returned by FFI functions
#define HWP_OK 0
#define HWP_ERROR_NULL_POINTER -1
#define HWP_ERROR_PARSE_FAILED -2
#define HWP_ERROR_PANIC -3
#define HWP_ERROR_NO_PREVIEW_IMAGE -4
#define HWP_ERROR_BASE64_DECODE_FAILED -5

// Parse HWP file data and convert to HTML
int32_t hwp_parse_to_html(const uint8_t *data,
                          uintptr_t data_len,
                          char **out_html,
                          uintptr_t *out_len);

// Get preview image from HWP file
int32_t hwp_get_preview_image(const uint8_t *data,
                              uintptr_t data_len,
                              uint8_t **out_data,
                              uintptr_t *out_len,
                              char **out_format);

// Free a string allocated by this library
void hwp_free_string(char *ptr);

// Free a byte buffer allocated by this library
void hwp_free_bytes(uint8_t *ptr,
                    uintptr_t _len);

#endif /* BridgingHeader_h */
