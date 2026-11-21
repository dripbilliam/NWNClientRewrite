'use strict';
// Reconstruct a PRIVATE accepted-D source tree. Never copies existing objects.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict'),cp=require('node:child_process');
const project=path.resolve(__dirname,'../..');
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
const inputFile=path.join(__dirname,'accepted-engine-inputs.json');
const inputSha='306e05bbfeeacb1b5eec28990a22a65b36e5131aab145301d40b6b7078980797';
function child(root,relative){assert(relative&&!path.isAbsolute(relative)&&!relative.split(/[\\/]/).some(x=>x==='..'||x===''));const result=path.resolve(root,relative);assert(result.startsWith(path.resolve(root)+path.sep));return result;}
function read(file,digest){assert.equal(sha(file),digest,'Pinned source changed: '+file);return JSON.parse(fs.readFileSync(file));}
function main(){
 const opt=Object.fromEntries(process.argv.slice(2).map(x=>{assert(/^--[a-z-]+=/.test(x));const i=x.indexOf('=');return[x.slice(2,i),x.slice(i+1)];}));
 assert(Object.keys(opt).every(k=>['mode','label'].includes(k)));const mode=opt.mode??'check';assert(['check','prepare'].includes(mode));
 const inputs=read(inputFile,inputSha);assert.equal(inputs.overrides.length,52);assert.equal(sha(inputs.originalArchive.file),inputs.originalArchive.sha256);
 for(const row of inputs.overrides){child(project,row.relative);assert.equal(sha(row.sourceFile),row.sha256);}
 const vendorFile=path.join(project,'.cache/native-tracy/vendor/tracy-v0.13.0.source.json');const vendor=read(vendorFile,'dd2592252feb4897fc974c74b61a7d04c3cc1adca481c2b7f840a339a359200b');assert.equal(vendor.commit,'e6b9ea460993a6f093283055ef3c98025b19f909');
 for(const pin of vendor.pins)assert.equal(sha(child(vendor.source,pin.relative)),pin.sha256);
 if(mode==='check'){console.log(JSON.stringify({success:true,overrides:52,archiveVerified:true,tracyVersion:vendor.version,materialized:false}));return;}
 assert(/^[a-z0-9-]+$/.test(opt.label??''));const stage=child(path.join(project,'.cache/native-tracy'),opt.label);assert(!fs.existsSync(stage),'Preserve prior diagnostic source/build');const source=path.join(stage,'source');fs.mkdirSync(source,{recursive:true});
 const tar=cp.spawnSync('tar.exe',['-xzf',inputs.originalArchive.file,'--strip-components=1','-C',source],{windowsHide:true,encoding:'utf8',maxBuffer:1024*1024,timeout:120000});assert.equal(tar.status,0,tar.stderr);
 for(const row of inputs.overrides){const target=child(source,row.relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(row.sourceFile,target);assert.equal(sha(target),row.sha256);}
 assert(!fs.existsSync(path.join(source,'bin/obj')),'Clean source must contain no old object tree');
 const original={kind:'private-accepted-d-source-reconstruction',stage,source,createdUtc:new Date().toISOString(),archive:inputs.originalArchive,inputs:{file:inputFile,sha256:inputSha},vendor:{file:vendorFile,sha256:sha(vendorFile),source:vendor.source,commit:vendor.commit},overrides:inputs.overrides.map(row=>({relative:row.relative,sha256:row.sha256})),installedSelectionChanged:false,compiled:false,scope:'Source equivalent accepted-D fork from the original archive and52 pinned authored overrides. Private Tracy instrumentation must be applied and separately sealed before building. A new compiler/profiler build is not byte-identical10b.'};
 const file=path.join(stage,'reconstruction.json');fs.writeFileSync(file,JSON.stringify(original,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({file,sha256:sha(file),source,compiled:false}));
}
if(require.main===module){try{main();}catch(error){console.error(error.stack);process.exitCode=1;}}
module.exports={project,sha,child,read};
