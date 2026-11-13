// Source-only until root grants a private CPU gate. No engine, server or GPU.
#include "frame_pose_cache.hpp"
#include <iostream>
#include <stdexcept>

int main(){
 using namespace nwn_managed_pose;
 int checks=0;const auto check=[&](bool ok){++checks;if(!ok)throw std::runtime_error("Managed policy check failed");};
 Mutation mutation;
 auto scope=std::make_shared<Scope>();scope->identity=71;scope->owner_id=101;
 Lease lease;lease.scope=scope;lease.identity=72;lease.placement_id=102;lease.source_id=103;
 int reads=0;
 const auto live=[&](){++reads;return true;};
 check(lease.validate(1,mutation,live)&&reads==1);
 const auto first=lease.witness(mutation);
 check(lease.accepts(first,mutation));
 check(lease.validate(1,mutation,live)&&reads==1);
 check(lease.validate(2,mutation,live)&&reads==2);
 // A new presentation call revalidates structure, but does not invalidate a
 // proven unchanged pose. Actual endpoint IDs still belong to the adapter.
 check(lease.accepts(first,mutation));
 mutation.enter();check(!lease.usable(mutation)&&!lease.accepts(first,mutation));
 check(!lease.validate(2,mutation,live)&&reads==2);
 mutation.enter();mutation.leave();check(!mutation.reusable());
 mutation.leave();check(mutation.reusable()&&!lease.accepts(first,mutation));
 check(lease.validate(2,mutation,live)&&reads==3);
 const auto after_callback=lease.witness(mutation);check(lease.accepts(after_callback,mutation));
 // Nested callback failure still crosses both mutation boundaries.
 try{mutation.enter();throw std::runtime_error("service");}catch(const std::exception&){mutation.leave();}
 check(!lease.accepts(after_callback,mutation));
 // Source reparent/removal detected after a callback never reactivates the old
 // token, even if a later callback restores the same numeric parent IDs.
 check(!lease.validate(3,mutation,[](){return false;}));
 check(!lease.active&&!lease.validate(4,mutation,live));
 Lease replacement;replacement.scope=scope;replacement.identity=73;replacement.placement_id=102;replacement.source_id=103;
 check(replacement.validate(4,mutation,live));
 check(!replacement.accepts(after_callback,mutation));
 const auto current=replacement.witness(mutation);check(replacement.accepts(current,mutation));
 replacement.revoke();replacement.revoke();check(!replacement.accepts(current,mutation));
 Lease next;next.scope=scope;next.identity=74;next.placement_id=104;next.source_id=105;
 check(next.validate(5,mutation,live));const auto old_scope=next.witness(mutation);
 scope->revoke();check(!next.usable(mutation)&&!next.accepts(old_scope,mutation));
 auto new_scope=std::make_shared<Scope>();new_scope->identity=75;new_scope->owner_id=106;
 Lease reconnect;reconnect.scope=new_scope;reconnect.identity=76;reconnect.placement_id=104;reconnect.source_id=105;
 check(reconnect.validate(6,mutation,live)&&!reconnect.accepts(old_scope,mutation));
 // Missing IDs never turn into a zero-valued/default pose grant.
 Lease absent;check(!absent.validate(7,mutation,live));
 absent=reconnect;absent.identity=0;check(!absent.validate(7,mutation,live));
 absent=reconnect;absent.placement_id=0;check(!absent.validate(7,mutation,live));
 absent=reconnect;absent.source_id=0;check(!absent.validate(7,mutation,live));
 check(!reconnect.validate(0,mutation,live));
 // Saturation disables reuse; there is no wrapped witness collision.
 Mutation saturated;saturated.revision.value=UINT64_MAX;saturated.enter();saturated.leave();
 check(saturated.revision.exhausted&&!reconnect.usable(saturated));
 auto almost=reconnect;almost.revision.value=UINT64_MAX;almost.revoke();check(almost.revision.exhausted&&!almost.usable(mutation));
 Witness empty;check(!reconnect.accepts(empty,mutation));
 // Exercise the actual frozen FramePoseCache retained row, not a parallel
 // model of the algorithm. Only the input getter/converter are pure stand-ins.
 auto cache_scope=std::make_shared<Scope>();cache_scope->identity=801;cache_scope->owner_id=802;
 Lease cached;cached.scope=cache_scope;cached.identity=803;cached.placement_id=804;cached.source_id=805;
 nwn_frame_pose::Cache<std::array<float,1>> cache;
 std::array<float,12> raw{};raw[0]=1;
 int live_reads=0,conversions=0;
 const auto read=[&](){++live_reads;return raw;};
 const auto convert=[&](const auto& value){++conversions;if(value[0]==-99)throw std::runtime_error("convert failure");return std::array<float,1>{value[0]};};
 const auto prior=nwn_frame_pose::active_epoch;nwn_frame_pose::active_epoch=&cache.epoch;
 const auto step=[&](){
  if(nwn_frame_pose::active_epoch!=&cache.epoch)return convert(read());
  if(cached.usable(callbacks))return cache.managed_read(805,cached,read,convert);
  return cache.read(805,read,convert);
 };
 cache.begin(1);check(step()[0]==1&&live_reads==1&&conversions==1);
 check(step()[0]==1&&live_reads==1&&cache.managed_hits==1);
 cache.begin(1);check(step()[0]==1&&live_reads==1&&cache.managed_hits==1);
 {
  nwn_frame_pose::CallbackBarrier barrier;raw[0]=2;
  check(!callbacks.reusable()&&step()[0]==2&&live_reads==2);
 }
 check(step()[0]==2&&live_reads==3);
 cache.begin(1);check(step()[0]==2&&live_reads==3);
 cached.revoke();cached=Lease{};cached.scope=cache_scope;cached.identity=806;cached.placement_id=804;cached.source_id=805;
 raw[0]=3;cache.begin(1);check(step()[0]==3&&live_reads==4);
 // Nonfinite inputs follow ordinary conversion but never get a retained row.
 {nwn_frame_pose::CallbackBarrier barrier;raw[0]=std::numeric_limits<float>::quiet_NaN();}
 check(std::isnan(step()[0])&&live_reads==5&&cache.rows.empty());
 check(std::isnan(step()[0])&&live_reads==6&&cache.rejected==2);
 raw[0]=4;check(step()[0]==4&&live_reads==7);
 {nwn_frame_pose::CallbackBarrier barrier;raw[0]=-99;}
 bool threw=false;try{step();}catch(const std::exception&){threw=true;}
 check(threw&&live_reads==8);
 raw[0]=5;check(step()[0]==5&&live_reads==9);
 callbacks.revision.value=UINT64_MAX;
 {nwn_frame_pose::CallbackBarrier barrier;raw[0]=6;}
 check(callbacks.revision.exhausted&&!cached.usable(callbacks));
 check(step()[0]==6&&live_reads==10);
 cache.begin(1);check(step()[0]==6&&live_reads==11&&cache.managed_hits==0);
 cache_scope->revoke();check(!cached.usable(callbacks));
 nwn_frame_pose::active_epoch=prior;
 std::cout<<"{\"success\":true,\"checks\":"<<checks<<",\"gpu\":false,\"server_connections\":0}\n";
}
