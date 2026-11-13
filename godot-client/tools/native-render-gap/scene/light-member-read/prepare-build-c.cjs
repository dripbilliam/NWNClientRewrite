'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const original=path.join(__dirname,'build-private.cjs'),output=path.join(__dirname,'build-private-c.cjs');if(fs.existsSync(output))throw Error('Retain existing C builder');let text=fs.readFileSync(original,'utf8');
function once(from,to){assert.equal(text.split(from).length,2,from.slice(0,100));text=text.replace(from,()=>to);}
once("??'light-member-build-b-a'","??'light-member-build-c-a'");once("scene/light-member-read-b/manifest.json'","scene/light-member-read-c/manifest.json'");once("kind:'private-normal-light-module-replacement'","kind:'private-manual-light-module-build'");once("path.join(__dirname,'build-private.cjs')","path.join(__dirname,'build-private-c.cjs')");
const helper=`
const frozenDependencies=new Map();
function freezeDependencies(row,name,sourceFile=null){
 const args=row.arguments[0].slice(1),at=args.indexOf('-o');assert(at>=0);args.splice(at,2);args.splice(args.indexOf('-c'),1);
 const sourceAt=args.findIndex(arg=>path.resolve(source,arg)===path.resolve(row.source));assert(sourceAt>=0);if(sourceFile)args[sourceAt]=relative(sourceFile);
 const dependencyFile=path.join(out,name+'-dependencies.d');args.push('-M','-MF',relative(dependencyFile),'-MT','light.o');invoke(name+'-dependencies',compiler,args);
 let content=fs.readFileSync(dependencyFile,'utf8');assert(content.startsWith('light.o:'));content=content.split(String.fromCharCode(92,13,10)).join(' ').split(String.fromCharCode(92,10)).join(' ');const words=[];let word='';
 for(let i=8;i<content.length;i++){const c=content[i],code=c.charCodeAt(0);if(code===92&&i+1<content.length&&[9,10,13,32,35,58,92].includes(content.charCodeAt(i+1)))word+=content[++i];else if([9,10,13,32].includes(code)){if(word){words.push(word);word='';}}else word+=c;}if(word)words.push(word);
 const files=[...new Set(words.map(file=>path.resolve(source,file)))];assert(files.length>30&&files.length<5000);const result=[];
 for(const file of files){const value=pin(file);result.push(value);if(frozenDependencies.has(file))continue;const rel=file.startsWith(source+path.sep)?path.join('engine',path.relative(source,file)):file.startsWith(out+path.sep)?path.join('private',path.relative(out,file)):path.join('external',String(frozenDependencies.size).padStart(4,'0'),path.basename(file));const frozen=path.join(dir('frozen-headers'),rel);fs.mkdirSync(path.dirname(frozen),{recursive:true});fs.copyFileSync(file,frozen,fs.constants.COPYFILE_EXCL);assert.equal(hash(frozen),value.sha256);frozenDependencies.set(file,{original:file,file:frozen,sha256:value.sha256,bytes:value.bytes});}
 return{dependencyFile,sha256:hash(dependencyFile),inputs:result};
}
`;
once('try{\n assert.equal(plan.baselineSha256',helper+'\ntry{\n assert.equal(plan.baselineSha256');
once(' const controlObjects=[];for(const row of receipt.commands.rows){',' receipt.controlDependencies=receipt.commands.rows.map((row,index)=>freezeDependencies(row,"control"+index));\n const controlObjects=[];for(const row of receipt.commands.rows){');
once(' receipt.candidateObjects=[];for(const row of receipt.commands.rows){',' receipt.candidateDependencies=receipt.commands.rows.map((row,index)=>freezeDependencies(row,"candidate"+index,path.join(shadow,path.basename(row.source))));\n receipt.candidateObjects=[];for(const row of receipt.commands.rows){');
once(' receipt.inputPins=[...pins.values()];receipt.sourceEvidence=',' receipt.frozenHeaders=[...frozenDependencies.values()];\n receipt.inputPins=[...pins.values()];receipt.sourceEvidence=');
fs.writeFileSync(output,text,{flag:'wx'});console.log(JSON.stringify({output,sourceOnly:true,changes:'Fresh C proposal, exact control first, actual compiler dependency closure pinned/frozen for both original and shadow module TUs. Used B driver remains unchanged.'}));
