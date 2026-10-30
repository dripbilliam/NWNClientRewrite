// Presentation/admission coordinator. Never invents characters or evaluates rules.
// Local keys are catalog identities, not filesystem paths accepted from Godot.
import {finiteResourceProgress,canCancelResources} from './resource-progress.mjs';
// Public protocol/catalog metadata only; paths, credentials and vault internals
// stay in this service. Fonts, class names, portraits and layout belong to Godot.
export function lobbyChoice(row){
 const result={key:row.key,label:row.label,source:row.source,classes:row.classes};
 for(const field of ['portrait','portraitRef','serverSource','pregenerated','firstName','lastName'])if(row[field]!==undefined)result[field]=row[field];
 if(row.source!=='server')for(const field of ['nativeFile','catalogStem'])if(row[field]!==undefined)result[field]=row[field];
 return result;
}
export function lobbyServerInfo(raw){
 const result={};if(!raw||typeof raw!=='object')return result;
 for(const field of ['serverName','moduleName','moduleDescription','gameDetails','serverVersion','address'])if(typeof raw[field]==='string')result[field]=raw[field];
 for(const field of ['minimumLevel','maximumLevel','playerCount','maximumPlayers','pvpSetting','serverStatus'])if(Number.isSafeInteger(raw[field]))result[field]=raw[field];
 if(typeof raw.extendedReceived==='boolean')result.extendedReceived=raw.extendedReceived;
 return result;
}
export class NativeLobby {
 constructor({listLocal,readLocal,connect,disconnect,save,publish,resolveName=async v=>v?.text??'',onSession=()=>{},inspectServer=async()=>null}){
  Object.assign(this,{listLocal,readLocal,connect,disconnect,save,publish,resolveName,onSession,inspectServer});
  this.connection=0;this.session=null;this.phase='menu';this.locals=new Map();this.servers=new Map();this.selected=null;this.preview=null;this.busy=false;this.error='';this.previewVersion=0;this.vaultId=null;this.transferring=false;this.portalDestinationConnection=null;
  this.players=new Map();this.pageIndex=0;this.pageVersion=0;this.pageError='';this.serverStatus=null;
 }
 snapshot(){return{localRefreshAck:this.localRefreshAck??null,previewAccountScope:this.previewAccountScope??'',phase:this.phase,busy:this.busy,creating:Boolean(this.creating),error:this.error,resourceProgress:this.resourceProgress??null,endpoint:this.endpoint??null,canCancelJoin:Boolean(this.joinWork||canCancelResources(this.session)||this.portalPending())&&!this.cancelling,connected:Boolean(this.session&&!this.session.closed),localAllowed:this.session?.localVaultAllowed===true,canJoin:!this.busy&&!this.transferring&&(!this.session||this.session.closed),canSelect:!this.creating&&!this.busy&&this.selectable(),canCreate:!this.creating&&!this.busy&&this.selectable()&&Boolean(this.session.resourceResult?.ready&&this.session.resolver),selected:this.selected,selectionAck:this.selectionAck??null,preview:this.preview,lobbyPage:this.pageIndex,canLobbyPages:Boolean(this.selectable()&&!this.creating&&!this.busy),players:[...this.players.values()],serverInfo:{...lobbyServerInfo(this.session?.serverInfo),...this.serverDetails,...(this.session&&!this.session.closed&&this.serverStatus!==null?{serverStatus:this.serverStatus}:{})},serverInfoPending:Boolean(this.infoController),pageError:this.pageError,choices:[...(this.session?.localVaultAllowed===true?this.locals.values():[]),...this.servers.values()].map(lobbyChoice)};}
 emit(){if(this.selectionAck&&(this.selectionAck.connection!==this.connection||this.selectionAck.key!==this.selected))this.selectionAck=null;const message={kind:'lobby',connection:this.connection,state:this.snapshot()},key=JSON.stringify(message);if(key!==this.lastPublished){this.lastPublished=key;this.publish(message);}}
 selectable(){return !this.transferring&&this.session&&!this.session.closed&&['character-selection','character-rejected'].includes(this.session.phase)&&!this.session.characterSubmitted&&!this.session.characterUploaded&&!this.session.serverCharacterListPending;}
 portalPending(){return Boolean(this.transferring||this.session&&!this.session.closed&&this.session.phase==='transferring'&&this.session.portalTransfer?.pending);}
 advancePortal(previous,endpoint){
  if(this.session!==previous||!previous.portalHandoffReady||!previous.closed)throw Error('Portal handoff no longer owns the native lobby');
  this.resetPages();
  this.connection++;this.portalDestinationConnection=this.connection;this.phase='transferring';this.transferring=true;this.busy=true;this.session=null;this.endpoint=endpoint;this.selected=this.preview=null;this.previewVersion++;this.servers.clear();this.vaultId=null;this.resourceProgress=null;this.error='';this.creating=false;this.emit();return this.connection;
 }
 portalConnected(session,connection){if(this.session!==session||this.connection!==connection)return;this.portalDestinationConnection=null;this.emit();}
 failPortal(connection,reason){if(this.connection!==connection)return;this.resetPages();this.portalDestinationConnection=null;this.transferring=false;this.busy=false;this.error=reason;this.phase='menu';this.session=null;this.resourceProgress=null;this.emit();}
 requireOwner(message){if(message.connection!==this.connection)throw Error('Character lobby belongs to an old connection');}
 resetPages(){this.pageVersion++;this.infoController?.abort();this.infoController=null;this.pageIndex=0;this.players.clear();this.serverDetails=null;this.pageError='';}
 async setPage(message){
  this.requireOwner(message);const index=message.page;
  if(!Number.isInteger(index)||index<0||index>2)throw Error('Invalid character lobby page');
  const session=this.session,connection=this.connection,endpoint=this.endpoint;
  if(index!==0&&(!this.selectable()||this.creating||this.busy))throw Error('Character lobby page is unavailable');
  const version=++this.pageVersion;this.infoController?.abort();this.infoController=null;this.pageError='';
  const previous=this.pageIndex;this.pageIndex=index;if(index!==2||previous!==2)this.players.clear();this.emit();
  const active=()=>this.session===session&&this.connection===connection&&this.pageVersion===version;
  try{
   if(session&&!session.closed&&Boolean(session.lobbyPlayersOpen)!==(index===2)&&!session.characterSubmitted)await session.lobbyPlayers(index===2);
  }catch(error){if(active()){this.pageError=error.message;this.emit();}return;}
  if(!active()||index!==1||this.serverDetails?.extendedReceived)return;
  const controller=new AbortController();this.infoController=controller;this.emit();
  void Promise.resolve().then(()=>active()&&!controller.signal.aborted?this.inspectServer({session,endpoint,signal:controller.signal}):null).then(details=>{
   if(active()&&!controller.signal.aborted&&details)this.serverDetails=lobbyServerInfo(details);
  }).catch(error=>{if(active()&&!controller.signal.aborted)this.pageError=error.message;}).finally(()=>{
   if(this.infoController===controller){this.infoController=null;if(active())this.emit();}
  });
 }
 async join(message){
  this.requireOwner(message);if(this.busy||this.transferring||this.session&&!this.session.closed)throw Error('Disconnect the current session before joining');
  this.resetPages();
  this.connection++;const connection=this.connection;this.previewAccountScope='';this.localRefreshAck=null;this.hiddenLocalRows=new Set();this.creating=false;this.busy=true;this.error='';this.resourceProgress=null;this.phase='connecting';this.servers.clear();this.selected=this.preview=null;this.previewVersion++;this.vaultId=null;this.emit();
  const controller=new AbortController();this.joinController=controller;
  const pending=Promise.resolve().then(async()=>{const locals=await this.listLocal();controller.signal.throwIfAborted();if(connection!==this.connection)return;this.locals=new Map(locals.map(row=>[row.key,row]));await this.connect(connection,message.details,{signal:controller.signal});});
  const aborted=new Promise((_,reject)=>controller.signal.addEventListener('abort',()=>reject(controller.signal.reason),{once:true}));
  const work=Promise.race([pending,aborted]);this.joinWork=work;this.emit();
  try{await work;}
  catch(error){if(connection===this.connection){this.error=error.message;this.phase='menu';}}
  finally{if(this.joinWork===work)this.joinWork=null;if(this.joinController===controller)this.joinController=null;if(connection===this.connection){this.busy=false;this.emit();}}
 }
 async cancelJoin(message){
  this.requireOwner(message);if((!this.joinWork&&!canCancelResources(this.session)&&!this.portalPending())||this.cancelling)throw Error('No connection attempt to cancel');
  return this.leave({...message,saveCharacter:false});
 }
 attach(session,connection){
  if(connection!==this.connection)throw Error('Cancelled native login session');this.resetPages();this.serverStatus=null;this.session=session;if(this.transferring)this.busy=false;this.onSession(session,connection);
  const active=()=>this.session===session&&this.connection===connection;
  session.on('state',state=>{
   if(!active())return;
   if(!['character-selection','character-rejected'].includes(state.phase)&&this.pageIndex!==0)this.resetPages();
   this.phase=state.closed&&session.portalHandoffReady?'transferring':state.phase;
   if(state.phase==='transferring')this.transferring=true;
   if(state.phase==='playing'){if(this.transferring)this.busy=false;this.transferring=false;this.portalDestinationConnection=null;}
   else if(state.closed&&!session.portalHandoffReady){
    if(this.portalDestinationConnection===connection){this.transferring=true;this.busy=true;}
    else{if(this.transferring)this.busy=false;this.transferring=false;}
   }
   this.resourceProgress=state.closed?null:finiteResourceProgress(state.resourceProgress);
   if(state.phase==='resources-unavailable')this.error='Required server content could not be loaded. Cancel this connection and retry.';
   if(state.closed&&!session.portalHandoffReady&&state.disconnectReason){const reason=state.disconnectReason;this.error=reason.text||`Server closed the connection${reason.strRef!==null?` (message ${reason.strRef})`:''}.`;}
   if(state.closed){this.resetPages();this.creating=false;this.previewVersion++;this.selected=this.preview=null;this.servers.clear();}this.emit();
  });
  session.on('message',({message})=>{
   if(!active())return;
   // Original SendServerToPlayerServerStatus_Status4df850 sends1/1 for
   // busy(1),1/2 for idle(0), and1/3 resources for running(2).
   const status={'server-loading':1,'server-unavailable':0,'server-resources':2}[message.kind];
   if(status!==undefined){this.serverStatus=status;this.emit();}
   if(message.kind==='server-character-player'){
    if(this.pageIndex!==2||!session.lobbyPlayersOpen||!this.selectable()||this.creating)return;
    const value=message.character;if(!value||!Number.isInteger(value.id)||value.id<0||value.id>0xffffffff)return;
    if(message.present){const row={id:value.id};for(const field of ['firstName','lastName','portrait','portraitRef','classes'])if(value[field]!==undefined)row[field]=value[field];this.players.set(row.id,row);}
    else this.players.delete(value.id);this.emit();return;
   }
   if(message.kind==='server-character-list')void this.serverList(message,session,connection).catch(e=>{if(active()){this.error=e.message;this.emit();}});
   if(message.kind==='server-character-preview'){
    const row=this.servers.get(this.selected);if(!row||row.resref!==message.resref||row.serverSource!==message.source||row.generation!==message.generation)return;
    this.preview=message.preview;this.emit();
   }
  });
 }
 async serverList(message,session,connection){
  const rows=await Promise.all(message.characters.map(async row=>({...row,key:`server:${row.source}:${row.resref}`,label:[await this.resolveName(row.firstName),await this.resolveName(row.lastName)].filter(Boolean).join(' ')||row.resref,source:'server',serverSource:row.source,generation:message.generation})));
  if(this.session!==session||this.connection!==connection||session.characterSubmitted||session.closed||message.generation!==session.characterListGeneration)return;
  this.servers=new Map(rows.map(row=>[row.key,row]));if(!this.locals.has(this.selected)){this.selected=this.preview=null;this.previewVersion++;}this.emit();
 }
 row(message){this.requireOwner(message);if(!this.selectable()||this.busy||this.creating)throw Error('Character selection is unavailable');const row=this.locals.get(message.key)??this.servers.get(message.key);if(!row||row.source!=='server'&&this.session.localVaultAllowed!==true)throw Error('Character is absent from the current allowed list');return row;}
 async choose(message){
  if(message.requestId!==undefined&&(!Number.isSafeInteger(message.requestId)||message.requestId<1))throw Error('Invalid character selection request identity');
  if(this.pageIndex!==0)await this.setPage({connection:message.connection,page:0});
  const row=this.row(message),session=this.session,connection=this.connection,version=++this.previewVersion;
  this.selected=row.key;this.selectionAck=message.requestId===undefined?null:{connection,requestId:message.requestId,key:row.key};this.preview=null;this.error='';this.emit();
  if(row.source==='server'){await session.previewServerCharacter({source:row.serverSource,resref:row.resref,generation:row.generation});return;}
  const bytes=await this.readLocal(row.key);
  try{if(session!==this.session||connection!==this.connection||version!==this.previewVersion||!this.selectable())return;const preview=await session.previewLocalCharacter(bytes);if(session===this.session&&connection===this.connection&&version===this.previewVersion&&!session.characterSubmitted){this.preview=preview;this.emit();}}finally{bytes.fill(0);}
 }
 async play(message){
  if(this.pageIndex!==0)await this.setPage({connection:message.connection,page:0});
  const row=this.row(message);if(this.selected!==row.key)throw Error('Select this character before playing');
  const session=this.session,connection=this.connection;this.busy=true;this.error='';this.emit();
  try{
   if(row.source==='server')await session.playServerCharacter({source:row.serverSource,resref:row.resref,generation:row.generation});
   else{const bytes=await this.readLocal(row.key);try{if(session!==this.session||connection!==this.connection||!this.selectable())throw Error('Character upload was cancelled');this.vaultId=row.vaultId??null;await session.selectCharacter(bytes);}finally{bytes.fill(0);}}
  }finally{if(session===this.session&&connection===this.connection){this.busy=false;this.emit();}}
 }
 async refreshLocal(message){
  const row=this.row(message);if(row.source==='server'||row.nativeFile?.sha256!==message.sha256||!Number.isSafeInteger(message.requestId)||message.requestId<1)throw Error('Local character refresh belongs to an unavailable selection');
  if(message.dismissInstalled!==undefined&&typeof message.dismissInstalled!=='boolean'||message.dismissInstalled&&row.nativeFile.storageSource!=='installed')throw Error('Installed character dismissal belongs to another storage role');
  this.hiddenLocalRows??=new Set();if(message.dismissInstalled)this.hiddenLocalRows.add(row.key);
  const connection=this.connection,session=this.session;this.busy=true;this.error='';this.emit();
  try{
   const rows=await this.listLocal();if(connection!==this.connection||session!==this.session||session.closed)return;
   this.locals=new Map(rows.filter(entry=>!this.hiddenLocalRows.has(entry.key)).map(entry=>[entry.key,entry]));this.selected=this.preview=null;this.previewVersion++;this.selectionAck=null;this.localRefreshAck={connection,requestId:message.requestId,key:row.key};
  }catch{if(connection===this.connection){this.error='The local character list could not be refreshed.';this.localRefreshAck={connection,requestId:message.requestId,key:row.key,accepted:false};}}
  finally{if(connection===this.connection){this.busy=false;this.emit();}}
 }
 async export(message){this.requireOwner(message);if(this.busy||!this.session||this.session.closed||!['playing','area-loading'].includes(this.session.phase))throw Error('Character export is unavailable');const connection=this.connection;this.busy=true;this.emit();try{const entry=await this.save();if(connection===this.connection){this.vaultId=entry.id;this.publish({kind:'character-saved',connection,key:'vault:'+entry.id,name:entry.name});}return entry;}finally{if(connection===this.connection){this.busy=false;this.emit();}}}
 async leave(message){
  this.requireOwner(message);if(this.cancelling||typeof message.saveCharacter!=='boolean')throw Error('Invalid disconnect request');
  this.resetPages();
  const targetSession=this.session;this.cancelling=true;this.connection++;this.busy=true;this.phase='disconnecting';this.error='';this.resourceProgress=null;
  this.joinController?.abort(new Error('Connection cancelled'));this.joinController=null;this.joinWork=null;
  this.creating=false;this.previewVersion++;this.selected=this.preview=null;this.servers.clear();this.emit();
  try{await this.disconnect({saveCharacter:message.saveCharacter,targetSession});}
  catch(error){this.error=error.message;}
  finally{this.session=null;this.phase='menu';this.vaultId=null;this.cancelling=false;this.busy=false;this.transferring=false;this.portalDestinationConnection=null;this.emit();}
 }
}
