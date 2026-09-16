#include "ZipInflate.h"
#include <zlib.h>
#include <limits.h>

int edge_inflate_raw(const uint8_t *input, size_t inputLength, uint8_t *output, size_t outputLength) {
    if (inputLength > UINT_MAX || outputLength > UINT_MAX) return -1;
    z_stream stream = {0};
    stream.next_in = (Bytef *)input;
    stream.avail_in = (uInt)inputLength;
    stream.next_out = output;
    stream.avail_out = (uInt)outputLength;
    if (inflateInit2(&stream, -MAX_WBITS) != Z_OK) return -1;
    int status = inflate(&stream, Z_FINISH);
    int result = (status == Z_STREAM_END && stream.total_out == outputLength && stream.total_in == inputLength) ? 0 : -1;
    inflateEnd(&stream);
    return result;
}

uint32_t edge_crc32(const uint8_t *input, size_t length) {
    return (uint32_t)crc32(0, input, (uInt)length);
}
