#pragma once
#include "core/variant/dictionary.h"
namespace NwnVisibilityChainCache {
// Cold main-thread-only observation; never called on the renderer thread.
Dictionary snapshot();
}
