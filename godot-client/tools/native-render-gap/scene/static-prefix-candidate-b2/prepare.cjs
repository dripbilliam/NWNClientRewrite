'use strict';
// Source-only derivative. Never edits sealed B; never parses/runs Godot/builds.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const project=path.resolve(__dirname,'../../../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const parentFile=path.join(project,'.cache/native-render-gap/scene/static-prefix-candidate-source-b/manifest.json');
assert.equal(sha(fs.readFileSync(parentFile)),'7cc76ba26e68c3d4e5c333f029a2ca7ca86728a763780ee40482c75fd8a40d08');
const parent=JSON.parse(fs.readFileSync(parentFile));
const sources=new Map(parent.files.map(row=>{const b=fs.readFileSync(row.file);assert.equal(sha(b),row.sha256);return[path.basename(row.file),b.toString('utf8')];}));
let owner=sources.get('candidate_owner.gd'),iterator=sources.get('prefix_iterator.gd'),factory=sources.get('candidate_factory.gd');
const once=(source,from,to)=>{assert.equal(source.split(from).length,2,from);return source.replace(from,to);};
owner=once(owner,'\t\tif bounds.is_empty():packet.clear();continue','\t\tif bounds.is_empty():continue');
owner=once(owner,'):packet.clear();continue','):continue');
owner=once(owner,'\t\tpacket.clear() # No transport aliases survive the original query boundary.\n','');
owner=once(owner,'\t\tvar native_admit: bool=packet.get("status")=="admit"\n','\t\tvar native_admit: bool=packet.get("status")=="admit"\n\t\tvar expansion_hint: float=float(packet.get("expansion",0.0)) if native_admit else 0.0\n\t\tpacket.clear() # Drop key/group/bounds/states before ANY original prefix/error/return.\n');
owner=once(owner,'float(packet.expansion) if native_admit else','expansion_hint if native_admit else');
iterator=once(iterator,'func _iter_get(_state: Variant)->Variant:return key','func _iter_get(_state: Variant)->Variant:\n\tvar value: Variant=key\n\tkey=null # Caller/return temporary and Cursor hidden-counter retain the key.\n\treturn value');
iterator=once(iterator,'func _resume()->bool:\n','func _resume()->bool:\n\tkey=null # Fail-safe: never carry an extra prior key across next/done.\n');
const label=process.argv[2];assert(/^[a-z0-9-]+$/.test(label??''),'Fresh source label required');const directory=path.join(project,'.cache/native-render-gap/scene',label);assert(!fs.existsSync(directory));
const output=path.join(directory,'source/tools/native-render-gap/scene/static-prefix-candidate-b2');fs.mkdirSync(output,{recursive:true});
const files=[];for(const [name,source]of [['candidate_owner.gd',owner],['prefix_iterator.gd',iterator],['candidate_factory.gd',factory]]){const text=source.replaceAll('static-prefix-candidate-b/','static-prefix-candidate-b2/'),file=path.join(output,name);fs.writeFileSync(file,text,{flag:'wx'});files.push({file,sha256:sha(Buffer.from(text))});}
const manifest={...parent,createdUtc:new Date().toISOString(),revision:'B2-early-prefix-and-helper-key-release',parent:{file:parentFile,sha256:sha(fs.readFileSync(parentFile))},generator:{file:__filename,sha256:sha(fs.readFileSync(__filename))},files,status:'SOURCE_ONLY_UNPARSED_UNCOMPILED_UNEXECUTED_UNACCEPTED',additionalRationale:['GDScript dictionary iteration retains model_key and hidden @counter until ascending stack teardown; Cursor.iterator models hidden counter and C++ destroys it before origin.','Helper _iter_get must not add a key owner surviving an early query/pending return; key is transferred through return temporary then helper field cleared.','Packet releases all key/group/bounds/states aliases immediately after numeric extraction, before any original prefix/error/return.'],additionalRequiredCases:['V3 Object-key original/normal, replaced-final, pending/early-unready, erase-current-key errors with PREDELETE ordering.','V3 actual readonly scratch/destructive/reentrant/typed/error cases plus V2 canonical fast-route coverage.'],scope:'Source proposal only, not a semantic proof. B remains sealed and unaccepted. No product/shared engine changes or native jobs.'};
const file=path.join(directory,'manifest.json');fs.writeFileSync(file,JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({file,sha256:sha(fs.readFileSync(file)),files,status:manifest.status}));
