#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include "Shared/BridgingHeader.h"

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <hwp_file>\n", argv[0]);
        return 1;
    }

    // Read file
    FILE *f = fopen(argv[1], "rb");
    if (!f) {
        fprintf(stderr, "Cannot open file: %s\n", argv[1]);
        return 1;
    }
    fseek(f, 0, SEEK_END);
    long fsize = ftell(f);
    fseek(f, 0, SEEK_SET);

    uint8_t *data = malloc(fsize);
    fread(data, 1, fsize, f);
    fclose(f);

    printf("File size: %ld bytes\n", fsize);

    // Test hwp_parse_to_html
    char *html = NULL;
    uintptr_t html_len = 0;
    int32_t result = hwp_parse_to_html(data, (uintptr_t)fsize, &html, &html_len);
    printf("hwp_parse_to_html result: %d\n", result);

    if (result == 0 && html) {
        printf("HTML length: %lu bytes\n", (unsigned long)html_len);
        printf("HTML preview (first 500 chars):\n%.500s\n...\n", html);

        // Save to file
        FILE *out = fopen("/tmp/hwp_test_output.html", "w");
        if (out) {
            fwrite(html, 1, html_len, out);
            fclose(out);
            printf("\nFull HTML saved to: /tmp/hwp_test_output.html\n");
        }
        hwp_free_string(html);
    }

    // Test hwp_get_preview_image
    uint8_t *img_data = NULL;
    uintptr_t img_len = 0;
    char *img_format = NULL;
    result = hwp_get_preview_image(data, (uintptr_t)fsize, &img_data, &img_len, &img_format);
    printf("\nhwp_get_preview_image result: %d\n", result);

    if (result == 0 && img_data) {
        printf("Image format: %s\n", img_format);
        printf("Image size: %lu bytes\n", (unsigned long)img_len);

        // Save image
        char img_path[256];
        snprintf(img_path, sizeof(img_path), "/tmp/hwp_preview.%s",
                 img_format[0] == 'B' ? "bmp" : "gif");
        FILE *img_out = fopen(img_path, "wb");
        if (img_out) {
            fwrite(img_data, 1, img_len, img_out);
            fclose(img_out);
            printf("Preview image saved to: %s\n", img_path);
        }
        hwp_free_bytes(img_data, img_len);
        hwp_free_string(img_format);
    } else if (result == HWP_ERROR_NO_PREVIEW_IMAGE) {
        printf("No preview image in this file (normal)\n");
    }

    free(data);
    printf("\nAll tests passed!\n");
    return 0;
}
