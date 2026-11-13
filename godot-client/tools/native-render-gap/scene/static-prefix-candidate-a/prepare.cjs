'use strict';
// Private integration SOURCE generator. Does not build, launch or activate.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const project=path.resolve(__dirname,'../../../..');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const sourceFile=path.join(project,'systems/native_render/drive_collision_indexed.gd'),bytes=fs.readFileSync(sourceFile),source=bytes.toString('utf8');
assert.equal(hash(bytes),'82bac2a28846e0413a1b55646d3ba71d9d0cc55dc67caccfbfd1de04feeb414f','Current collision source changed; review extraction again');
const label=process.argv[2];assert(/^[a-z0-9-]+$/.test(label??''),'Fresh stage label required');
const directory=path.join(project,'.cache/native-render-gap/scene',label);assert(!fs.existsSync(directory),'Retain prior stages');
const begin=source.indexOf('func static_candidates('),end=source.indexOf('\nstatic func cross(',begin);assert(begin>=0&&end>begin);
const original=source.slice(begin,end),loop='\tfor model_key in static_groups:\n';assert.equal(original.split(loop).length,2);
const [head,afterLoop]=original.split(loop),query='\t\tvar selected: Dictionary=';assert.equal(afterLoop.split(query).length,2);
let [prefix,narrow]=afterLoop.split(query);narrow=query+narrow;
assert(narrow.endsWith('\n\treturn result'));narrow=narrow.slice(0,-'\n\treturn result'.length);
// Shared locals carry precisely the values which the original loop reassigned.
for(const [from,to]of [
 ['var group: Dictionary=','group='],['var bounds: Dictionary=','bounds='],
 ['var pending: bool=','pending='],['var states: Array=','states='],['var expansion:=','expansion=']
]){assert.equal(prefix.split(from).length,2,from);prefix=prefix.replace(from,to);}
// Only add close/counter collection at existing return sites. Runtime lifetime
// behavior still needs the isolated error/destructor fixtures before acceptance.
prefix=prefix.replaceAll('return result','_prefix_finish_cursor(cursor);return result');
narrow=narrow.replaceAll('return result','_prefix_finish_cursor(cursor);return result');
const originalHeader=head.slice(0,head.indexOf('\n')),initialization=head.slice(head.indexOf('\n')+1);
const candidate=`extends "res://systems/native_render/drive_collision_indexed.gd"
# PRIVATE SOURCE-ONLY candidate. No ordinary launcher/source activation.
var _prefix_cursor_calls:=0
var _prefix_scanned:=0
var _prefix_admit:=0
var _prefix_fallback:=0
var _prefix_failures: Array=[]
func _prefix_finish_cursor(cursor: RefCounted)->void:
\tvar counters: Dictionary=cursor.call("dispatch",6,{})
\t_prefix_scanned+=int(counters.get("scanned",0))
\t_prefix_admit+=int(counters.get("admit",0))
\t_prefix_fallback+=int(counters.get("fallback",0))
\tcursor.call("dispatch",5,{})
func prefix_statistics()->Dictionary:
\treturn {"native_cursor_calls":_prefix_cursor_calls,"native_scanned":_prefix_scanned,"native_admit":_prefix_admit,"native_fallback":_prefix_fallback,"failures":_prefix_failures.duplicate()}
${originalHeader}
\tif not ClassDB.class_exists("NwnStaticPrefixCursor"):
\t\t_prefix_failures.append("Private native cursor is unavailable")
\t\treturn super.static_candidates(from,to,radius,exclude)
\tvar cursor: RefCounted=ClassDB.instantiate("NwnStaticPrefixCursor")
\tvar started: Dictionary=cursor.call("dispatch",1,{"groups":static_groups,"from":from,"to":to,"radius":radius})
\tif started.get("status")!="ready" or started.get("supported")!=true:
\t\t_prefix_failures.append("Private native cursor begin rejected")
\t\tcursor.call("dispatch",5,{})
\t\treturn super.static_candidates(from,to,radius,exclude)
${initialization}\tvar model_key: Variant=null
\tvar group: Dictionary={}
\tvar bounds: Dictionary={}
\tvar states: Array=[]
\tvar pending:=false
\tvar expansion:=0.0
\twhile true:
\t\tvar admission: Dictionary=cursor.call("dispatch",2,{"groups":static_groups,"models":models,"model_bounds":model_bounds,"prior_key":model_key,"prior_group":group,"prior_bounds":bounds,"prior_states":states})
\t\t_prefix_cursor_calls+=1
\t\tvar status: String=str(admission.get("status",""))
\t\tif status=="done":break
\t\tif status=="unready":
\t\t\tadmission.clear();result.ready=false;_prefix_finish_cursor(cursor);return result
\t\tif status!="admit" and status!="fallback":
\t\t\t_prefix_failures.append("Private native cursor returned invalid status")
\t\t\tpush_error("Private native cursor status rejected")
\t\t\tadmission.clear();result.ready=false;_prefix_finish_cursor(cursor);return result
\t\tmodel_key=admission.key
\t\tif status=="fallback":
\t\t\t# Same original iterator key; never restart completed group queries.
\t\t\tadmission.clear()
${prefix.split('\n').filter((line,index,all)=>index<all.length-1||line!=='').map(line=>'\t'+line).join('\n')}
\t\telse:
\t\t\tgroup=admission.group;bounds=admission.bounds;states=admission.states
\t\t\tpending=admission.pending;expansion=admission.expansion
\t\t\t# Drop transport aliases before the original query/callback boundary.
\t\t\tadmission.clear()
${narrow}
\t_prefix_finish_cursor(cursor)
\treturn result
`;
const factory=`extends RefCounted
const Candidate=preload("res://tools/native-render-gap/scene/static-prefix-candidate-a/candidate_owner.gd")
func create_owner()->Node:return Candidate.new()
func oracle_statistics(owner)->Dictionary:return owner.prefix_statistics()
`;
fs.mkdirSync(directory,{recursive:true});
const outputDirectory=path.join(directory,'source/tools/native-render-gap/scene/static-prefix-candidate-a');fs.mkdirSync(outputDirectory,{recursive:true});
const files=[];for(const [name,text]of [['candidate_owner.gd',candidate],['candidate_factory.gd',factory]]){const file=path.join(outputDirectory,name);fs.writeFileSync(file,text,{flag:'wx'});files.push({file,sha256:hash(Buffer.from(text))});}
const manifest={version:1,status:'SOURCE_ONLY_NOT_GODOT_PARSED_OR_EXECUTED',created:new Date().toISOString(),original:{file:sourceFile,sha256:hash(bytes)},generator:{file:__filename,sha256:hash(fs.readFileSync(__filename))},files,core:'Frozen numeric C; native cursor adapter and actual engine module proof are separate prerequisites',scope:'Private candidate source. Original per-key fallback prefix and downstream narrow body mechanically retained, full owner/fallback/error/lifetime/runtime/performance acceptance outstanding. No installed source modified, native library built or process launched.'};
fs.writeFileSync(path.join(directory,'manifest.json'),JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({directory,files,status:manifest.status}));
