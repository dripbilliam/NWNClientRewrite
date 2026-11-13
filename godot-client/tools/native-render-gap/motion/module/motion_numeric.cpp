#include "motion_numeric.h"
#include "core/object/class_db.h"
#include <atomic>
#include <cmath>
namespace {
std::atomic<uint64_t> calls{0},supported{0};
// GDScript f() returns a float32 value carried in a Variant double. Keep every
// established rounding boundary and evaluate the intervening scalar math as
// double; do not substitute approximate trig or a new facing rule.
double f(double value) { return double(float(value)); }
double length32(const Vector3 &v) {
 return f(std::sqrt(f(f(f(double(v.x)*v.x)+f(double(v.y)*v.y))+f(double(v.z)*v.z))));
}
Vector3 normalized32(const Vector3 &v) {
 const double length=length32(v);
 return length>0 ? v/real_t(length) : Vector3();
}
bool ordinary(const Vector3 &v) {
 return v.is_finite() && std::abs(v.x)<=1000000 && std::abs(v.y)<=1000000 && std::abs(v.z)<=1000000;
}
}
Dictionary NwnMotionNumeric::facing_step(Vector3 old,Vector3 target,int64_t animation,int64_t dt,const Dictionary &options) {
 calls.fetch_add(1,std::memory_order_relaxed);
 if(sizeof(real_t)!=4 || !ordinary(old) || !ordinary(target) || dt<0 || dt>60000) return Dictionary();
 const Variant restored=options.get("restored",int64_t(0)),model=options.get("model",true),type=options.get("modelType",int64_t(1));
 // Custom/malformed options retain the original conversion/error behavior.
 if(restored.get_type()!=Variant::INT || model.get_type()!=Variant::BOOL || type.get_type()!=Variant::INT) return Dictionary();
 supported.fetch_add(1,std::memory_order_relaxed);
 const Vector3 desired=normalized32(Vector3(target.x,target.y,0));
 const double dot=f(f(f(double(old.y)*desired.y)+f(double(old.x)*desired.x))+f(double(old.z)*desired.z));
 const double sign=f(f(double(old.x)*desired.y)-f(double(old.y)*desired.x))<0 ? -1.0 : 1.0;
 Array requests;
 auto result=[&](const Vector3 &orientation) { Dictionary out;out["orientation"]=orientation;out["target"]=desired;out["requests"]=requests;return out; };
 if(dot<1 && (animation==0 || animation==1 || animation==53 || animation==54)) {
  if(dot>=f(0.99)) return result(old);
  const int64_t base=(animation==53 || animation==54) ? int64_t(restored) : animation;
  if(base==0 && bool(model) && int64_t(type)==1) requests.push_back(int64_t(sign<0?80:81));
  else if(base==1) requests.push_back(int64_t(sign<0?82:83));
 }
 double speed=f(f(1-dot)*3);
 if(animation==4) speed=f(speed+speed);
 speed=speed<=f(0.55) ? f(0.55) : MIN(f(1.55),speed);
 const double angle=f(f(f(f(double(dt))*speed)*4000)/f(1e6));
 Vector3 next=desired;
 if(dot<f(std::cos(angle))) {
  const double signed_angle=f(angle*sign),cosine=f(std::cos(signed_angle)),sine=f(std::sin(signed_angle));
  next=Vector3(real_t(f(f(double(old.x)*cosine)-f(double(old.y)*sine))),real_t(f(f(double(old.x)*sine)+f(double(old.y)*cosine))),0);
 }
 return result(normalized32(next));
}
Dictionary NwnMotionNumeric::inspect() {
 Dictionary out;out["abi"]=1;out["calls"]=int64_t(calls.load());out["supported"]=int64_t(supported.load());return out;
}
void NwnMotionNumeric::_bind_methods() {
 ClassDB::bind_static_method("NwnMotionNumeric",D_METHOD("facing_step","old","target","animation","dt","options"),&NwnMotionNumeric::facing_step);
 ClassDB::bind_static_method("NwnMotionNumeric",D_METHOD("inspect"),&NwnMotionNumeric::inspect);
}
