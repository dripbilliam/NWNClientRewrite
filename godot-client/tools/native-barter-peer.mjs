// Owned loopback test participant only. Real original-server packets; no scene,
// renderer, local rules execution, fabricated keys or predicted trade outcomes.
import fs from 'node:fs/promises';import path from 'node:path';import crypto from 'node:crypto';
import {createInstalledNetworkSession} from '../../electron/installed_network_session.mjs';
import {actionTestCharacter} from './native-actions-fixture.mjs';
export async function startNativeBarterPeer({install,userDirectory,cdKey,publish,mainSession,port=5125,signal}){
 if(port!==5125)throw Error('Barter fixture is restricted to owned loopback5125');
 let session,created,last='',disposed=false,ready=false,preparedItemId=null,stage='resources';
 const diagnostics=[];
 const cancel=()=>{disposed=true;void session?.disconnect().catch(()=>{});};signal?.addEventListener('abort',cancel,{once:true});
 const wait=async predicate=>{const deadline=Date.now()+45000;while(!predicate()){if(disposed||session?.closed||Date.now()>=deadline)throw Error('Owned barter peer could not reach its requested local state');await new Promise(resolve=>setTimeout(resolve,25));}};
 const disclosedActor=(world,player)=>[player?.objectId,player?.character?.id].find(id=>world.registry.get(id)?.objectType===5)??0x7f000000;
 const mainViewOfPeer=()=>disclosedActor(mainSession.world,[...mainSession.world.players.values()].find(player=>player.name==='NativeBarterPartner'));
 const peerViewOfMain=()=>{
  const main=[...mainSession.world.players.values()].find(player=>player.objectId===mainSession.world.localObjectId||player.character?.id===mainSession.world.localObjectId);
  return disclosedActor(session.world,session.world.players.get(main?.playerId));
 };
 const snapshot=()=>{
  const actor=session?.world.registry.get(session.world.localObjectId),state=session?.world.barter;
  return{party:session?.world.party??[],partyState:actor?.replicated?.party??{},partyInviteNotice:session?.world.partyInviteNotice??null,mainTargetId:peerViewOfMain(),ready,phase:session?.phase??'starting',actorId:session?.world.localObjectId??0x7f000000,mainViewActorId:mainViewOfPeer(),areaId:session?.world.areaId??0x7f000000,preparedItemId,gold:actor?.playerState?.combat?.field898??null,backpack:(session?.world.inventories.get('R')?.entries??[]).map(v=>v.id).sort((a,b)=>a-b),offered:(session?.world.inventories.get('B')?.entries??[]).map(v=>v.id).sort((a,b)=>a-b),trade:state?structuredClone(state):null};
 };
 const update=()=>{if(disposed)return;const value=snapshot(),key=JSON.stringify(value);if(key!==last){last=key;publish(value);}};
 try{
  created=await createInstalledNetworkSession({signal,install,userDirectory,cacheDirectory:path.join(userDirectory,'barter-peer-content'),modsDirectory:path.join(userDirectory,'workshop'),disabledMods:[],host:'127.0.0.1',port,name:'NativeBarterPartner',credentials:{cdKey},onDiagnostic:d=>{if(diagnostics.length<32)diagnostics.push({code:d.code,connectionError:Number.isInteger(d.connectionError)?d.connectionError:null});}});cdKey='';session=created.session;session.on('state',update);
  stage='connect';await session.connect({host:'127.0.0.1',port,metadata:created.metadata,timeout:30000});stage='character-selection';await wait(()=>session.phase==='character-selection'&&session.resourceResult?.ready);
  const original=await fs.readFile(path.join(install,'data/lcv/fighter.bic')),hash=crypto.createHash('sha256').update(original).digest('hex'),character=await actionTestCharacter(original);
  stage='character-upload';await session.selectCharacter(character.bytes);character.bytes.fill(0);await wait(()=>session.phase==='area-loading');stage='area-ready';await session.areaReady(session.areaGeneration);await wait(()=>session.phase==='playing'&&session.world.registry.get(session.world.localObjectId)?.objectType===5);
  stage='inventory';const scope={areaId:session.world.areaId,areaGeneration:session.areaGeneration};await session.inventoryWindow({...scope,open:true});await session.inventoryPanel({...scope,panel:0});
  await wait(()=>session.world.inventories.get('I')?.entries.some(row=>row.slot===2)&&session.world.inventories.has('R'));
  stage='disclosed-players';await wait(()=>mainViewOfPeer()!==0x7f000000&&peerViewOfMain()!==0x7f000000);ready=true;
  const api={snapshot,metadata:{originalCharacterSha256:hash,protocolOnly:true,endpoint:'127.0.0.1:5125'},async perform(operation,value){
   if(disposed||session.phase!=='playing')throw Error('Owned barter peer is unavailable');
   const actorId=session.world.localObjectId,scope={actorId,areaId:session.world.areaId,areaGeneration:session.areaGeneration},state=session.world.barter;
   if(operation==='attitude'){
    const player=[...session.world.players.values()].find(row=>row.objectId===peerViewOfMain());if(!player)throw Error('Owned attitude target is unavailable');await session.playerAttitude({...scope,playerId:player.playerId,likes:Boolean(value)});update();return;
   }
   if(operation.startsWith('party-')){
    const action=operation.slice(6),targetId=peerViewOfMain(),player=[...session.world.players.values()].find(row=>row.objectId===targetId),flags=session.world.registry.get(actorId)?.replicated?.party??{};
    await session.partyInput({...scope,operation:action,...(['accept','reject','ignore'].includes(action)?{targetId:flags.field7D8}:['list','leave'].includes(action)?{}:{targetId,playerId:player?.playerId})});update();return;
   }
   if(operation==='start')await session.barterInput({...scope,operation:'start',targetId:peerViewOfMain()});
   else if(operation==='prepare-item'){
    const entry=session.world.inventories.get('I')?.entries.find(row=>row.slot===2);
    if(!entry)throw Error('Owned barter peer has no sample chest item');preparedItemId=entry.id;
    await session.itemAction({...scope,itemId:preparedItemId,operation:'unequip'});await wait(()=>session.world.registry.get(preparedItemId)?.inventoryLocation?.channel==='R');
   }else if(operation==='add'){
    const id=Number.isInteger(value)?value:preparedItemId;
    const item=id!==null?session.world.registry.get(id):(session.world.inventories.get('R')?.entries??[]).map(row=>session.world.registry.get(row.id)).find(item=>item?.inventoryLocation?.ownerId===actorId&&!session.objectRules.quickbarItemInfo?.(item.item?.baseItem)?.container);
    if(!item)throw Error('Owned barter peer has no available carried item');await session.barterInput({...scope,serial:state?.serial,operation:'add',itemId:item.id,x:0,y:0});
   }else if(['lock','accept','close'].includes(operation))await session.barterInput({...scope,serial:state?.serial,operation,value:Boolean(value)});
   else throw Error('Unsupported owned barter peer operation');
   update();
  },async close(){signal?.removeEventListener('abort',cancel);disposed=true;await session.disconnect();}};
  update();return api;
 }catch{const phase=session?.phase??'uncreated',code=session?.disconnectReason?.code;cdKey='';disposed=true;await session?.disconnect().catch(()=>{});throw Object.assign(Error('The second owned test peer could not enter the local server'),{stage,phase,reasonCode:typeof code==='number'?code:null,connectionError:diagnostics.find(v=>v.connectionError!==null)?.connectionError??null,diagnosticCodes:diagnostics.map(v=>v.code)});}
}
