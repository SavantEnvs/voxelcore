#include <cstddef>
#include <cstdint>
#include <stdexcept>
#include <string_view>

#include "coders/obj.hpp"
#include "graphics/commons/Model.hpp"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
    std::string_view source(reinterpret_cast<const char*>(data), size);
    try {
        (void)obj::parse("fuzz.obj", source);
    } catch (const std::runtime_error&) {
        return -1;
    }
    return 0;
}
