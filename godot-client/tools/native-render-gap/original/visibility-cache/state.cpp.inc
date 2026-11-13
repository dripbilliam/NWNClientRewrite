// NWN_VISIBILITY_CHAIN_EPOCHS_V1. Numeric state only on the query path.
namespace {
struct VisibilityChainState {
 uint64_t epoch=1,queries=0,hits=0,misses=0,walk_steps=0,main_fallbacks=0;
 uint64_t ancestor_hits=0,fills=0,fill_steps=0;
 uint64_t visible_invalidations=0,parent_invalidations=0,overflow_disables=0;
 std::atomic<bool> disabled{false};
 std::atomic<uint64_t> off_main_writes{0},off_main_reads{0};
};
VisibilityChainState visibility_chain;
bool visibility_chain_enabled(){
 static const bool enabled=OS::get_singleton()&&OS::get_singleton()->get_cmdline_user_args().find("--visibility-chain-cache=epochs")!=nullptr;
 return enabled;
}
void visibility_chain_invalidate(bool parent){
 if(!visibility_chain_enabled())return;
 // Release templates omit ERR_MAIN_THREAD_GUARD. Preserve that old path but
 // permanently stop caching BEFORE any unexpected off-main authored write.
 if(!Thread::is_main_thread()){
  visibility_chain.disabled.store(true,std::memory_order_release);
  visibility_chain.off_main_writes.fetch_add(1,std::memory_order_relaxed);
  return;
 }
 if(parent)++visibility_chain.parent_invalidations;else ++visibility_chain.visible_invalidations;
 if(visibility_chain.epoch==UINT64_MAX){
  ++visibility_chain.overflow_disables;
  visibility_chain.disabled.store(true,std::memory_order_release);
  return;
 }
 ++visibility_chain.epoch;
}
}
Dictionary NwnVisibilityChainCache::snapshot(){
 Dictionary out;out["enabled"]=visibility_chain_enabled();out["available"]=Thread::is_main_thread();
 if(!Thread::is_main_thread()){out["scope"]="Cold visibility counters require main thread";return out;}
 out["disabled"]=visibility_chain.disabled.load(std::memory_order_acquire);
 out["epoch"]=int64_t(visibility_chain.epoch);out["queries"]=int64_t(visibility_chain.queries);
 out["hits"]=int64_t(visibility_chain.hits);out["misses"]=int64_t(visibility_chain.misses);
 out["walk_steps"]=int64_t(visibility_chain.walk_steps);out["main_fallbacks"]=int64_t(visibility_chain.main_fallbacks);
 out["ancestor_hits"]=int64_t(visibility_chain.ancestor_hits);out["fills"]=int64_t(visibility_chain.fills);out["fill_steps"]=int64_t(visibility_chain.fill_steps);
 out["visible_invalidations"]=int64_t(visibility_chain.visible_invalidations);out["parent_invalidations"]=int64_t(visibility_chain.parent_invalidations);
 out["off_main_writes"]=int64_t(visibility_chain.off_main_writes.load(std::memory_order_relaxed));
 out["off_main_reads"]=int64_t(visibility_chain.off_main_reads.load(std::memory_order_relaxed));
 out["overflow_disables"]=int64_t(visibility_chain.overflow_disables);
 out["scope"]="Profiling-independent cumulative main-thread visibility queries and walks. Off-main readers keep the original walk; any off-main authored visibility/parent write permanently disables memoization. No wall/CPU/FPS quantity.";
 return out;
}
