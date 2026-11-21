// Source-prepared gate runner. Do not execute during the user's live session.
import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';
import {digest} from './processor-graph.mjs';import {runHeadless} from './run-isolated-once.mjs';import {runFixedHeadless} from './run-fixed-engine-once.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..'),parentLabel=process.argv[2],label=process.argv[3],fixed=process.argv[4]?{file:process.argv[4],sha256:process.argv[5]}:null;
if(!/^drive-preview-[a-z0-9-]+$/.test(parentLabel??'')||!/^drive-preview-gate-[a-z0-9-]+$/.test(label??''))throw Error('Frozen drive parent and fresh gate label required');
const parentFile=path.join(project,'.cache/native-140fps/loading-agent',parentLabel,'manifest.json'),parentBytes=fs.readFileSync(parentFile),parent=JSON.parse(parentBytes),rootStage=path.join(project,'.cache/native-140fps/loading-agent',label);
if(fs.existsSync(rootStage))throw Error('Existing evidence preserved');fs.mkdirSync(rootStage);
const routeOnly=process.argv[6]==='--only-route';
const suites=[['route-off','native_perf140_loading_drive_route_test.gd',[]],...(['index','envelope','clear'].includes(parent.mode)?[['route-on','native_perf140_loading_drive_route_test.gd',['--drive-collision=indexed']]]:[]),...(['envelope','clear'].includes(parent.mode)?[['envelope','native_perf140_loading_drive_envelope_test.gd',['--drive-collision=indexed']]]:[]),...(parent.mode==='clear'?[['compiled-clear','native_perf140_loading_drive_clear_test.gd',['--drive-collision=indexed','--drive-clear=native']]]:[]),...(routeOnly?[]:[['index','native_drive_spatial_index_test.gd',[]],['adapter','native_drive_spatial_adapter_test.gd',parent.mode==='clear'?['--drive-clear=native']:[]],['collision','native_drive_collision_test.gd',[]]])];
const expected={
 'native_drive_spatial_index_test.gd':'1c0d246d96e29090e895a7bf6b310358eb0cdad33850f2731d402d6eeffb535e',
 'native_drive_spatial_adapter_test.gd':'7d3cb384e958fdc2a0b466cb0f9c9f57c6c4c18bacbfabc420fafd2fcc8f3335',
 'native_drive_collision_test.gd':'9f55c941d5d4143938f8bce197cb58aff4f59885583929c3d8f787b37fcb58d2',
 'native_drive_collision_legacy.gd':'0b49304d86a356439c7adbf465ed5e6c7d93cdd32ab1fd79a689811e7a1b6c56'
};
const runs=[];
for(const [suite,script,args]of suites){
 const stage=path.join(rootStage,suite),copy=path.join(stage,'project');fs.mkdirSync(copy,{recursive:true});
 for(const pin of parent.pins){const source=path.join(parent.project,pin.relative),bytes=fs.readFileSync(source);if(digest(bytes)!==pin.sha256)throw Error('Frozen private source differs: '+pin.relative);const target=path.join(copy,pin.relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes);}
 const supplemental=[];
 for(const name of new Set([script,'native_drive_collision_legacy.gd',...(['native_perf140_loading_drive_envelope_test.gd','native_perf140_loading_drive_clear_test.gd'].includes(script)?['native_drive_spatial_adapter_test.gd']:[])])){
  let source=path.join(parent.project,'tests',name);if(!fs.existsSync(source))source=path.join(project,'tests',name);
  const bytes=fs.readFileSync(source);if(expected[name]&&digest(bytes)!==expected[name])throw Error('Exact prior fixture pin differs: '+name);
  fs.mkdirSync(path.join(copy,'tests'),{recursive:true});fs.writeFileSync(path.join(copy,'tests',name),bytes);supplemental.push({relative:'tests/'+name,sha256:digest(bytes),source});
 }
 fs.writeFileSync(path.join(copy,'project.godot'),'config_version=5\n[application]\nconfig/name="Owned Drive Prediction Gate"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
 const capsule={stage,copy,script},result=fixed?await runFixedHeadless(capsule,args,65000,'process',fixed):await runHeadless(capsule,args,65000);
 const sourceDrift=parent.pins.filter(v=>digest(fs.readFileSync(path.join(parent.project,v.relative)))!==v.sha256).map(v=>v.relative);
 const row={suite,manifestSha256:digest(parentBytes),supplemental,...result,sourceDrift};row.success=result.success&&!sourceDrift.length;fs.writeFileSync(path.join(stage,'receipt.json'),JSON.stringify(row,null,2)+'\n');runs.push(row);
 console.log(JSON.stringify({suite,success:row.success,checks:row.proof?.checks,failures:row.proof?.failures}));if(!row.success)break;
}
const receipt={success:runs.length===suites.length&&runs.every(v=>v.success),routeOnly,runs,graphics:0,serverConnections:0,timingClaim:false,scope:routeOnly?'Supplemental exact CLI/factory/subphase/numeric gate; prior full suites not rerun because their source pins are unchanged.':'Exact owner selection and numeric transforms plus source-pinned existing full/delta/lifetime/door/motion/collision suites. Prior boundary diagnostics retained without fresh timing claims.'};
const file=path.join(rootStage,'receipt.json');fs.writeFileSync(file,JSON.stringify(receipt,null,2)+'\n');console.log(JSON.stringify({file,success:receipt.success,checks:runs.reduce((s,v)=>s+Number(v.proof?.checks??0),0)}));if(!receipt.success)process.exitCode=1;
