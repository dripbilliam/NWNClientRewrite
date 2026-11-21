'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const project=path.resolve(__dirname,'../../../..'),out=path.join(project,'.cache/native-render-gap/scene/static-prefix-core-a'),sha=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');assert(!fs.existsSync(out));fs.mkdirSync(path.join(out,'project'),{recursive:true});
const sourceFile=path.join(project,'systems/native_render/drive_collision_indexed.gd'),source=fs.readFileSync(sourceFile,'utf8'),start=source.indexOf('func static_candidates('),end=source.indexOf('\n\t\tvar selected: Dictionary=group.index.query_flat_control',start);assert(start>=0&&end>start);let prefix=source.slice(start,end);assert(prefix.includes('expansion+=magnitude*0.000003814697265625'));const functionHash=crypto.createHash('sha256').update(prefix).digest('hex');
prefix=prefix.replace('func static_candidates(','func extracted_prefix(');prefix+='\n\t\tresult.rows.append({"index":group.input_index,"expansion":double_bits(expansion),"pending":pending})\n\treturn result\n';
const gd=`extends SceneTree
class NoProfile:
 static func count(_name: String,_value: Variant)->void:pass
const DriveProfile=NoProfile
var static_groups: Dictionary={}
var models: Dictionary={}
var model_bounds: Dictionary={}
func double_bits(value: float)->String:
 var bytes:=PackedByteArray();bytes.resize(8);bytes.encode_double(0,value);return bytes.hex_encode()
${prefix}
func _init()->void:
 var input:=FileAccess.open("res://../cases.bin",FileAccess.READ)
 if input==null or input.get_32()!=0x31505343:push_error("Fixture input unavailable");quit(2);return
 var count:=input.get_32();var results: Array=[]
 for case_index in count:
  var from:=Vector3(input.get_float(),input.get_float(),input.get_float());var to:=Vector3(input.get_float(),input.get_float(),input.get_float());var radius:=input.get_double();var groups:=input.get_32()
  static_groups={};models={};model_bounds={}
  for index in groups:
   var empty_bounds:=input.get_8()!=0;var exists:=input.get_8()!=0;var model_empty:=input.get_8()!=0;var model_error:=input.get_8()!=0
   var bounds: Dictionary={};var numbers: Array=[]
   for coordinate in 4:numbers.append(input.get_double())
   if not empty_bounds:bounds={"min_x":numbers[0],"min_y":numbers[1],"max_x":numbers[2],"max_y":numbers[3]}
   var states: Array=[];var state_count:=input.get_32()
   for state_index in state_count:
    var pending:=input.get_8()!=0;var present:=input.get_8()!=0;var value:=input.get_double();var state: Dictionary={}
    if pending:state.pending=true
    if present:state.radius=value
    states.append(state)
   var key: String="g"+str(index);static_groups[key]={"bounds":bounds,"input_index":index};model_bounds[key]=states
   if exists:models[key]={} if model_empty else {"error":true} if model_error else {"canonical":true}
  var result: Dictionary=extracted_prefix(from,to,radius,-1);result.index=case_index;results.append(result)
 var file:=FileAccess.open("res://../godot.json",FileAccess.WRITE);file.store_string(JSON.stringify({"version":1,"cases":results}));file.close();print("EXTRACTED_PREFIX_ORACLE "+str(count));quit(0)
`;
fs.writeFileSync(path.join(out,'project/project.godot'),'config_version=5\n[application]\nconfig/name="Private static prefix oracle"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');fs.writeFileSync(path.join(out,'project/oracle.gd'),gd);
const cases=[],labels=[];const group=(patch={})=>({empty_bounds:false,model_exists:true,model_empty:false,model_error:false,bounds:[-1,-1,1,1],states:[],...patch}),add=(name,q={},groups=[])=>{labels.push(name);cases.push({from:q.from??[0,0,0],to:q.to??[1,1,0],radius:q.radius??0.5,groups});};
add('empty-registry');add('empty-bounds-before-pending',{},[group({empty_bounds:true,states:[{pending:true}]})]);
for(const [name,patch]of [['absent',{model_exists:false}],['empty',{model_empty:true}],['error',{model_error:true}],['empty-and-error',{model_empty:true,model_error:true}]])add('pending-'+name,{radius:NaN},[group({...patch,states:[{pending:true}]})]);
add('ordered-admission-and-failure',{},[group(),group({bounds:[100,100,101,101]}),group({states:[{pending:true}]}),group()]);add('distant-pending-state-still-fails',{},[group({bounds:[1e6,1e6,1e6+1,1e6+1],states:[{pending:true}]})]);add('multiple-radius-states',{},[group({states:[{}, {radius_present:true,radius:3},{radius_present:true,radius:2},{radius_present:true,radius:-1}]})]);
const edges=[0,-0,1,-1,12,-12,1e-20,1e20,Number.MAX_VALUE,Number.MIN_VALUE,Infinity,-Infinity,NaN];
for(const value of edges){add('query-radius-'+String(value),{radius:value},[group()]);add('state-radius-'+String(value),{},[group({states:[{radius_present:true,radius:value}]})]);for(let axis=0;axis<4;axis++){const bounds=[-1,-1,1,1];bounds[axis]=value;add('bound-'+axis+'-'+String(value),{},[group({bounds})]);}for(let axis=0;axis<3;axis++){const from=[0,0,0],to=[1,1,0];from[axis]=value;add('from-'+axis+'-'+String(value),{from},[group()]);to[axis]=value;add('to-'+axis+'-'+String(value),{to},[group()]);}}
for(const first of edges)for(const last of edges)add('radius-state-order-'+String(first)+'-'+String(last),{},[group({states:[{radius_present:true,radius:first},{radius_present:true,radius:last}]})]);
const margin=0.000003814697265625;for(const scale of [1,2,1024,1e6])for(const direction of [-1,1])for(const adjustment of [-1e-12,0,1e-12]){const x=scale*direction,bounds=[x,-1,x,1];const expansion=0.5+Math.max(1,Math.abs(x))*margin;add('margin-edge-'+scale+'-'+direction+'-'+adjustment,{from:[x-expansion+adjustment,0,0],to:[x-expansion+adjustment,0,0],radius:0.5},[group({bounds})]);}
let seed=0xc053e123;const random=()=>{seed^=seed<<13;seed^=seed>>>17;seed^=seed<<5;return(seed>>>0)/4294967296;};
for(let index=0;index<3200;index++){const groups=[];const x=(random()-.5)*100000,y=(random()-.5)*100000;for(let n=0;n<1+Math.floor(random()*9);n++){const a=x+(random()-.5)*100,b=y+(random()-.5)*100;const states=[];for(let at=0;at<Math.floor(random()*6);at++)states.push({pending:random()<.02,radius_present:random()>.1,radius:(random()-.1)*40});groups.push(group({empty_bounds:random()<.04,model_exists:random()>.07,model_empty:random()<.04,model_error:random()<.04,bounds:[a,b,a+random()*30,b+random()*30],states}));}add('random-'+index,{from:[x,y,(random()-.5)*20],to:[x+(random()-.5)*100,y+(random()-.5)*100,0],radius:(random()-.1)*3},groups);}
const chunks=[],u8=n=>{const b=Buffer.alloc(1);b.writeUInt8(n?1:0);chunks.push(b);},u32=n=>{const b=Buffer.alloc(4);b.writeUInt32LE(n);chunks.push(b);},f32=n=>{const b=Buffer.alloc(4);b.writeFloatLE(n);chunks.push(b);},f64=n=>{const b=Buffer.alloc(8);b.writeDoubleLE(n);chunks.push(b);};u32(0x31505343);u32(cases.length);for(const c of cases){c.from.forEach(f32);c.to.forEach(f32);f64(c.radius);u32(c.groups.length);for(const g of c.groups){u8(g.empty_bounds);u8(g.model_exists);u8(g.model_empty);u8(g.model_error);g.bounds.forEach(f64);u32(g.states.length);for(const s of g.states){u8(s.pending);u8(s.radius_present);f64(s.radius??0);}}}fs.writeFileSync(path.join(out,'cases.bin'),Buffer.concat(chunks));fs.writeFileSync(path.join(out,'labels.json'),JSON.stringify(labels,null,2)+'\n');
const manifest={version:1,kind:'private-static-prefix-numeric-differential',createdUtc:new Date().toISOString(),source:{file:sourceFile,sha256:sha(sourceFile),prefixLine:source.slice(0,start).split('\n').length,extractedPrefixSha256:functionHash,extractionEnd:'Immediately before original group.index.query; append observation of admitted index/expansion/pending, then return unchanged ready/rows carrier'},files:['coarse_prefix.hpp','oracle_main.cpp','prepare.cjs'].map(name=>({file:path.join(__dirname,name),sha256:sha(path.join(__dirname,name))})),generated:[path.join(out,'project/oracle.gd'),path.join(out,'project/project.godot'),path.join(out,'cases.bin'),path.join(out,'labels.json')].map(file=>({file,sha256:sha(file)})),caseCount:cases.length,scope:'Data-only native numeric prototype; actual extracted GDScript prefix is the oracle. Typed/object/callback adapter and activation are unimplemented. No scene integration or cache; no FPS/microbenchmark claim.'};fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');console.log(JSON.stringify({out,cases:cases.length,binaryBytes:fs.statSync(path.join(out,'cases.bin')).size,manifestSha256:sha(path.join(out,'manifest.json'))}));
