// Source-only dependency analysis. This module is not used by game/cache code.
// A future runtime implementation must retain the fail-closed rules and prove
// the same artifact/source/schema/native-library invalidations independently.
import crypto from 'node:crypto';
export const digest=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
export const DRIVER='systems/native_data/asset_service.gd';
export const STORE='systems/native_data/prework_store.gd';
export const FINISHED='systems/native_item_icons.gd';
export const REJECTIONS='systems/native_prework_assets.gd';
export const IDENTITY_CONTROL='systems/native_data/scoped_processor_identity.gd';
export function collectGlobalClasses(entries){
 const result=new Map();
 for(const [relative,bytes] of entries){if(!relative.endsWith('.gd')||bytes==null)continue;for(const match of lex(bytes.toString()).code.matchAll(/^class_name\s+([A-Za-z_]\w*)\b/gm)){if(result.has(match[1])&&result.get(match[1])!==relative)throw Error('Ambiguous global script class: '+match[1]);result.set(match[1],relative);}}
 return result;
}
const MODEL_KINDS=['static-model','actor-model','gui-icon-v1'];
const KERNEL='.cache/native-kernel/nwn-particle-kernel.dll';
// These registrations were checked in native/particle_kernel.cpp and its
// included owner headers. Never guess a library for a new Nwn* class name.
const KERNEL_CLASSES=new Set(['NwnLightHistory','NwnModelPoseStorage','NwnParticleClock','NwnParticlePoseLease','NwnVisualRandom','NwnParticleCounters','NwnParticleFrameGroup','NwnParticleKernel','NwnParticleOwner','NwnParticlePresentation','NwnParticleStreamRender','NwnParticleUpload','NwnParticleUploadBatch','NwnSceneGeometry','NwnSceneIndex','NwnSceneModel','NwnWindManager']);
const BUILTIN_BASES=new Set(['Object','RefCounted','Resource','Node','Node3D','MeshInstance3D','MultiMeshInstance3D','StaticBody3D','OmniLight3D','Light3D','ShaderMaterial','StandardMaterial3D','Material','Control','PanelContainer','CanvasLayer','SubViewport','SceneTree','CompositorEffect']);
export function lex(source){
 const chars=source.split(''),strings=[];let index=0;
 while(index<source.length){
  if(source[index]==='#'){while(index<source.length&&source[index]!=='\n')chars[index++]=' ';continue;}
  if(source[index]!=="'"&&source[index]!=='"'){index++;continue;}
  const start=index,quote=source[index],triple=source.slice(index,index+3)===quote.repeat(3),width=triple?3:1;index+=width;let closed=false;
  while(index<source.length){if(source[index]==='\\'){index+=2;continue;}if(source.slice(index,index+width)===quote.repeat(width)){closed=true;index+=width;break;}index++;}
  const end=Math.min(index,source.length);strings.push({start,end,value:source.slice(start+width,end-(closed?width:0)),closed,triple});for(let at=start;at<end;at++)if(chars[at]!=='\n'&&chars[at]!=='\r')chars[at]=' ';
 }
 return {code:chars.join(''),strings};
}
export function imports(source,owner){
 const masked=lex(source),rows=[],issues=[];
 for(const match of masked.code.matchAll(/\b((?:ResourceLoader\s*\.\s*)?load|preload)\s*\(/g)){
  if(match.index>0&&/[.\w]/.test(masked.code[match.index-1]))continue;
  const open=masked.code.indexOf('(',match.index),token=masked.strings.find(s=>s.start>open&&masked.code.slice(open+1,s.start).trim()==='');
  if(!token||!token.closed||token.triple||!/^\s*\)/.test(masked.code.slice(token.end))||!token.value.startsWith('res://')||token.value.includes('\\')){issues.push({owner,reason:'nonliteral-resource-load',at:match.index});continue;}
  rows.push({path:token.value.slice(6),at:match.index,operation:match[1]});
 }
 for(const match of masked.code.matchAll(/\bextends\b/g)){
  const end=match.index+match[0].length,lineEnd=masked.code.indexOf('\n',end),token=masked.strings.find(s=>s.start>=end&&(lineEnd<0||s.start<lineEnd)&&masked.code.slice(end,s.start).trim()==='');
  if(token?.closed&&!token.triple&&token.value.startsWith('res://'))rows.push({path:token.value.slice(6),at:match.index,operation:'extends'});
  else {const base=/^[ \t]*([A-Za-z_]\w*)/.exec(masked.code.slice(end))?.[1];if(!BUILTIN_BASES.has(base))issues.push({owner,reason:'unresolved-script-base',name:base,at:match.index});}
 }
 return {rows,issues,masked};
}
function nativeUsage(source,owner){
 const masked=lex(source),issues=[],names=new Set();
 for(const match of masked.code.matchAll(/\bClassDB\s*\.\s*(instantiate|class_exists|class_has_method|class_call_static)\s*\(/g)){
  const open=masked.code.indexOf('(',match.index),token=masked.strings.find(s=>s.start>open&&['','&'].includes(masked.code.slice(open+1,s.start).trim()));
  if(!token||!token.closed||token.triple||!/^\s*[,)]/.test(masked.code.slice(token.end)))issues.push({owner,reason:'nonliteral-native-class',at:match.index});
 }
 for(const token of masked.strings)if(/^Nwn[A-Za-z0-9_]+$/.test(token.value))names.add(token.value);
 // Direct registered-class use is a dependency too; do not require a string.
 for(const match of masked.code.matchAll(/\bNwn[A-Za-z0-9_]+\b/g))names.add(match[0]);
 return {names:[...names],issues};
}
function functionBlocks(source){
 const masked=lex(source),starts=[...masked.code.matchAll(/^(?:static\s+)?func\s+([A-Za-z_]\w*)\s*\(/gm)],blocks=new Map();
 for(let index=0;index<starts.length;index++){const start=starts[index].index,end=starts[index+1]?.index??source.length;blocks.set(starts[index][1],{name:starts[index][1],source:source.slice(start,end)});}
 return blocks;
}
function selectDecodeBranches(source,allowed){
 const masked=lex(source),marker=/^\tmatch decoder:\s*$/m.exec(masked.code);if(!marker)throw Error('Known decoder dispatcher is absent');
 const start=masked.code.indexOf('\n',marker.index)+1;let end=source.length;
 for(const match of masked.code.slice(start).matchAll(/^(\t?)([^\s].*)$/gm)){if(!match[1]&&match[2].trim()||match[1]==='\t'){end=start+match.index;break;}}
 const cases=[];let offset=start;
 for(const line of source.slice(start,end).split('\n')){
  if(/^\t\t[^\t\s]/.test(line)){const text=lex(line);const labels=text.strings.filter(v=>!v.triple&&v.closed).map(v=>v.value);if(!labels.length)throw Error('Unrecognized decoder case shape');cases.push({offset,labels});}
  offset+=line.length+1;
 }
 if(!cases.length)throw Error('No decoder cases');let result=source.slice(0,start);const seen=new Set();
 for(let index=0;index<cases.length;index++){const row=cases[index],next=cases[index+1]?.offset??end;if(row.labels.some(v=>allowed.has(v))){result+=source.slice(row.offset,next);for(const value of row.labels)seen.add(value);}}
 for(const decoder of allowed)if(!seen.has(decoder))throw Error('Required decoder branch is absent: '+decoder);
 return result+source.slice(end);
}
export function projectDriver(source,kind,actorDecoder){
 const blocks=functionBlocks(source);if(!blocks.has('_work')||!blocks.has('decode_uncached'))throw Error('Unknown asset driver shape');
 const allowed=new Set(['raster',actorDecoder]);if(kind==='static-model')allowed.add('mdl-original');
 blocks.get('decode_uncached').source=selectDecodeBranches(blocks.get('decode_uncached').source,allowed);
 const visited=new Set(),queue=['_work'];
 while(queue.length){const name=queue.shift();if(visited.has(name))continue;visited.add(name);const code=lex(blocks.get(name).source).code;for(const token of code.matchAll(/\b[A-Za-z_]\w*\b/g))if(blocks.has(token[0])&&!visited.has(token[0]))queue.push(token[0]);}
 const body=[...visited].sort().map(name=>blocks.get(name).source).join('\n'),tokens=new Set(lex(body).code.match(/\b[A-Za-z_]\w*\b/g)??[]),firstFunction=/^(?:static\s+)?func\s+/m.exec(lex(source).code)?.index??source.length,header=source.slice(0,firstFunction);
 const all=imports(header,DRIVER);if(all.issues.length)throw Error('Unsupported driver header imports');
 const selected=[];for(const row of all.rows){const lineStart=header.lastIndexOf('\n',row.at)+1,lineEnd=header.indexOf('\n',row.at),line=header.slice(lineStart,lineEnd<0?header.length:lineEnd),name=/\bconst\s+([A-Za-z_]\w*)\s*(?::[^=]+)?=/.exec(line)?.[1];if(!name)throw Error('Unrecognized driver import owner');if(tokens.has(name))selected.push(row);}
 const inline=imports(body,DRIVER);if(inline.issues.length)throw Error('Unsupported active driver load');
 return {source:body,functions:[...visited].sort(),imports:[...selected,...inline.rows].map(v=>v.path),decoders:[...allowed].sort()};
}
export function buildGraph(kind,read,options={}){
 const rejection=kind.startsWith('rejection:'),base=rejection?kind.slice(10):kind,finished=base==='finished-icon-v1';if(!finished&&!MODEL_KINDS.includes(base))throw Error('Unsupported artifact kind');
 const modelKind=finished?'actor-model':base,nodes=new Map(),edges=[],issues=[],nativeLibraries=new Set(),nativeClasses=new Set(),queue=[{path:DRIVER,mode:'driver'},{path:STORE,mode:'full'}];
 if(finished)queue.push({path:FINISHED,mode:'full'});if(rejection)queue.push({path:REJECTIONS,mode:'full'});
 const actorBytes=read('systems/native_data/actor_model.gd');if(actorBytes==null)throw Error('Actor parser absent');const actorSource=actorBytes.toString(),actorDecoder=/^const SOURCE_DECODER\s*:?=\s*"([^"]+)"/m.exec(actorSource)?.[1];if(!actorDecoder)throw Error('Actor decoder declaration unresolved');
 while(queue.length){const item=queue.shift();if(nodes.has(item.path))continue;if(nodes.size>=256)throw Error('Dependency graph exceeds source bound');if(item.path.includes('..')||item.path.startsWith('/')||item.path.includes('\\'))throw Error('Invalid dependency path');
  const bytes=read(item.path);if(bytes==null){issues.push({owner:item.path,reason:'missing-source'});continue;}const source=bytes.toString(),node={path:item.path,mode:item.mode,sha256:digest(bytes),bytes:bytes.length,functions:[],imports:[]};let active=source;
  if(item.mode==='driver'){const projected=projectDriver(source,modelKind,actorDecoder);active=projected.source;node.functions=projected.functions;node.decoders=projected.decoders;node.imports=projected.imports;node.strictCodeGuard=true;}
  else if(item.path.endsWith('.gd')){const found=imports(source,item.path);issues.push(...found.issues.filter(v=>v.reason!=='unresolved-script-base'||!options.globalClasses?.has(v.name)));node.imports=found.rows.map(v=>v.path);}
  else if(item.path.endsWith('.gdextension'))node.strictCodeGuard=true;
  else issues.push({owner:item.path,reason:'unsupported-resource-kind'});
  if(options.globalClasses){const identifiers=new Set(lex(active).code.match(/\b[A-Za-z_]\w*\b/g)??[]);for(const [name,relative] of options.globalClasses)if(identifiers.has(name)&&relative!==item.path&&!node.imports.includes(relative))node.imports.push(relative);}
  nodes.set(item.path,node);
  for(const child of node.imports){edges.push({from:item.path,to:child});queue.push({path:child,mode:child===DRIVER?'driver':'full'});}
  // This source-pinned control owner only observes the generated dependency
  // metadata; its dynamic class-name query is not model computation. A caller
  // must attest the exact audited helper bytes or this exception fails closed.
  if(item.path===IDENTITY_CONTROL){if(options.controlHash!==node.sha256)issues.push({owner:item.path,reason:'unverified-identity-control'});}
  else {const native=nativeUsage(active,item.path);issues.push(...native.issues);for(const name of native.names){nativeClasses.add(name);if(name==='NwnResourceIndex')nativeLibraries.add('.cache/native-resource-index/nwn-resource-index.dll');else if(KERNEL_CLASSES.has(name))nativeLibraries.add(KERNEL);else issues.push({owner:item.path,reason:'unmapped-native-class',name});}}
 }
 const files=[...nodes.values()].sort((a,b)=>a.path.localeCompare(b.path)),libraries=[...nativeLibraries].sort();
 return {version:1,kind,ready:!issues.length,files,edges:edges.sort((a,b)=>(a.from+'\0'+a.to).localeCompare(b.from+'\0'+b.to)),nativeClasses:[...nativeClasses].sort(),nativeLibraries:libraries,issues,scope:'Source-only graph inventory. Native DLL bytes are deliberately not read by this analysis; this is not a usable cache identity, runtime implementation, performance test or promotion receipt.'};
}
