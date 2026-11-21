import {isolatedHeadless} from './isolated-headless.mjs';
import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const additional=process.argv.slice(3);
if(additional.some(v=>!/^--(?:recorded-catalog|models)=/.test(v)))throw Error('Only recorded catalog/model-list inputs are accepted');
const catalog=additional.find(v=>v.startsWith('--recorded-catalog='))?.slice('--recorded-catalog='.length),hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const guard=catalog?{file:path.join(catalog,'manifest.json'),sha256:hash(fs.readFileSync(path.join(catalog,'manifest.json')))}:null;
const report=await isolatedHeadless({
 label:process.argv[2],pattern:/^readonly-loan-[a-z0-9-]+$/,
 script:'native_perf140_loading_loan_copy_benchmark.gd',directory:'checks-copy-benchmark',timeoutMs:180000,
 argumentsForVariant:()=>['--prepared-cache-write=disabled',...additional]
});
if(guard){
 const after=hash(fs.readFileSync(guard.file)),unchanged=after===guard.sha256;
 const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),file=path.join(project,'.cache/native-140fps/loading-agent',process.argv[2],'checks-copy-benchmark/capture-guard.json');
 fs.writeFileSync(file,JSON.stringify({success:unchanged,before:guard,afterSha256:after,scope:'Read-only recorded catalog; every used payload is also checked by RecordedCatalog against its sealed content SHA256. No capture writes.'},null,2)+'\n');
 if(!unchanged)throw Error('Sealed catalog manifest changed during benchmark');
}
if(!report.success)process.exitCode=1;
