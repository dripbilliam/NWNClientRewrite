'use strict';
// Prepare private source only; never clone the project, build or launch it.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const project=path.resolve(__dirname,'../../../..'),hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const args=Object.fromEntries(process.argv.slice(2).map(v=>{assert(v.startsWith('--')&&v.includes('='));const i=v.indexOf('=');return[v.slice(2,i),v.slice(i+1)];}));
for(const key of Object.keys(args))assert(['candidate','sha256','label'].includes(key),'Unknown option');
assert(/^[a-z0-9-]+$/.test(args.label??''));assert(/^[a-f0-9]{64}$/.test(args.sha256??''));
const candidateFile=path.resolve(args.candidate??''),candidateBytes=fs.readFileSync(candidateFile);assert.equal(hash(candidateBytes),args.sha256);const candidate=JSON.parse(candidateBytes);
const originalFile=path.join(project,'systems/native_render/drive_collision_indexed.gd'),originalBytes=fs.readFileSync(originalFile),original=originalBytes.toString('utf8');
assert.equal(hash(originalBytes),'82bac2a28846e0413a1b55646d3ba71d9d0cc55dc67caccfbfd1de04feeb414f');assert.equal(candidate.original.sha256,hash(originalBytes));
function inProject(file){const relative=path.relative(project,path.resolve(file));assert(relative&&!relative.startsWith('..')&&!path.isAbsolute(relative),'Input escaped workspace');return relative;}
function sourcePin(row){inProject(row.file);const bytes=fs.readFileSync(row.file);assert.equal(hash(bytes),row.sha256,'Candidate drift: '+row.file);return bytes;}
assert(Array.isArray(candidate.files)&&candidate.files.length>=3);for(const row of candidate.files)sourcePin(row);
assert(candidate.nativePrerequisite?.file&&candidate.nativePrerequisite?.sha256);sourcePin(candidate.nativePrerequisite);
const ownerPin=candidate.files.find(p=>path.basename(p.file)==='candidate_owner.gd');assert(ownerPin);
const owner=sourcePin(ownerPin).toString('utf8');assert(owner.startsWith('extends "res://systems/native_render/drive_collision_indexed.gd"\n'));
assert(owner.includes('for model_key in native_iterator:')&&!owner.includes('while true:'),'Only actual-FOR candidate source may be prepared');
const functionStart=original.indexOf('func static_candidates('),functionEnd=original.indexOf('\nstatic func cross(',functionStart);assert(functionStart>=0&&functionEnd>functionStart);
const originalFunction=original.slice(functionStart,functionEnd),referenceFunction=originalFunction.replace('func static_candidates(','func _prefix_reference_static_candidates(');
const ownerFunctionStart=owner.indexOf('func static_candidates(');assert(ownerFunctionStart>=0);
let support=owner.slice(owner.indexOf('\n')+1,ownerFunctionStart),functionSource=owner.slice(ownerFunctionStart);
assert(!original.includes('func _prefix_observe(')&&!original.includes('func prefix_statistics(')&&!original.includes('var _prefix_enabled'));
functionSource=functionSource.replaceAll('super.static_candidates(from,to,radius,exclude)','_prefix_reference_static_candidates(from,to,radius,exclude)');
const headerEnd=functionSource.indexOf('\n');assert(headerEnd>0);
functionSource=functionSource.slice(0,headerEnd)+`\n\t_prefix_query_calls+=1
\tif not _prefix_enabled:return _prefix_reference_static_candidates(from,to,radius,exclude)`+functionSource.slice(headerEnd);
support+='var _prefix_enabled:=OS.get_cmdline_user_args().has("--static-prefix-cursor=on")\nvar _prefix_query_calls:=0\n';
let overlay=original.slice(0,functionStart)+support+functionSource+'\n'+referenceFunction+original.slice(functionEnd);
const snapshotStart=overlay.indexOf('func snapshot()'),snapshotEnd=overlay.indexOf('\nfunc ',snapshotStart+5);assert(snapshotStart>0&&snapshotEnd>snapshotStart);
const snapshot=overlay.slice(snapshotStart,snapshotEnd),needle='\treturn state';assert.equal(snapshot.split(needle).length,2,'Snapshot source seam changed');
const changed=snapshot.replace(needle,'\tstate.static_prefix_cursor={"enabled":_prefix_enabled,"queries":_prefix_query_calls,"statistics":prefix_statistics(),"scope":"Private actual-FOR cursor overlay; activation and performance acceptance separate"}\n'+needle);
overlay=overlay.slice(0,snapshotStart)+changed+overlay.slice(snapshotEnd);
const directory=path.join(project,'.cache/native-render-gap/scene',args.label);assert(!fs.existsSync(directory),'Retain prior source stage');fs.mkdirSync(directory,{recursive:true});
const outputs=[];function write(relative,bytes){const file=path.resolve(directory,'overlay',relative),inside=path.relative(path.join(directory,'overlay'),file);assert(inside&&!inside.startsWith('..')&&!path.isAbsolute(inside));fs.mkdirSync(path.dirname(file),{recursive:true});fs.writeFileSync(file,bytes,{flag:'wx'});outputs.push({relative,file,sha256:hash(bytes)});}
write('systems/native_render/drive_collision_indexed.gd',Buffer.from(overlay));
for(const row of candidate.files){if(row===ownerPin||path.basename(row.file)==='candidate_factory.gd')continue;const relative=path.relative(path.join(path.dirname(candidateFile),'source'),row.file);assert(!relative.startsWith('..')&&!path.isAbsolute(relative));write(relative,sourcePin(row));}
const manifest={version:1,created:new Date().toISOString(),status:'SOURCE_ONLY_NOT_GODOT_PARSED_EXECUTED_OR_ACCEPTED',candidate:{file:candidateFile,sha256:args.sha256},original:{file:originalFile,sha256:hash(originalBytes)},nativePrerequisite:candidate.nativePrerequisite,generator:{file:__filename,sha256:hash(fs.readFileSync(__filename))},outputs,selection:{off:'--static-prefix-cursor=off',on:'--static-prefix-cursor=on',absent:'Original reference path',scope:'Both arms must load the same isolated DLL/source and preserve all16 normal-D features/settings; only this private explicit selector differs.'},outstanding:['Selected cursor/candidate must first pass canonical and isolated lifetime/error suites.','Full-overlay parser and existing whole collision/preview/route suites are additional gates; subclass fixture alone does not prove this copied owner.','Actual CLI must contain exactly one private on/off selector, verified by an outer owned-runtime observer.','Preserve recorded timeline/authority and loading/warmup scope; separate loaded-query diagnostics from warmed player movement.','No production selection, DLL, engine, original assets, settings or live session was modified.'],scope:'Private graphical/route source preparation only. Original reference function retained byte-for-byte except its name; actual-FOR native candidate copied from sealed source. Same fixed source supports explicit off/on arms. No runtime or FPS gain claim.'};
fs.writeFileSync(path.join(directory,'manifest.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({directory,files:outputs.length,status:manifest.status}));
