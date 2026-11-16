#include <cstddef>
#include <cstdint>
#include <stdexcept>
#include <string_view>

#include "coders/json.hpp"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
    std::string_view source(reinterpret_cast<const char*>(data), size);
    try {
        auto value = json::parse("fuzz.json", source);
        (void)json::stringify(value, true);
        (void)json::stringify(value, false, "  ", true);
    } catch (const std::runtime_error&) {
        return -1;
    }
    return 0;
}
