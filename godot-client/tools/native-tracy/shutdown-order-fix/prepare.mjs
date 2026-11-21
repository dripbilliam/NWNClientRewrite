// Source-only private patch. Root owns compilation/runtime and acceptance.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const args=Object.fromEntries(process.argv.slice(2).map(x=>{const n=x.indexOf('=');if(n<3||!x.startsWith('--'))throw Error('Use --engine-src=... --out=...');return[x.slice(2,n),x.slice(n+1)];}));
if(!args['engine-src']||!args.out)throw Error('Missing --engine-src or --out');
const source=fs.realpathSync(args['engine-src']),output=path.resolve(args.out);
const relative=path.relative(source,output);
if(relative===''||(!relative.startsWith('..'+path.sep)&&relative!=='..'&&!path.isAbsolute(relative)))throw Error('Output must be outside source');
if(fs.existsSync(output))throw Error('Preserve prior output; choose fresh --out');
const sha=x=>crypto.createHash('sha256').update(x).digest('hex'),inputs=[],outputs=[];
function read(name){const file=path.join(source,name),bytes=fs.readFileSync(file);inputs.push({file,sha256:sha(bytes),bytes:bytes.length});return bytes.toString('utf8').replaceAll('\r\n','\n');}
function exact(text,from,to,count){if(text.split(from).length-1!==count)throw Error('Source anchor count changed: '+from);return text.replaceAll(from,to);}
let header=read('core/os/thread.h');
header=exact(header,'static SafeNumeric<uint64_t> id_counter;','static std::atomic<uint64_t> id_counter;',1);
// safe_refcount.h already supplies <atomic>; include it explicitly for this type.
header=exact(header,'#include "core/templates/safe_refcount.h"','#include "core/templates/safe_refcount.h"\n#include <atomic>',1);
let cpp=read('core/os/thread.cpp');
cpp=exact(cpp,'SafeNumeric<uint64_t> Thread::id_counter(1);','std::atomic<uint64_t> Thread::id_counter{ 1 };',1);
cpp=exact(cpp,'thread_local Thread::ID Thread::caller_id = Thread::id_counter.increment();','thread_local Thread::ID Thread::caller_id = (Thread::id_counter.fetch_add(1, std::memory_order_acq_rel) + 1);',1);
cpp=exact(cpp,'\tid = id_counter.increment();','\tid = (id_counter.fetch_add(1, std::memory_order_acq_rel) + 1);',1);
cpp=exact(cpp,'\tcaller_id = id_counter.increment();','\tcaller_id = (id_counter.fetch_add(1, std::memory_order_acq_rel) + 1);',1);
const checks={
 qualifiedTLSInitializer:cpp.includes('thread_local Thread::ID Thread::caller_id = (Thread::id_counter.fetch_add(1, std::memory_order_acq_rel) + 1);'),
 exactThreeIncrements:(cpp.match(/id_counter\.fetch_add\(1, std::memory_order_acq_rel\)/g)||[]).length===3,
 noMalformedQualifiedExpression:!cpp.includes('Thread::('),
 noOldIncrementCalls:!cpp.includes('id_counter.increment()'),
 constantInitializedCounter:cpp.includes('std::atomic<uint64_t> Thread::id_counter{ 1 };')&&header.includes('static std::atomic<uint64_t> id_counter;'),
 claimAndReleaseAssertionsPreserved:cpp.includes('CRASH_COND_MSG(!is_main_thread_assigned.set_if_clear(), "A second thread attempted to become the main thread.");')&&cpp.includes('CRASH_COND(!is_main_thread_assigned.clear_if_set());'),
};
if(Object.values(checks).some(value=>value!==true))throw Error('Generated source contract failed: '+JSON.stringify(checks));
for(const[name,text]of[['core/os/thread.h',header],['core/os/thread.cpp',cpp]]){const file=path.join(output,name);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,text);outputs.push({relative:name,sha256:sha(Buffer.from(text)),bytes:Buffer.byteLength(text)});}
const factory=fs.readFileSync(fileURLToPath(import.meta.url));
fs.writeFileSync(path.join(output,'prepare.used.mjs'),factory);
const manifest={schema:1,kind:'private-thread-id-constant-initialization-proposal',revision:'B',status:'SOURCE_ONLY_UNCOMPILED_UNEXECUTED',source,output,inputs,outputs,checks,factorySha256:sha(factory),scope:'Only Thread::id_counter storage initialization changes. Same acq_rel fetch-add arithmetic, TLS initializer, main claim/release assertions, callbacks and shutdown order.',hypothesis:'Tracy MSVC .CRT$XCB early initialization can trigger dynamic image TLS before normal SafeNumeric counter initialization, making caller_id incorrectly equal reserved MAIN_ID.',proofRequired:['Root-owned old/fixed early-CRT TLS reproducer','Actual engine smoke with natural zero exit and all main/worker identities valid','Tracy trace readback and balanced bridge/error-free shutdown'],normalRuntimeChanged:false,accepted:false};
const file=path.join(output,'manifest.json');fs.writeFileSync(file,JSON.stringify(manifest,null,2)+'\n');process.stdout.write(JSON.stringify({manifest:file,sha256:sha(fs.readFileSync(file)),outputs:outputs.length,compiled:false})+'\n');
