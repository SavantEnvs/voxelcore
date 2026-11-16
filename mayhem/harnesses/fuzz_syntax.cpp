#include <cstddef>
#include <cstdint>
#include <stdexcept>
#include <string_view>

#include "coders/syntax_parser.hpp"
#include "util/stringutil.hpp"

static devtools::Syntax make_lua_syntax() {
    devtools::Syntax syntax;
    syntax.language = "lua";
    syntax.extensions = {".lua"};
    syntax.keywords = {L"and",   L"break", L"do",       L"else",  L"elseif",
                       L"end",   L"false", L"for",      L"function", L"if",
                       L"in",    L"local", L"nil",      L"not",   L"or",
                       L"repeat", L"return", L"then",   L"true",  L"until",
                       L"while"};
    syntax.lineComment = L"--";
    syntax.multilineCommentStart = L"--[[";
    syntax.multilineCommentEnd = L"]]";
    syntax.multilineStringStart = L"[[";
    syntax.multilineStringEnd = L"]]";
    syntax.identifierStarts = L"_";
    syntax.identifierParts = L"_";
    return syntax;
}

static const devtools::Syntax SYNTAX = make_lua_syntax();

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
    std::string_view utf8(reinterpret_cast<const char*>(data), size);
    try {
        auto source = util::str2wstr_utf8(utf8);
        (void)devtools::tokenize(SYNTAX, "fuzz.lua", source);
    } catch (const std::runtime_error&) {
        return -1;
    }
    return 0;
}
