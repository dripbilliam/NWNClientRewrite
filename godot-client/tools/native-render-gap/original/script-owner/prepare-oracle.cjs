'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'../../../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const label=process.argv[2]||'a',sourceLabel=process.argv[3]||'a',source=path.join(root,'.cache/native-render-gap/original/script-owner/source-'+sourceLabel),out=path.join(root,'.cache/native-render-gap/original/script-owner/oracle-'+label);
if(!/^[a-z0-9-]+$/.test(label)||fs.existsSync(out))throw Error('Fresh label');fs.mkdirSync(out,{recursive:true});
let h=fs.readFileSync(path.join(source,'modules/nwn_frame_probe/script_owner_trace.h'),'utf8').replace(/^#pragma once\s*$/m,'').replace(/^#include.*$/gm,'').replace('Dictionary snapshot(bool p_include_rows);','');
let cpp=fs.readFileSync(path.join(source,'modules/nwn_frame_probe/script_owner_trace.cpp'),'utf8').replace(/^#include.*$/gm,'');const snapshotStart=cpp.indexOf('Dictionary snapshot(bool p_include_rows)'),shutdownStart=cpp.indexOf('void shutdown()');cpp=cpp.slice(0,snapshotStart)+(shutdownStart<0?'}\n':cpp.slice(shutdownStart));
const prelude=`#include <atomic>
#include <cstdint>
#include <string>
#include <vector>
#include <thread>
#include <stdexcept>
#include <new>
#include <cstdlib>
#include <iostream>
#define _FORCE_INLINE_ inline
using StringName=std::string;
using String=std::string;
static std::atomic<uint64_t> allocations{0};
void *operator new(std::size_t n) { allocations.fetch_add(1); if(void*p=std::malloc(n))return p;throw std::bad_alloc(); }
void operator delete(void*p) noexcept {std::free(p);}
void operator delete(void*p,std::size_t) noexcept {std::free(p);}
class OS {public:static inline OS *singleton=nullptr;std::vector<String>args;static OS*get_singleton(){return singleton;}const std::vector<String>&get_cmdline_user_args(){return args;}};
class Thread {public:static inline std::thread::id main_id;static bool is_main_thread(){return std::this_thread::get_id()==main_id;}};
`;
const test=`
static uint64_t checks=0;
static void check(bool b){++checks;if(!b)throw std::runtime_error("check "+std::to_string(checks));}
struct Function {uint32_t id=0;String source,name;int line;Function(String s,String n,int l):source(s),name(n),line(l){}};
static uint64_t entry(Function&f,bool enabled){return enabled?NwnScriptOwnerTrace::enter(f.id,f.source,f.name,f.line):NwnScriptOwnerTrace::NO_SCOPE;}
static uint32_t active(){return nwn_script_trace_active_id.load(std::memory_order_relaxed);}
static int early(Function&f,bool enabled,int kind){NwnScriptOwnerTrace::Scope scope(entry(f,enabled));check(!enabled||active()==f.id);if(kind<3)return kind;try{throw 7;}catch(int){return 3;}}
int main(int argc,char**argv){try{OS os;OS::singleton=&os;bool on=argc>1&&std::string(argv[1])=="on";if(on)os.args.push_back("--script-owner-trace=on");Thread::main_id=std::this_thread::get_id();check(NwnScriptOwnerTrace::enabled()==on);check(native_main_tid==0);Function a("res://a-long-source.gd","outer",10),b("res://a-long-source.gd","inner",20);check(active()==0);
{NwnScriptOwnerTrace::Scope sa(entry(a,on));check(active()==(on?a.id:0));for(int k=0;k<4;++k){check(early(b,on,k)==k);check(active()==(on?a.id:0));}
{NwnScriptOwnerTrace::Scope sb(entry(b,on));check(active()==(on?b.id:0));{NwnScriptOwnerTrace::Scope recurse(entry(a,on));check(active()==(on?a.id:0));}check(active()==(on?b.id:0));}check(active()==(on?a.id:0));
// Await returns its scope; later resumption uses the same immutable ID.
check(early(b,on,0)==0);check(active()==(on?a.id:0));uint32_t before=b.id;check(early(b,on,1)==1);check(b.id==before);check(active()==(on?a.id:0));
struct Cleanup {Function&f;bool on;~Cleanup(){NwnScriptOwnerTrace::Scope s(entry(f,on));if(on&&active()!=f.id)std::abort();}};
{NwnScriptOwnerTrace::Scope sb(entry(b,on));Cleanup c{a,on};}check(active()==(on?a.id:0));
std::atomic<bool>go{false},done{false};uint32_t id_before=b.id;uint32_t count_before=registered;std::thread t([&]{while(!go.load()){}for(int i=0;i<20000;++i){NwnScriptOwnerTrace::Scope s(entry(b,on));}done.store(true);});go.store(true);while(!done.load()){check(active()==(on?a.id:0));}t.join();check(b.id==id_before);check(registered==count_before);
}
check(active()==0);
alignas(Function) unsigned char storage[sizeof(Function)];Function*f=new(storage)Function("res://deleted-script.gd","deleted",30);{NwnScriptOwnerTrace::Scope s(entry(*f,on));}uint32_t deleted=f->id;f->~Function();f=new(storage)Function("res://replacement-script.gd","replacement",40);{NwnScriptOwnerTrace::Scope s(entry(*f,on));}if(on){check(f->id!=deleted);check(rows[deleted-1].name=="deleted");check(rows[f->id-1].name=="replacement");}f->~Function();
uint64_t alloc_before=allocations.load();for(int i=0;i<100000;++i){NwnScriptOwnerTrace::Scope sa(entry(a,on));{NwnScriptOwnerTrace::Scope sb(entry(b,on));}check(active()==(on?a.id:0));}check(allocations.load()==alloc_before);check(active()==0);
if(on){while(registered<REGISTRY_LIMIT){Function next("res://overflow.gd","unique",5);NwnScriptOwnerTrace::Scope s(entry(next,true));check(next.id==registered);}Function full("res://overflow.gd","full",6),full2("res://overflow.gd","full2",7);{NwnScriptOwnerTrace::Scope sa(entry(full,true));check(active()==UINT32_MAX);{NwnScriptOwnerTrace::Scope sb(entry(a,true));check(active()==a.id);}check(active()==UINT32_MAX);{NwnScriptOwnerTrace::Scope sb(entry(full2,true));check(active()==UINT32_MAX);}check(active()==UINT32_MAX);}check(active()==0);check(registered==REGISTRY_LIMIT);check(overflow_functions==2);for(int i=0;i<10;++i){NwnScriptOwnerTrace::Scope s(entry(full,true));}check(overflow_functions==2);}else{check(registered==0);check(a.id==0&&b.id==0);check(overflow_functions==0);}
std::thread shutdown_worker([]{NwnScriptOwnerTrace::shutdown();});shutdown_worker.join();check(!shutting_down);const uint32_t retained_count=registered;NwnScriptOwnerTrace::shutdown();check(shutting_down);check(active()==0);for(uint32_t i=0;i<registered;++i){check(rows[i].name.empty());check(rows[i].source.empty());}Function after("res://after.gd","after",8);{NwnScriptOwnerTrace::Scope s(entry(after,on));check(active()==0);}check(after.id==0);check(registered==retained_count);NwnScriptOwnerTrace::shutdown();check(registered==retained_count);
std::cout<<"{\\"pass\\":true,\\"on\\":"<<(on?"true":"false")<<",\\"checks\\":"<<checks<<",\\"registered\\":"<<registered<<",\\"overflow\\":"<<overflow_functions<<",\\"steady_allocations\\":0,\\"shutdown_cleared\\":true}"<<std::endl;return 0;}catch(const std::exception&e){std::cerr<<e.what()<<std::endl;return 1;}}
`;
const text=prelude+h+'\n'+cpp+test;fs.writeFileSync(path.join(out,'oracle.cpp'),text,{flag:'wx'});fs.writeFileSync(path.join(out,'source.json'),JSON.stringify({version:1,source,out,sourceSha256:sha(text),extractedHeaderSha256:sha(h),extractedImplementationSha256:sha(cpp),limitations:'Actual enter/enabled/Scope fragments, mocked OS/thread/string providers. Actual Godot VM/error/await behavior still requires compiled engine fixture.'},null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({out,sourceSha256:sha(text)}));
