// Offline oracle only: original assets stay in their external capture. Reports
// contain resource names, colors and pixel hashes, never original asset payloads.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {SceneCaptureArchive} from '../../electron/scene_capture_archive.mjs';
import {SceneCaptureSupplement} from '../../electron/scene_capture_supplement.mjs';
import {parse2da} from '../../src/area.js';
import {networkCreatureModelPlan,nativeCreatureAttachments} from '../../src/network_creature_models.js';
import {decodeBioWarePlt,PLT_PALETTE_NAMES} from '../../src/bioware_plt.js';
import {parseNativeTga} from '../../src/native_tga.js';
const arg=n=>process.argv.find(a=>a.startsWith('--'+n+'='))?.slice(n.length+3);
const run=arg('run')??'native-creature-oracle-v1';if(!/^[a-z0-9-]+$/.test(run))throw Error('Invalid oracle run');
const descriptor=JSON.parse(await fs.readFile('godot-client/reports/native-capture-input-v1.json','utf8'));
const input=JSON.parse(await fs.readFile(descriptor.input,'utf8'));
const parent=await SceneCaptureArchive.open(input.capture),extra=await SceneCaptureSupplement.open(input.supplements[0],parent),resolver=SceneCaptureSupplement.combine(parent,[extra]).resolver(input.context);
const names=['appearance','racialtypes','gender','phenotype','capart','parts_robe','tailmodel','wingmodel','cloakmodel'];
const tables=Object.fromEntries(await Promise.all(names.map(async name=>[name,parse2da(new TextDecoder('windows-1252').decode(await resolver.getResource(name,2017)))])));
const canonical=plan=>({model:plan.model,fallbackModel:plan.fallbackModel??null,paletteColors:plan.paletteColors,parts:plan.parts.map(p=>({model:p.model,fallbackModel:p.fallbackModel??null,pltCandidates:p.pltCandidates??[],node:p.node??null,partIndex:p.partIndex??null,paletteColors:p.paletteColors??plan.paletteColors})),attachments:plan.attachments??[]});
const cases=[];
for(const object of input.objects.filter(o=>o.objectType===5&&o.appearance)){
 const plan=networkCreatureModelPlan(object,tables);if(!plan)continue;
 plan.attachments=nativeCreatureAttachments(object,tables,plan.paletteColors).map(p=>({...p,pltCandidates:[p.model]}));
 cases.push({id:object.id,expected:canonical(plan)});
}
const palettes=new Map(await Promise.all([...new Set(PLT_PALETTE_NAMES)].map(async name=>{const parsed=parseNativeTga(await resolver.getResource(name,3));return[name,{width:parsed.width,height:parsed.height,data:parsed.data}];})));
const seen=new Set(),plts=[];
for(const archive of [parent,extra.archive])for(const [key,record]of Object.entries(archive.manifest.contexts[input.context]?.resources??{})){
 if(!key.endsWith(':6')||seen.has(key)||record.missing)continue;seen.add(key);
 if(plts.length>=12)continue;
 const name=key.slice(0,-2),bytes=await resolver.getResource(name,6);
 for(const rows of [[],[3,7,11,15,19,23,27,31,35,39]]){
  const image=decodeBioWarePlt(bytes,palettes,rows);
  plts.push({name,rows,width:image.width,height:image.height,sha256:createHash('sha256').update(image.data).digest('hex')});
 }
}
if(!cases.length||!plts.length)throw Error('Original creature/PLT oracle coverage is empty');
const output={scope:'Offline original creature rules and PLT pixel hashes; no runtime JS preparation',input:descriptor.input,inputSha256:descriptor.sha256,tables:names,cases,plts};
await fs.writeFile(path.resolve('godot-client/reports',run+'.json'),JSON.stringify(output,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({run,creatures:cases.length,originalPltVariants:plts.length}));
