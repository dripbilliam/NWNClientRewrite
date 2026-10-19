const path=require('node:path');
const crypto=require('node:crypto');
const {pathToFileURL}=require('node:url');
const applicationUrl=pathToFileURL(path.resolve(__dirname,'../dist/index.html')).href;

// Only attached main frames own sessions. No path-based file reader, arbitrary
// IPC channel forwarding, credential storage or raw player-message API.
function registerNetworkIpc(ipcMain,{defaultInstall,userDirectory,chooseInstall,createSession}){
 const attached=new Map(),owners=new Map();
 const publish=(sender,id,kind,value)=>{if(attached.has(sender.id)&&!sender.isDestroyed())sender.send('network:event',{sessionId:id,kind,...value});};
 const disconnect=async sender=>{const owner=owners.get(sender.id);if(!owner)return;owner.cancelled=true;if(owner.session)await owner.session.disconnect();if(owners.get(sender.id)===owner)owners.delete(sender.id);};
 async function connect(sender,request){
  if(!attached.has(sender.id)||sender.isDestroyed())throw new Error('Multiplayer window is unavailable');
  if(owners.has(sender.id))throw new Error('Disconnect the current multiplayer session first');
  if(!request||typeof request.host!=='string'||!request.host.trim()||request.host.length>255||!Number.isInteger(request.port)||request.port<1||request.port>65535||typeof request.name!=='string'||!request.name.length||request.name.length>64)throw new Error('Invalid multiplayer connection settings');
  let pin=null;
  if(request.serverPublicKey){if(typeof request.serverPublicKey!=='string'||!/^[A-Za-z0-9+/]{43}=$/.test(request.serverPublicKey))throw new Error('Invalid server public identity');pin=Buffer.from(request.serverPublicKey,'base64');}
  const owner={id:crypto.randomUUID(),cancelled:false,session:null};owners.set(sender.id,owner);
  const credentials=request.credentials;delete request.credentials;
  try{
   const result=await createSession({install:attached.get(sender.id).install,userDirectory,name:request.name,credentials,onDiagnostic:d=>publish(sender,owner.id,'diagnostic',{diagnostic:d})});
   owner.session=result.session;
   if(owner.cancelled||!attached.has(sender.id)||sender.isDestroyed()){await owner.session.disconnect();throw new Error('Multiplayer connection was cancelled');}
   owner.session.on('state',state=>publish(sender,owner.id,'state',{state}));
   owner.session.on('message',event=>publish(sender,owner.id,'message',event));
   owner.session.once('closed',()=>{if(owners.get(sender.id)===owner)owners.delete(sender.id);});
   if(request.character)await owner.session.selectCharacter(request.character);
   await owner.session.connect({host:request.host.trim(),port:request.port,expectedServerPublicKey:pin,metadata:result.metadata});
   return{sessionId:owner.id,state:owner.session.state()};
  }catch{if(owner.session)await owner.session.disconnect();if(owners.get(sender.id)===owner)owners.delete(sender.id);throw new Error('Multiplayer connection failed or was cancelled');}
 }
 const session=(sender,id)=>{const owner=owners.get(sender.id);if(!owner||owner.id!==id||owner.cancelled||!owner.session||owner.session.closed)throw new Error('Multiplayer session is unavailable');return owner.session;};
 const trusted=event=>{if(!attached.has(event.sender.id)||event.senderFrame!==event.sender.mainFrame||event.sender.getURL()!==applicationUrl)throw new Error('Untrusted multiplayer sender');return event.sender;};
 const handle=(channel,fn)=>ipcMain.handle(channel,async(event,...args)=>{try{return{ok:true,value:await fn(trusted(event),...args)};}catch(error){return{ok:false,message:error.message};}});
 handle('network:connect',connect);handle('network:disconnect',disconnect);
 handle('network:character',(sender,id,bytes)=>session(sender,id).selectCharacter(bytes));
 handle('network:area-ready',(sender,id,generation)=>session(sender,id).areaReady(generation));
 handle('network:walk',(sender,id,request)=>session(sender,id).walkTo(request));
 handle('network:interact',(sender,id,request)=>session(sender,id).interact(request));
  handle('network:examine',(sender,id,request)=>session(sender,id).examine(request));
 handle('network:dialog-reply',(sender,id,request)=>session(sender,id).replyDialog(request));
 handle('network:inventory-window',(sender,id,request)=>session(sender,id).inventoryWindow(request));
 handle('network:inventory-panel',(sender,id,request)=>session(sender,id).inventoryPanel(request));
 handle('network:item-action',(sender,id,request)=>session(sender,id).itemAction(request));
 handle('network:quickbar-assign',(sender,id,request)=>session(sender,id).assignQuickbar(request));
 handle('network:quickbar-use',(sender,id,request)=>session(sender,id).activateQuickbar(request));
 handle('network:spell-cast',(sender,id,request)=>session(sender,id).castSpell(request));
 handle('network:spell-prepare',(sender,id,request)=>session(sender,id).prepareSpell(request));
 handle('network:rest',(sender,id,request)=>session(sender,id).rest(request));
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
 handle('network:install',async sender=>{if(owners.has(sender.id))throw new Error('Disconnect before choosing an installation');const chosen=await chooseInstall(sender);if(chosen){const current=attached.get(sender.id);if(!current)throw new Error('Multiplayer window is unavailable');current.install=path.resolve(chosen);}return{selected:Boolean(chosen)};});
 return{connect,disconnect,attach(window){const sender=window.webContents;attached.set(sender.id,{install:defaultInstall});sender.once('destroyed',()=>{attached.delete(sender.id);void disconnect(sender).catch(()=>{});});window.on('close',()=>{void disconnect(sender).catch(()=>{});});}};
}
module.exports={registerNetworkIpc};
