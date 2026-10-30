// Offline comparison only. Emit counts, names and hashes; original MDL/skin/
// animation payloads stay in their external immutable capture.
import fs from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {SceneCaptureArchive} from '../../electron/scene_capture_archive.mjs';
import {SceneCaptureSupplement} from '../../electron/scene_capture_supplement.mjs';
import {parseModel} from '../../src/model_parser.js';
import {inheritAnimations} from '../../src/mdl_animation.js';
import * as T from 'three';
import {createModelHierarchy} from '../../src/model_hierarchy.js';
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
function asciiSkins(model,bytes){
 if(model.format!=='ASCII MDL')return [];
 // This reference parses named influences directly from source text; the
 // existing JS parser does not decode ASCII skin weights. Rest transforms
 // use Three's independent hierarchy/math, ignoring scale as native skin does.
 const text=Buffer.from(bytes).toString('ascii'),hierarchy=createModelHierarchy(model),rests=new Map();
 function rigid(group){if(rests.has(group))return rests.get(group);const m=new T.Matrix4().compose(group.position,group.quaternion,new T.Vector3(1,1,1));if(group.parent)m.premultiply(rigid(group.parent));rests.set(group,m);return m;}
 const output=[];
 for(const match of text.matchAll(/^\s*node\s+skin\s+(\S+)\s*\r?\n([\s\S]*?)^\s*endnode\s*$/gmi)){
  const name=match[1],node=model.nodes.find(n=>n.name.toLowerCase()===name.toLowerCase());if(!node)throw Error('Original ASCII skin node missing');
  const weightsMatch=/^\s*weights\s+(\d+)\s*\r?\n([\s\S]*)/mi.exec(match[2]);if(!weightsMatch)throw Error('Original ASCII weights missing');
  const count=Number(weightsMatch[1]),lines=weightsMatch[2].split(/\r?\n/).map(l=>l.trim()).filter(l=>l&&!l.startsWith('#')).slice(0,count);
  if(lines.length!==count||count!==node.verts.length)throw Error('Original ASCII weight count mismatch');
  const weights=[],names=[],bones=new Set();
  for(const line of lines){const pairs=line.split(/\s+/);if(pairs.length%2||pairs.length>8)throw Error('Original ASCII influence shape');for(let i=0;i<4;i++){const weight=i*2+1<pairs.length?Number(pairs[i*2+1]):0;if(!Number.isFinite(weight)||weight<0)throw Error('Original ASCII influence weight');const bone=weight>0?pairs[i*2].toLowerCase():'';weights.push(weight);names.push(bone);if(bone)bones.add(bone);}}
  const inverse=[];
  for(const bone of bones){const target=model.nodes.find(n=>n.name.toLowerCase()===bone);if(!target)throw Error('Original ASCII named bone missing');const matrix=rigid(hierarchy.nodeGroups.get(target)).clone().invert().multiply(rigid(hierarchy.nodeGroups.get(node))),p=new T.Vector3(),q=new T.Quaternion(),s=new T.Vector3();matrix.decompose(p,q,s);inverse.push({bone,position:[p.x,-p.z,p.y],quaternion:[q.w,q.x,-q.z,q.y]});}
  output.push({name,vertices:count,weightsSha256:f32(weights),boneNamesSha256:hash(JSON.stringify(names)),faceVerticesSha256:i32(node.faces.flatMap(f=>f.slice(0,3))),inverse});
 }
 return output;
}
const samples=[];
for(const name of selected){const model=await load(name),part=f.cases.flatMap(c=>c.expected.parts).find(p=>p.model===name),options=part?{plt_candidates:part.pltCandidates,palette_colors:part.paletteColors}:{};samples.push({name,options,sha256:hash(Buffer.from(raw.get(name))),format:model.format,nodes:model.nodes.length,supermodel:model.supermodel.toLowerCase(),animationScale:model.animationScale,clips:clips(model),skins:model.nodes.flatMap((node,index)=>node.skinned?[{part:index,vertices:node.verts.length,weightsSha256:f32(node.skinData.weights.flat()),bonesSha256:i32(node.skinData.boneIndices.flat()),slotsSha256:i32(node.skinData.boneConstantSlots),qboneSha256:f32(node.skinData.qboneRefInv.flat()),tboneSha256:f32(node.skinData.tboneRefInv.flat()),indexTableSha256:i32(node.skinData.boneIndexTable),constantsSha256:i32(node.skinData.boneConstantIndices)}]:[])});}
for(const sample of samples){const model=await load(sample.name);sample.asciiSkins=asciiSkins(model,raw.get(sample.name));await inheritAnimations(model,load);sample.inheritedClips=clips(model);}
const sources={};for(const file of ['src/model_parser.js','src/binary_mdl.js','src/mdl_animation.js','src/model_controller_remap.js','src/mdl_format.js','src/model_hierarchy.js'])sources[file]=hash(await fs.readFile(file));
await fs.writeFile('godot-client/reports/'+run+'.json',JSON.stringify({scope:'Read-only original actor animation/skin counts and hashes; no runtime JS or copied assets',input:f.input,inputSha256:f.inputSha256,sources,samples},null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({samples:samples.length,clips:samples.reduce((n,s)=>n+s.inheritedClips.length,0),skinModels:samples.filter(s=>s.skins.length).length,loadedResources:models.size}));
