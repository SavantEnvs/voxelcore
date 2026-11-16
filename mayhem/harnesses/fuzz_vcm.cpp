#include <cstddef>
#include <cstdint>
#include <stdexcept>
#include <string_view>

#include "coders/vcm.hpp"

// First byte selects the dialect: odd = XML model, even = native VCM text.
extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
    if (size < 2) {
        return -1;
    }
    bool usexml = (data[0] & 1) != 0;
    std::string_view source(reinterpret_cast<const char*>(data + 1), size - 1);
    try {
        auto model = vcm::parse("fuzz.vcm", source, usexml);
        (void)model.squash();
    } catch (const std::runtime_error&) {
        return -1;
    }
    return 0;
}
