// Shared engine/extension bytes only. No Node, engine, server or GPU.
#include "scene_snapshot_abi.hpp"
#include <iostream>
#include <stdexcept>
#include <vector>

int main(){
 using namespace nwn_scene_snapshot_abi;
 int checks=0;const auto check=[&](bool ok){++checks;if(!ok)throw std::runtime_error("Scene snapshot ABI check failed");};
 std::vector<uint8_t> bytes(header_bytes+3*row_bytes);header(bytes.data(),3,ok,1,1);
 const auto row=[&](size_t n){return bytes.data()+header_bytes+n*row_bytes;};
 write64(row(0),UINT64_C(0xdeadbeef00000031));write32(row(0)+8,exists|node3d|inside|visible|processable|has_transform);write32(row(0)+12,eligibility|validate|transform);
 for(size_t n=0;n<12;++n)write_float(row(0)+16+n*4,float(n)*0.125f);
 write_float(row(0)+16,-0.0f);write32(row(0)+20,0x7fc12345);write32(row(0)+24,0x7f800000);
 write64(row(1),72);write32(row(1)+12,validate); // Explicit absent node.
 write64(row(2),73);write32(row(2)+8,exists);write32(row(2)+12,validate); // Existing non-Node3D.
 View view;check(view.open(bytes.data(),bytes.size())&&view.count==3&&view.transforms==1&&view.eligible==1);
 uint32_t flags=0;std::array<float,12> pose{};
 check(view.row(0,UINT64_C(0xdeadbeef00000031),eligibility|validate|transform,flags,&pose)&&flags==(exists|node3d|inside|visible|processable|has_transform));
 uint32_t word=0;std::memcpy(&word,&pose[0],4);check(word==0x80000000);std::memcpy(&word,&pose[1],4);check(word==0x7fc12345);std::memcpy(&word,&pose[2],4);check(word==0x7f800000);
 pose.fill(7);check(view.row(1,72,validate,flags,&pose)&&flags==0&&pose[0]==7);check(view.row(2,73,validate,flags,&pose)&&flags==exists&&pose[0]==7);
 check(!view.row(0,31,eligibility|validate|transform,flags));check(!view.row(0,UINT64_C(0xdeadbeef00000031),validate,flags));check(!view.row(3,0,0,flags));
 const auto malformed=[&](size_t offset,uint8_t value){auto copy=bytes;copy[offset]=value;View bad;return !bad.open(copy.data(),copy.size());};
 check(malformed(0,0));check(malformed(4,2));check(malformed(6,0));check(malformed(8,0));check(malformed(10,8));check(malformed(11,255));check(malformed(24,1));
 check(!View{}.open(nullptr,0));check(!View{}.open(bytes.data(),header_bytes-1));check(!View{}.open(bytes.data(),bytes.size()-1));
 auto copy=bytes;copy.push_back(0);check(!View{}.open(copy.data(),copy.size()));
 copy=bytes;write32(copy.data()+12,maximum_rows+1);check(!View{}.open(copy.data(),copy.size()));
 copy=bytes;write32(copy.data()+16,4);check(!View{}.open(copy.data(),copy.size()));
 copy=bytes;write32(copy.data()+20,4);check(!View{}.open(copy.data(),copy.size()));
 const auto bad_flags=[&](uint32_t invalid,uint8_t roles){auto packet=bytes;write32(packet.data()+header_bytes+8,invalid);write32(packet.data()+header_bytes+12,roles);View parsed;return parsed.open(packet.data(),packet.size())&&!parsed.row(0,UINT64_C(0xdeadbeef00000031),roles,flags);};
 check(bad_flags(node3d,validate));check(bad_flags(exists|inside,validate));check(bad_flags(exists|node3d|visible,eligibility));check(bad_flags(exists|node3d|inside|processable,eligibility));check(bad_flags(exists|node3d|inside|has_transform,validate));check(bad_flags(exists|node3d|inside|visible,validate));check(bad_flags(64,validate));check(bad_flags(0,8));
 std::vector<uint8_t> unavailable(header_bytes);header(unavailable.data(),0,unsupported_thread_group);View unsupported;check(!unsupported.open(unavailable.data(),unavailable.size())&&unsupported.status==unsupported_thread_group&&unsupported.count==0);
 std::vector<uint8_t> empty(header_bytes);header(empty.data(),0);View zero;check(zero.open(empty.data(),empty.size())&&!zero.at(0));
 // A tombstoned request row has no roles and no invented node/transform.
 copy.assign(header_bytes+row_bytes,0);header(copy.data(),1);View tombstone;check(tombstone.open(copy.data(),copy.size())&&tombstone.row(0,0,0,flags,&pose)&&flags==0&&pose[0]==7);
 std::cout<<"{\"success\":true,\"checks\":"<<checks<<",\"gpu\":false,\"server_connections\":0}\n";
}
