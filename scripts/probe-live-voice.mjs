import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {openLocalModule} from './local-module.mjs';
import {ModuleSession} from '../src/module_session.js';
import {VoicePresentation} from '../src/voice_presentation.js';
import {creatureRoot} from '../src/creature_rules.js';
import {parseTalkTable,GameText} from '../src/talk_table.js';
import {decodeImaWav} from '../src/ima_adpcm.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
let presentation=null;
const root=process.argv[2]??'../FullDecomp/NwnRootInstall',packets=[],captions=[],sounds=[],resolver=await openLocalModule(root,`${root}/data/nwm/Prelude.nwm`),
 s=await new ModuleSession(resolver,{runStartupScripts:false,runNativeAI:false,serverPvpSetting:0,onCombatMessage:event=>{packets.push(event);if(presentation)void presentation.receive(event);}})
 .initialize(['m0q1a'],{character:await fs.readFile(`${root}/data/lcv/wizard.bic`)});
await s.enterArea('m0q1a',[24,0,-14]);s.scheduler.events=[];
const start=runtimeDiagnostics.records.length,text=new GameText({base:parseTalkTable(await fs.readFile(`${root}/lang/en/data/dialog.tlk`))});
presentation=new VoicePresentation(resolver,{getObject:id=>s.registry.get(id),getPlayer:()=>s.player,getText:()=>text,
 onCaption:c=>captions.push({...c,text:undefined,textLength:c.text.length}),onSound:async event=>{
  const bytes=await resolver.getResource(event.resRef,4),ima=decodeImaWav(bytes);sounds.push({...event,bytes:bytes.byteLength,ima:ima?{channels:ima.channels,frames:ima.frames,sampleRate:ima.sampleRate}:null});}});
const rows=[];
for(const actor of [s.player,...[...s.registry.objects.values()].filter(o=>o.objectType===5&&o.areaId===s.player.areaId&&o.id!==s.player.id&&creatureRoot(o)?.SoundSetFile!==65535).slice(0,1)]){
 const setId=creatureRoot(actor).SoundSetFile&65535,set=await presentation.soundSet(setId);assert.ok(set);
 const available=Array.from({length:set.count},(_,id)=>({id,entry:set.get(id)})).filter(v=>v.entry?.resRef);assert.ok(available.length);
 const codes=[available[0].id,...available.filter(v=>v.id===22).map(v=>v.id)];
 for(const code of codes){const before=packets.length;await s.commands.PlayVoiceChat([code,actor.id===s.player.id?0x7f000000:actor.id],{self:s.player.id});await presentation.tail;
  assert.ok(packets.length>before);assert.equal(packets.at(-1).actorId,actor.id);rows.push({actorId:actor.id,setId,code,resRef:set.get(code).resRef,strRef:set.get(code).strRef});}
}
const before=packets.length;await s.commands.PlayVoiceChat([7,0x7f000001],{self:s.player.id});assert.equal(packets.length,before);
const diagnostics=runtimeDiagnostics.records.slice(start),report={rows,packets,captions,sounds,diagnostics,
 limits:'Installed voice command, local recipients, active soundset/SSF and TLK plus real WAV/IMA resource reads. Metadata only; browser playback and exact native client mixer/UI remain separate validation.'};
await fs.writeFile('backups/animations/live-voice.json',JSON.stringify(report,null,2));console.log(JSON.stringify({rows,packets:packets.length,captions:captions.length,sounds:sounds.map(s=>({resRef:s.resRef,bytes:s.bytes,ima:s.ima})),errors:diagnostics.filter(d=>d.severity==='error').map(d=>d.message)},null,2));
assert.equal(sounds.length,rows.length);assert.deepEqual(diagnostics.filter(d=>d.severity==='error'),[]);
