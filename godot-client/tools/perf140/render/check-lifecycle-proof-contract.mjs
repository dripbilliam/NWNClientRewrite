// Tiny pure Node negative controls. No engine/process launch, Node3D, native
// compile, GPU, server, copied tree or performance measurements.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {generatedLifecycleOrder,parseLifecycleRecord,lifecyclePhasesValid,lifecycleEngineErrors,LIFECYCLE_PREFIX,LIFECYCLE_PHASES} from './lifecycle_proof_contract.mjs';

const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const label=process.argv[2];if(!/^[a-z0-9-]+$/.test(label??''))throw Error('Fresh private pure-check label required');
const stage=path.join(project,'.cache/native-140fps/render-agent',label);if(fs.existsSync(stage))throw Error('Retain earlier pure-check artifacts');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),fileHash=file=>hash(fs.readFileSync(file));
const frozenFile=path.join(project,'.cache/native-140fps/particles-agent/synchronous-engine-read-lifecycle-source-v1/source-manifest.json');
const freezeHash='2eee803ff43619ab49fb7d12657a1bb191b8d0a2e83fdb65a2588444092c0815';
if(fileHash(frozenFile)!==freezeHash)throw Error('Frozen module receipt changed');
const sourceFiles=['lifecycle_proof_contract.mjs','check-lifecycle-proof-contract.mjs','synchronous-read-lifecycle-engine.mjs'].map(relative=>({file:path.join(project,'tools/perf140/render',relative),relative}));
const sourcePins=sourceFiles.map(pin=>({...pin,sha256:fileHash(pin.file)}));
const results=[];
function check(name,value){results.push({name,success:value===true});}
function acceptsOrder(text){try{generatedLifecycleOrder(text);return true;}catch{return false;}}
function functionText(name,calls){return 'void '+name+'(ModuleInitializationLevel p_level) {\n'+calls.map(call=>'\t'+call).join('\n')+'\n}\n';}
const initProducer='initialize_nwn_particle_reads_module(p_level);',initProbe='initialize_nwn_particle_reads_lifecycle_test_module(p_level);';
const uninitProducer='uninitialize_nwn_particle_reads_module(p_level);',uninitProbe='uninitialize_nwn_particle_reads_lifecycle_test_module(p_level);';
const generated=(init=[initProducer,initProbe],uninit=[uninitProducer,uninitProbe])=>functionText('initialize_modules',init)+'\n'+functionText('uninitialize_modules',uninit);
const goodOrder=generated();
check('same forward order is accepted independently in both functions',acceptsOrder(goodOrder));
check('actual Windows CRLF spelling is accepted',acceptsOrder(goodOrder.replaceAll('\n','\r\n')));
check('unrelated other modules preserve proof',acceptsOrder(generated(['initialize_other_module(p_level);',initProducer,initProbe],['uninitialize_other_module(p_level);',uninitProducer,uninitProbe])));
for(const [name,init,uninit]of [
 ['reverse init',[initProbe,initProducer],[uninitProducer,uninitProbe]],
 ['reverse teardown',[initProducer,initProbe],[uninitProbe,uninitProducer]],
 ['missing init producer',[initProbe],[uninitProducer,uninitProbe]],
 ['missing init probe',[initProducer],[uninitProducer,uninitProbe]],
 ['missing teardown producer',[initProducer,initProbe],[uninitProbe]],
 ['missing teardown probe',[initProducer,initProbe],[uninitProducer]],
 ['duplicate init producer',[initProducer,initProducer,initProbe],[uninitProducer,uninitProbe]],
 ['duplicate teardown probe',[initProducer,initProbe],[uninitProducer,uninitProbe,uninitProbe]],
 ['wrong producer verb in init',[uninitProducer,initProbe],[uninitProducer,uninitProbe]],
 ['wrong probe verb in init',[initProducer,uninitProbe],[uninitProducer,uninitProbe]],
 ['comment is not a producer call',['// '+initProducer,initProbe],[uninitProducer,uninitProbe]],
 ['identifier suffix is not a producer',['fake_'+initProducer,initProbe],[uninitProducer,uninitProbe]],
 ['wrong argument is not a producer call',[initProducer.replace('(p_level)','(other_level)'),initProbe],[uninitProducer,uninitProbe]],
])check('reject '+name,!acceptsOrder(generated(init,uninit)));
check('reject duplicate function definitions',!acceptsOrder(goodOrder+functionText('initialize_modules',[initProducer,initProbe])));
check('reject missing function body terminator',!acceptsOrder(goodOrder.slice(0,goodOrder.lastIndexOf('\n}'))));
check('reject non-text generated source',!acceptsOrder(null));

