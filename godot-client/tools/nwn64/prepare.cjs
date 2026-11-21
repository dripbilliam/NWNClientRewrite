'use strict';
// Freeze control/candidate input closures and a pure-data parity test. No build.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const project=path.resolve(__dirname,'../..'),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const baseline=JSON.parse(fs.readFileSync(path.join(project,'.cache/nwn64/baseline-source-pins.json')));
const pin=file=>{const b=fs.readFileSync(file);return {file,bytes:b.length,sha256:sha(b)};};
const changed=['native/particle_compact.hpp','native/particle_compact_bridge.hpp'];
const stages=[];
for(const [label,control]of [['nwn64-hit-control-a',true],['nwn64-hit-coalesce-a',false]]){
 const out=path.join(project,'.cache/native-render-gap/particles',label),view=path.join(out,'kernel-project');assert(!fs.existsSync(out));fs.mkdirSync(view,{recursive:true});
 const pins=baseline.pins.map(row=>{
  const source=path.join(control?baseline.project:project,row.relative),bytes=fs.readFileSync(source);
  if(control||!changed.includes(row.relative))assert.equal(sha(bytes),row.sha256,'Unrelated native source changed');
  const target=path.join(view,row.relative);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes,{flag:'wx'});
  return {relative:row.relative,bytes:bytes.length,sha256:sha(bytes)};
 });
 const file=path.join(out,'kernel-source-pins.json');fs.writeFileSync(file,JSON.stringify({version:1,issue:'NWN-64',project:view,pins,scope:control?'Exact frozen pre-edit native source control':'Only compact pure private hit-clear coalescing; full other source closure unchanged'},null,2)+'\n',{flag:'wx'});stages.push({label,project:view,sourcePins:pin(file)});
}
const candidate=stages[1].project,read=r=>fs.readFileSync(path.join(candidate,r),'utf8');
function func(source,start){const at=source.indexOf(start);assert(at>=0);const begin=source.indexOf('{',at);let depth=1,end=begin+1;while(depth&&end<source.length){if(source[end]==='{')depth++;if(source[end]==='}')depth--;end++;}assert.equal(depth,0);return source.slice(at,end);}
const cpp=read('native/particle_kernel.cpp'),simulation=read('native/particle_simulation.hpp'),resident=read('native/particle_resident.hpp'),bridge=read('native/particle_compact_bridge.hpp');
const includes=['algorithm','array','cmath','cstdint','cstring','memory','stdexcept','string','unordered_map','vector','functional','iostream','type_traits'].map(n=>'#include <'+n+'>').join('\n');
const include=file=>'#include "'+file.replaceAll('\\','/')+'"\n';
let support=includes+'\n#include "gdextension_interface.h"\nusing V3=std::array<float,3>;using Q4=std::array<float,4>;\n';
for(const name of ['Q4 multiply(','V3 axis_x(','V3 axis_y(','V3 axis_z(','V3 cross(','int32_t cvtt(','int exponent(','double polynomial(','float trig('])support+=func(cpp,name)+'\n';
support+='struct EngineVar { GDExtensionVariantType type()const{return GDEXTENSION_VARIANT_TYPE_NIL;} };\n';
support+=include(path.join(candidate,'native/particle_field_keys.hpp'))+'namespace resident {\n'+include(path.join(candidate,'native/particle_records.hpp'));
support+=resident.slice(resident.indexOf('struct Container;'),resident.indexOf('#include "hot_parameters.hpp"'))+'\n';
for(const name of ['V3 add(','V3 subtract(','V3 normalize(','V3 rotate(','Q4 rotation_arc('])support+=func(simulation,name)+'\n';
support+='}\n';
let proof=func(bridge,'bool can_coalesce_hit_clears()const override');proof=proof.replace('bool can_coalesce_hit_clears()const override','bool bridge_can_coalesce(const resident::Var& hit)');support+='using namespace resident;\n'+proof+'\n';
support+='namespace original {\n'+include(path.join(stages[0].project,'native/particle_compact.hpp'))+'}\nnamespace candidate {\n'+include(path.join(candidate,'native/particle_compact.hpp'))+'}\n';
const supportFile=path.join(project,'.cache/nwn64/unit-support.hpp');fs.writeFileSync(supportFile,support,{flag:'wx'});
const proposal={version:1,issue:'NWN-64',baselineSourcePins:pin(path.join(project,'.cache/nwn64/baseline-source-pins.json')),stages,changed,
 unitSupport:pin(supportFile),unitSource:pin(path.join(project,'tools/nwn64/hit-clear-parity.cpp')),
 proof:'Only final Bridge opts in, and only for an existing present schema slot containing an exclusively owned inline-three-float Array with no generic items. First clear stays at its exact original first moving-particle point. No-wind/no-bounce/non-chunk loop contains no intervening callback, hit-normal read, throw or RNG/birth boundary. Later identical clears can be omitted. Custom/aliased/missing/generic shapes and tiny pools retain original path; all-stopped pools retain zero clears.',
 expectedScope:'Remove repeated private hit-clear work in existing compact CPU simulation. Exact movement f32 arithmetic, source order and complete effects unchanged. No threading, sorting/upload change or Godot particle integration.',
 scope:'Frozen proposal and pure-data alias/service/exception regression source only; no compiler invocation, binary promotion or performance acceptance.'};
const out=path.join(project,'.cache/nwn64/proposal-a.json');fs.writeFileSync(out,JSON.stringify(proposal,null,2)+'\n',{flag:'wx'});console.log(JSON.stringify({proposal:pin(out),stages:stages.map(s=>({label:s.label,sourcePins:s.sourcePins})),support:pin(supportFile)}));
