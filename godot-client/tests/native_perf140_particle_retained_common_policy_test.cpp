// Actual frozen common cache + frame epoch policy. No engine/server/GPU.
#include "frame_pose_cache.hpp"
#include "retained_common_input.hpp"
#include <iostream>
#include <stdexcept>

int main(){
 int checks=0;const auto check=[&](bool ok){++checks;if(!ok)throw std::runtime_error("Common cache policy check failed");};
 nwn_frame_pose::Epoch epoch;
 particle_common_input::Cache<nwn_frame_pose::Epoch> cache;
 bool value=true,bad=false;int calls=0;
 const auto read=[&](){++calls;if(bad)throw std::runtime_error("truth conversion");return value;};
 const auto step=[&](bool retain=true,bool profile=true){return cache.get(retain,nwn_frame_pose::active_epoch,profile,read);};
 auto* prior=nwn_frame_pose::active_epoch;nwn_frame_pose::active_epoch=&epoch;
 check(step()&&calls==1&&cache.reads==1);
 check(step()&&calls==1&&cache.hits==1);
 epoch.invalidate();value=false;check(!step()&&calls==2&&cache.reads==2);
 check(!step()&&calls==2&&cache.hits==2);
 {
  nwn_frame_pose::CallbackBarrier callback;value=true;
  check(step()&&calls==3);check(step()&&calls==4);
  {nwn_frame_pose::CallbackBarrier nested;value=false;check(!step()&&calls==5);}
  check(!step()&&calls==6);
 }
 check(!step()&&calls==7);
 check(!step()&&calls==7);
 // Conversion failure never installs a new epoch/value, even if retried before
 // any other callback. The original exception escapes unchanged.
 epoch.invalidate();bad=true;bool threw=false;
 try{step();}catch(const std::exception& error){threw=std::string(error.what())=="truth conversion";}
 check(threw&&calls==8);bad=false;value=true;check(step()&&calls==9);
 check(step()&&calls==9);
 // Turning retention off must keep calling the ordinary evaluator.
 check(step(false)&&calls==10);check(step(false)&&calls==11);
 check(step()&&calls==12);check(step()&&calls==12);
 // A separate presentation call owns another cache, even if an epoch pointer
 // and numeric value are deliberately reused.
 particle_common_input::Cache<nwn_frame_pose::Epoch> next;
 value=false;check(!next.get(true,&epoch,true,read)&&calls==13);
 check(!next.get(true,&epoch,true,read)&&calls==13);
 // Disabled diagnostics avoid counter increments without changing evaluation.
 const auto reads=next.reads,hits=next.hits;
 check(!next.get(true,&epoch,false,read)&&next.reads==reads&&next.hits==hits);
 epoch.invalidate();value=true;check(next.get(true,&epoch,false,read)&&calls==14&&next.reads==reads&&next.hits==hits);
 // A full callback exception still invalidates on entry AND exit.
 const auto invalidations=epoch.invalidations;
 try{nwn_frame_pose::CallbackBarrier callback;value=false;throw std::runtime_error("service");}catch(const std::exception&){}
 check(epoch.invalidations==invalidations+2&&nwn_frame_pose::active_epoch==&epoch);
 check(!next.get(true,&epoch,true,read)&&calls==15);
 epoch.value=UINT64_MAX;check(!next.get(true,&epoch,true,read)&&calls==16);
 epoch.invalidate();check(epoch.wrapped&&epoch.cache_forbidden);
 check(!next.get(true,&epoch,true,read)&&calls==17);
 epoch.wrapped=false;value=true;
 check(next.get(true,&epoch,true,read)&&calls==18);
 check(next.get(true,&epoch,true,read)&&calls==19);
 // Only the next presentation boundary clears the sticky wrap rejection.
 nwn_frame_pose::Cache<int> fresh;fresh.epoch.cache_forbidden=true;fresh.begin(0);
 check(!fresh.epoch.cache_forbidden);
 particle_common_input::Cache<nwn_frame_pose::Epoch> fresh_common;
 check(fresh_common.get(true,&fresh.epoch,true,read)&&calls==20);
 check(fresh_common.get(true,&fresh.epoch,true,read)&&calls==20);
 nwn_frame_pose::active_epoch=prior;
 std::cout<<"{\"success\":true,\"checks\":"<<checks<<",\"gpu\":false,\"server_connections\":0}\n";
}
