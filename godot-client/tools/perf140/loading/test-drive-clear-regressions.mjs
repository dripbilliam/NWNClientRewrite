// Deferred functional entry only. Do not execute while a live/GPU/heavy-game
// quiet window is active. It stages private copies and hashes pinned inputs.
import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';
import {digest} from './processor-graph.mjs';import {runFixedHeadless} from './run-fixed-engine-once.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const [parentLabel,label,engineFile,engineSha,sourceMode,sourcePath]=process.argv.slice(2);
if(!/^drive-preview-clear-provenance-[a-z0-9-]+$/.test(parentLabel??'')||!/^drive-preview-clear-regression-[a-z0-9-]+$/.test(label??'')||!path.isAbsolute(engineFile??'')||!/^[0-9a-f]{64}$/.test(engineSha??'')||!['--catalog','--fixture'].includes(sourceMode)||!path.isAbsolute(sourcePath??''))throw Error('Explicit frozen metadata successor, fresh gate, exact engine and read-only WOK source required');
const parentFile=path.join(project,'.cache/native-140fps/loading-agent',parentLabel,'manifest.json'),parentBytes=fs.readFileSync(parentFile),parent=JSON.parse(parentBytes);
const pins=new Map(parent.pins.map(p=>[p.relative,p.sha256])),dll='.cache/native-kernel/nwn-particle-kernel.dll';
if(pins.get(dll)!=='101efc79d3c2985d2267d05f9ffbd01578d2f14bbf52bad575ef921cd2412417')throw Error('This gate is scoped to the frozen V1 compiled runtime');
const kernelBytes=fs.readFileSync(path.join(parent.project,'.cache/native-kernel/build-manifest.json')),kernel=JSON.parse(kernelBytes);
if(digest(kernelBytes)!==pins.get('.cache/native-kernel/build-manifest.json')||kernel.binarySha256!==pins.get(dll)||kernel.sourceReceiptSha256!=='f19c7f383953cf25b058daf51c06155fbaa019709b779e0da5231919578cb571'||kernel.relocatedSourceProject!==parent.project||kernel.successorCompilations!==0)throw Error('Corrected original-versus-relocated build provenance required');
const buildBytes=fs.readFileSync(path.join(parent.project,kernel.sourceReceiptRelative));if(digest(buildBytes)!==kernel.sourceReceiptSha256)throw Error('Actual original private build receipt differs');
const build=JSON.parse(buildBytes.toString('utf8').replace(/^\uFEFF/,''));if(build.project!==kernel.compiledSourceRoot||build.binarySha256!==pins.get(dll))throw Error('Actual compiled source/binary correlation differs');
for(const [relative,sha256]of Object.entries(build.sources))if(pins.get(relative)!==sha256)throw Error('Built native source inventory differs '+relative);
const stage=path.join(project,'.cache/native-140fps/loading-agent',label);if(fs.existsSync(stage))throw Error('Existing evidence preserved');fs.mkdirSync(stage);
const script='native_perf140_loading_drive_clear_physical_test.gd',fixtureSource=path.join(project,'tests',script),fixtureBytes=fs.readFileSync(fixtureSource);
const input=sourceMode==='--fixture'?{mode:'original',file:sourcePath,sha256:digest(fs.readFileSync(sourcePath))}:{mode:'recorded',directory:sourcePath,manifestSha256:digest(fs.readFileSync(path.join(sourcePath,'manifest.json')))};
const samePath=(a,b)=>typeof a==='string'&&path.resolve(a).toLowerCase()===path.resolve(b).toLowerCase();
const runs=[];
for(const native of [false,true]){
 const ownStage=path.join(stage,native?'native':'script'),copy=path.join(ownStage,'project');fs.mkdirSync(copy,{recursive:true});
 for(const pin of parent.pins){const bytes=fs.readFileSync(path.join(parent.project,pin.relative));if(digest(bytes)!==pin.sha256)throw Error('Frozen successor input drift '+pin.relative);const target=path.join(copy,pin.relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes);}
 fs.mkdirSync(path.join(copy,'tests'),{recursive:true});fs.writeFileSync(path.join(copy,'tests',script),fixtureBytes);
 const config='config_version=5\n[application]\nconfig/name="Isolated Physical WOK and Clear Mode Gate"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n';fs.writeFileSync(path.join(copy,'project.godot'),config);
 const result=await runFixedHeadless({stage:ownStage,copy,script},['--particle-kernel=compiled','--drive-collision=indexed',...(native?['--drive-clear=native']:[]),sourceMode+'='+sourcePath],120000,'process',{file:engineFile,sha256:engineSha});
 const drift=parent.pins.filter(p=>digest(fs.readFileSync(path.join(parent.project,p.relative)))!==p.sha256).map(p=>p.relative);
 const critical=[dll,'native/particle_kernel.gdextension','.godot/extension_list.cfg','systems/native_render/drive_collision_indexed.gd','systems/native_render/drive_clear_cache.gd'];
 const capsuleDrift=critical.filter(relative=>digest(fs.readFileSync(path.join(copy,relative)))!==pins.get(relative));
 if(digest(fs.readFileSync(path.join(copy,'tests',script)))!==digest(fixtureBytes))capsuleDrift.push('tests/'+script);
 const p=result.proof,a=p?.activation,c=p?.clear_activation;
 const activationAccepted=p?.native_clear_requested===native&&a?.pid===result.outcome.pid&&a?.display==='headless'&&samePath(a?.executable,engineFile)&&a?.kernel_enabled===true&&a?.native_class===true&&samePath(a?.library_file,path.join(copy,dll))&&c?.requested===native&&c?.enabled===native&&c?.last_height_calls===2&&(native?c?.configured>0&&c?.queries>0:c?.configured===0&&c?.queries===0);
 const corpusAccepted=Array.isArray(p?.sources)&&p.sources.length>0&&p.sources.length<=8&&p.sources.every(s=>s?.type===2016&&/^[0-9a-f]{64}$/.test(s?.sha256??''))&&p.native_resources===p.sources.length&&p.rays===p.sources.length*4*121&&Number.isSafeInteger(p.checks)&&p.checks>p.rays;
 const row={...result,success:result.success&&!drift.length&&!capsuleDrift.length&&activationAccepted&&corpusAccepted,nativeRequested:native,activationAccepted,corpusAccepted,sourceDrift:drift,capsuleDrift,manifestSha256:digest(parentBytes),fixtureSha256:digest(fixtureBytes),projectConfigSha256:digest(Buffer.from(config)),buildReceiptSha256:kernel.sourceReceiptSha256,input};
 fs.writeFileSync(path.join(ownStage,'receipt.json'),JSON.stringify(row,null,2)+'\n');runs.push(row);console.log(JSON.stringify({native,success:row.success,checks:row.proof?.checks,rays:row.proof?.rays,failures:row.proof?.failures}));if(!row.success)break;
}
const receipt={success:runs.length===2&&runs.every(r=>r.success),parent:{file:parentFile,sha256:digest(parentBytes)},compiledSourceRoot:kernel.compiledSourceRoot,relocatedSourceProject:parent.project,buildReceiptSha256:kernel.sourceReceiptSha256,fixtureSource,fixtureSha256:digest(fixtureBytes),input,runs,graphics:0,serverConnections:0,nativeBuilds:0,scope:'Fresh physical-WOK and distinct script/native clear route regressions only. No original-binary live, visual or performance acceptance.'};
const file=path.join(stage,'receipt.json');fs.writeFileSync(file,JSON.stringify(receipt,null,2)+'\n');console.log(JSON.stringify({file,success:receipt.success,checks:runs.reduce((sum,r)=>sum+Number(r.proof?.checks??0),0)}));if(!receipt.success)process.exitCode=1;
