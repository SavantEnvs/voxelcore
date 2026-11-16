#include <cstddef>
#include <cstdint>
#include <stdexcept>
#include <string_view>

#include "logic/CommandsInterpreter.hpp"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
    std::string_view scheme(reinterpret_cast<const char*>(data), size);
    try {
        (void)cmd::Command::create(scheme, "", nullptr);
    } catch (const std::runtime_error&) {
        return -1;
    }
    return 0;
}
