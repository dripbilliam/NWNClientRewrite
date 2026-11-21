import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),label=process.argv[2];
if(!/^readonly-loan-[a-z0-9-]+$/.test(label??''))throw Error('Fresh readonly-loan label required');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex'),parentFile=path.join(project,'.cache/native-render-trials/native-manual-light-input-movement-1793869228225/overlay.json'),parentBytes=fs.readFileSync(parentFile),parent=JSON.parse(parentBytes);
const stage=path.join(project,'.cache/native-140fps/loading-agent',label);if(fs.existsSync(stage))throw Error('Existing evidence preserved');const baseline=path.join(stage,'baseline'),candidate=path.join(stage,'candidate'),pins=[];
for(const target of [baseline,candidate]){fs.mkdirSync(target,{recursive:true});for(const pin of parent.trialPins){const bytes=fs.readFileSync(path.join(parent.rendererProject,pin.relative));if(hash(bytes)!==pin.sha256)throw Error('Frozen source changed: '+pin.relative);const file=path.join(target,pin.relative);fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes);if(target===baseline)pins.push({...pin});}}
const once=(s,a,b)=>{if(s.split(a).length!==2)throw Error('Loan boundary changed: '+a);return s.replace(a,b);};
const storeRelative='systems/native_data/preparation_store.gd',assetRelative='systems/native_data/asset_service.gd',helperRelative='systems/native_data/readonly_bundle_loan.gd';
let store=fs.readFileSync(path.join(baseline,storeRelative),'utf8').replaceAll('\r\n','\n'),assets=fs.readFileSync(path.join(baseline,assetRelative),'utf8').replaceAll('\r\n','\n');
store=once(store,'const Accounting=preload("res://systems/native_data/resource_index_backend.gd")','const Accounting=preload("res://systems/native_data/resource_index_backend.gd")\nconst BundleLoan=preload("res://systems/native_data/readonly_bundle_loan.gd")\nvar loan_stats:={"published":0,"hits":0,"fallbacks":0,"rejected":0,"compile_us":0}');
store=once(store,'\t\tvar saved: Dictionary=entries[requests[request]].value; hits+=1; mutex.unlock()\n\t\treturn {"owner":false,"value":saved.duplicate(true) if private_graph else saved,"wait_us":0}',
 '\t\tvar entry: Dictionary=entries[requests[request]]; var saved: Dictionary=entry.value; var plan: Variant=entry.get("loan_plan"); hits+=1; mutex.unlock()\n\t\treturn {"owner":false,"value":saved.duplicate(true) if private_graph else (BundleLoan.borrow(plan) if plan!=null else saved),"wait_us":0}');
store=once(store,'\treturn {"owner":false,"value":flight.value.duplicate(true) if private_graph else flight.value,"wait_us":Time.get_ticks_usec()-began}',
 '\tvar plan: Variant=flight.get("loan_plan")\n\treturn {"owner":false,"value":flight.value.duplicate(true) if private_graph else (BundleLoan.borrow(plan) if plan!=null else flight.value),"wait_us":Time.get_ticks_usec()-began}');
store=once(store,'\tvar frozen: Dictionary=entries[requests[request]].value if expected==epoch and requests.has(request) and entries.has(requests[request]) else {}\n\tmutex.unlock()',
 '\tvar entry: Dictionary=entries[requests[request]] if expected==epoch and requests.has(request) and entries.has(requests[request]) else {}\n\tvar frozen: Dictionary=entry.get("value",{}); var plan: Variant=entry.get("loan_plan")\n\tmutex.unlock()');
store=once(store,'\tmutex.lock(); flight.value=frozen; flights.erase(flight_key); var count:=int(flight.waiters); mutex.unlock()',
 '\tmutex.lock(); flight.value=frozen\n\tif plan!=null:flight.loan_plan=plan\n\tflights.erase(flight_key); var count:=int(flight.waiters); mutex.unlock()');
