// Presentation/admission coordinator. Never invents characters or evaluates rules.
// Local keys are catalog identities, not filesystem paths accepted from Godot.
import {finiteResourceProgress,canCancelResources} from './resource-progress.mjs';
export class NativeLobby {
 constructor({listLocal,readLocal,connect,disconnect,save,publish,resolveName=async v=>v?.text??'',onSession=()=>{}}){
  Object.assign(this,{listLocal,readLocal,connect,disconnect,save,publish,resolveName,onSession});
  this.connection=0;this.session=null;this.phase='menu';this.locals=new Map();this.servers=new Map();this.selected=null;this.preview=null;this.busy=false;this.error='';this.previewVersion=0;this.vaultId=null;this.transferring=false;this.portalDestinationConnection=null;
 }
 snapshot(){return{phase:this.phase,busy:this.busy,creating:Boolean(this.creating),error:this.error,resourceProgress:this.resourceProgress??null,endpoint:this.endpoint??null,canCancelJoin:Boolean(this.joinWork||canCancelResources(this.session)||this.portalPending())&&!this.cancelling,connected:Boolean(this.session&&!this.session.closed),localAllowed:this.session?.localVaultAllowed===true,canJoin:!this.busy&&!this.transferring&&(!this.session||this.session.closed),canSelect:!this.creating&&!this.busy&&this.selectable(),canCreate:!this.creating&&!this.busy&&this.selectable()&&Boolean(this.session.resourceResult?.ready&&this.session.resolver),selected:this.selected,preview:this.preview,choices:[...(this.session?.localVaultAllowed===true?this.locals.values():[]),...this.servers.values()].map(({key,label,source,classes})=>({key,label,source,classes}))};}
 emit(){const message={kind:'lobby',connection:this.connection,state:this.snapshot()},key=JSON.stringify(message);if(key!==this.lastPublished){this.lastPublished=key;this.publish(message);}}
 selectable(){return !this.transferring&&this.session&&!this.session.closed&&['character-selection','character-rejected'].includes(this.session.phase)&&!this.session.characterSubmitted&&!this.session.characterUploaded&&!this.session.serverCharacterListPending;}
 portalPending(){return Boolean(this.transferring||this.session&&!this.session.closed&&this.session.phase==='transferring'&&this.session.portalTransfer?.pending);}
 advancePortal(previous,endpoint){
  if(this.session!==previous||!previous.portalHandoffReady||!previous.closed)throw Error('Portal handoff no longer owns the native lobby');
  this.connection++;this.portalDestinationConnection=this.connection;this.phase='transferring';this.transferring=true;this.busy=true;this.session=null;this.endpoint=endpoint;this.selected=this.preview=null;this.previewVersion++;this.servers.clear();this.vaultId=null;this.resourceProgress=null;this.error='';this.creating=false;this.emit();return this.connection;
 }
 portalConnected(session,connection){if(this.session!==session||this.connection!==connection)return;this.portalDestinationConnection=null;this.emit();}
 failPortal(connection,reason){if(this.connection!==connection)return;this.portalDestinationConnection=null;this.transferring=false;this.busy=false;this.error=reason;this.phase='menu';this.session=null;this.resourceProgress=null;this.emit();}
 requireOwner(message){if(message.connection!==this.connection)throw Error('Character lobby belongs to an old connection');}
 async join(message){
  this.requireOwner(message);if(this.busy||this.transferring||this.session&&!this.session.closed)throw Error('Disconnect the current session before joining');
  this.connection++;const connection=this.connection;this.creating=false;this.busy=true;this.error='';this.resourceProgress=null;this.phase='connecting';this.servers.clear();this.selected=this.preview=null;this.previewVersion++;this.vaultId=null;this.emit();
  const work=Promise.resolve().then(async()=>{const locals=await this.listLocal();if(connection!==this.connection)return;this.locals=new Map(locals.map(row=>[row.key,row]));await this.connect(connection,message.details);});this.joinWork=work;this.emit();
  try{await work;}
  catch(error){if(connection===this.connection){this.error=error.message;this.phase='menu';}}
  finally{if(this.joinWork===work)this.joinWork=null;if(connection===this.connection){this.busy=false;this.emit();}}
 }
 async cancelJoin(message){
  this.requireOwner(message);if((!this.joinWork&&!canCancelResources(this.session)&&!this.portalPending())||this.cancelling)throw Error('No connection attempt to cancel');
  const work=this.joinWork??Promise.resolve();this.cancelling=true;this.connection++;this.busy=true;this.phase='disconnecting';this.resourceProgress=null;this.emit();
  try{await this.disconnect({saveCharacter:false});await work.catch(()=>{});this.session=null;this.phase='menu';this.error='';this.selected=this.preview=null;this.servers.clear();this.previewVersion++;}
  catch(error){await work.catch(()=>{});this.error=error.message;throw error;}
  finally{this.cancelling=false;this.busy=false;this.transferring=false;this.portalDestinationConnection=null;this.emit();}
 }
 attach(session,connection){
  if(connection!==this.connection)throw Error('Cancelled native login session');this.session=session;if(this.transferring)this.busy=false;this.onSession(session,connection);
  const active=()=>this.session===session&&this.connection===connection;
  session.on('state',state=>{
   if(!active())return;
   this.phase=state.closed&&session.portalHandoffReady?'transferring':state.phase;
   if(state.phase==='transferring')this.transferring=true;
   if(state.phase==='playing'){if(this.transferring)this.busy=false;this.transferring=false;this.portalDestinationConnection=null;}
   else if(state.closed&&!session.portalHandoffReady){
    if(this.portalDestinationConnection===connection){this.transferring=true;this.busy=true;}
    else{if(this.transferring)this.busy=false;this.transferring=false;}
   }
   this.resourceProgress=state.closed?null:finiteResourceProgress(state.resourceProgress);
   if(state.phase==='resources-unavailable')this.error='Required server content could not be loaded. Cancel this connection and retry.';
   if(state.closed){this.creating=false;this.previewVersion++;this.selected=this.preview=null;this.servers.clear();}this.emit();
  });
  session.on('message',({message})=>{
   if(!active())return;
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
  const row=this.row(message),session=this.session,connection=this.connection,version=++this.previewVersion;
  this.selected=row.key;this.preview=null;this.error='';this.emit();
  if(row.source==='server'){await session.previewServerCharacter({source:row.serverSource,resref:row.resref,generation:row.generation});return;}
  const bytes=await this.readLocal(row.key);
  try{if(session!==this.session||connection!==this.connection||version!==this.previewVersion||!this.selectable())return;const preview=await session.previewLocalCharacter(bytes);if(session===this.session&&connection===this.connection&&version===this.previewVersion&&!session.characterSubmitted){this.preview=preview;this.emit();}}finally{bytes.fill(0);}
 }
 async play(message){
  const row=this.row(message);if(this.selected!==row.key)throw Error('Select this character before playing');
  const session=this.session,connection=this.connection;this.busy=true;this.error='';this.emit();
  try{
   if(row.source==='server')await session.playServerCharacter({source:row.serverSource,resref:row.resref,generation:row.generation});
   else{const bytes=await this.readLocal(row.key);try{if(session!==this.session||connection!==this.connection||!this.selectable())throw Error('Character upload was cancelled');this.vaultId=row.vaultId??null;await session.selectCharacter(bytes);}finally{bytes.fill(0);}}
  }finally{if(session===this.session&&connection===this.connection){this.busy=false;this.emit();}}
 }
 async export(message){this.requireOwner(message);if(this.busy||!this.session||this.session.closed||!['playing','area-loading'].includes(this.session.phase))throw Error('Character export is unavailable');const connection=this.connection;this.busy=true;this.emit();try{const entry=await this.save();if(connection===this.connection){this.vaultId=entry.id;this.publish({kind:'character-saved',connection,key:'vault:'+entry.id,name:entry.name});}return entry;}finally{if(connection===this.connection){this.busy=false;this.emit();}}}
 async leave(message){
  this.requireOwner(message);if(this.busy||typeof message.saveCharacter!=='boolean')throw Error('Invalid disconnect request');this.busy=true;this.error='';this.emit();
  try{await this.disconnect({saveCharacter:message.saveCharacter});this.connection++;this.session=null;this.phase='menu';this.servers.clear();this.selected=this.preview=null;this.previewVersion++;this.vaultId=null;}
  catch(error){this.error=error.message;throw error;}
  finally{this.busy=false;this.emit();}
 }
}
