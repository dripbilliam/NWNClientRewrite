'use strict';
// Prepare actual-template concurrency/window tests; execution is separately
// scheduled by root so this source step cannot contaminate an FPS window.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const source=fs.readFileSync(path.join(__dirname,'module/frame_pacing.cpp'),'utf8'),prepare=require('./prepare.cjs');
function body(s,a){const begin=s.indexOf(a);assert(begin>=0,a);let i=s.indexOf('{',begin),depth=1;for(i++;depth;i++){if(s[i]==='{')depth++;if(s[i]==='}')depth--;assert(i<s.length);}return s.slice(begin,i+(s[i]===';'?1:0));}
const ring=body(source,'template<uint64_t Capacity,uint64_t Width> struct Ring '),endpoint=body(source,'struct CpuEndpoint '),cpu=body(source,'void cpu_endpoint(');
const cpp=`#include <array>
#include <atomic>
#include <algorithm>
#include <cstdint>
#include <vector>
#include <thread>
#include <cassert>
#include <iostream>
struct Array {std::vector<int64_t> values;std::vector<std::vector<int64_t>> rows;void resize(size_t n){values.resize(n);}int64_t&operator[](size_t n){return values[n];}void push_back(const Array&value){rows.push_back(value.values);}};
${ring}
enum Lane{MAIN,RENDER};constexpr uint64_t CPU_WIDTH=11;
${endpoint}
thread_local std::array<CpuEndpoint,2> endpoints{};
Ring<128,CPU_WIDTH> cpu_windows;
#define WINDOWS_ENABLED 1
using BOOL=int;using DWORD=uint32_t;constexpr BOOL FALSE=0;
struct FILETIME {uint32_t dwLowDateTime=0,dwHighDateTime=0;};
uint64_t api_calls=0,tick=0;bool fail_cpu=false;
uint64_t own_thread(){return 71;}
void*GetCurrentThread(){return nullptr;}
DWORD GetLastError(){return 5;}
BOOL GetThreadTimes(void*,FILETIME*,FILETIME*,FILETIME*k,FILETIME*u){api_calls++;if(fail_cpu)return 0;k->dwLowDateTime=uint32_t(api_calls*13);u->dwLowDateTime=uint32_t(api_calls*29);return 1;}
struct OS {static OS*get_singleton(){static OS value;return &value;}uint64_t get_ticks_usec(){return ++tick;}};
${cpu}
int main(){
 Ring<16,8> ring;std::atomic<bool> start{false};std::atomic<int> done{0};std::atomic<uint64_t> reads{0},dropped{0};
 const auto writer=[&](uint64_t id){while(!start.load())std::this_thread::yield();for(uint64_t n=0;n<100000;n++){uint64_t row[8]={0,id,n,n^0x6cf31e2d,~n,n*3,n+17,n-19};ring.publish(row);}done++;};
 std::thread a(writer,1),b(writer,2);start=true;do{uint64_t missing=0;const auto rows=ring.read(16,missing);dropped+=missing;for(const auto&r:rows.rows){assert(r.size()==8);assert(r[1]==1||r[1]==2);const uint64_t n=uint64_t(r[2]);assert(uint64_t(r[3])==(n^0x6cf31e2d));assert(uint64_t(r[4])==~n);assert(uint64_t(r[5])==n*3);assert(uint64_t(r[6])==n+17);assert(uint64_t(r[7])==n-19);reads++;}}while(done.load()!=2);a.join();b.join();assert(reads>0);assert(ring.count.load()==200000);
 const auto frames=[](int count){for(int i=0;i<count;i++){cpu_endpoint(MAIN,true);cpu_endpoint(MAIN,false);}};
 frames(119);assert(api_calls==1);frames(1);assert(api_calls==2);frames(240);assert(api_calls==4);uint64_t missing=0;const auto windows=cpu_windows.read(128,missing);assert(windows.rows.size()==3);for(const auto&r:windows.rows){assert(r[5]==120);assert(r[6]==13);assert(r[7]==29);assert(r[8]==1);}
 endpoints={};api_calls=0;fail_cpu=true;frames(1000);assert(api_calls==9);fail_cpu=false;frames(80);assert(api_calls==10);frames(120);assert(api_calls==11);
 std::cout<<"{\\"success\\":true,\\"concurrentPublishes\\":200000,\\"validRowsRead\\":"<<reads<<",\\"droppedReadAttempts\\":"<<dropped<<",\\"cpuWindows\\":3,\\"cpuFailureSamplingBounded\\":true}\\n";
}
`;
const project=path.resolve(__dirname,'../../../..'),label=process.argv[2]??'a';assert(/^[a-z0-9-]+$/.test(label));const out=path.join(project,'.cache/native-render-gap/original/frame-pacing/oracle-'+label);assert(!fs.existsSync(out),'Preserve prior oracle');fs.mkdirSync(out,{recursive:true});const sha=x=>crypto.createHash('sha256').update(x).digest('hex');fs.writeFileSync(path.join(out,'ring-window.cpp'),cpp,{flag:'wx'});
const input=path.join(project,'.cache/native-render-gap/engine/source'),main=fs.readFileSync(path.join(input,'main/main.cpp'),'utf8'),render=fs.readFileSync(path.join(input,'servers/rendering/rendering_server_default.cpp'),'utf8'),patchedMain=prepare.transformMain(main),patchedRender=prepare.transformRender(render);
assert(patchedMain.includes('pacing.first_at(NwnFramePacingMetrics::PHYSICS_BEGIN,physics_begin)'));assert.equal(patchedMain.split('pacing.add(NwnFramePacingMetrics::RENDER_DISPATCHES)').length-1,2);assert(patchedMain.includes('pacing.at(NwnFramePacingMetrics::DRAW_RETURN,pacing_draw_return)'));assert(!/SetPriority|SetProcess|SetThread|SetFocus|SetForeground|SetWindow/.test(source));
const recordBody=source.slice(source.indexOf('Frame::Frame('),source.indexOf('Dictionary NwnFramePacing::snapshot('));assert(!/Dictionary|Array |push_back|new |memnew/.test(recordBody));
const result={version:1,sourceOnly:true,sourceSha256:sha(source),ringSha256:sha(ring),cpuEndpointSha256:sha(cpu),cppSha256:sha(cpp),transforms:{mainBefore:sha(main),mainAfter:sha(patchedMain),renderBefore:sha(render),renderAfter:sha(patchedRender)},scope:'Actual Ring/CpuEndpoint/cpu_endpoint source extracted; synthetic Array/OS/GetThreadTimes lower providers. Pending compiled execution, actual engine acceptance and disabled/enabled overhead checks.'};fs.writeFileSync(path.join(out,'source-pins.json'),JSON.stringify(result,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({out,cppSha256:result.cppSha256}));