function validResult(){return {version:1,success:true,events:LIFECYCLE_PHASES.map((phase,i)=>({phase,expected:i===1?1:5,eligibility:i===1?1:5,validation:i===1?1:5,transform:i===1?1:5,table:true,same_table:true,output:true,bounds:true})),nodes_retained:0,dll_callbacks_retained:0};}
const line=value=>LIFECYCLE_PREFIX+JSON.stringify(value)+'\n';
function acceptsRecord(stdout){try{return lifecyclePhasesValid(parseLifecycleRecord(stdout))===true;}catch{return false;}}
check('accept complete valid lifecycle record',acceptsRecord(line(validResult())));
check('accept unrelated ordinary stdout before/after',acceptsRecord('Godot startup\n'+line(validResult())+'ordinary shutdown\n'));
check('accept CRLF lifecycle output',acceptsRecord(line(validResult()).replaceAll('\n','\r\n')));
check('reject missing result',!acceptsRecord('ordinary exit\n'));
check('reject duplicate complete records',!acceptsRecord(line(validResult())+line(validResult())));
check('reject truncated JSON record',!acceptsRecord(line(validResult()).slice(0,-4)+'\n'));
check('reject final newline lost to short write',!acceptsRecord(line(validResult()).slice(0,-1)));
check('reject interleaved text before record prefix',!acceptsRecord('partial other writer '+line(validResult())));
check('reject appended garbage on JSON line',!acceptsRecord(line(validResult()).slice(0,-1)+'garbage\n'));
check('reject wrong result prefix',!acceptsRecord(line(validResult()).replace(LIFECYCLE_PREFIX,'OTHER_RESULT ')));
for(const [name,mutate] of [
 ['version',v=>{v.version=2;}],['source false',v=>{v.success=false;}],['missing events',v=>{delete v.events;}],['event not array',v=>{v.events={length:5};}],['missing phase',v=>{v.events.pop();}],['extra phase',v=>{v.events.push(v.events[0]);}],['retained Node',v=>{v.nodes_retained=1;}],['retained callback',v=>{v.dll_callbacks_retained=1;}],['format failure record',v=>{v.format_error=true;v.success=false;v.events=[];}],
]){const v=validResult();mutate(v);check('reject '+name,!acceptsRecord(line(v)));}
for(let index=0;index<5;index++)for(const field of ['phase','expected','eligibility','validation','transform','table','same_table','output','bounds']){
 const v=validResult();v.events[index][field]=field==='phase'?'wrong_phase':typeof v.events[index][field]==='boolean'?false:99;
 check('reject '+LIFECYCLE_PHASES[index]+' '+field+' corruption',!acceptsRecord(line(v)));
}
{const v=validResult();v.events[2]=null;check('reject null phase record',!acceptsRecord(line(v)));}
{const v=validResult();v.events[1].expected='1';check('reject string status',!acceptsRecord(line(v)));}
check('ordinary output is clean',!lifecycleEngineErrors('Godot\n','',''));
for(const text of ['SCRIPT ERROR: failed','ERROR: failed','WARNING: ObjectDB instances leaked at exit','Resources still in use at exit'])check('reject engine/lifetime error '+text,lifecycleEngineErrors('',text,''));

const changed=sourcePins.filter(pin=>fileHash(pin.file)!==pin.sha256);
const frozenUnchanged=fileHash(frozenFile)===freezeHash;
const receipt={version:1,success:results.every(r=>r.success)&&!changed.length&&frozenUnchanged,checks:results.length,failures:results.filter(r=>!r.success),sourcePins,changed,frozenModuleReceipt:{file:frozenFile,sha256:freezeHash,unchanged:frozenUnchanged},results,scope:'Pure generated-order and completed-record rejection only; no engine, native ABI or lifecycle execution.',engineStarts:0,engineCopies:0,nativeBuilds:0,gpu:false,serverConnections:0};
fs.mkdirSync(stage,{recursive:true});fs.writeFileSync(path.join(stage,'receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({success:receipt.success,stage,checks:receipt.checks,failures:receipt.failures,changed,frozenUnchanged}));if(!receipt.success)process.exitCode=1;
