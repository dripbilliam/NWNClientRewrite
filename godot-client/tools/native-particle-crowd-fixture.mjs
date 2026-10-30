// Authored localhost stress scene. The unchanged original server applies all
// effects; original model/texture resources remain in the external installation.
import fs from 'node:fs/promises';import path from 'node:path';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';
import {parseErf,decodeResourceText} from '../../src/resource_archive.js';import {parseGff} from '../../src/gff.js';import {typedGff,writeGff,gffField} from '../../src/gff_writer.js';import {parseNcs,parseScriptApi} from '../../src/ncs.js';import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
const hash=b=>createHash('sha256').update(b).digest('hex');
export async function createNativeParticleCrowdFixture(home,prior){
 const input=await fs.readFile(path.join(home,'modules',prior.module+'.mod'));assert.equal(hash(input),prior.sha256);const entries=new Map(parseErf(input).entries);
 const git=typedGff(parseGff(entries.get('dense_a:2023')).root),creatures=git.fields['Creature List'].value,places=git.fields['Placeable List'].value;
 const npc=creatures.find(row=>row.fields.Tag.value==='native_speaker'),brazier=places.find(row=>row.fields.Appearance.value===57);assert.ok(npc&&brazier);
 const tags=[];for(let i=0;i<12;i++){
  const c=structuredClone(npc),tag='particle_crowd_'+i;tags.push(tag);c.fields.Tag.value=tag;c.fields.FirstName=gffField(12,'Particle Test '+i);c.fields.LastName=gffField(12,'');
  c.fields.XPosition.value=43+(i%4)*3;c.fields.YPosition.value=43+Math.floor(i/4)*3;c.fields.Gender.value=i%2;c.fields.Appearance_Head.value=1+i%4;c.fields.Color_Skin.value=i%8;c.fields.Color_Hair.value=i%16;creatures.push(c);
  const p=structuredClone(brazier);p.fields.Tag.value='particle_brazier_'+i;p.fields.X.value=41.5+(i%4)*3;p.fields.Y.value=43+Math.floor(i/4)*3;places.push(p);
 }
 entries.set('dense_a:2023',writeGff('GIT ',git));
 const resolver=await openServerResourceContext({install:path.resolve('../FullDecomp/NwnRootInstall')}),header=decodeResourceText(await resolver.getResource('nwscript',2009)),api=parseScriptApi(header);
 const constant=name=>{const match=new RegExp('^int\\s+'+name+'\\s*=\\s*([0-9]+)\\s*;','m').exec(header);assert.ok(match,name);return Number(match[1]);};
 const code=[],patches=[],int=n=>{const b=Buffer.alloc(4);b.writeInt32BE(n);code.push(4,3,...b);},float=n=>{const b=Buffer.alloc(4);b.writeFloatBE(n);code.push(4,4,...b);},str=s=>{const b=Buffer.from(s,'ascii');code.push(4,5,b.length>>>8,b.length&255,...b);},action=(name,count)=>{const row=api.find(r=>r.name===name);assert.equal(row.args.length,count,name);code.push(5,0,row.id>>>8,row.id&255,count);};
 const visual=constant('VFX_IMP_HEALING_S'),greatVisual=constant('VFX_IMP_HEALING_G');assert.equal(visual,69);assert.equal(greatVisual,66);
 const commands=[{chat:'-native-heal4',count:4,visual},{chat:'-native-heal12',count:12,visual},{chat:'-native-healg4',count:4,visual:greatVisual},{chat:'-native-healg12',count:12,visual:greatVisual}];
 for(const spec of commands){const {count,visual}=spec;
  str(spec.chat);action('GetPCChatMessage',0);code.push(0x0b,0x23);const at=code.length;code.push(0x1f,0,0,0,0,0);
  for(const tag of tags.slice(0,count)){float(0);int(0);str(tag);action('GetObjectByTag',2);for(let axis=0;axis<6;axis++)float(0);float(1);int(0);int(visual);action('EffectVisualEffect',5);int(constant('DURATION_TYPE_INSTANT'));action('ApplyEffectToObject',4);}
  str('GODOT_PARTICLE_CROWD_'+count);action('GetPCChatSpeaker',0);action('SendMessageToPC',2);code.push(0x20,0);patches.push({at,to:code.length});
 }
 code.push(...entries.get('godot_chat:2010').subarray(13));const body=Buffer.from(code);for(const p of patches)body.writeInt32BE(p.to-p.at,p.at+2);const script=Buffer.alloc(13+body.length);script.write('NCS V1.0');script[8]=0x42;script.writeUInt32BE(script.length,9);script.set(body,13);parseNcs(script);entries.set('godot_chat:2010',script);
 const module='GodotPartCrowd1',ifo=typedGff(parseGff(entries.get('module:2014')).root);ifo.fields.Mod_Name=gffField(12,'Native particle crowd');ifo.fields.Mod_Tag=gffField(10,module);entries.set('module:2014',writeGff('IFO ',ifo));
 const count=entries.size,keys=160,resources=keys+24*count,start=resources+8*count,out=Buffer.alloc(start+[...entries.values()].reduce((n,v)=>n+v.length,0));out.write('MOD V1.0');out.writeUInt32LE(count,16);out.writeUInt32LE(160,20);out.writeUInt32LE(keys,24);out.writeUInt32LE(resources,28);let offset=start;
 for(const[index,[key,value]]of[...entries].entries()){const split=key.lastIndexOf(':');out.write(key.slice(0,split),keys+24*index,16,'ascii');out.writeUInt32LE(index,keys+24*index+16);out.writeUInt16LE(Number(key.slice(split+1)),keys+24*index+20);out.writeUInt32LE(offset,resources+8*index);out.writeUInt32LE(value.length,resources+8*index+4);out.set(value,offset);offset+=value.length;}assert.equal(parseErf(out).entries.size,count);
 for(const dir of ['modules','client/nwm']){const file=path.join(home,dir,module+'.'+(dir==='modules'?'mod':'nwm'));try{assert.ok((await fs.readFile(file)).equals(out));}catch(error){if(error.code!=='ENOENT')throw error;await fs.writeFile(file,out,{flag:'wx'});}}
 return{...prior,module,sha256:hash(out),baseline:prior.sha256,crowd:{creatures:12,braziers:12,tags,commands},scope:'Authored diverse human NPCs and braziers; original localhost server applies genuine original small/great Heal effects to distinct targets. No art or simulated effect packets.'};
}
