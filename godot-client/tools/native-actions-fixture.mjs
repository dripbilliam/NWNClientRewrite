// Authored localhost fixture and in-memory BIC edits only. No UI/rules service.
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {parseErf,decodeResourceText} from '../../src/resource_archive.js';
import {parseGff} from '../../src/gff.js';
import {typedGff,writeGff,gffField as field} from '../../src/gff_writer.js';
import {parseScriptApi,parseNcs} from '../../src/ncs.js';
import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
export const actionsHome=path.resolve('runtime-logs/native-playability-actions-server');
export async function createActionsFixture({nui=false,effects=false,ranged=false,deflection=false,miss=false,parry=false,shield=false,shieldKind='small',specialAttack=false,particleCrowd=false,correction=false,identify=false,journal=false,map=false,players=false,quickbar=false}={}){
	if(quickbar){const base=await createActionsFixture();const result=await(await import('../tests/native_quickbar_associate_server_fixture.mjs')).createQuickbarAssociateFixture(actionsHome,base);await fs.writeFile(path.join(actionsHome,'fixture.json'),JSON.stringify(result,null,2)+'\n');return result;}
	if(players){const base=await createActionsFixture();const result=await(await import('./native-players-fixture.mjs')).createNativePlayersFixture(actionsHome,base);await fs.writeFile(path.join(actionsHome,'fixture.json'),JSON.stringify(result,null,2)+'\n');return result;}
	if(map){const base=await createActionsFixture({identify:true});const result=await(await import('./native-map-fixture.mjs')).createNativeMapFixture(actionsHome,base);await fs.writeFile(path.join(actionsHome,'fixture.json'),JSON.stringify(result,null,2)+'\n');return result;}
	if(journal){const base=await createActionsFixture({identify:true});const result=await(await import('./native-journal-fixture.mjs')).createNativeJournalFixture(actionsHome,base);await fs.writeFile(path.join(actionsHome,'fixture.json'),JSON.stringify(result,null,2)+'\n');return result;}
	if(correction){const base=await createActionsFixture();const result=await(await import('./native-correction-fixture.mjs')).createNativeCorrectionFixture(actionsHome,base);await fs.writeFile(path.join(actionsHome,'fixture.json'),JSON.stringify(result,null,2)+'\n');return result;}
	if(particleCrowd){assert.ok(effects);const base=await createActionsFixture({effects:true});const result=await(await import('./native-particle-crowd-fixture.mjs')).createNativeParticleCrowdFixture(actionsHome,base);await fs.writeFile(path.join(actionsHome,'fixture.json'),JSON.stringify(result,null,2)+'\n');return result;}
	if(specialAttack){const base=await createActionsFixture();const result=await(await import('./native-special-attack-fixture.mjs')).createNativeSpecialAttackFixture(actionsHome,base);await fs.writeFile(path.join(actionsHome,'fixture.json'),JSON.stringify(result,null,2)+'\n');return result;}
	if(parry){const base=await createActionsFixture();const result=await(await import('./native-parry-fixture.mjs')).createNativeParryFixture(actionsHome,base);await fs.writeFile(path.join(actionsHome,'fixture.json'),JSON.stringify(result,null,2)+'\n');return result;}
	if(ranged){const base=await createActionsFixture();const result=await(await import('./native-ranged-fixture.mjs')).createNativeRangedFixture(actionsHome,base,{deflection,miss,shield,shieldKind});await fs.writeFile(path.join(actionsHome,'fixture.json'),JSON.stringify(result,null,2)+'\n');return result;}
	if(effects){
	 const result=await(await import('./native-effects-fixture.mjs')).createNativeEffectsFixture(actionsHome);await fs.writeFile(path.join(actionsHome,'fixture.json'),JSON.stringify(result,null,2)+'\n');return result;
	}
 if(nui)return createNativeNuiFixture();
 const source=path.resolve('runtime-logs/local-multiplayer-server/modules/GodotStores.mod');
 const baseline=await fs.readFile(source),prior=JSON.parse(await fs.readFile('godot-client/reports/store-server-fixture-v1.json'));
 assert.equal(hash(baseline),prior.sha256,'Authored baseline changed');
 const entries=new Map(parseErf(baseline).entries),resolver=await openServerResourceContext({install:path.resolve('../FullDecomp/NwnRootInstall')});
 const api=parseScriptApi(decodeResourceText(await resolver.getResource('nwscript',2009))),code=[],patches=[];
 const int=n=>{const b=Buffer.alloc(4);b.writeInt32BE(n);code.push(4,3,...b);},str=s=>{const b=Buffer.from(s,'ascii');code.push(4,5,b.length>>>8,b.length&255,...b);};
 const action=(name,count)=>{const row=api.find(r=>r.name===name);assert.equal(row.args.length,count);code.push(5,0,row.id>>>8,row.id&255,count);};
 for(const operation of ['add','remove']){
  str('-native-party-'+operation);action('GetPCChatMessage',0);code.push(0x0b,0x23);const at=code.length;code.push(0x1f,0,0,0,0,0);
  int(0);str('native_speaker');action('GetObjectByTag',2);action('GetPCChatSpeaker',0);action(operation==='add'?'AddHenchman':'RemoveHenchman',2);
  str('GODOT_PARTY_'+operation.toUpperCase());action('GetPCChatSpeaker',0);action('SendMessageToPC',2);code.push(0x20,0);patches.push({at,to:code.length});
 }
 let identifyMetadata=null,scrollMetadata=null;
 if(identify){
  // Real original template with a high Lore DC; preserve the PC's real skills.
  const template='x2_c3_wswmbs006',bytes=new Uint8Array(await resolver.getResource(template,2025));assert.equal(parseGff(bytes).root.Cost,557850);identifyMetadata={template,sha256:hash(bytes),originalCost:557850};
  str('-native-identify-setup');action('GetPCChatMessage',0);code.push(0x0b,0x23);const at=code.length;code.push(0x1f,0,0,0,0,0);
  int(0);str('native_identify_sword');int(1);action('GetPCChatSpeaker',0);str(template);action('CreateItemOnObject',4);action('SetIdentified',2);
  str('GODOT_IDENTIFY_ITEM_READY');action('GetPCChatSpeaker',0);action('SendMessageToPC',2);code.push(0x20,0);patches.push({at,to:code.length});
  // Owned test items only; original UTI bytes and the test PC's known spells,
  // class, abilities and skills remain unchanged. These installed spells were
  // selected by the original-compared scroll-learning probe.
  scrollMetadata=[];
  for(const [template,spellId,subtype,stack]of[['nw_it_sparscr101',50,98,2],['nw_it_sparscr102',321,284,1]]){
   const bytes=new Uint8Array(await resolver.getResource(template,2025)),root=parseGff(bytes).root;
   assert.equal(root.BaseItem,75);assert.equal(root.PropertiesList[0].Subtype,subtype);
   scrollMetadata.push({template,spellId,subtype,stack,sha256:hash(bytes)});
  }
  str('-native-scroll-setup');action('GetPCChatMessage',0);code.push(0x0b,0x23);const scrollAt=code.length;code.push(0x1f,0,0,0,0,0);
  for(const row of scrollMetadata){str('native_scroll_'+row.spellId);int(row.stack);action('GetPCChatSpeaker',0);str(row.template);action('CreateItemOnObject',4);code.push(0x1b,0,0xff,0xff,0xff,0xfc);}
  str('GODOT_SCROLL_ITEMS_READY');action('GetPCChatSpeaker',0);action('SendMessageToPC',2);code.push(0x20,0);patches.push({at:scrollAt,to:code.length});
 }
 code.push(...entries.get('godot_chat:2010').subarray(13));const body=Buffer.from(code);for(const p of patches)body.writeInt32BE(p.to-p.at,p.at+2);
 const ncs=Buffer.alloc(13+body.length);ncs.write('NCS V1.0');ncs[8]=0x42;ncs.writeUInt32BE(ncs.length,9);ncs.set(body,13);parseNcs(ncs);entries.set('godot_chat:2010',ncs);
 const ifo=typedGff(parseGff(entries.get('module:2014')).root);ifo.fields.Mod_Name=field(12,'Godot Native Actions');ifo.fields.Mod_Tag=field(10,'GodotActions');entries.set('module:2014',writeGff('IFO ',ifo));
 const git=typedGff(parseGff(entries.get('dense_a:2023')).root),npc=git.fields['Creature List'].value[0];
 for(const key of ['HitPoints','CurrentHitPoints','MaxHitPoints'])npc.fields[key].value=2000;
 npc.fields.Plot.value=0;npc.fields.IsImmortal.value=1;entries.set('dense_a:2023',writeGff('GIT ',git));
 const count=entries.size,keys=160,resources=keys+24*count,start=resources+8*count,out=Buffer.alloc(start+[...entries.values()].reduce((n,v)=>n+v.length,0));
 out.write('MOD V1.0');out.writeUInt32LE(count,16);out.writeUInt32LE(160,20);out.writeUInt32LE(keys,24);out.writeUInt32LE(resources,28);let at=start;
 for(const[index,[key,value]]of[...entries].entries()){const split=key.lastIndexOf(':');out.write(key.slice(0,split),keys+24*index,16,'ascii');out.writeUInt32LE(index,keys+24*index+16);out.writeUInt16LE(Number(key.slice(split+1)),keys+24*index+20);out.writeUInt32LE(at,resources+8*index);out.writeUInt32LE(value.length,resources+8*index+4);out.set(value,at);at+=value.length;}
 assert.equal(parseErf(out).entries.size,count);
 const module=identify?'GodotItemUi3':'GodotActions';
 for(const dir of ['modules','client/nwm']){await fs.mkdir(path.join(actionsHome,dir),{recursive:true});const file=path.join(actionsHome,dir,module+'.'+(dir==='modules'?'mod':'nwm'));try{assert.equal(hash(await fs.readFile(file)),hash(out));}catch(e){if(e.code!=='ENOENT')throw e;await fs.writeFile(file,out,{flag:'wx'});}}
 const result={module,port:5125,sha256:hash(out),baseline:prior.sha256,...(identifyMetadata?{identify:identifyMetadata,scrolls:scrollMetadata}:{}),scope:'Authored isolated loopback module; original UTI/model/icon resources are referenced only; original characters remain read-only'};
 await fs.writeFile(path.join(actionsHome,'fixture.json'),JSON.stringify(result,null,2)+'\n');return result;
}
export async function actionTestCharacter(bytes,{rangedWeapon='bow'}={}){
 const root=typedGff(parseGff(bytes,'BIC ').root);root.fields.Experience.value=136000;
	if(rangedWeapon==='sling'){
	 const resolver=await openServerResourceContext({install:path.resolve('../FullDecomp/NwnRootInstall')}),items=root.fields.Equip_ItemList.value;
	 const header=decodeResourceText(await resolver.getResource('nwscript',2009)),slot=/^int\s+INVENTORY_SLOT_BULLETS\s*=\s*(\d+)\s*;/m.exec(header);assert.ok(slot);
	 const weapon=typedGff(parseGff(await resolver.getResource('nw_wbwsl001',2025)).root,16),ammunition=typedGff(parseGff(await resolver.getResource('nw_wambu001',2025)).root,1<<Number(slot[1]));
	 assert.equal(weapon.fields.BaseItem.value,61);assert.equal(ammunition.fields.BaseItem.value,27);
	 root.fields.Equip_ItemList.value=items.filter(item=>![16,2048,4096,8192].includes(item.type));root.fields.Equip_ItemList.value.push(weapon,ammunition);
	}else assert.equal(rangedWeapon,'bow');
 const output=writeGff('BIC ',root);assert.equal(parseGff(output,'BIC ').root.Experience,136000);
 return{bytes:output,metadata:{originalSha256:hash(bytes),uploadedSha256:hash(output),xp:136000,rangedWeapon,originalUnchanged:true}};
}
if(process.argv[1]?.replaceAll('\\','/').endsWith('/native-actions-fixture.mjs'))console.log(JSON.stringify(await createActionsFixture({quickbar:process.argv.includes('--quickbar'),players:process.argv.includes('--players'),map:process.argv.includes('--map'),journal:process.argv.includes('--journal'),identify:process.argv.includes('--identify'),correction:process.argv.includes('--correction'),particleCrowd:process.argv.includes('--particle-crowd'),nui:process.argv.includes('--nui'),effects:process.argv.includes('--effects'),ranged:process.argv.includes('--ranged'),deflection:process.argv.includes('--deflection'),miss:process.argv.includes('--miss'),parry:process.argv.includes('--parry'),shield:process.argv.includes('--shield'),shieldKind:process.argv.find(x=>x.startsWith('--shield-kind='))?.slice(14)??'small',specialAttack:process.argv.includes('--special-attack')})));

