#include <cstddef>
#include <cstdint>
#include <stdexcept>

#include "coders/vec3.hpp"
#include "util/Buffer.hpp"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
    util::Buffer<ubyte> source(data, size);
    try {
        (void)vec3::load("fuzz.vec3", source);
    } catch (const std::runtime_error&) {
        return -1;
    }
    return 0;
}
