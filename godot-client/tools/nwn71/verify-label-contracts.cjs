'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../..'),arg=n=>process.argv.find(x=>x.startsWith('--'+n+'='))?.slice(n.length+3),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const capsule=path.resolve(root,arg('capsule')??'.cache/nwn71/group-labels-a'),receipt=JSON.parse(fs.readFileSync(path.join(capsule,'source-receipt.json'))),output=path.resolve(root,arg('report')??'.cache/nwn71/group-label-contract-a.json');
let checks=0;const check=(value,label)=>{checks++;assert(value,label);};
function preprocess(text,defines){
 const stack=[];let active=true;const result=[];
 function condition(expr){expr=expr.replace(/defined\((\w+)\)/g,(_,key)=>defines[key]?'1':'0').replace(/\b[A-Z_][A-Z_0-9]*\b/g,key=>defines[key]?'1':'0');if(!/^[\s01!&|()]+$/.test(expr))throw Error('Unknown conditional '+expr);return Boolean(Function('return ('+expr+')')());}
 for(const line of text.split('\n')){
  let match;if((match=line.match(/^#if(n?def)?\s+(.+)$/))){const value=match[1]?Boolean(defines[match[2].trim()])!==Boolean(match[1]==='ndef'):condition(match[2]);stack.push({parent:active,taken:value});active=active&&value;}
  else if((match=line.match(/^#elif\s+(.+)$/))){const row=stack.at(-1),value=!row.taken&&condition(match[1]);row.taken||=value;active=row.parent&&value;}
  else if(line==='#else'){const row=stack.at(-1);active=row.parent&&!row.taken;row.taken=true;}
  else if(line==='#endif'){active=stack.pop().parent;}
  else if(active)result.push(line);
 }
 assert.equal(stack.length,0);return result.join('\n');
}
function normalize(text){return text.replace(/^#include "core\/profiling\/profiling.h"\n/gm,'').replace(/\{\s*(WorkerThreadPool::get_singleton\(\)->wait_for_group_task_completion\(group_task\);)\s*\}/g,'$1').replace(/\/\/[^\n]*/g,'').replace(/\/\*[\s\S]*?\*\//g,'').replace(/\s+/g,'');}
for(const row of receipt.changes){
 const before=fs.readFileSync(path.join(capsule,'before',row.file),'utf8'),after=fs.readFileSync(path.join(capsule,'after',row.file),'utf8');
 check(sha(Buffer.from(before))===row.beforeSha256&&sha(Buffer.from(after))===row.afterSha256,'snapshot hashes');
 check(sha(fs.readFileSync(path.join(root,receipt.source,row.file)))===row.originalBytesSha256,'original engine source remains unedited');
 for(const threaded of [false,true])for(const cache of [false,true])for(const debug of [false,true]){
  const defs={THREADS_ENABLED:threaded,ENABLE_SHADER_CACHE:cache,DEBUG_ENABLED:debug,GODOT_USE_TRACY:false};
  check(normalize(preprocess(before,defs))===normalize(preprocess(after,defs)),'normal/non-Tracy code token equivalence '+row.file+' '+JSON.stringify(defs));
 }
 if(row.file.endsWith('worker_thread_pool.cpp')){
  const capture=after.indexOf('nwn71_task_id = p_task->self;'),lock=after.lastIndexOf('task_mutex.lock();',capture),unlock=after.indexOf('task_mutex.unlock();',capture);
  check(lock>=0&&lock<capture&&unlock>capture,'task IDs/description copied under existing mutex');
  check(after.indexOf('ZoneTextVF(nwn71_worker_task')>unlock,'UTF8 formatting/copy outside worker mutex');
  check(after.includes('"pool=%p;group=%lld;task=%lld;description=%s"')&&after.includes('"pool=%p;group=%lld"'),'task/wait exported text carries exact same pool+group join key');
  check(after.includes('.replace("\\t", " ").replace("\\r", " ").replace("\\n", " ")'),'worker descriptions cannot break TSV row framing');
 }
 if(row.file.endsWith('shader_rd.cpp')){
  check(after.includes('"pool=%p;group=%lld;shader=%s;variant_group=%d"'),'shader wait carries actual group ID and family');
  check(after.includes('"NWN71/Shader/compile_variant"'),'worker shader child is labeled without racing group task publication');
  check(!after.slice(after.indexOf('void ShaderRD::_compile_variant'),after.indexOf('Vector<RD::ShaderStageSPIRVData>')).includes('group_compilation_tasks'),'worker label never reads producer-published task vector');
 }
}
const exporter=fs.readFileSync(path.join(root,'.cache/native-tracy/vendor/tracy-0.13.0/csvexport/src/csvexport.cpp'),'utf8');check(exporter.includes('values[6] = worker.GetString(text);'),'official0.13 CSV value column exports ZoneText');
if(fs.existsSync(output))throw Error('Preserve existing report');fs.writeFileSync(output,JSON.stringify({passed:true,checks,sourceReceipt:{file:path.relative(root,path.join(capsule,'source-receipt.json')).replaceAll('\\','/'),sha256:sha(fs.readFileSync(path.join(capsule,'source-receipt.json')))},scope:'Source and preprocessing contract proof only, not a C++ compile or runtime trace-label acceptance.'},null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({passed:true,checks,report:path.relative(root,output).replaceAll('\\','/')}));