async function createNativeNuiFixture(){
 const meta=JSON.parse(await fs.readFile('godot-client/reports/native-nui-actions-server-fixture-v1.json')),input=await fs.readFile(path.resolve('runtime-logs/local-multiplayer-server/modules',meta.module+'.mod'));assert.equal(hash(input),meta.sha256);
 for(const dir of ['modules','client/nwm']){await fs.mkdir(path.join(actionsHome,dir),{recursive:true});const file=path.join(actionsHome,dir,meta.module+'.'+(dir==='modules'?'mod':'nwm'));try{assert.equal(hash(await fs.readFile(file)),hash(input));}catch(e){if(e.code!=='ENOENT')throw e;await fs.writeFile(file,input,{flag:'wx'});}}
 const jui=await fs.readFile('runtime-logs/local-multiplayer-server/override/godot_nui_jui.jui');assert.equal(JSON.parse(jui).title,'Resource-backed grandchild');for(const dir of ['override','client/override']){await fs.mkdir(path.join(actionsHome,dir),{recursive:true});const file=path.join(actionsHome,dir,'godot_nui_jui.jui');try{assert.ok((await fs.readFile(file)).equals(jui));}catch(e){if(e.code!=='ENOENT')throw e;await fs.writeFile(file,jui,{flag:'wx'});}}
 const result={...meta,port:5125,juiSha256:hash(jui)};await fs.writeFile(path.join(actionsHome,'fixture.json'),JSON.stringify(result,null,2)+'\n');return result;
}
