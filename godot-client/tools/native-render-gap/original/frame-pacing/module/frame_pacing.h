#pragma once
#include "core/object/ref_counted.h"
#include "core/variant/dictionary.h"
#include <cstdint>

// Absolute process-OS microsecond ticks. These wall spans can overlap and nest;
// CPU time is a separate own-thread, 120-completion window in 100ns units.
namespace NwnFramePacingMetrics {
enum Lane { MAIN, RENDER };
enum Field { SEQUENCE, THREAD_ID, START, PHYSICS_BEGIN, PHYSICS_END, PROCESS_BEGIN, PROCESS_END, SYNC_BEGIN, SYNC_END, DRAW_RETURN, AUDIO_BEGIN, AUDIO_END, DELAY_BEGIN, END, PHYSICS_STEPS, RENDER_DISPATCHES, BEGIN_FRAME_END, SETUP_END, VIEWPORT_BEGIN, VIEWPORT_END, END_FRAME_BEGIN, END_FRAME_END, FIELD_COUNT };
bool enabled();
class Frame {
 Lane lane;
 bool recording=false;
 uint64_t values[FIELD_COUNT];
public:
 explicit Frame(Lane p_lane,uint64_t start=0);
 ~Frame();
 void at(Field field,uint64_t tick);
 void first_at(Field field,uint64_t tick);
 void mark(Field field);
 void add(Field field,uint64_t value=1);
};
}
class NwnFramePacing : public RefCounted {
 GDCLASS(NwnFramePacing,RefCounted);
protected:
 static void _bind_methods();
public:
 static Dictionary snapshot(int max_frames=1024);
};
