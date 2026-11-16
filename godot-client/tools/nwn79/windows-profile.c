#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <wincrypt.h>
#include <bcrypt.h>
#include <shlobj.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <io.h>

static int read_input(BYTE **data, DWORD *size) {
    BYTE *buffer = (BYTE *)malloc(65536);
    if (!buffer) return 0;
    size_t count = fread(buffer, 1, 65536, stdin);
    if (ferror(stdin) || count == 65536 || count == 0) {
        SecureZeroMemory(buffer, 65536); free(buffer); return 0;
    }
    *data = buffer; *size = (DWORD)count; return 1;
}

static int exact_read(HANDLE pipe, BYTE *data, DWORD size) {
    DWORD done = 0, got = 0;
    while (done < size) {
        if (!ReadFile(pipe, data + done, size - done, &got, NULL) || !got) return 0;
        done += got;
    }
    return 1;
}

static int exact_write(HANDLE pipe, const BYTE *data, DWORD size) {
    DWORD done = 0, put = 0;
    while (done < size) {
        if (!WriteFile(pipe, data + done, size - done, &put, NULL) || !put) return 0;
        done += put;
    }
    return 1;
}

static DWORD little_u32(const BYTE *data) {
    return (DWORD)data[0] | (DWORD)data[1] << 8 | (DWORD)data[2] << 16 | (DWORD)data[3] << 24;
}

/* Chromium v10: DPAPI-wrapped 32-byte key, then AES-256-GCM nonce/body/tag.
   The caller supplies only ciphertext; neither key nor plaintext is logged. */
static int decrypt_chromium(const BYTE *input, DWORD size, BYTE **plain, DWORD *plain_size) {
    BCRYPT_ALG_HANDLE algorithm = NULL;
    BCRYPT_KEY_HANDLE cipher_key = NULL;
    DATA_BLOB wrapped = { 0, NULL }, master = { 0, NULL };
    BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO auth;
    BYTE *key_object = NULL, *result = NULL;
    DWORD key_object_size = 0, property_size = 0, written = 0;
    DWORD wrapped_size, blob_size, body_size;
    const BYTE *blob;
    int ok = 0;
    if (size < 4) return 0;
    wrapped_size = little_u32(input);
    if (wrapped_size < 16 || wrapped_size > size - 4) return 0;
    blob = input + 4 + wrapped_size;
    blob_size = size - 4 - wrapped_size;
    if (blob_size < 3 + 12 + 16 || memcmp(blob, "v10", 3) != 0) return 0;
    body_size = blob_size - 3 - 12 - 16;
    wrapped.cbData = wrapped_size; wrapped.pbData = (BYTE *)(input + 4);
    if (!CryptUnprotectData(&wrapped, NULL, NULL, NULL, NULL, CRYPTPROTECT_UI_FORBIDDEN, &master) || master.cbData != 32) goto cleanup;
    if (BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_AES_ALGORITHM, NULL, 0) != 0) goto cleanup;
    if (BCryptSetProperty(algorithm, BCRYPT_CHAINING_MODE, (PUCHAR)BCRYPT_CHAIN_MODE_GCM, sizeof(BCRYPT_CHAIN_MODE_GCM), 0) != 0) goto cleanup;
    if (BCryptGetProperty(algorithm, BCRYPT_OBJECT_LENGTH, (PUCHAR)&key_object_size, sizeof(key_object_size), &property_size, 0) != 0 || key_object_size == 0 || key_object_size > 65536) goto cleanup;
    key_object = (BYTE *)malloc(key_object_size);
    result = (BYTE *)malloc((size_t)body_size + 1);
    if (!key_object || !result) goto cleanup;
    if (BCryptGenerateSymmetricKey(algorithm, &cipher_key, key_object, key_object_size, master.pbData, master.cbData, 0) != 0) goto cleanup;
    BCRYPT_INIT_AUTH_MODE_INFO(auth);
    auth.pbNonce = (PUCHAR)(blob + 3); auth.cbNonce = 12;
    auth.pbTag = (PUCHAR)(blob + blob_size - 16); auth.cbTag = 16;
    if (BCryptDecrypt(cipher_key, (PUCHAR)(blob + 15), body_size, &auth, NULL, 0, result, body_size, &written, 0) != 0 || written == 0 || written > 65536) goto cleanup;
    *plain = result; *plain_size = written; result = NULL; ok = 1;
