import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {spawnSync} from 'node:child_process';
const project=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'),root=path.dirname(project);
const [label,mode]=process.argv.slice(2);
if(!/^[a-z0-9-]{3,80}$/.test(label??'')||!['before','staged','integrated'].includes(mode))throw Error('Supply a unique evidence label and before/staged/integrated mode');
const directory=path.join(project,'.cache/level-up-context',label);if(fs.existsSync(directory))throw Error('Preserve existing evidence');fs.mkdirSync(directory,{recursive:true});
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),inputs=new Map();
function include(file){
 file=path.resolve(file);if(inputs.has(file))return;if(!file.startsWith(root+path.sep))throw Error('Input escapes workspace');
 const bytes=fs.readFileSync(file);inputs.set(file,{path:path.relative(root,file).replaceAll('\\','/'),sha256:hash(bytes)});
 // This runner has no relative imports; its quoted future patch is data.
 if(file===fileURLToPath(import.meta.url))return;
 if(/\.(?:m?js|cjs)$/.test(file))for(const match of bytes.toString().matchAll(/\bfrom\s*["'](\.[^"']+)["']|\bimport\(\s*["'](\.[^"']+)["']\s*\)/g))include(path.resolve(path.dirname(file),match[1]??match[2]));
}
const session=path.join(root,'electron/network_game_session.mjs'),helper=path.join(root,'src/network_level_up_context.js'),probe=path.join(project,'tools/probe-native-level-up-context.mjs');
include(session);include(helper);include(probe);include(fileURLToPath(import.meta.url));
for(const [file,row]of inputs){const target=path.join(directory,'inputs',row.path);fs.mkdirSync(path.dirname(target),{recursive:true});fs.copyFileSync(file,target);if(hash(fs.readFileSync(target))!==row.sha256)throw Error('Source changed while copied');}
const before=fs.readFileSync(session,'utf8'),needle='pending.resolve({token,snapshot,available:pending.available,protocolFeatures});}',replacement='pending.resolve({token,snapshot,available:pending.available,protocolFeatures,draftContext:nativeLevelUpDraftContext(actor)});}';
if(mode==='integrated'){
 if(before.split(replacement).length!==2||!before.includes("import {nativeLevelUpDraftContext} from '../src/network_level_up_context.js';"))throw Error('Integrated context producer is missing or ambiguous');
}else if(before.split(needle).length!==2)throw Error('Expected producer hunk is no longer unique');
const after=mode==='staged'?"import {nativeLevelUpDraftContext} from '../src/network_level_up_context.js';\n"+before.replace(needle,replacement):before;
const resolve=specifier=>pathToFileURL(path.resolve(path.dirname(session),specifier)).href;
const working=after.replace(/\bfrom(\s*)(["'])(\.[^"']+)\2/g,(_all,space,_quote,specifier)=>'from'+space+JSON.stringify(resolve(specifier))).replace(/\bimport\(\s*(["'])(\.[^"']+)\1\s*\)/g,(_all,_quote,specifier)=>'import('+JSON.stringify(resolve(specifier))+')');
const copiedSession=path.join(directory,'network_game_session.probe.mjs');fs.writeFileSync(copiedSession,working);
fs.writeFileSync(path.join(directory,'network_game_session.before.mjs'),before);fs.writeFileSync(path.join(directory,'network_game_session.after.mjs'),after);
const report=path.join(directory,'result.json'),child=spawnSync(process.execPath,[probe,copiedSession,report,mode==='integrated'?'staged':mode],{windowsHide:true,timeout:35000,maxBuffer:1024*1024,encoding:'utf8'});
fs.writeFileSync(path.join(directory,'stdout.log'),child.stdout??'');fs.writeFileSync(path.join(directory,'stderr.log'),child.stderr??'');
const result=fs.existsSync(report)?JSON.parse(fs.readFileSync(report)):null,changed=[...inputs].filter(([file,row])=>hash(fs.readFileSync(file))!==row.sha256).map(([,row])=>row.path);
const changedCopies=[...inputs].filter(([,row])=>hash(fs.readFileSync(path.join(directory,'inputs',row.path)))!==row.sha256).map(([,row])=>row.path);
const proof={success:child.status===0&&!child.error&&result?.success===true&&!changed.length&&!changedCopies.length,mode,directory,checks:result?.checks??0,exitCode:child.status,error:child.error?.message??null,inputs:[...inputs.values()],changedInputs:changed,changedCopiedInputs:changedCopies,candidate:{path:'electron/network_game_session.mjs',beforeSha256:hash(before),afterSha256:hash(after),needle,replacement,import:"import {nativeLevelUpDraftContext} from '../src/network_level_up_context.js';"},productionApplied:mode==='integrated',serverConnections:0,nativeBuilds:0,scope:'Copied Session begin metadata producer, original local protocol decoding and controlled peer. Raw received context only; no canonical snapshot change, server login or native level-up UI acceptance.'};
fs.writeFileSync(path.join(directory,'proof.json'),JSON.stringify(proof,null,2)+'\n');console.log(JSON.stringify({...proof,inputs:proof.inputs.length}));process.exitCode=proof.success?0:1;
