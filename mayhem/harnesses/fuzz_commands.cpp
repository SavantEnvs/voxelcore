#include <cstddef>
#include <cstdint>
#include <stdexcept>
#include <string_view>

#include "logic/CommandsInterpreter.hpp"

// Console schemes registered by res/scripts/stdcmd.lua.
static const char* const SCHEMES[] = {
    "clear",
    "help name:str=''",
    "time.uptime",
    "tp entity:sel=$entity.id x:num~pos.x y:num~pos.y z:num~pos.z",
    "echo value:str",
    "time.set value:num",
    "time.daycycle operation:[stop|reset]",
    "blocks.fill id:str x1:int~pos.x y1:int~pos.y z1:int~pos.z "
    "x2:int~pos.x y2:int~pos.y z2:int~pos.z",
    "player.respawn player:sel=$obj.id",
    "entity.spawn name:str x:num~pos.x y:num~pos.y z:num~pos.z",
    "entity.despawn entity:sel=$entity.selected",
    "fragment.place file:str x:num~pos.x y:num~pos.y z:num~pos.z rotation:int=0",
    "rule.set name:str value:bool",
};

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
    // A fresh interpreter per input: parsing a "$name" argument inserts the
    // variable into the interpreter, so a shared one would grow across inputs.
    cmd::CommandsInterpreter interpreter;
    auto repo = interpreter.getRepository();
    for (const char* scheme : SCHEMES) {
        repo->add(scheme, "", nullptr);
    }
    std::string_view text(reinterpret_cast<const char*>(data), size);
    try {
        (void)interpreter.parse(text);
    } catch (const std::runtime_error&) {
        return -1;
    }
    return 0;
}
