// Build-time descriptor generation only; never used on the game frame path.
import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';
import {buildGraph,collectGlobalClasses,digest,lex,IDENTITY_CONTROL} from './processor-graph.mjs';
const own=path.dirname(fileURLToPath(import.meta.url));
function scriptInventory(root){
 const found=[],queue=[''];while(queue.length){const relative=queue.shift();for(const entry of fs.readdirSync(path.join(root,relative),{withFileTypes:true})){if(entry.isSymbolicLink())throw Error('Source graph inventory rejects symbolic links');const name=relative?relative+'/'+entry.name:entry.name;if(entry.isDirectory()){if(!['.godot','.git'].includes(entry.name))queue.push(name);}else if(entry.isFile()&&name.endsWith('.gd'))found.push(name);}}
 return found.sort();
}
export function buildDescriptor(root){
 const reads=new Map(),read=relative=>{if(!reads.has(relative)){const file=path.join(root,relative);reads.set(relative,fs.existsSync(file)?fs.readFileSync(file):null);}return reads.get(relative);};
 const helperBytes=fs.readFileSync(path.join(own,'scoped_processor_identity.gd')),controlHash=digest(helperBytes);
 if(!read(IDENTITY_CONTROL)||digest(read(IDENTITY_CONTROL))!==controlHash)throw Error('Audited identity control owner differs from current generator');
 const inventory=scriptInventory(root),globalClasses=collectGlobalClasses(inventory.map(relative=>[relative,read(relative)])),graphs={};
 for(const kind of ['static-model','actor-model','gui-icon-v1','finished-icon-v1','rejection:static-model','rejection:actor-model','rejection:gui-icon-v1']){
  const found=buildGraph(kind,read,{controlHash,globalClasses});if(!found.ready)throw Error('Graph failed closed: '+JSON.stringify({kind,issues:found.issues}));
  const prefixes=new Set(),environment=new Set();
  for(const row of found.files){if(row.path===IDENTITY_CONTROL)continue;const source=read(row.path).toString(),masked=lex(source);for(const token of masked.strings)if(/^--[a-z0-9-]+(?:=|$)/.test(token.value))prefixes.add(token.value.includes('=')?token.value.slice(0,token.value.indexOf('=')+1):token.value);
   for(const match of masked.code.matchAll(/\bOS\s*\.\s*get_environment\s*\(/g)){const open=masked.code.indexOf('(',match.index),token=masked.strings.find(v=>v.start>open&&masked.code.slice(open+1,v.start).trim()==='');if(!token||!/^\s*\)/.test(masked.code.slice(token.end)))throw Error('Dynamic environment dependency: '+row.path);environment.add(token.value);}
  }
  graphs[kind]={kind,ready:true,files:found.files.map(v=>({path:v.path,sha256:v.sha256})),libraries:found.nativeLibraries,argument_prefixes:[...prefixes].sort(),environment:[...environment].sort(),native_classes:found.nativeClasses};
 }
 const sources=['processor-graph.mjs','processor-descriptor.mjs'].map(name=>[name,digest(fs.readFileSync(path.join(own,name)))]);
 return {descriptor:{format:'native-processor-graph-v1',generator:digest(Buffer.from(JSON.stringify(sources))),graphs},inventoryCount:inventory.length,globalClasses:[...globalClasses].sort(),generatorSources:sources};
}
