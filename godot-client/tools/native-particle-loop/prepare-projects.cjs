'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const project=path.resolve(__dirname,'../..'),label=process.argv[2];if(!/^[a-z0-9-]+$/.test(label??''))throw Error('Explicit experiment label required');
const root=path.join(project,'.cache/native-presentation-parity/root/fps-max-v1','particle-loop-'+label);
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const baseFile=path.join(project,'.cache/native-presentation-parity/production-replay/fps-max-v1-merged-workers-b/production-selection.json'),base=JSON.parse(fs.readFileSync(baseFile));
for(const pin of base.pins)if(hash(fs.readFileSync(path.join(base.sourceProject,pin.relative)))!==pin.sha256)throw Error('Frozen accepted selection differs: '+pin.relative);
for(const variant of ['control','candidate']){
 const folder=path.join(root,variant),stage=path.join(folder,'project');if(fs.existsSync(stage))throw Error('Existing project preserved');
 const buildFile=path.join(folder,'build/build-proof.json'),build=JSON.parse(fs.readFileSync(buildFile));if(!build.success||build.variant!==variant)throw Error('Private build missing');
 fs.mkdirSync(stage);
 const files=new Map(base.pins.map(pin=>[pin.relative,path.join(base.sourceProject,pin.relative)]));
 for(const pin of build.sourcePins)files.set(pin.relative,path.join(folder,pin.relative));
 files.set('.cache/native-kernel/nwn-particle-kernel.dll',path.join(folder,'build/nwn-particle-kernel.dll'));
 files.set('.cache/native-kernel/build-manifest.json',buildFile);
 files.set('tools/native-particle-loop/bookkeeping_test.gd',path.join(__dirname,'bookkeeping_test.gd'));
 const pins=[];for(const [relative,source]of files){const bytes=fs.readFileSync(source),dest=path.join(stage,relative);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,bytes,{flag:'wx'});pins.push({relative,sha256:hash(bytes)});}
 const oracle='native-emitter-bucket-v1.json',bytes=fs.readFileSync(path.resolve(project,'../backups/animations',oracle));fs.mkdirSync(path.join(folder,'backups/animations'),{recursive:true});fs.writeFileSync(path.join(folder,'backups/animations',oracle),bytes,{flag:'wx'});
 const manifest={version:1,variant,project:stage,pins,engine:base.runtime,base:{file:baseFile,sha256:hash(fs.readFileSync(baseFile))},build:{file:buildFile,sha256:hash(fs.readFileSync(buildFile)),binarySha256:build.binarySha256},oracle:{file:path.join(folder,'backups/animations',oracle),sha256:hash(bytes)},source:require('../native-feature-manifest.cjs').sourceIdentity(stage).sha256,scope:'Isolated native-loop test project, no main source/default/library changes and no production acceptance'};
 fs.writeFileSync(path.join(folder,'test-manifest.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({variant,project:stage,files:pins.length,source:manifest.source,binarySha256:build.binarySha256}));
}
