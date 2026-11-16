#include <cstddef>
#include <cstdint>
#include <stdexcept>
#include <vector>

#include "coders/rle.hpp"

// Layout: [codec selector][u16 destination length / 4, masked to at most 4092 bytes][RLE stream...]
extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
    if (size < 3) {
        return -1;
    }
    size_t dstLength = ((static_cast<size_t>(data[1]) | (data[2] << 8)) & 0x3ff) * 4;
    const uint8_t* src = data + 3;
    size_t length = size - 3;
    std::vector<ubyte> dst(dstLength);
    try {
        switch (data[0] & 3) {
            case 0:
                (void)rle::decode(src, length, dst.data(), dstLength);
                break;
            case 1:
                (void)rle::decode16(src, length, dst.data(), dstLength);
                break;
            case 2:
                (void)extrle::decode(src, length, dst.data(), dstLength);
                break;
            default:
                (void)extrle::decode16(src, length, dst.data(), dstLength);
                break;
        }
    } catch (const std::runtime_error&) {
        return -1;
    }
    return 0;
}
