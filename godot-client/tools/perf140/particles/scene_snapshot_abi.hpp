#pragma once
// Shared byte contract for a private builtin engine method and its extension
// consumer. No pointers cross this boundary. Transform words deliberately match
// the pinned public GDExtension carrier: nine C++ Basis ROW words, then origin.
// GDScript Basis indexing exposes columns, so a GDScript fixture transposes its
// indexed access when comparing these raw row-major words.
#include <array>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <limits>

namespace nwn_scene_snapshot_abi {
constexpr uint32_t magic=0x3153574e;
constexpr uint16_t version=1,header_bytes=32,row_bytes=64;
constexpr uint32_t maximum_rows=1048576;
enum Role:uint8_t {eligibility=1,validate=2,transform=4};
enum Flag:uint32_t {exists=1,node3d=2,inside=4,visible=8,processable=16,has_transform=32};
enum Status:uint8_t {ok=0,not_main_thread=1,bad_request=2,unsupported_precision=3,unsupported_thread_group=4};
inline void write16(uint8_t* p,uint16_t v){p[0]=static_cast<uint8_t>(v);p[1]=static_cast<uint8_t>(v>>8);}
inline void write32(uint8_t* p,uint32_t v){for(size_t n=0;n<4;++n)p[n]=static_cast<uint8_t>(v>>(n*8));}
inline void write64(uint8_t* p,uint64_t v){for(size_t n=0;n<8;++n)p[n]=static_cast<uint8_t>(v>>(n*8));}
inline uint16_t read16(const uint8_t* p){return static_cast<uint16_t>(p[0]|(uint16_t(p[1])<<8));}
inline uint32_t read32(const uint8_t* p){uint32_t v=0;for(size_t n=0;n<4;++n)v|=uint32_t(p[n])<<(n*8);return v;}
inline uint64_t read64(const uint8_t* p){uint64_t v=0;for(size_t n=0;n<8;++n)v|=uint64_t(p[n])<<(n*8);return v;}
inline void write_float(uint8_t* p,float v){uint32_t bits;std::memcpy(&bits,&v,4);write32(p,bits);}
inline float read_float(const uint8_t* p){const auto bits=read32(p);float v;std::memcpy(&v,&bits,4);return v;}
inline void header(uint8_t* p,uint32_t count,uint8_t status=ok,uint32_t transforms=0,uint32_t eligible=0){
 std::memset(p,0,header_bytes);write32(p,magic);write16(p+4,version);write16(p+6,header_bytes);write16(p+8,row_bytes);p[10]=4;p[11]=status;write32(p+12,count);write32(p+16,transforms);write32(p+20,eligible);
}
struct View {
 const uint8_t* bytes=nullptr;size_t length=0;uint32_t count=0,transforms=0,eligible=0;uint8_t status=bad_request;
 bool open(const uint8_t* input,size_t size){
  *this={};if(!input||size<header_bytes)return false;
  if(read32(input)!=magic||read16(input+4)!=version||read16(input+6)!=header_bytes||read16(input+8)!=row_bytes||input[10]!=4||read64(input+24)!=0)return false;
  const auto rows=read32(input+12);if(rows>maximum_rows||size!=size_t(header_bytes)+size_t(rows)*row_bytes)return false;
  status=input[11];if(status>unsupported_thread_group)return false;
  count=rows;transforms=read32(input+16);eligible=read32(input+20);if(transforms>rows||eligible>rows)return false;
  bytes=input;length=size;return status==ok;
 }
 const uint8_t* at(size_t index)const{return bytes&&index<count?bytes+header_bytes+index*row_bytes:nullptr;}
 bool row(size_t index,uint64_t expected,uint8_t roles,uint32_t& flags,std::array<float,12>* pose=nullptr)const{
  const auto* p=at(index);if(!p||read64(p)!=expected||read32(p+12)!=roles||(roles&~uint8_t(eligibility|validate|transform)))return false;
  flags=read32(p+8);if(flags&~uint32_t(exists|node3d|inside|visible|processable|has_transform))return false;
  if((flags&node3d)&&!(flags&exists))return false;
  if((flags&(inside|visible|processable|has_transform))&&!(flags&node3d))return false;
  if((flags&(visible|processable|has_transform))&&!(flags&inside))return false;
  if((flags&processable)&&!(flags&visible))return false;
  if((flags&(visible|processable))&&!(roles&eligibility))return false;
  if((flags&has_transform)&&!(roles&transform))return false;
  if(pose&&(flags&has_transform))for(size_t n=0;n<12;++n)(*pose)[n]=read_float(p+16+n*4);
  return true;
 }
};
} // namespace nwn_scene_snapshot_abi
