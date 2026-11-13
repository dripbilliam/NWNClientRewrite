// SOURCE-ONLY, unexecuted. Pure oracle plus optional actual-Godot corpus input.
#include "drive_height_kernel.hpp"
#include <iostream>
#include <fstream>
#include <cstring>
#include <random>
#include <cstdint>
#include <algorithm>
namespace kh=drive_height_kernel;
size_t checks=0;
void check(bool value,const std::string&label){++checks;if(!value)throw std::runtime_error(label);}
uint64_t bits(double value){uint64_t out;std::memcpy(&out,&value,sizeof(out));return out;}
double ref_f(double value){return static_cast<double>(static_cast<float>(value));}
double ref_edge(const kh::Point&a,const kh::Point&b,double x,double y){return ref_f(ref_f(ref_f(y-a[1])*ref_f(b[0]-a[0]))+ref_f(ref_f(a[1]-b[1])*ref_f(x-a[0])));}
kh::Result reference(const std::vector<kh::SourceFace>&faces,double sx,double sy){
 const double x=ref_f(sx),y=ref_f(sy);
 for(const bool allowed:{true,false})for(size_t index=0;index<faces.size();++index){const auto&t=faces[index];if(t.walkable!=allowed)continue;
  if(ref_edge(t.points[0],t.points[1],x,y)>=0&&ref_edge(t.points[1],t.points[2],x,y)>=0&&ref_edge(t.points[2],t.points[0],x,y)>=0){
   const auto&n=t.normal;const double result=n[2]==0?0.0:ref_f(-ref_f(ref_f(ref_f(n[1]*y)+ref_f(ref_f(n[0]*x)+ref_f(t.constant))))/n[2]);return {true,result,index,allowed};
  }
 }
 return {};
}
void equal(const kh::Result&a,const kh::Result&b,const std::string&label){check(bits(a.height)==bits(b.height),label+" exact double height bits");check(a.found==b.found&&a.physical_face==b.physical_face&&a.walkable==b.walkable,label+" physical source face/pass");}
kh::SourceFace triangle(double z,bool walk){kh::SourceFace f;f.points={kh::Point{0,0},kh::Point{10,0},kh::Point{10,10}};f.normal={0,0,1};f.constant=-z;f.walkable=walk;return f;}
template<class F>void rejects(F fn,const std::string&label){bool caught=false;try{fn();}catch(const kh::Unsupported&){caught=true;}check(caught,label);}
void pure(){
 kh::Batch batch;std::vector<kh::SourceFace> faces={triangle(9,false),triangle(2,true)};batch.configure(faces,1024);
 equal(batch.height(8,2),reference(faces,8,2),"Walkable second physical face wins");check(batch.height(8,2).height==2&&batch.height(8,2).physical_face==1,"Reference overlap recipe reaches lower walkable plane");
 faces[1].walkable=false;batch.configure(faces,1024);check(batch.height(8,2).height==9&&batch.height(8,2).physical_face==0,"Denied fallback keeps first physical plane");equal(batch.height(-1,-1),reference(faces,-1,-1),"No containing face");check(bits(batch.height(-1,-1).height)==bits(0.0),"No-hit result is valid positive zero");
 faces={triangle(2,true),triangle(9,true)};batch.configure(faces,1024);check(batch.height(8,2).height==2&&batch.height(8,2).physical_face==0,"Same-pass physical order is not highest/nearest floor");
 faces={triangle(0,true)};batch.configure(faces,1024);check(bits(batch.height(8,2).height)==bits(-0.0),"Ordinary zero plane preserves negative zero from original solve");
 faces={triangle(0,true)};for(double nz:{0.0,-0.0}){faces[0].normal[2]=nz;batch.configure(faces,1024);check(batch.height(8,2).found&&bits(batch.height(8,2).height)==bits(0.0),"Vertical plane yields original positive zero");}
 faces={triangle(0,true)};faces[0].points={kh::Point{0,0},kh::Point{0,0},kh::Point{0,0}};faces[0].constant=-3;batch.configure(faces,1024);check(batch.height(900,-700).found&&batch.height(900,-700).height==3,"Degenerate source is not silently area-filtered");
 for(const auto p:{kh::Point{0,0},kh::Point{10,0},kh::Point{10,10},kh::Point{8,2},kh::Point{5,5},kh::Point{5,-0.0},kh::Point{-0.0,0.0}}){faces={triangle(2,true)};batch.configure(faces,1024);equal(batch.height(p[0],p[1]),reference(faces,p[0],p[1]),"Inclusive edge/vertex/signed zero");}
 std::mt19937 rng(0x15ca902U);std::uniform_real_distribution<float> real(-20,20);
 for(size_t sample=0;sample<4000;++sample){std::vector<kh::SourceFace> source;const size_t count=1+sample%9;
  for(size_t i=0;i<count;++i){kh::SourceFace f;for(auto&p:f.points)for(auto&axis:p)axis=static_cast<double>(real(rng));for(auto&n:f.normal)n=static_cast<double>(real(rng));if(sample%29==0)f.normal[2]=0;f.constant=static_cast<double>(real(rng));f.walkable=(i+sample)%3!=0;if(sample%17==0)f.points[2]=f.points[1];source.push_back(f);}
  batch.configure(source,1024*1024);for(size_t q=0;q<5;++q){const double x=real(rng),y=real(rng);equal(batch.height(x,y),reference(source,x,y),"Seeded mixed-pass F32 mesh");}
 }
 faces={triangle(1,true)};faces[0].constant=0.1;batch.configure(faces,1024);equal(batch.height(8.123456789,2.987654321),reference(faces,8.123456789,2.987654321),"Input/constant explicit f32 narrowing");
 const double denorm=static_cast<double>(std::numeric_limits<float>::denorm_min());
 for(double x:{0.0,-0.0,denorm,-denorm,static_cast<double>(std::nextafter(1.0f,2.0f)),static_cast<double>(std::nextafter(1.0f,0.0f))}){faces={triangle(0,true)};faces[0].normal={denorm,-denorm,1};batch.configure(faces,1024);equal(batch.height(x,0),reference(faces,x,0),"Subnormal/adjacent f32 arithmetic");}
 faces={triangle(2,true)};batch.configure(faces,1024);faces[0].constant=-7;check(batch.height(8,2).height==2,"Typed batch detaches caller source values");
 auto invalid=faces;invalid[0].points[0][0]=0.1;rejects([&](){batch.configure(invalid,1024);},"Non-f32 vertex must fall back");check(!batch.configured()&&batch.size()==0,"Rejected replacement cannot preserve stale typed values");
 invalid=faces;invalid[0].normal[0]=0.1;rejects([&](){batch.configure(invalid,1024);},"Non-f32 normal must fall back");
 invalid=faces;invalid[0].constant=std::numeric_limits<double>::infinity();rejects([&](){batch.configure(invalid,1024);},"Infinite source must fall back");
 invalid=faces;invalid[0].normal[2]=0;invalid[0].constant=std::numeric_limits<double>::max();rejects([&](){batch.configure(invalid,1024);},"Unsupported unused constant still requires fallback, not invented zero");check(bits(reference(invalid,8,2).height)==bits(0.0),"Fallback reference retains vertical-plane positive zero");
 rejects([&](){batch.configure(faces,1);},"Native payload bound");
 batch.configure(faces,1024);rejects([&](){batch.height(std::numeric_limits<double>::quiet_NaN(),0);},"NaN query unavailability, not zero");rejects([&](){batch.height(std::numeric_limits<double>::max(),0);},"Overflow query unavailability, not zero");
 invalid={triangle(0,true)};invalid[0].normal={std::numeric_limits<float>::max(),0,std::numeric_limits<float>::denorm_min()};batch.configure(invalid,1024);rejects([&](){batch.height(8,2);},"Plane overflow preserves fallback instead of clamping");
 batch.configure({},1024);const auto empty=batch.height(1,1);check(!empty.found&&bits(empty.height)==bits(0.0),"Empty source supports valid no-hit zero");batch.clear();rejects([&](){batch.height(1,1);},"Retired calculations are explicitly unavailable");
}
struct Input {
 std::vector<uint8_t> data;size_t offset=0;
 explicit Input(const char*file){std::ifstream in(file,std::ios::binary);if(!in)throw std::runtime_error("Godot corpus unavailable");in.seekg(0,std::ios::end);const auto size=in.tellg();if(size<0||size>64*1024*1024)throw std::runtime_error("Godot corpus byte bound");data.resize(static_cast<size_t>(size));in.seekg(0);in.read(reinterpret_cast<char*>(data.data()),static_cast<std::streamsize>(data.size()));if(!in)throw std::runtime_error("Truncated Godot corpus");}
 template<class T>T read(){if(offset>data.size()||sizeof(T)>data.size()-offset)throw std::runtime_error("Corpus scalar bounds");T value;std::memcpy(&value,data.data()+offset,sizeof(T));offset+=sizeof(T);return value;}
 std::string text(){const auto count=read<uint16_t>();if(count>4096||offset>data.size()||count>data.size()-offset)throw std::runtime_error("Corpus label bounds");const std::string value(reinterpret_cast<const char*>(data.data()+offset),count);offset+=count;return value;}
};
void corpus(const char*file){
 uint32_t endian=1;if(*reinterpret_cast<uint8_t*>(&endian)!=1)throw std::runtime_error("Corpus requires verified little-endian reader");Input input(file);
 const char magic[]="NWNHGT01";for(size_t i=0;i<8;++i)check(input.read<uint8_t>()==static_cast<uint8_t>(magic[i]),"Godot corpus schema");const auto count=input.read<uint32_t>();if(count==0||count>10000)throw std::runtime_error("Corpus case bound");
 for(uint32_t i=0;i<count;++i){const auto label=input.text();const auto face_count=input.read<uint32_t>(),queries=input.read<uint32_t>();if(face_count>100000||queries==0||queries>100000)throw std::runtime_error("Corpus face/query bound");std::vector<kh::SourceFace> faces;faces.reserve(face_count);
  for(uint32_t index=0;index<face_count;++index){kh::SourceFace face;for(auto&p:face.points)for(auto&axis:p)axis=input.read<double>();for(auto&n:face.normal)n=input.read<double>();face.constant=input.read<double>();const auto walk=input.read<uint8_t>();if(walk>1)throw std::runtime_error("Corpus boolean invalid");face.walkable=walk!=0;faces.push_back(face);}
  kh::Batch batch;bool configured=true;try{batch.configure(faces,16*1024*1024);}catch(const kh::Unsupported&){configured=false;}
  for(uint32_t query=0;query<queries;++query){const auto x=input.read<double>(),y=input.read<double>();const auto expected_bits=input.read<uint64_t>();const auto found=input.read<uint8_t>();const auto selected=input.read<uint32_t>();const auto walk=input.read<uint8_t>();const auto policy=input.read<uint8_t>();if(found>1||walk>1||policy>1)throw std::runtime_error("Corpus query metadata invalid");
   bool supported=configured;kh::Result result;if(supported)try{result=batch.height(x,y);}catch(const kh::Unsupported&){supported=false;}
   if(policy==0){check(!supported,label+" must report unsupported");continue;}if(policy==1)check(supported,label+" required supported source/query");
   if(supported){check(bits(result.height)==expected_bits,label+" actual Godot original height bits");check(result.found==(found!=0)&&result.walkable==(walk!=0)&&result.physical_face==(selected==0xffffffffU?std::numeric_limits<size_t>::max():selected),label+" actual Godot physical face/pass");}
  }
 }
 check(input.offset==input.data.size(),"Corpus has no unparsed trailing payload");
}
int main(int argc,char**argv){try{pure();if(argc==2)corpus(argv[1]);else if(argc!=1)throw std::runtime_error("Usage: drive-height-pure.exe [verified-golden-corpus]");std::cout<<"{\"success\":true,\"checks\":"<<checks<<",\"goldenCorpusProvided\":"<<(argc==2?"true":"false")<<",\"scope\":\"Standalone height-kernel oracle only; engine/corpus provenance is external, no runtime integration or performance claim\"}\n";return 0;}catch(const std::exception&e){std::cerr<<"Height oracle failure after "<<checks<<": "<<e.what()<<'\n';return 1;}}
