#include <cstddef>
#include <cstdint>
#include <string_view>

#include "util/stringutil.hpp"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
    std::string_view text(reinterpret_cast<const char*>(data), size);
    auto decoded = util::base64_decode(text);
    (void)util::base64_encode(decoded.data(), decoded.size());
    auto urlsafe = util::base64_urlsafe_decode(text);
    (void)util::base64_urlsafe_encode(urlsafe.data(), urlsafe.size());
    return 0;
}
