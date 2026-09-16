#pragma once
#include <stdint.h>
#include <stddef.h>

// Returns 0 only when exactly outputLength bytes were inflated.
int edge_inflate_raw(const uint8_t *input, size_t inputLength, uint8_t *output, size_t outputLength);
uint32_t edge_crc32(const uint8_t *input, size_t length);
