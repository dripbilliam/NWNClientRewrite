// Deferred isolated golden exporter. No native height integration/build.
import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';
import {digest} from './processor-graph.mjs';import {runFixedHeadless} from './run-fixed-engine-once.mjs';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const [parentFile,parentSha,label,engineFile,engineSha,sourceMode,sourcePath]=process.argv.slice(2);
if(!path.isAbsolute(parentFile??'')||!/^[0-9a-f]{64}$/.test(parentSha??'')||!/^drive-height-reference-[a-z0-9-]+$/.test(label??'')||!path.isAbsolute(engineFile??'')||!/^[0-9a-f]{64}$/.test(engineSha??'')||!['--catalog','--fixture'].includes(sourceMode)||!path.isAbsolute(sourcePath??''))throw Error('Explicit frozen parent/exact engine/fresh label/read-only source required');
const parentBytes=fs.readFileSync(parentFile);if(digest(parentBytes)!==parentSha)throw Error('Frozen reference parent differs');const parent=JSON.parse(parentBytes);
const stage=path.join(project,'.cache/native-140fps/loading-agent',label),copy=path.join(stage,'project');if(fs.existsSync(stage))throw Error('Existing evidence preserved');fs.mkdirSync(copy,{recursive:true});
for(const pin of parent.pins){const bytes=fs.readFileSync(path.join(parent.project,pin.relative));if(digest(bytes)!==pin.sha256)throw Error('Frozen reference source differs '+pin.relative);const target=path.join(copy,pin.relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes);}
const script='native_perf140_loading_drive_height_reference.gd',fixtureSource=path.join(project,'tests',script),fixture=fs.readFileSync(fixtureSource);fs.mkdirSync(path.join(copy,'tests'),{recursive:true});fs.writeFileSync(path.join(copy,'tests',script),fixture);
const config='config_version=5\n[application]\nconfig/name="Original Height Golden Export Only"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n';fs.writeFileSync(path.join(copy,'project.godot'),config);
const corpus=path.join(stage,'height-original.bin');
const input=sourceMode==='--fixture'?{mode:'original',file:sourcePath,sha256:digest(fs.readFileSync(sourcePath))}:{mode:'recorded',directory:sourcePath,manifestSha256:digest(fs.readFileSync(path.join(sourcePath,'manifest.json')))};
const result=await runFixedHeadless({stage,copy,script},['--corpus='+corpus,sourceMode+'='+sourcePath],120000,'process',{file:engineFile,sha256:engineSha});
const drift=parent.pins.filter(pin=>digest(fs.readFileSync(path.join(parent.project,pin.relative)))!==pin.sha256).map(pin=>pin.relative);
const actualCorpus=fs.existsSync(corpus)?{file:corpus,bytes:fs.statSync(corpus).size,sha256:digest(fs.readFileSync(corpus))}:null;
const samePath=(a,b)=>typeof a==='string'&&path.resolve(a).toLowerCase()===path.resolve(b).toLowerCase();
const p=result.proof,pinnedSurface=parent.pins.find(pin=>pin.relative==='systems/native_data/tile_surface.gd')?.sha256;
const activationAccepted=p?.activation?.pid===result.outcome.pid&&p?.activation?.display==='headless'&&samePath(p?.activation?.executable,engineFile)&&typeof pinnedSurface==='string'&&p?.surface_script_sha256===pinnedSurface;
const corpusAccepted=actualCorpus!==null&&typeof p?.corpus?.sha256==='string'&&actualCorpus.sha256===p.corpus.sha256&&actualCorpus.bytes===p.corpus.bytes&&actualCorpus.bytes>=12&&actualCorpus.bytes<=64*1024*1024&&Number.isSafeInteger(p.corpus.cases)&&p.corpus.cases>0&&Number.isSafeInteger(p.corpus.queries)&&p.corpus.queries>0&&Array.isArray(p.sources)&&p.sources.some(s=>s.resource==='surfacemat'&&s.type===2017)&&p.sources.some(s=>s.type===2016);
const capsuleDrift=[];
if(digest(fs.readFileSync(path.join(copy,'systems/native_data/tile_surface.gd')))!==pinnedSurface)capsuleDrift.push('systems/native_data/tile_surface.gd');
if(digest(fs.readFileSync(path.join(copy,'tests',script)))!==digest(fixture))capsuleDrift.push('tests/'+script);
const receipt={...result,success:result.success&&!drift.length&&!capsuleDrift.length&&activationAccepted&&corpusAccepted,parent:{file:parentFile,sha256:parentSha},sourceDrift:drift,capsuleDrift,activationAccepted,corpusAccepted,fixtureSource,fixtureSha256:digest(fixture),projectConfigSha256:digest(Buffer.from(config)),input,corpus:actualCorpus,nativeBuilds:0,nativeHeightIntegration:false,graphics:0,serverConnections:0,scope:'Unchanged production Godot Surface.height golden bytes only; no native kernel or gameplay/performance acceptance.'};
const file=path.join(stage,'receipt.json');fs.writeFileSync(file,JSON.stringify(receipt,null,2)+'\n');console.log(JSON.stringify({file,success:receipt.success,checks:result.proof?.checks,corpus:actualCorpus}));if(!receipt.success)process.exitCode=1;
