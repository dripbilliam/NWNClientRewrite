#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <wincrypt.h>
#include <stdlib.h>
#include <string.h>

#define MAX_PAYLOAD 65536

static int read_exact(HANDLE pipe, BYTE *data, DWORD size) {
    while (size) {
        DWORD count = 0;
        if (!ReadFile(pipe, data, size, &count, NULL) || !count) return 0;
        data += count;
        size -= count;
    }
    return 1;
}

static int write_exact(HANDLE pipe, const BYTE *data, DWORD size) {
    while (size) {
        DWORD count = 0;
        if (!WriteFile(pipe, data, size, &count, NULL) || !count) return 0;
        data += count;
        size -= count;
    }
    return 1;
}

int main(int argc, char **argv) {
    BYTE header[5];
    DWORD size;
    DWORD reply_size;
    DATA_BLOB input;
    DATA_BLOB output = {0, NULL};
    HANDLE in = GetStdHandle(STD_INPUT_HANDLE);
    HANDLE out = GetStdHandle(STD_OUTPUT_HANDLE);
    BOOL ok;
    int written;

    if (argc != 2 || strcmp(argv[1], "serve") || !read_exact(in, header, sizeof(header))) return 2;
    size = (DWORD)header[0] | (DWORD)header[1] << 8 | (DWORD)header[2] << 16 | (DWORD)header[3] << 24;
    if (!size || size > MAX_PAYLOAD || (header[4] != 1 && header[4] != 2)) return 2;
    input.cbData = size;
    input.pbData = (BYTE *)malloc(size);
    if (!input.pbData) return 3;
    ok = FALSE;
    if (read_exact(in, input.pbData, size)) {
        ok = header[4] == 1
            ? CryptProtectData(&input, L"NWN native client", NULL, NULL, NULL, CRYPTPROTECT_UI_FORBIDDEN, &output)
            : CryptUnprotectData(&input, NULL, NULL, NULL, NULL, CRYPTPROTECT_UI_FORBIDDEN, &output);
    }
    SecureZeroMemory(input.pbData, size);
    free(input.pbData);
    reply_size = ok && output.cbData <= MAX_PAYLOAD ? output.cbData : 0;
    header[0] = (BYTE)reply_size;
    header[1] = (BYTE)(reply_size >> 8);
    header[2] = (BYTE)(reply_size >> 16);
    header[3] = (BYTE)(reply_size >> 24);
    header[4] = reply_size ? 0 : 1;
    written = write_exact(out, header, sizeof(header)) && (!reply_size || write_exact(out, output.pbData, reply_size));
    if (output.pbData) {
        SecureZeroMemory(output.pbData, output.cbData);
        LocalFree(output.pbData);
    }
    return written ? 0 : 4;
}
