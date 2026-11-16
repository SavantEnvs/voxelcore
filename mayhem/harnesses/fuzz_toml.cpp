#include <cstddef>
#include <cstdint>
#include <stdexcept>
#include <string_view>

#include "coders/toml.hpp"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
    std::string_view source(reinterpret_cast<const char*>(data), size);
    try {
        auto value = toml::parse("fuzz.toml", source);
        (void)toml::stringify(value);
    } catch (const std::runtime_error&) {
        return -1;
    }
    return 0;
}
