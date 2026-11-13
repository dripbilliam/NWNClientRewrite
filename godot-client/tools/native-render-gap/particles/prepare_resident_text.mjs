import fs from 'node:fs';import path from 'node:path';import crypto from 'node:crypto';import {fileURLToPath} from 'node:url';
const here=path.dirname(fileURLToPath(import.meta.url)),project=path.resolve(here,'../../..'),label=process.argv[2];
if(!/^[a-z0-9-]+$/.test(label??''))throw Error('Fresh private label required');
const base=path.join(project,'.cache/native-render-gap/particles/hot-parameters-c'),manifest=JSON.parse(fs.readFileSync(path.join(base,'kernel-source-pins.json'))),stage=path.join(project,'.cache/native-render-gap/particles',label),kernel=path.join(stage,'kernel-project');
if(fs.existsSync(stage))throw Error('Retain prior candidate evidence');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),pins=[],once=(text,from,to)=>{if(text.split(from).length!==2)throw Error('Expected one frozen text boundary: '+from.slice(0,100));return text.replace(from,to);};
fs.mkdirSync(kernel,{recursive:true});
for(const pin of manifest.pins){const source=path.join(manifest.project,pin.relative),bytes=fs.readFileSync(source);if(hash(bytes)!==pin.sha256)throw Error('Sealed compiler input drift');const output=path.join(kernel,pin.relative);fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,bytes);pins.push({...pin,source,originalSha256:pin.sha256});}
function write(relative,text){const bytes=Buffer.from(text),output=path.join(kernel,relative);fs.writeFileSync(output,bytes);const pin=pins.find(row=>row.relative===relative);if(pin){pin.sha256=hash(bytes);pin.bytes=bytes.length;}else pins.push({relative,source:path.join(here,path.basename(relative)),sha256:hash(bytes),bytes:bytes.length,originalSha256:null});}
write('native/resident_text.hpp',fs.readFileSync(path.join(here,'resident_text.hpp')));
let relative='native/particle_resident.hpp',text=fs.readFileSync(path.join(kernel,relative),'utf8');
text=once(text,'#include "hot_parameters.hpp"','#include "hot_parameters.hpp"\n#include "resident_text.hpp"');
text=once(text,'bool nonempty_text(Var v);','bool nonempty_text(const Var& v);');write(relative,text);
relative='native/particle_simulation.hpp';text=fs.readFileSync(path.join(kernel,relative),'utf8');
const original='bool nonempty_text(Var v){if(v.type()!=GDEXTENSION_VARIANT_TYPE_STRING)throw std::runtime_error("Native particle resource name must be String");return method(v,"length").integer()!=0;}';
text=once(text,original,`#ifdef NWN_PARTICLE_RESIDENT
namespace resident_text {
bool read_borrowed(const Var& input){++borrowed_reads;if(input.type()!=GDEXTENSION_VARIANT_TYPE_STRING)throw std::runtime_error("Native particle resource name must be String");return !input.string.empty();}
bool read_legacy(const Var& input){++legacy_reads;auto value=input;if(value.type()!=GDEXTENSION_VARIANT_TYPE_STRING)throw std::runtime_error("Native particle resource name must be String");return method(value,"length").integer()!=0;}
}
bool nonempty_text(const Var& input){return resident_text::borrowed?resident_text::read_borrowed(input):resident_text::read_legacy(input);}
#else
${original}
#endif`);write(relative,text);
relative='native/particle_presentation.hpp';text=fs.readFileSync(path.join(kernel,relative),'utf8');
text=once(text,'case 19:out=resident::hot_parameters::component_oracle();break;','case 19:out=resident::hot_parameters::component_oracle();break;case 20:out=resident::resident_text::component_oracle();break;case 21:out=resident::resident_text::inspect();break;');write(relative,text);
relative='native/particle_kernel.cpp';text=fs.readFileSync(path.join(kernel,relative),'utf8');text=once(text,'#include <mutex>','#include <mutex>\n#include <thread>');text=once(text,'resident::hot_parameters::bind();','resident::hot_parameters::bind();resident::resident_text::bind();');write(relative,text);
const group=fs.readFileSync(path.join(base,'systems/native_render/particle_stream_group.gd'));fs.mkdirSync(path.join(stage,'systems/native_render'),{recursive:true});fs.writeFileSync(path.join(stage,'systems/native_render/particle_stream_group.gd'),group);
fs.writeFileSync(path.join(stage,'kernel-source-pins.json'),JSON.stringify({version:1,project:kernel,pins,compilerInvoked:false,scope:'Default-legacy resident private string borrow; exact type/error/current-value semantics, engine Variant route unchanged'},null,2)+'\n');
fs.writeFileSync(path.join(stage,'proposal.json'),JSON.stringify({label,kernel,sourcePins:pins,groupSha256:hash(group),flag:'--particle-resident-text=borrow',default:'legacy',coldOracleDispatch:20,coldInspectDispatch:21,lazyHit:false,sharedSourceWrites:0,sharedBinaryWrites:0,engineStarts:0},null,2)+'\n');
console.log(JSON.stringify({stage,files:pins.length,default:'legacy'}));
