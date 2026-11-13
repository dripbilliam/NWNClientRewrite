 // NWN_VISIBILITY_CHAIN_EPOCHS_V1: keep the pre-existing read-thread guard.
 if(visibility_chain_enabled()){
  if(Thread::is_main_thread()){
   ++visibility_chain.queries;
   if(is_effective_process_thread_group_main_thread()&&!visibility_chain.disabled.load(std::memory_order_acquire)){
    const uint64_t epoch=visibility_chain.epoch;
    if(visibility_chain_cached_epoch==epoch){++visibility_chain.hits;return visibility_chain_cached_value;}
    ++visibility_chain.misses;
    bool visible=true;uint64_t steps=0;const Node3D* stop=nullptr;
    for(const Node3D* node=this;node;node=node->data.parent){
     ++steps;
     if(node->visibility_chain_cached_epoch==epoch){visible=node->visibility_chain_cached_value;stop=node;++visibility_chain.ancestor_hits;break;}
     if(!node->data.visible){visible=false;stop=node;break;}
    }
    visibility_chain.walk_steps+=steps;
    // No callbacks/allocations between these two walks. Prefix nodes all have
    // the same suffix result. Never carry a hidden child's false value above
    // its stopping node, and never rewrite an already memoized stopping node.
    for(const Node3D* node=this;node;node=node->data.parent){
     ++visibility_chain.fill_steps;
     if(node==stop&&node->visibility_chain_cached_epoch==epoch)break;
     node->visibility_chain_cached_value=visible;node->visibility_chain_cached_epoch=epoch;++visibility_chain.fills;
     if(node==stop)break;
    }
    return visible;
   }
   ++visibility_chain.main_fallbacks;
  }else visibility_chain.off_main_reads.fetch_add(1,std::memory_order_relaxed);
 }
