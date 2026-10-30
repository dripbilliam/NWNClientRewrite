// Owned loopback participant for pregame roster tests. No rendering or keys on disk.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {createInstalledNetworkSession} from '../../electron/installed_network_session.mjs';
import {actionTestCharacter} from './native-actions-fixture.mjs';
import {serverCharacterPreviewSummary} from '../../src/network_character_preview.js';
export async function startNativeLobbyParticipant({install,userDirectory,cdKey,signal}){
 const endpoint={host:'127.0.0.1',port:5125};let session,closed=false,stage='resources';
 const cancel=()=>{closed=true;void session?.disconnect().catch(()=>{});};signal?.addEventListener('abort',cancel,{once:true});
 const wait=async predicate=>{const until=Date.now()+45000;while(!predicate()){if(closed||session?.closed||signal?.aborted||Date.now()>=until)throw Error('Owned lobby participant did not reach its requested state');await new Promise(resolve=>setTimeout(resolve,25));}};
 try{
  const created=await createInstalledNetworkSession({signal,install,userDirectory,cacheDirectory:path.join(userDirectory,'roster-content'),modsDirectory:path.join(userDirectory,'workshop'),disabledMods:[],...endpoint,name:'NativeRosterParticipant',credentials:{cdKey}});cdKey='';session=created.session;
  stage='connect';await session.connect({...endpoint,metadata:created.metadata,timeout:30000});await wait(()=>session.phase==='character-selection'&&session.resourceResult?.ready);
  const original=await fs.readFile(path.join(install,'data/lcv/fighter.bic')),character=await actionTestCharacter(original),preview=serverCharacterPreviewSummary(character.bytes);
  const metadata={protocolOnly:true,endpoint:'127.0.0.1:5125',originalSha256:createHash('sha256').update(original).digest('hex'),submittedSha256:createHash('sha256').update(character.bytes).digest('hex'),expected:{firstName:preview.firstName,lastName:preview.lastName,classes:preview.classes}};
  stage='upload';try{await session.selectCharacter(character.bytes);}finally{character.bytes.fill(0);}
  await wait(()=>session.phase==='area-loading');stage='area-ready';await session.areaReady(session.areaGeneration);await wait(()=>session.phase==='playing'&&session.world.registry.get(session.world.localObjectId)?.objectType===5);
  return{metadata,snapshot:()=>({ready:!closed&&!session.closed&&session.phase==='playing',closed:closed||session.closed,phase:session.phase,actorId:session.world.localObjectId,expected:metadata.expected}),async close(){signal?.removeEventListener('abort',cancel);closed=true;await session.disconnect();}};
 }catch{
  cdKey='';signal?.removeEventListener('abort',cancel);closed=true;await session?.disconnect().catch(()=>{});throw Error('Owned roster participant failed at '+stage);
 }
}
