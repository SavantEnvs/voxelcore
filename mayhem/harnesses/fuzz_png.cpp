#include <cstddef>
#include <cstdint>
#include <stdexcept>

#include "coders/png.hpp"
#include "graphics/core/ImageData.hpp"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
    try {
        auto image = png::load_image(data, size);
        (void)png::encode_image(*image);
    } catch (const std::runtime_error&) {
        return -1;
    }
    return 0;
}