cleanup:
    if (result) { SecureZeroMemory(result, (size_t)body_size + 1); free(result); }
    if (cipher_key) BCryptDestroyKey(cipher_key);
    if (key_object) { SecureZeroMemory(key_object, key_object_size); free(key_object); }
    if (algorithm) BCryptCloseAlgorithmProvider(algorithm, 0);
    if (master.pbData) { SecureZeroMemory(master.pbData, master.cbData); LocalFree(master.pbData); }
    return ok;
}

static int serve(void) {
    HANDLE in = GetStdHandle(STD_INPUT_HANDLE), out = GetStdHandle(STD_OUTPUT_HANDLE);
    BYTE *input = (BYTE *)malloc(65536);
    if (!input) return 3;
    for (;;) {
        BYTE header[5];
        DWORD length;
        DATA_BLOB source, output = { 0, NULL };
        BYTE reply[5];
        if (!exact_read(in, header, 5)) break;
        length = little_u32(header);
        if (length == 0 || length > 65536 || (header[4] != 1 && header[4] != 2 && header[4] != 3) || !exact_read(in, input, length)) break;
        source.cbData = length; source.pbData = input;
        BYTE *legacy_plain = NULL;
        DWORD legacy_length = 0;
        BOOL ok = header[4] == 1
            ? CryptProtectData(&source, L"NWN native client", NULL, NULL, NULL, CRYPTPROTECT_UI_FORBIDDEN, &output)
            : header[4] == 2
                ? CryptUnprotectData(&source, NULL, NULL, NULL, NULL, CRYPTPROTECT_UI_FORBIDDEN, &output)
                : decrypt_chromium(input, length, &legacy_plain, &legacy_length);
        DWORD reply_length = ok && (header[4] == 3 ? legacy_length : output.cbData) <= 65536 ? (header[4] == 3 ? legacy_length : output.cbData) : 0;
        reply[0] = (BYTE)reply_length; reply[1] = (BYTE)(reply_length >> 8);
        reply[2] = (BYTE)(reply_length >> 16); reply[3] = (BYTE)(reply_length >> 24);
        reply[4] = reply_length ? 0 : 1;
        int written = exact_write(out, reply, 5) && (!reply_length || exact_write(out, header[4] == 3 ? legacy_plain : output.pbData, reply_length));
        SecureZeroMemory(input, length);
        if (legacy_plain) { SecureZeroMemory(legacy_plain, legacy_length); free(legacy_plain); }
        if (output.pbData) { SecureZeroMemory(output.pbData, output.cbData); LocalFree(output.pbData); }
        if (!written) break;
    }
    SecureZeroMemory(input, 65536); free(input);
    return 0;
}

int main(int argc, char **argv) {
    if (argc != 2) return 2;
    if (strcmp(argv[1], "serve") == 0) return serve();
    if (strcmp(argv[1], "documents") == 0) {
        PWSTR wide = NULL;
        if (SHGetKnownFolderPath(&FOLDERID_Documents, 0, NULL, &wide) != S_OK) return 3;
        int size = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, wide, -1, NULL, 0, NULL, NULL);
        char *utf8 = size ? (char *)malloc((size_t)size) : NULL;
        int result = 3;
        if (utf8 && WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, wide, -1, utf8, size, NULL, NULL) && fwrite(utf8, 1, (size_t)size - 1, stdout) == (size_t)size - 1) result = 0;
        free(utf8); CoTaskMemFree(wide); return result;
    }
    if (strcmp(argv[1], "protect") != 0 && strcmp(argv[1], "unprotect") != 0) return 2;
    if (_setmode(_fileno(stdin), _O_BINARY) == -1 || _setmode(_fileno(stdout), _O_BINARY) == -1) return 3;
    BYTE *input = NULL; DWORD size = 0;
    if (!read_input(&input, &size)) return 3;
    DATA_BLOB source = { size, input }, output = { 0, NULL };
    BOOL ok = strcmp(argv[1], "protect") == 0
        ? CryptProtectData(&source, L"NWN native client", NULL, NULL, NULL, CRYPTPROTECT_UI_FORBIDDEN, &output)
        : CryptUnprotectData(&source, NULL, NULL, NULL, NULL, CRYPTPROTECT_UI_FORBIDDEN, &output);
    int result = 3;
    if (!ok) fprintf(stderr, "Windows profile protection failed (code %lu)\n", GetLastError());
    if (ok && output.cbData <= 65536 && fwrite(output.pbData, 1, output.cbData, stdout) == output.cbData) result = 0;
    SecureZeroMemory(input, 65536); free(input);
    if (output.pbData) { SecureZeroMemory(output.pbData, output.cbData); LocalFree(output.pbData); }
    return result;
}
