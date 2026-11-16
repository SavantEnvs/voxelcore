#include <cstddef>
#include <cstdint>
#include <stdexcept>
#include <string_view>

#include "coders/xml.hpp"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
    std::string_view source(reinterpret_cast<const char*>(data), size);
    try {
        auto document = xml::parse("fuzz.xml", source);
        (void)xml::stringify(*document, true);
        (void)xml::stringify(*document, false);
    } catch (const std::runtime_error&) {
        return -1;
    }
    return 0;
}
