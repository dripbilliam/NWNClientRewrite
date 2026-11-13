#pragma once
// Private source candidate. This policy stores no pose or Node pointer. A native
// adapter must validate live full ObjectIDs and containment before blessing a
// token, and must keep the ordinary endpoint/eligibility checks at every use.
#include <cstdint>
#include <limits>
#include <memory>
#include <unordered_map>
#include <vector>

namespace nwn_managed_pose {
struct Revision {
 std::uint64_t value=1;
 bool exhausted=false;
 void advance() noexcept {
  if(exhausted)return;
  if(value==std::numeric_limits<std::uint64_t>::max()){exhausted=true;return;}
  ++value;
 }
};

// Advancing a presentation call alone does not prove source mutation. An opaque
// callback advances this separate revision on entry AND exit, even if it throws.
// Saturation permanently disables reuse for this revision's lifetime.
struct Mutation {
 Revision revision;
 std::uint64_t depth=0;
 void enter() noexcept {revision.advance();++depth;}
 void leave() noexcept {if(depth)--depth;revision.advance();}
 bool reusable() const noexcept {return depth==0&&!revision.exhausted;}
};

struct Scope {
 std::uint64_t identity=0,owner_id=0;
 bool active=true;
 std::uint64_t validated_call=0,validated_mutation=0;
 void revoke() noexcept {active=false;}
 bool usable() const noexcept {return active&&identity!=0&&owner_id!=0;}
 template<class Validate> bool validate(std::uint64_t call,const Mutation& mutation,Validate&& live) {
  if(!usable()||call==0||!mutation.reusable())return false;
  if(validated_call==call&&validated_mutation==mutation.revision.value)return true;
  if(!live()){revoke();return false;}
  validated_call=call;validated_mutation=mutation.revision.value;return true;
 }
};

struct FrameStamp {
 std::uint64_t call=0,mutation=0;
 bool operator==(const FrameStamp& other) const noexcept {return call==other.call&&mutation==other.mutation;}
};

struct Witness {
 std::uint64_t lifetime=0,revision=0,mutation=0;
 bool matches(std::uint64_t current_lifetime,std::uint64_t current_revision,const Mutation& current) const noexcept {
  return lifetime!=0&&lifetime==current_lifetime&&revision==current_revision&&
   current.reusable()&&mutation==current.revision.value;
 }
 void clear() noexcept {*this={};}
};

struct Lease {
 struct Endpoint {std::vector<std::uint64_t> parents;std::uint64_t checked_mutation=0;};
 std::shared_ptr<Scope> scope;
 std::uint64_t identity=0,placement_id=0,source_id=0;
 std::unordered_map<std::uint64_t,Endpoint> endpoints;
 Revision revision;
 bool active=true;
 FrameStamp validation_stamp;
 bool validated=false;

 void revoke() noexcept {active=false;validated=false;revision.advance();}
 bool usable(const Mutation& mutation) const noexcept {
  return active&&identity!=0&&placement_id!=0&&source_id!=0&&scope&&scope->usable()&&
   !revision.exhausted&&mutation.reusable();
 }
 // A failed structural witness permanently retires this grant. A future
 // canonical placement change creates a new token; an old token never revives.
 template<class Validate> bool validate(std::uint64_t call,const Mutation& mutation,Validate&& live) {
  if(!usable(mutation)||call==0)return false;
  const FrameStamp next{call,mutation.revision.value};
  if(validated&&validation_stamp==next)return true;
  if(!live()){revoke();return false;}
  validation_stamp=next;validated=true;return true;
 }
 Witness witness(const Mutation& mutation) const noexcept {
  return usable(mutation)?Witness{identity,revision.value,mutation.revision.value}:Witness{};
 }
 bool accepts(const Witness& old,const Mutation& mutation) const noexcept {
  return usable(mutation)&&old.matches(identity,revision.value,mutation);
 }
};
inline thread_local Mutation callbacks;
inline thread_local Revision presentation_calls;
inline std::uint64_t next_presentation_call() noexcept {
 presentation_calls.advance();return presentation_calls.exhausted?0:presentation_calls.value;
}
} // namespace nwn_managed_pose
