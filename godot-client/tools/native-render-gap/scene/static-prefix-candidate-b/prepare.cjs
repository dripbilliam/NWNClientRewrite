'use strict';
// SOURCE ONLY: actual FOR/compiler cleanup alternative to unaccepted candidate A.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const project=path.resolve(__dirname,'../../../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const file=path.join(project,'systems/native_render/drive_collision_indexed.gd'),bytes=fs.readFileSync(file),source=bytes.toString('utf8');
assert.equal(sha(bytes),'82bac2a28846e0413a1b55646d3ba71d9d0cc55dc67caccfbfd1de04feeb414f');
const label=process.argv[2];assert(/^[a-z0-9-]+$/.test(label??''),'Fresh source label required');
const directory=path.join(project,'.cache/native-render-gap/scene',label);assert(!fs.existsSync(directory),'Retain every prior source stage');
const begin=source.indexOf('func static_candidates('),end=source.indexOf('\nstatic func cross(',begin);assert(begin>=0&&end>begin);
const original=source.slice(begin,end),header=original.slice(0,original.indexOf('\n'));
let body=original.slice(original.indexOf('\n')+1);
const loop='\tfor model_key in static_groups:\n';assert.equal(body.split(loop).length,2);
body=body.replace(loop,'\tfor model_key in native_iterator:\n\t\tvar packet: Dictionary=native_iterator.take_packet()\n\t\tvar native_admit: bool=packet.get("status")=="admit"\n');
assert.equal(body.split('\t\t\tfor state in states:\n').length,2);
body=body.replace('\t\t\tfor state in states:\n','\t\t\tfor state in states:\n\t\t\t\t# Retain the SAME compiler state-loop container on both routes.\n\t\t\t\tif native_admit:break\n');
body=body.replace('\t\tif bounds.is_empty():continue','\t\tif bounds.is_empty():packet.clear();continue');
body=body.replace('\t\tvar expansion:=footprint+(0.0 if pending else radius)','\t\tvar expansion:=float(packet.expansion) if native_admit else footprint+(0.0 if pending else radius)');
const magnitude='\t\tif not pending:\n\t\t\tvar magnitude:=';assert.equal(body.split(magnitude).length,2);body=body.replace(magnitude,'\t\tif not pending and not native_admit:\n\t\t\tvar magnitude:=');
const outside='\t\tif float(bounds.min_x)>max_x+expansion or float(bounds.max_x)<min_x-expansion or float(bounds.min_y)>max_y+expansion or float(bounds.max_y)<min_y-expansion:continue';
assert.equal(body.split(outside).length,2);body=body.replace(outside,'\t\tif not native_admit and (float(bounds.min_x)>max_x+expansion or float(bounds.max_x)<min_x-expansion or float(bounds.min_y)>max_y+expansion or float(bounds.max_y)<min_y-expansion):packet.clear();continue\n\t\tpacket.clear() # No transport aliases survive the original query boundary.');
assert(body.endsWith('\n\treturn result'));body=body.slice(0,-'\n\treturn result'.length)+'\n\t\tnative_iterator.report_priors(model_key,group,bounds,states)\n\tif native_iterator.failed:result.ready=false\n\treturn result';
const owner=`extends "res://systems/native_render/drive_collision_indexed.gd"
# PRIVATE SOURCE ONLY; not parsed, compiled, run, accepted, or activated.
const PrefixIterator=preload("res://tools/native-render-gap/scene/static-prefix-candidate-b/prefix_iterator.gd")
var _prefix_cursor_calls:=0
var _prefix_scanned:=0
var _prefix_admit:=0
var _prefix_fallback:=0
var _prefix_failures: Array=[]
func _prefix_observe(counters: Dictionary,previous: Dictionary)->void:
\t_prefix_cursor_calls+=1
\t_prefix_scanned+=int(counters.get("scanned",0))-int(previous.get("scanned",0))
\t_prefix_admit+=int(counters.get("admit",0))-int(previous.get("admit",0))
\t_prefix_fallback+=int(counters.get("fallback",0))-int(previous.get("fallback",0))
func prefix_statistics()->Dictionary:
\treturn {"native_cursor_calls":_prefix_cursor_calls,"native_scanned":_prefix_scanned,"native_admit":_prefix_admit,"native_fallback":_prefix_fallback,"failures":_prefix_failures.duplicate()}
${header}
\tvar native_iterator=PrefixIterator.new()
\tif not native_iterator.begin(self,from,to,radius):
\t\t_prefix_failures.append("Private cursor unavailable or begin rejected")
\t\treturn super.static_candidates(from,to,radius,exclude)
${body}
`;
const iterator=`extends RefCounted
# Owns the only Cursor reference. Actual FOR @container retains this helper;
# NO explicit close/destructor hook changes original normal/early-return cleanup.
var cursor: RefCounted
var owner_ref: WeakRef
var packet: Dictionary={}
var prior: Dictionary={}
var last_counters: Dictionary={}
var key: Variant=null
var failed:=false
func begin(owner: Node,from: Vector3,to: Vector3,radius: float)->bool:
\tif not ClassDB.class_exists("NwnStaticPrefixCursor"):return false
\towner_ref=weakref(owner)
\tcursor=ClassDB.instantiate("NwnStaticPrefixCursor")
\tvar capability: Dictionary=cursor.call("dispatch",0,{})
\tif capability.get("supported")!=true or int(capability.get("abi",0))!=1 or capability.get("retained_original_iterator")!=true:return false
\tvar started: Dictionary=cursor.call("dispatch",1,{"groups":owner.static_groups,"from":from,"to":to,"radius":radius})
\treturn started.get("status")=="ready" and started.get("supported")==true
func _iter_init(_state: Array)->bool:return _resume()
func _iter_next(_state: Array)->bool:return _resume()
func _iter_get(_state: Variant)->Variant:return key
func take_packet()->Dictionary:
\tvar value: Dictionary=packet
\tpacket={}
\treturn value
func report_priors(model_key: Variant,group: Dictionary,bounds: Dictionary,states: Array)->void:
\tprior={"prior_key":model_key,"prior_group":group,"prior_bounds":bounds,"prior_states":states}
func _resume()->bool:
\tvar owner=owner_ref.get_ref()
\tif not is_instance_valid(owner):
\t\tfailed=true;push_error("Private cursor owner disappeared; equivalence unaccepted");return false
\tvar input: Dictionary={"groups":owner.static_groups,"models":owner.models,"model_bounds":owner.model_bounds}
\tinput.merge(prior)
\tprior.clear() # Input and still-live caller locals retain these references.
\tpacket=cursor.call("dispatch",2,input)
\tinput.clear() # Release before yielding/done, while old FOR-body locals live.
\tvar counters: Dictionary=cursor.call("dispatch",6,{})
\towner._prefix_observe(counters,last_counters)
\tlast_counters=counters
\tvar status: String=str(packet.get("status",""))
\tif status=="done":packet.clear();return false
\tif status=="admit" or status=="fallback" or status=="unready":
\t\t# Unready MUST execute original current-key declarations/state early return.
\t\tkey=packet.key
\t\treturn true
\tfailed=true
\towner._prefix_failures.append("Private cursor unsupported mid-iteration; isolated error equivalence remains outstanding")
\tpacket.clear();push_error("Private cursor continuation rejected");return false
`;
const factory=`extends RefCounted
const Candidate=preload("res://tools/native-render-gap/scene/static-prefix-candidate-b/candidate_owner.gd")
func create_owner()->Node:return Candidate.new()
func oracle_statistics(owner)->Dictionary:return owner.prefix_statistics()
`;
const output=path.join(directory,'source/tools/native-render-gap/scene/static-prefix-candidate-b');fs.mkdirSync(output,{recursive:true});
const files=[];for(const [name,text]of [['candidate_owner.gd',owner],['prefix_iterator.gd',iterator],['candidate_factory.gd',factory]]){const target=path.join(output,name);fs.writeFileSync(target,text,{flag:'wx'});files.push({file:target,sha256:sha(Buffer.from(text))});}
const native=path.join(project,'tools/native-render-gap/scene/static-prefix-adapter-a/cursor_extension_e.cpp');
const manifest={version:1,createdUtc:new Date().toISOString(),status:'SOURCE_ONLY_UNPARSED_UNCOMPILED_UNEXECUTED_UNACCEPTED',original:{file,sha256:sha(bytes)},generator:{file:__filename,sha256:sha(fs.readFileSync(__filename))},nativePrerequisite:{file:native,sha256:sha(fs.readFileSync(native)),required:'E live-groups identity, exact real_t32 engine/ABI and main-thread module contract; no compiled DLL exists yet'},files,preserved:['Original outer FOR body-local reference declarations and original return sites.','One original inner state FOR/container on native-admitted and fallback paths.','Original query/row narrow phase text, ordering, witness/door/source/world-bounds behavior.','Cursor origin is helper-owned until actual FOR @container/function cleanup; no explicit close.','Prior aliases and transport release before next yield/query while caller locals retain original values.'],outstanding:['Actual Godot parser/runtime and isolated error/PREDELETE/readonly/typed/reentrant mutation fixtures.','Unexpected mid-iteration unsupported/error and owner-destruction behavior is explicitly NOT equivalent yet.','Helper/extra local/compiler @container stack-slot ordering needs actual PREDELETE transcript; source proposal is not proof.','No performance result or activation.']};
fs.writeFileSync(path.join(directory,'manifest.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({directory,manifestSha256:sha(fs.readFileSync(path.join(directory,'manifest.json'))),files,status:manifest.status}));
