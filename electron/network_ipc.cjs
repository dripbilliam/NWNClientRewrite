const path=require('node:path');
const crypto=require('node:crypto');
const {pathToFileURL}=require('node:url');
const defaultApplicationUrl=pathToFileURL(path.resolve(__dirname,'../dist/index.html')).href;

// Only attached main frames own sessions. No path-based file reader, arbitrary
// IPC channel forwarding, credential readback or raw player-message API.
function registerNetworkIpc(ipcMain,{defaultInstall,userDirectory,cacheDirectory=null,chooseInstall,createSession,characterVault=null,clientSettings=null,chooseMods=null,modelCache=null,sceneCapture=null,onPortalSession=null,onPortalConnected=null,onPortalFailure=null,applicationUrl=defaultApplicationUrl}){
 if(typeof applicationUrl!=='string')throw Error('Invalid application URL');
 const documentUrl=new URL(applicationUrl);
 if(documentUrl.protocol!=='file:'||documentUrl.hostname||documentUrl.search||documentUrl.hash)throw Error('Application URL must be one exact local document');
 const attached=new Map(),owners=new Map();
 const publish=(sender,id,kind,value)=>{if(attached.has(sender.id)&&!sender.isDestroyed())sender.send('network:event',{sessionId:id,kind,...value});};
 const watchSession=(sender,owner,current)=>{
  const captureContext=sceneCapture?.contextFor(current);
  const active=()=>owners.get(sender.id)===owner&&owner.session===current&&!owner.cancelled;
  current.on('state',state=>{
   // Cancelling an explicit disconnect must suppress further gameplay work,
   // while its terminal state still tells the renderer to retire the area.
   // Keep the exact connection check: an old portal/session cannot close a
   // replacement owner, even if its asynchronous peer shutdown finishes later.
   const terminal=owner.cancelled&&state.closed&&owners.get(sender.id)===owner&&owner.session===current;
   if(active()||terminal){sceneCapture?.event(captureContext,{kind:'state',state:{phase:state.phase,closed:state.closed,areaGeneration:state.areaGeneration,resourcesReady:state.resourcesReady}});publish(sender,owner.id,'state',{state});}
  });
  current.on('message',event=>{if(active()){sceneCapture?.message(captureContext,event);publish(sender,owner.id,'message',event);}});
  current.once('closed',()=>{if(active()&&!current.portalHandoffReady&&owner.portalFailing!==current&&owner.portalConnecting!==current)owners.delete(sender.id);});
  current.once('portal-ready',next=>{
   if(!active()){void next.session.disconnect().catch(()=>{});return;}
   owner.portalSession=next.session;
   const replace=async()=>{
    try{
     // Native frontends retire their old UI/render services before destination
     // state or content can arrive. The original frontend needs no hook.
     if(onPortalSession)await onPortalSession({previous:current,next});
     if(!active()){await next.session.disconnect();return;}
     owner.session=next.session;owner.portalSession=null;owner.portalConnecting=next.session;owner.id=crypto.randomUUID();owner.vaultId=null;watchSession(sender,owner,next.session);
     await next.session.connect({host:next.host,port:next.port,metadata:next.metadata,...(next.expectedServerPublicKey?{expectedServerPublicKey:next.expectedServerPublicKey}:{})});
     if(next.session.closed)throw Error('Destination closed during connection');
     if(onPortalConnected&&owners.get(sender.id)===owner&&!owner.cancelled&&owner.session===next.session)await onPortalConnected({previous:current,next});
    }catch(error){
     owner.portalFailing=next.session;
     await next.session.disconnect().catch(()=>{});
     if(owners.get(sender.id)===owner&&!owner.cancelled&&(owner.session===current||owner.session===next.session)){
      // Optional native presentation cleanup must not prevent disposal or
      // remove a newer owner if it asynchronously triggers another login.
      if(onPortalFailure)try{await onPortalFailure({previous:current,next,error});}catch{}
      if(owners.get(sender.id)===owner){publish(sender,owner.id,'diagnostic',{diagnostic:{code:'network.portal-connect-failed',reason:'The destination server connection failed'}});owners.delete(sender.id);}
     }
    }finally{if(owner.portalConnecting===next.session)owner.portalConnecting=null;if(owner.portalFailing===next.session)owner.portalFailing=null;if(owner.portalSession===next.session)owner.portalSession=null;}
   };void replace();
  });
 };
 const disconnect=async(sender,{saveCharacter=true}={})=>{
  if(typeof saveCharacter!=='boolean')throw new Error('Invalid disconnect option');const owner=owners.get(sender.id);if(!owner)return;if(owner.disconnecting&&saveCharacter)return owner.disconnecting;
  const work=(async()=>{if(saveCharacter&&characterVault&&['playing','area-loading'].includes(owner.session?.phase)&&!owner.session.closed)await owner.session.exportCharacter();owner.cancelled=true;const pending=owner.portalSession;owner.portalSession=null;if(pending&&pending!==owner.session)await pending.disconnect();if(owner.session)await owner.session.disconnect();if(owners.get(sender.id)===owner)owners.delete(sender.id);})();owner.disconnecting=work;
  try{return await work;}finally{if(owner.disconnecting===work)owner.disconnecting=null;}
 };
 async function connect(sender,request){
  if(!attached.has(sender.id)||sender.isDestroyed())throw new Error('Multiplayer window is unavailable');
  if(owners.has(sender.id))throw new Error('Disconnect the current multiplayer session first');
  if(!request||typeof request.host!=='string'||!request.host.trim()||request.host.length>255||!Number.isInteger(request.port)||request.port<1||request.port>65535||typeof request.name!=='string'||!request.name.length||request.name.length>64)throw new Error('Invalid multiplayer connection settings');
  let pin=null;
  if(request.serverPublicKey){if(typeof request.serverPublicKey!=='string'||!/^[A-Za-z0-9+/]{43}=$/.test(request.serverPublicKey))throw new Error('Invalid server public identity');pin=Buffer.from(request.serverPublicKey,'base64');}
  const owner={id:crypto.randomUUID(),cancelled:false,session:null};owners.set(sender.id,owner);
  const credentials=request.credentials??{};delete request.credentials;
  try{
   if(!credentials.cdKey&&clientSettings)credentials.cdKey=await clientSettings.cdKey();
   const settings=clientSettings?await clientSettings.status():null;
   if(owner.cancelled||!attached.has(sender.id)||sender.isDestroyed())throw Error('Multiplayer connection was cancelled');
   if(request.vaultId!==undefined){if(!characterVault||request.character)throw new Error('Invalid saved character selection');owner.vaultId=request.vaultId;owner.character=await characterVault.read(request.vaultId);}
   const result=await createSession({sceneCapture,install:attached.get(sender.id).install,modsDirectory:settings?.modsDirectory??null,disabledMods:settings?.disabledMods??[],userDirectory,cacheDirectory,host:request.host.trim(),port:request.port,name:request.name,credentials,onDiagnostic:d=>publish(sender,owner.id,'diagnostic',{diagnostic:d}),persistCharacter:characterVault?async message=>{const entry=await characterVault.save(message,{id:owner.vaultId??null});owner.vaultId=entry.id;return entry;}:null});
   owner.session=result.session;
   if(owner.cancelled||!attached.has(sender.id)||sender.isDestroyed()){await owner.session.disconnect();throw new Error('Multiplayer connection was cancelled');}
   watchSession(sender,owner,owner.session);
   if(owner.character||request.character)await owner.session.selectCharacter(owner.character??request.character);
   owner.character?.fill(0);owner.character=null;
   await owner.session.connect({host:request.host.trim(),port:request.port,expectedServerPublicKey:pin,metadata:result.metadata});
   return{sessionId:owner.id,state:owner.session.state()};
  }catch{if(owner.session)await owner.session.disconnect();if(owners.get(sender.id)===owner)owners.delete(sender.id);throw new Error('Multiplayer connection failed or was cancelled');}
  finally{owner.character?.fill(0);owner.character=null;for(const key of Object.keys(credentials??{}))credentials[key]='';}
 }
 const session=(sender,id)=>{const owner=owners.get(sender.id);if(!owner||owner.id!==id||owner.cancelled||!owner.session||owner.session.closed)throw new Error('Multiplayer session is unavailable');return owner.session;};
 const trusted=event=>{if(!attached.has(event.sender.id)||event.senderFrame!==event.sender.mainFrame||event.sender.getURL()!==applicationUrl)throw new Error('Untrusted multiplayer sender');return event.sender;};
 const handle=(channel,fn)=>ipcMain.handle(channel,async(event,...args)=>{try{return{ok:true,value:await fn(trusted(event),...args)};}catch(error){return{ok:false,message:error.message,...(error.code==='RESOURCE_NOT_FOUND'?{code:'RESOURCE_NOT_FOUND'}:{})};}});
 const lobbyResolver=sender=>{const owner=attached.get(sender.id);return owner.uiResolver??=(async()=>{const {openServerResourceContext}=await import('./server_resource_context.mjs'),settings=clientSettings?await clientSettings.status():null;return openServerResourceContext({install:owner.install,userDirectory,modsDirectory:settings?.modsDirectory??null,disabledMods:settings?.disabledMods??[]});})();};
 handle('network:connect',connect);handle('network:disconnect',disconnect);
 handle('network:settings',async sender=>{if(!clientSettings)throw Error('Client settings are unavailable');return{...await clientSettings.status(),resourcesLocked:owners.has(sender.id)};});
 handle('network:settings-save',async(sender,request)=>{if(!clientSettings)throw Error('Client settings are unavailable');const resourcesChanged=request?.modsDirectory!==undefined||request?.disabledMods!==undefined;if(resourcesChanged&&owners.has(sender.id))throw Error('Disconnect before changing mods');try{const result=await clientSettings.update(request);if(resourcesChanged)for(const owner of attached.values())owner.uiResolver=null;return{...result,resourcesLocked:owners.has(sender.id)};}finally{if(request&&typeof request.cdKey==='string')request.cdKey='';}});
 handle('network:mods-list',async(sender,directory)=>{if(!clientSettings)throw Error('Client settings are unavailable');const settings=await clientSettings.status(),selected=directory??settings.modsDirectory;if(typeof selected!=='string'||selected.length>4096||selected.includes('\0')||selected&&!path.isAbsolute(selected))throw Error('Invalid mods folder');const {workshopContent}=await import('./workshop_content.mjs');return workshopContent(selected,{disabledMods:selected===settings.modsDirectory?settings.disabledMods:[]}).mods();});
 handle('network:mods-folder',async sender=>{if(!clientSettings||!chooseMods)throw Error('Mods folder selection is unavailable');if(owners.has(sender.id))throw Error('Disconnect before changing the mods folder');const selected=await chooseMods(sender);return{...await clientSettings.status(),resourcesLocked:false,selected:Boolean(selected),chosenModsDirectory:selected??null};});
 handle('network:scene-capture-status',()=>sceneCapture?.status()??{recording:false});
 handle('network:scene-capture-finish',()=>sceneCapture?.close()??{complete:false});
 handle('network:scene-capture-view',(sender,id,value)=>{const active=session(sender,id);if(!sceneCapture)return false;return sceneCapture.view(sceneCapture.contextFor(active),value);});
 handle('network:character',(sender,id,bytes)=>session(sender,id).selectCharacter(bytes));
 handle('network:server-characters',(sender,id)=>session(sender,id).requestServerCharacters());
 handle('network:lobby-players',(sender,id,open)=>session(sender,id).lobbyPlayers(open));
 handle('network:server-character-preview',(sender,id,request)=>session(sender,id).previewServerCharacter(request));
 handle('network:server-character-play',(sender,id,request)=>session(sender,id).playServerCharacter(request));
 handle('network:server-character-create',(sender,id,bytes)=>session(sender,id).selectCharacter(bytes,{createOnServer:true}));
 handle('network:server-query',async(_sender,endpoint)=>{const {queryNetworkServer}=await import('./server_browser.mjs');return queryNetworkServer(endpoint);});
 handle('network:server-list',async()=>{const {fetchNetworkServerList}=await import('./server_browser.mjs');return fetchNetworkServerList();});
 handle('network:lobby-resource',async(sender,resref,type)=>{if(typeof resref!=='string'||!/^[a-z0-9_]{1,32}$/i.test(resref)||![3,2002,2033,2047,2074].includes(type))throw new Error('Invalid lobby resource');return(await lobbyResolver(sender)).getResource(resref,type);});
 handle('network:lobby-texture',async(sender,resref)=>{if(typeof resref!=='string'||!/^[a-z0-9_]{1,32}$/i.test(resref))throw new Error('Invalid lobby texture');return(await lobbyResolver(sender)).getTextureResource(resref);});
 handle('network:talk-table',(sender,id,custom)=>session(sender,id).getTalkTable(custom));
 handle('network:creation-models',(sender,id)=>session(sender,id).creationModels());
 handle('network:creation-portraits',(sender,id)=>session(sender,id).creationPortraits());
 handle('network:creation-portrait-availability',(sender,id,refs)=>session(sender,id).creationPortraitAvailability(refs));
 handle('network:local-character-preview',(sender,id,bytes)=>session(sender,id).previewLocalCharacter(bytes));
 handle('network:saved-character-preview',async(sender,id,vaultId)=>{const active=session(sender,id);if(active.localVaultAllowed!==true||!characterVault)throw new Error('Local character selection is unavailable');const bytes=await characterVault.read(vaultId);try{const preview=await active.previewLocalCharacter(bytes);session(sender,id);return preview;}finally{bytes.fill(0);}});
 handle('network:saved-character-play',async(sender,id,vaultId)=>{const active=session(sender,id),owner=owners.get(sender.id);if(active.localVaultAllowed!==true||!characterVault)throw new Error('Local character selection is unavailable');const bytes=await characterVault.read(vaultId);try{session(sender,id);await active.selectCharacter(bytes);owner.vaultId=vaultId;return{submitted:true};}finally{bytes.fill(0);}});
 handle('network:lobby-exit',sender=>attached.get(sender.id).window.close());
 handle('network:characters',()=>{if(!characterVault)throw new Error('The character vault is unavailable');return characterVault.list();});
 handle('network:character-export',(sender,id)=>session(sender,id).exportCharacter());
 handle('network:area-ready',(sender,id,generation)=>session(sender,id).areaReady(generation));
 handle('network:walk',(sender,id,request)=>session(sender,id).walkTo(request));
 handle('network:keyboard',(sender,id,request)=>session(sender,id).keyboardMove(request));
 handle('network:interact',(sender,id,request)=>session(sender,id).interact(request));
 handle('network:chat',(sender,id,request)=>session(sender,id).chat(request));
  handle('network:examine',(sender,id,request)=>session(sender,id).examine(request));
 handle('network:dialog-reply',(sender,id,request)=>session(sender,id).replyDialog(request));
 handle('network:inventory-window',(sender,id,request)=>session(sender,id).inventoryWindow(request));
 handle('network:inventory-panel',(sender,id,request)=>session(sender,id).inventoryPanel(request));
 handle('network:container-input',(sender,id,request)=>session(sender,id).containerInput(request));
 handle('network:store-input',(sender,id,request)=>session(sender,id).storeInput(request));
 handle('network:item-action',(sender,id,request)=>session(sender,id).itemAction(request));
 handle('network:quickbar-assign',(sender,id,request)=>session(sender,id).assignQuickbar(request));
 handle('network:quickbar-use',(sender,id,request)=>session(sender,id).activateQuickbar(request));
 handle('network:spell-cast',(sender,id,request)=>session(sender,id).castSpell(request));
 handle('network:spell-prepare',(sender,id,request)=>session(sender,id).prepareSpell(request));
 handle('network:rest',(sender,id,request)=>session(sender,id).rest(request));
 handle('network:level-up',(sender,id,request)=>session(sender,id).levelUp(request));
 handle('network:nui-input',(sender,id,request)=>session(sender,id).nuiInput(request));
 handle('network:script-target',(sender,id,request)=>session(sender,id).selectScriptTarget(request));
 handle('network:action-cancel',(sender,id,request)=>session(sender,id).cancelAction(request));
 handle('network:hud-panel',(sender,id,request)=>session(sender,id).hudPanel(request));
 handle('network:player-attitude',(sender,id,request)=>session(sender,id).playerAttitude(request));
 handle('network:item-use',(sender,id,request)=>session(sender,id).useItem(request));
 handle('network:spell-like-cast',(sender,id,request)=>session(sender,id).castSpellLike(request));
 handle('network:feat-use',(sender,id,request)=>session(sender,id).useFeat(request));
 handle('network:mode-change',(sender,id,request)=>session(sender,id).changeMode(request));
 handle('network:familiar-possess',(sender,id,request)=>session(sender,id).possessFamiliar(request));
 handle('network:associate-command',(sender,id,request)=>session(sender,id).associateCommand(request));
 handle('network:quick-chat',(sender,id,request)=>session(sender,id).quickChat(request));
 handle('network:talk-string',(sender,id,ref,gender)=>session(sender,id).talkString(ref,gender));
 handle('network:resource',(sender,id,resref,type)=>session(sender,id).getResource(resref,type));
 handle('network:model-source',async(sender,id,resref,knownKey=null)=>{
  if(typeof resref!=='string'||!/^[a-z0-9_]{1,32}$/i.test(resref))throw Error('Invalid model resource');
  if(!modelCache)throw Error('Prepared-model cache is unavailable');
  if(knownKey!==null&&(typeof knownKey!=='string'||!/^[a-f0-9]{64}$/.test(knownKey)))throw Error('Invalid prepared-model key');
  const current=session(sender,id),bytes=await current.getResource(resref,2002);
  if(session(sender,id)!==current)throw Error('Model resource belongs to an old connection');
  const model=await modelCache.prepare(bytes,{knownKey,metadata:true});
  if(session(sender,id)!==current)throw Error('Prepared model belongs to an old connection');
  return model;
 });
 handle('network:texture-resource',(sender,id,resref)=>session(sender,id).getTextureResource(resref));
 handle('network:audio-resource',(sender,id,resref,type)=>session(sender,id).getAudioResource(resref,type));
 handle('network:install',async sender=>{if(owners.has(sender.id))throw new Error('Disconnect before choosing an installation');const chosen=await chooseInstall(sender);if(chosen){const current=attached.get(sender.id);if(!current)throw new Error('Multiplayer window is unavailable');current.install=path.resolve(chosen);current.uiResolver=null;}return{selected:Boolean(chosen)};});
 return{connect,disconnect,invalidateLobbyResources(sender){const owner=attached.get(sender.id);if(!owner||sender.isDestroyed())throw Error('Multiplayer window is unavailable');owner.uiResolver=null;},attach(window){const sender=window.webContents;let closing=false,allowClose=false;attached.set(sender.id,{install:defaultInstall,window});sender.once('destroyed',()=>{attached.delete(sender.id);void disconnect(sender,{saveCharacter:false}).catch(()=>{});});window.on('close',event=>{
  if(allowClose)return;const owner=owners.get(sender.id);
  if(!characterVault||!['playing','area-loading'].includes(owner?.session?.phase)){void disconnect(sender,{saveCharacter:false}).catch(()=>{});return;}
  event.preventDefault();if(closing)return;closing=true;
  void disconnect(sender).then(()=>{allowClose=true;window.close();}).catch(error=>publish(sender,owner.id,'diagnostic',{diagnostic:{code:'network.character-close-save-failed',reason:'Character save failed; the window remains open. Retry Export Character or disconnect without saving.',detail:error.message}})).finally(()=>{closing=false;});
 });}};
}
module.exports={registerNetworkIpc};