store=once(store,'\tvar detached: Array=[]\n\tmutex.lock()\n\tif epoch!=expected: mutex.unlock(); return','\tpublish_owned(request,identity,copy,expected,size)\nfunc publish_owned(request: String,identity: String,copy: Dictionary,expected: int,size: int,loan_plan: Variant=null) -> bool:\n\tvar detached: Array=[]\n\tmutex.lock()\n\tif epoch!=expected: mutex.unlock(); return false');
store=once(store,'\t\tentries[identity]={"value":copy,"bytes":size}; order.append(identity); bytes+=size','\t\tentries[identity]={"value":copy,"bytes":size}\n\t\tif loan_plan!=null: entries[identity].loan_plan=loan_plan\n\t\torder.append(identity); bytes+=size');
store=once(store,'\tdetached.clear() # Worker-owned data disposal, outside the presentation lock.','\tdetached.clear() # Worker-owned data disposal, outside the presentation lock.\n\treturn true');
store=once(store,'func snapshot() -> Dictionary:',`func load_readonly_data(request: String,expected: int) -> Dictionary:
\tmutex.lock()
\tif expected!=epoch or not requests.has(request) or not entries.has(requests[request]): misses+=1; mutex.unlock(); return {}
\tvar entry: Dictionary=entries[requests[request]]; var value: Dictionary=entry.value; var plan: Variant=entry.get("loan_plan"); hits+=1
\tloan_stats["hits" if plan!=null else "fallbacks"]+=1; mutex.unlock()
\treturn BundleLoan.borrow(plan) if plan!=null else value.duplicate(true)
func save_readonly_data(request: String,identity: String,value: Dictionary,expected: int) -> bool:
\tvar began:=Time.get_ticks_usec(); var prepared:=BundleLoan.prepare(value)
\tmutex.lock(); loan_stats.compile_us+=Time.get_ticks_usec()-began
\tif not prepared.ready: loan_stats.rejected+=1; mutex.unlock(); return false
\tmutex.unlock()
\tvar cost:=Accounting.retained_cost({"value":prepared.value,"plan":prepared.plan},maximum_bytes)
\tvar size: int=int(cost.estimated_bytes) if cost.has("estimated_bytes") else var_to_bytes(prepared.value).size()+int(prepared.stats.containers)*256+int(prepared.stats.copy_branches)*320+int(prepared.stats.packed_leaves)*192
\tif size<=0 or size>maximum_bytes:return false
\tvar accepted:=publish_owned(request,identity,prepared.value,expected,size,prepared.plan)
\tif not accepted:return false
\tmutex.lock()
\tvar loanable: bool=expected==epoch and requests.get(request)==identity and entries.has(identity) and entries[identity].has("loan_plan")
\tif loanable:loan_stats.published+=1
\tmutex.unlock();return loanable
func snapshot() -> Dictionary:`);
store=once(store,'"accounting":accounting.duplicate()}; mutex.unlock()','"accounting":accounting.duplicate(),"readonly_bundle_loans":loan_stats.duplicate()}; mutex.unlock()');
// Decoded-source contracts keep their original behavior; completed loan entries
// must also detach packed wrappers when reached through generic begin/followers.
assets=once(assets,'var saved: Dictionary=job.memory_store.load_data(memory_key,int(job.memory_epoch))','var saved: Dictionary=job.memory_store.load_readonly_data(memory_key,int(job.memory_epoch)) if job.decoder=="static-model" and job.memory_store.has_method("load_readonly_data") else job.memory_store.load_data(memory_key,int(job.memory_epoch))');
assets=once(assets,'job.memory_store.save_data(memory_key,Cache.digest(var_to_bytes(saved.get("prework_inputs",[]))),saved,int(job.memory_epoch))','save_completed_bundle(job,memory_key,Cache.digest(var_to_bytes(saved.get("prework_inputs",[]))),saved)');
assets=once(assets,'job.memory_store.save_data(memory_key,identity,content,int(job.memory_epoch))','save_completed_bundle(job,memory_key,identity,content)');
assets=once(assets,'func publish_result(job: Dictionary,result: Dictionary) -> void:',`func save_completed_bundle(job: Dictionary,key: String,identity: String,content: Dictionary) -> void:
\tif job.decoder=="static-model" and job.memory_store.has_method("save_readonly_data") and job.memory_store.save_readonly_data(key,identity,content,int(job.memory_epoch)):return
\tjob.memory_store.save_data(key,identity,content,int(job.memory_epoch))
func publish_result(job: Dictionary,result: Dictionary) -> void:`);
fs.writeFileSync(path.join(candidate,storeRelative),store);fs.writeFileSync(path.join(candidate,assetRelative),assets);
const helper=fs.readFileSync(path.join(project,'tools/perf140/loading/readonly_bundle_loan.gd'));for(const target of [baseline,candidate])fs.writeFileSync(path.join(target,helperRelative),helper);
const changed=[storeRelative,assetRelative].map(relative=>({relative,before:hash(fs.readFileSync(path.join(baseline,relative))),after:hash(fs.readFileSync(path.join(candidate,relative)))}));changed.push({relative:helperRelative,before:null,after:hash(helper)});
const manifest={version:1,label,stage,baseline,candidate,parent:{file:parentFile,sha256:hash(parentBytes),rendererProject:parent.rendererProject},pins:[...pins,{relative:helperRelative,sha256:hash(helper)}],changed,backup:changed.filter(p=>p.before!==null).map(p=>({file:path.join(baseline,p.relative),sha256:p.before,verified:true})),serverConnections:0,sharedNativeBuilds:0,scope:'Static completed bundles only: private canonical publication; structurally immutable metadata loan; detached packed-array wrappers and every containing branch; existing actor/table/icon and rejected graphs retain private deep-copy path.'};
const file=path.join(stage,'manifest.json');fs.writeFileSync(file,JSON.stringify(manifest,null,2)+'\n');console.log(JSON.stringify({success:true,file,baseline,candidate,changed}));
