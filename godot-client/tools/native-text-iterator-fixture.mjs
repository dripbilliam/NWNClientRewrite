// Compile the exact upstream iterator with an allocation-checking harness.
// Unicode classifiers below cover only the authored scalar corpus. This is
// memory/range evidence, not ICU/font/rendering or full engine acceptance.
import fs from 'node:fs/promises';import path from 'node:path';import {spawnSync} from 'node:child_process';import {createHash} from 'node:crypto';import {patchScriptIterator,SCRIPT_ITERATOR_SOURCE_SHA256} from './native-text-iterator-fix.mjs';
const run=process.argv.find(a=>a.startsWith('--run='))?.slice(6)??'v1';if(!/^v[0-9]+$/.test(run))throw Error('Invalid fixture run');
const lab=path.resolve('godot-client/.cache/native-text-build'),folder=path.join(lab,'iterator-fixture-'+run),report=path.resolve('godot-client/reports/native-text-iterator-fixture-'+run+'.json');
await fs.mkdir(folder);const original=await fs.readFile(path.join(lab,'source/modules/text_server_adv/script_iterator.cpp'),'utf8');
const patched=patchScriptIterator(original),sha=s=>createHash('sha256').update(s).digest('hex');
const header=String.raw`#pragma once
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <stdexcept>
#include <string>
#include <vector>
#include <unordered_map>
using UChar32=int32_t;using UErrorCode=int;using hb_script_t=uint32_t;
enum UScriptCode {USCRIPT_COMMON=0,USCRIPT_INHERITED=1,USCRIPT_GREEK=14,USCRIPT_LATIN=25,USCRIPT_CYRILLIC=8};
enum {UCHAR_EMOJI,UCHAR_EXTENDED_PICTOGRAPHIC,UCHAR_EMOJI_PRESENTATION,UCHAR_EMOJI_MODIFIER,UCHAR_REGIONAL_INDICATOR,UCHAR_BIDI_PAIRED_BRACKET_TYPE,U_BPT_NONE=0,U_BPT_OPEN=1,U_BPT_CLOSE=2};
constexpr int U_ZERO_ERROR=0;constexpr int HB_SCRIPT_COMMON=0;
#define U_FAILURE(e) ((e)!=0)
#define unlikely(x) (x)
#define HB_TAG(a,b,c,d) ((uint32_t(a)<<24)|(uint32_t(b)<<16)|(uint32_t(c)<<8)|uint32_t(d))
#define ERR_FAIL_MSG(s) throw std::runtime_error(s)
inline const char* u_errorName(int){return "authored error";}
inline UScriptCode uscript_getScript(UChar32 c,UErrorCode*){
 if((c>='A'&&c<='Z')||(c>='a'&&c<='z')||c==0xe9)return USCRIPT_LATIN;
 if(c==0x3a9||c==0x3b1)return USCRIPT_GREEK;if(c==0x416)return USCRIPT_CYRILLIC;
 if(c==0x1f48e||c==' '||c=='('||c==')'||c=='"'||c=='\\'||c==0)return USCRIPT_COMMON;
 throw std::runtime_error("Classifier outside authored corpus");
}
inline bool u_hasBinaryProperty(UChar32 c,int p){return c==0x1f48e&&(p==UCHAR_EMOJI||p==UCHAR_EXTENDED_PICTOGRAPHIC||p==UCHAR_EMOJI_PRESENTATION);}
inline int u_getIntPropertyValue(UChar32 c,int p){return p==UCHAR_BIDI_PAIRED_BRACKET_TYPE?(c=='('?U_BPT_OPEN:(c==')'?U_BPT_CLOSE:U_BPT_NONE)):0;}
inline UChar32 u_getBidiPairedBracket(UChar32 c){return c==')'?'(':')';}
inline hb_script_t hb_icu_script_to_script(UScriptCode s){return uint32_t(s);}
template<class T> using Vector=std::vector<T>;
class String {std::u32string s;public:String(std::u32string v):s(v){}const char32_t* ptr()const{return s.data();}};
struct Allocation {size_t size;bool alive;};
inline std::unordered_map<void*,Allocation> allocations;
inline int invalid_frees=0;inline int invalid_reallocs=0;inline int frees=0;
inline void* memalloc(size_t n){void* p=malloc(n);if(!p)throw std::bad_alloc();memset(p,0xcd,n);allocations[p]={n,true};return p;}
inline void* memrealloc(void* p,size_t n){auto it=allocations.find(p);if(it==allocations.end()||!it->second.alive){invalid_reallocs++;throw std::runtime_error("reallocation of freed storage");}size_t old=it->second.size;it->second.alive=false;void* q=realloc(p,n);if(!q)throw std::bad_alloc();if(n>old)memset(static_cast<char*>(q)+old,0xcd,n-old);allocations[q]={n,true};return q;}
inline void memfree(void* p){auto it=allocations.find(p);if(it==allocations.end()||!it->second.alive){invalid_frees++;return;}it->second.alive=false;frees++;free(p);}
class ScriptIterator {static constexpr int PAREN_STACK_DEPTH=128,EMOJI_STACK_DEPTH=32;static bool same_script(int32_t,int32_t);static bool is_emoji(UChar32,UChar32);public:struct ScriptRange{int start=0,end=0;hb_script_t script=HB_SCRIPT_COMMON;};Vector<ScriptRange> script_ranges;ScriptIterator(const String&,int,int);};
`;
const main=String.raw`
#include <iostream>
#include "script_iterator.h"
int main(){
 int cases=0,bad_ranges=0,double_frees=0,leaks=0,exceptions=0,bad_brackets=0;
 for(int runs:{0,1,31,32,33,63,64,65,200})for(int scripts:{1,2,3}){
  std::u32string input;for(int i=0;i<runs;i++)input+=U"é💎\\ \"";if(input.empty())input=U"a";
  if(scripts>=2)input+=U"Ω";if(scripts>=3)input+=U"Ж";
  int before=invalid_frees;cases++;try{ScriptIterator iterator(String(input),0,int(input.size()));int at=0;bool ok=true;
   for(const auto& range:iterator.script_ranges){if(range.start!=at||range.end<range.start||range.end>int(input.size()))ok=false;at=range.end;}
   if(!ok||at!=int(input.size()))bad_ranges++;
  }catch(...){exceptions++;}if(invalid_frees>before)double_frees++;
 }
 for(int depth:{127,128,129,256}){
  std::u32string input(depth,U'(');input+=U"aΩ";input+=std::u32string(depth,U')');input+=U"a";cases++;
  try{ScriptIterator iterator(String(input),0,int(input.size()));int at=0;bool ok=true;for(const auto& range:iterator.script_ranges){if(range.start!=at||range.end<range.start||range.end>int(input.size()))ok=false;at=range.end;}if(!ok||at!=int(input.size()))bad_ranges++;}catch(...){exceptions++;}
 }
 for(int depth:{127,128,129,256}){
  std::u32string input=U"a";input+=std::u32string(depth,U'(');input+=U"Ω(Ω)";input+=std::u32string(depth,U')');cases++;
  try{ScriptIterator iterator(String(input),0,int(input.size()));bool ok=false;for(const auto& range:iterator.script_ranges)if(range.start<int(input.size())&&range.end==int(input.size()))ok=range.script==uint32_t(USCRIPT_LATIN);if(!ok)bad_brackets++;}catch(...){exceptions++;}
 }
 for(const auto& [p,state]:allocations)if(state.alive)leaks++;
 std::cout<<"{\"cases\":"<<cases<<",\"invalidRangeCases\":"<<bad_ranges<<",\"doubleFreeCases\":"<<double_frees<<",\"invalidBracketScriptCases\":"<<bad_brackets<<",\"invalidFrees\":"<<invalid_frees<<",\"invalidReallocs\":"<<invalid_reallocs<<",\"leakedAllocations\":"<<leaks<<",\"exceptions\":"<<exceptions<<"}\n";
 return bad_ranges||double_frees||bad_brackets||invalid_reallocs||leaks||exceptions?1:0;
}
`;
await Promise.all([fs.writeFile(path.join(folder,'script_iterator.h'),header),fs.writeFile(path.join(folder,'main.cpp'),main)]);
const results={scope:'Exact pinned upstream C++ iterator compiled with allocation instrumentation and authored scalar classifiers; not whole-engine or font/rendering acceptance',originalSourceSha256:SCRIPT_ITERATOR_SOURCE_SHA256,patchedSourceSha256:sha(patched),cases:{}};
const compiler=path.join(lab,'compiler/w64devkit/bin/g++.exe');
for(const [name,source]of [['before',original],['after',patched]]){
 const cpp=path.join(folder,name+'.cpp'),exe=path.join(folder,name+'.exe');await fs.writeFile(cpp,source);
 const compile=spawnSync(compiler,['-std=c++17','-O0','-g',cpp,path.join(folder,'main.cpp'),'-o',exe],{windowsHide:true,encoding:'utf8'});
 if(compile.status!==0)throw Error(compile.stderr||compile.error||'Native fixture compile failed');
 const run=spawnSync(exe,[],{windowsHide:true,encoding:'utf8',timeout:10000});if(run.error)throw run.error;
 results.cases[name]={exit:run.status,...JSON.parse(run.stdout)};
}
const a=results.cases.after,b=results.cases.before;
results.passed=b.exit===1&&b.invalidRangeCases>0&&b.doubleFreeCases>0&&b.invalidBracketScriptCases>0&&a.exit===0&&a.cases===35&&a.invalidRangeCases===0&&a.invalidBracketScriptCases===0&&a.invalidFrees===0&&a.invalidReallocs===0&&a.leakedAllocations===0&&a.exceptions===0;
await fs.writeFile(report,JSON.stringify(results,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify(results));process.exitCode=results.passed?0:1;
