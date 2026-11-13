// Pure-source check, including the actual A regression. No compiler/native launch.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
const [manifestFile, rejectedAFile] = process.argv.slice(2);
if(!manifestFile || !rejectedAFile)throw Error('Usage: node source-check.mjs <new-manifest> <rejected-A-thread.cpp>');
const manifest=JSON.parse(fs.readFileSync(manifestFile,'utf8'));
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const normalize=b=>b.toString('utf8').replaceAll('\r\n','\n');
let pinChecks=0;
for(const row of manifest.inputs){assert.equal(sha(fs.readFileSync(row.file)),row.sha256);++pinChecks;}
for(const row of manifest.outputs){assert.equal(sha(fs.readFileSync(path.join(manifest.output,row.relative))),row.sha256);++pinChecks;}
const oldCpp=normalize(fs.readFileSync(path.join(manifest.source,'core/os/thread.cpp')));
const newCpp=normalize(fs.readFileSync(path.join(manifest.output,'core/os/thread.cpp')));
const oldHeader=normalize(fs.readFileSync(path.join(manifest.source,'core/os/thread.h')));
const newHeader=normalize(fs.readFileSync(path.join(manifest.output,'core/os/thread.h')));
assert(newCpp.includes('thread_local Thread::ID Thread::caller_id = (Thread::id_counter.fetch_add(1, std::memory_order_acq_rel) + 1);'));
assert(!newCpp.includes('Thread::('));
const inverseCpp=newCpp
 .replace('std::atomic<uint64_t> Thread::id_counter{ 1 };','SafeNumeric<uint64_t> Thread::id_counter(1);')
 .replace('(Thread::id_counter.fetch_add(1, std::memory_order_acq_rel) + 1)','Thread::id_counter.increment()')
 .replaceAll('(id_counter.fetch_add(1, std::memory_order_acq_rel) + 1)','id_counter.increment()');
assert.equal(inverseCpp,oldCpp,'No other thread.cpp behavior may change');
const inverseHeader=newHeader
 .replace('static std::atomic<uint64_t> id_counter;','static SafeNumeric<uint64_t> id_counter;')
 .replace('#include "core/templates/safe_refcount.h"\n#include <atomic>','#include "core/templates/safe_refcount.h"');
assert.equal(inverseHeader,oldHeader,'No other thread.h behavior may change');
const rejected=normalize(fs.readFileSync(rejectedAFile));
assert(rejected.includes('Thread::(id_counter.fetch_add('),'Must test the retained actual malformed A output');
assert(!rejected.includes('thread_local Thread::ID Thread::caller_id = (Thread::id_counter.fetch_add(1, std::memory_order_acq_rel) + 1);'));
assert(!oldCpp.includes('Thread::(id_counter.fetch_add('));
assert.equal(Object.values(manifest.checks).every(x=>x===true),true);
process.stdout.write(JSON.stringify({success:true,scope:'source-only, not C++ compilation or runtime acceptance',pinChecks,exactInverseCPP:true,exactInverseHeader:true,actualRejectedARecognized:true,checks:manifest.checks})+'\n');
