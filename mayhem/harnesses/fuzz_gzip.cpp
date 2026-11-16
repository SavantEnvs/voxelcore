#include <cstddef>
#include <cstdint>
#include <cstring>
#include <stdexcept>

#include "coders/gzip.hpp"

// gzip::decompress reads its output size from the last 4 bytes of the input (the ISIZE footer), so an
// input shorter than 4 bytes has no footer and is rejected. A footer claiming more than 1 MiB is rejected
// too: the library allocates that many bytes up front, so it would only exhaust memory. Header magic and
// minimum length are left to zlib.
extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
    if (size < 4) {
        return -1;
    }
    uint32_t isize;
    std::memcpy(&isize, data + size - 4, sizeof isize);
    if (isize > (1u << 20)) {
        return -1;
    }
    try {
        (void)gzip::decompress(data, size);
    } catch (const std::runtime_error&) {
        return -1;
    }
    return 0;
}
