'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),project=path.resolve(__dirname,'../../../..'),label=process.argv[2]??'a',out=path.join(project,'.cache/native-render-gap/original/visibility-cache/oracle-'+label),sha=x=>crypto.createHash('sha256').update(x).digest('hex');if(!/^[a-z0-9-]+$/.test(label))throw Error('Fresh label');if(fs.existsSync(out))throw Error('Preserve oracle');const state=fs.readFileSync(path.join(__dirname,'state.cpp.inc'),'utf8').split('Dictionary NwnVisibilityChainCache::snapshot()')[0],getter=fs.readFileSync(path.join(__dirname,'getter.cpp.inc'),'utf8');
const cpp=`#include <atomic>
#include <cstdint>
#include <cstring>
#include <thread>
#include <array>
#include <cassert>
#include <iostream>
#include <new>
bool flag=true;const auto main_id=std::this_thread::get_id();
struct Thread{static bool is_main_thread(){return std::this_thread::get_id()==main_id;}};
struct Args{const void*find(const char*s)const{static int token;return flag&&std::strcmp(s,"--visibility-chain-cache=epochs")==0?&token:nullptr;}};
struct OS{static OS*get_singleton(){static OS o;return &o;}Args get_cmdline_user_args(){return {};}};
${state}
struct Node3D{
 struct{Node3D*parent=nullptr;bool visible=true;}data;
 mutable uint64_t visibility_chain_cached_epoch=0;mutable bool visibility_chain_cached_value=true;
 bool group_main=true;bool is_effective_process_thread_group_main_thread()const{return group_main;}
 bool is_visible_in_tree()const{
${getter}
  const Node3D*s=this;while(s){if(!s->data.visible)return false;s=s->data.parent;}return true;
 }
};
bool original(const Node3D*node){for(;node;node=node->data.parent)if(!node->data.visible)return false;return true;}
void visible(Node3D&node,bool value){if(node.data.visible==value)return;visibility_chain_invalidate(false);node.data.visible=value;}
void parent(Node3D&node,Node3D*next){visibility_chain_invalidate(true);node.data.parent=next;}
int main(int argc,char**argv){flag=!(argc>1&&std::strcmp(argv[1],"--off")==0);std::array<Node3D,128> nodes{};uint64_t checks=0;const auto query=[&](Node3D&n){assert(n.is_visible_in_tree()==original(&n));++checks;};for(size_t n=1;n<nodes.size();n++)parent(nodes[n],&nodes[(n-1)/2]);for(auto&n:nodes){query(n);query(n);}uint32_t rng=0x6cf31e2d;const auto next=[&](){rng=rng*1664525u+1013904223u;return rng;};
 for(int step=0;step<50000;step++){const size_t id=next()%nodes.size();switch(next()%6){case 0:visible(nodes[id],!nodes[id].data.visible);break;case 1:parent(nodes[id],id?&nodes[next()%id]:nullptr);break;case 2:query(nodes[id]);break;case 3:{const auto before=visibility_chain.epoch;visible(nodes[id],nodes[id].data.visible);assert(visibility_chain.epoch==before);break;}case 4:nodes[id].group_main=!nodes[id].group_main;break;case 5:{query(nodes[id]);parent(nodes[id],nullptr);query(nodes[id]);break;}}for(int n=0;n<5;n++)query(nodes[next()%nodes.size()]);}
 // Reentrant visibility callbacks observe the newly-authored field; a nested
 // ancestor mutation invalidates the descendant value again before return.
 Node3D root,child,other;parent(child,&root);query(child);visible(root,false);query(child);visible(root,true);query(child);visible(other,false);query(child);parent(child,&other);query(child);
 // EXIT_WORLD callbacks run with OLD parent; the actual later clear must
 // invalidate callback-warmed data. This catches invalidating only at entry.
 query(child);parent(child,nullptr);query(child);assert(child.is_visible_in_tree());
 // Same storage reused for a fresh object must start at epoch0, not inherit a
 // memo from a deleted prior occupant. No external node pointers retained.
 alignas(Node3D) unsigned char storage[sizeof(Node3D)];auto*first=new(storage)Node3D;visible(*first,false);query(*first);first->~Node3D();auto*second=new(storage)Node3D;query(*second);assert(second->is_visible_in_tree());second->~Node3D();
 // Shared-parent/deep-chain reuse survives a global mutation each frame.
 std::array<Node3D,32> chain{};for(size_t n=1;n<chain.size();n++)parent(chain[n],&chain[n-1]);Node3D sibling;parent(sibling,&chain[30]);for(int frame=0;frame<40;frame++){visible(root,(frame&1)!=0);query(chain[31]);query(sibling);for(auto&n:chain)query(n);}if(flag)assert(visibility_chain.ancestor_hits>0&&visibility_chain.fills>0);
 // A hidden stopping node must not poison visible ancestors above it.
 visible(chain[15],false);query(chain[31]);query(chain[0]);assert(chain[0].is_visible_in_tree());query(sibling);visible(chain[15],true);query(chain[31]);
 bool worker_result=false;std::thread reader([&](){worker_result=child.is_visible_in_tree();});reader.join();assert(worker_result==original(&child));query(child);
 if(flag){assert(visibility_chain.hits>0&&visibility_chain.misses>0&&visibility_chain.walk_steps>0&&visibility_chain.main_fallbacks>0&&visibility_chain.off_main_reads.load()==1);visibility_chain.epoch=UINT64_MAX;visible(root,false);assert(visibility_chain.disabled.load()&&visibility_chain.epoch==UINT64_MAX);query(child);visibility_chain.disabled.store(false);visibility_chain.epoch=7;}
 else assert(visibility_chain.queries==0&&visibility_chain.hits==0&&visibility_chain.visible_invalidations==0);
 query(child);std::thread writer([&](){visible(child,false);});writer.join();query(child);assert(!child.is_visible_in_tree());if(flag)assert(visibility_chain.disabled.load()&&visibility_chain.off_main_writes.load()==1);
 std::cout<<"{\\"success\\":true,\\"enabled\\":"<<(flag?"true":"false")<<",\\"checks\\":"<<checks<<",\\"hits\\":"<<visibility_chain.hits<<",\\"misses\\":"<<visibility_chain.misses<<",\\"exactOriginalWalk\\":true,\\"reentrantAndExitWriter\\":true,\\"addressReuse\\":true,\\"workerReadAndFailClosedWrite\\":true}\\n";
}
`;
fs.mkdirSync(out,{recursive:true});fs.writeFileSync(path.join(out,'oracle.cpp'),cpp,{flag:'wx'});fs.writeFileSync(path.join(out,'source.json'),JSON.stringify({version:1,scope:'Source preparation only. Actual cache state/getter fragments extracted verbatim into independent original-walk differential mock; real engine callbacks/reparent fixture remains required.',stateSha256:sha(state),getterSha256:sha(getter),cppSha256:sha(cpp)},null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({out,cppSha256:sha(cpp)}));
