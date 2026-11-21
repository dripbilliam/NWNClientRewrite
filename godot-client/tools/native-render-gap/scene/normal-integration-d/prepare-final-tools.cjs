'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
function fresh(name,content){const file=path.join(__dirname,name);assert(!fs.existsSync(file),'Retain final source '+name);fs.writeFileSync(file,content,{flag:'wx'});return file;}
function change(text,from,to){assert.equal(text.split(from).length,2,from.slice(0,100));return text.replace(from,()=>to);}
let patches=fs.readFileSync(path.join(__dirname,'patches.cjs'),'utf8');
patches=change(patches," relative='.cache/native-kernel/nwn-particle-kernel.dll';",`
 // Rebuild policy follows the reviewed selected compile mode. Dependency
 // adoption is not a claim that this ordinary script compiled the binary.
 if(build.flags.includes('/Ob3')){
  const relative='tools/build-particle-kernel.ps1';let code=read(relative);
  code=once(code,'/nologo /O2 /fp:strict','/nologo /O2 /Ob3 /fp:strict');
  code=once(code,"flags='/O2 /fp:strict","flags='/O2 /Ob3 /fp:strict");put(relative,code);
 }
 relative='.cache/native-kernel/nwn-particle-kernel.dll';`);
patches=change(patches,"for(const pin of build.sourcePins)if(pin.relative.startsWith('native/'))sources[pin.relative]=pin.sha256;put(relative,", "for(const pin of build.sourcePins)if(pin.relative.startsWith('native/'))sources[pin.relative]=pin.sha256;if(files.has('tools/build-particle-kernel.ps1'))sources['tools/build-particle-kernel.ps1']=sha(files.get('tools/build-particle-kernel.ps1'));put(relative,");
fresh('patches-final.cjs',patches);
let factory=fs.readFileSync(path.join(__dirname,'prepare.cjs'),'utf8');factory=change(factory,"??'normal-integration-d-a'","??'normal-integration-d-c-a'");factory=change(factory,"path.join(__dirname,'policy.cjs')","path.join(__dirname,'policy-d-c.json')");factory=change(factory,"require('./patches.cjs')","require('./patches-final.cjs')");
factory=change(factory,"assert.equal(before,policy.expectedMainSourceSha256,'Current installed C source differs');",`assert.equal(before,policy.expectedMainSourceSha256,'Current installed C source differs');
 const sourceSnapshots=[];fs.mkdirSync(path.join(directory,'execution-source'),{recursive:true});
 for(const file of [__filename,path.join(__dirname,'patches-final.cjs'),policyFile,path.join(__dirname,'check-final.cjs')]){
  const value=fs.readFileSync(file),snapshot=path.join(directory,'execution-source',path.basename(file));fs.writeFileSync(snapshot,value,{flag:'wx'});sourceSnapshots.push({origin:file,file:snapshot,sha256:sha(value)});
 }`);
factory=change(factory,"const oldArtifact=JSON.parse(bytes('.tools/native-core/accepted-core-v7.json')),acceptedReceipts=[...oldArtifact.acceptedReceipts];",`const oldArtifact=JSON.parse(bytes('.tools/native-core/accepted-core-v7.json')),acceptedReceipts=[...oldArtifact.acceptedReceipts];
 if(policy.engine.functionalReceipt){const evidence=pin(policy.engine.functionalReceipt);assert.equal(evidence.sha256,policy.engine.functionalReceiptSha256);assert.equal(JSON.parse(fs.readFileSync(evidence.file)).success,true);acceptedReceipts.push(evidence);}`);
factory=change(factory,"data.set(relative,value);persistent.push({relative,sha256:row.sha256});", "data.set(relative,value);proposal.files.set(relative,value);proposal.original.set(relative,fs.existsSync(path.join(project,relative))?bytes(relative):null);persistent.push({relative,sha256:row.sha256});");
factory=change(factory,"data.set(sourceRoot+'/rebuild-recipe.json',Buffer.from(JSON.stringify(recipe,null,2)+'\\n'));", "const relative=sourceRoot+'/rebuild-recipe.json',value=Buffer.from(JSON.stringify(recipe,null,2)+'\\n');data.set(relative,value);proposal.files.set(relative,value);proposal.original.set(relative,fs.existsSync(path.join(project,relative))?bytes(relative):null);");
factory=change(factory,"const result={version:3,created:","const result={version:4,sourceSnapshots,created:");
factory=change(factory,"fs.writeFileSync(path.join(directory,'manifest.json'),JSON.stringify(result,null,2)+'\\n',{flag:'wx'});", "for(const row of sourceSnapshots){assert.equal(sha(fs.readFileSync(row.origin)),row.sha256,'Factory input changed during execution');assert.equal(sha(fs.readFileSync(row.file)),row.sha256);}\n fs.writeFileSync(path.join(directory,'manifest.json'),JSON.stringify(result,null,2)+'\\n',{flag:'wx'});");
fresh('prepare-final.cjs',factory);
const base=require('./policy.cjs'),policy={...base,engine:{...base.unselectedEngineEC},flags:[...base.flags,'--light-dictionary-read=single','--light-input-lifetime=guarded'],deferredChoices:{index:'Not selected: isolated FPS inconclusive',nativeOb3:'Not selected: final matched data pending'},selectionBasis:{engine:'Selected for proven lifetime correctness; isolated guard+single speed difference is inconclusive. Final normal package FPS must hold.',kernel:'Accepted combined-b; Ob3 not selected.'}};delete policy.unselectedEngineEC;
fresh('policy-d-c.json',JSON.stringify(policy,null,2)+'\n');console.log(JSON.stringify({sourceOnly:true,files:['prepare-final.cjs','patches-final.cjs','policy-d-c.json'],engine:policy.engine.sha256,native:policy.nativeKernel.sha256,flags:policy.flags.length}));
