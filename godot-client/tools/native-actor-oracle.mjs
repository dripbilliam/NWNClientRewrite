// Offline comparison only. Emit counts, names and hashes; original MDL/skin/
// animation payloads stay in their external immutable capture.
import fs from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {SceneCaptureArchive} from '../../electron/scene_capture_archive.mjs';
import {SceneCaptureSupplement} from '../../electron/scene_capture_supplement.mjs';
import {parseModel} from '../../src/model_parser.js';
import {inheritAnimations} from '../../src/mdl_animation.js';
const arg=n=>process.argv.find(a=>a.startsWith('--'+n+'='))?.slice(n.length+3);
const run=arg('run')??'native-actor-oracle-v1';if(!/^[a-z0-9-]+$/.test(run))throw Error('Invalid oracle name');
const f=JSON.parse(await fs.readFile('godot-client/reports/native-creature-oracle-v1.json','utf8')),data=JSON.parse(await fs.readFile(f.input,'utf8'));
const parent=await SceneCaptureArchive.open(data.capture),supplement=await SceneCaptureSupplement.open(data.supplements[0],parent),resolver=SceneCaptureSupplement.combine(parent,[supplement]).resolver(data.context);
const hash=b=>createHash('sha256').update(b).digest('hex'),f32=values=>hash(Buffer.from(Float32Array.from(values).buffer)),i32=values=>hash(Buffer.from(Int32Array.from(values).buffer));
const raw=new Map(),models=new Map();
async function load(name){if(!models.has(name)){const bytes=await resolver.getResource(name,2002);raw.set(name,bytes);models.set(name,parseModel(bytes));}return models.get(name);}
const selected=[...new Set(f.cases.flatMap(c=>[c.expected.model,...c.expected.parts.filter(p=>p.partIndex===18).map(p=>p.model)]))].filter(name=>{const r=resolver.resourceRecord(name,2002);return r&&!r.missing;});
if(resolver.resourceRecord('c_golstone',2002)&&!resolver.resourceRecord('c_golstone',2002).missing)selected.push('c_golstone');
function clips(model){return model.animations.map(clip=>({name:clip.name,length:clip.length,transition:clip.transition,root:clip.root,events:clip.events,tracks:clip.tracks.filter(t=>['position','orientation','scale'].includes(t.property)).map(t=>({node:t.node,property:t.property,interpolation:t.interpolation,frames:t.frames.length,sha256:f32(t.frames.flatMap(f=>[f.time,...f.value,...(f.in??[]),...(f.out??[])]))}))}));}
const samples=[];
for(const name of selected){const model=await load(name),part=f.cases.flatMap(c=>c.expected.parts).find(p=>p.model===name),options=part?{plt_candidates:part.pltCandidates,palette_colors:part.paletteColors}:{};samples.push({name,options,sha256:hash(Buffer.from(raw.get(name))),format:model.format,nodes:model.nodes.length,supermodel:model.supermodel.toLowerCase(),animationScale:model.animationScale,clips:clips(model),skins:model.nodes.flatMap((node,index)=>node.skinned?[{part:index,vertices:node.verts.length,weightsSha256:f32(node.skinData.weights.flat()),bonesSha256:i32(node.skinData.boneIndices.flat()),slotsSha256:i32(node.skinData.boneConstantSlots),qboneSha256:f32(node.skinData.qboneRefInv.flat()),tboneSha256:f32(node.skinData.tboneRefInv.flat()),indexTableSha256:i32(node.skinData.boneIndexTable),constantsSha256:i32(node.skinData.boneConstantIndices)}]:[])});}
for(const sample of samples){const model=await load(sample.name);await inheritAnimations(model,load);sample.inheritedClips=clips(model);}
const sources={};for(const file of ['src/model_parser.js','src/binary_mdl.js','src/mdl_animation.js','src/model_controller_remap.js','src/mdl_format.js'])sources[file]=hash(await fs.readFile(file));
await fs.writeFile('godot-client/reports/'+run+'.json',JSON.stringify({scope:'Read-only original actor animation/skin counts and hashes; no runtime JS or copied assets',input:f.input,inputSha256:f.inputSha256,sources,samples},null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({samples:samples.length,clips:samples.reduce((n,s)=>n+s.inheritedClips.length,0),skinModels:samples.filter(s=>s.skins.length).length,loadedResources:models.size}));
