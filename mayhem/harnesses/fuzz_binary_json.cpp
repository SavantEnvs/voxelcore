#include <cstddef>
#include <cstdint>
#include <stdexcept>

#include "coders/binary_json.hpp"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
    try {
        auto value = json::from_binary(data, size);
        auto encoded = json::to_binary(value, false);
        (void)json::from_binary(encoded.data(), encoded.size());
    } catch (const std::runtime_error&) {
        return -1;
    }
    return 0;
}
