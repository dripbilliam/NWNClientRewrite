// UI ownership only. The protected store owns credentials; views publish metadata.
import {validateCommand} from './local-protocol.cjs';
export class LoginProfileService{
 constructor({store,connection,locked,send,onChange=()=>{}}){Object.assign(this,{store,connection,locked,send,onChange});this.serial=0;this.epoch=0;this.view=null;this.busy=false;this.closed=false;}
 reset(){this.epoch++;this.view=null;}
 current(scope){return!this.closed&&scope.connection===this.connection()&&scope.epoch===this.epoch;}
 async publish(requestId,status,operation='open'){
  const scope={connection:this.connection(),epoch:this.epoch};this.view={id:++this.serial,scope};
  this.send({kind:'login-profiles-view',connection:scope.connection,requestId,viewId:this.view.id,operation,activeProfileId:status.activeProfileId??null,profiles:(status.loginProfiles??[]).map(({id,label,playerName,hasSavedCdKey})=>({id,label,playerName,hasSavedCdKey:Boolean(hasSavedCdKey)})),hasLegacyCdKey:Boolean(status.hasLegacyCdKey??status.hasSavedCdKey),protectedStorageAvailable:Boolean(status.protectedStorageAvailable),locked:Boolean(this.locked())});
 }
 async command(m){
  try{
   validateCommand({...m,kind:'login-profile-input'},{connection:this.connection()});
   if(this.closed||m.connection!==this.connection())throw Error('Login profiles belong to an old connection');
   if(m.operation==='close'){this.reset();return;}
   if(this.busy)throw Error('A login profile change is still being saved');
   if(m.operation==='open'){
    this.reset();const scope={connection:this.connection(),epoch:this.epoch},status=await this.store.status();
    if(this.current(scope))await this.publish(m.requestId,status);return;
   }
   if(!this.view||m.viewId!==this.view.id||!this.current(this.view.scope))throw Error('This login-profile view is no longer current');
   if(this.locked())throw Error('Disconnect before switching or changing login profiles');
   const scope=this.view.scope;this.busy=true;let release;this.commitDone=new Promise(resolve=>release=resolve);
   try{
    let status;
    if(m.operation==='save')status=await this.store.saveProfile(m.values);
    else if(m.operation==='select')status=await this.store.selectProfile(m.profileId);
    else if(m.operation==='delete')status=await this.store.deleteProfile(m.profileId);
    else throw Error('Unsupported login-profile operation');
    await this.onChange(status);
    if(this.current(scope))await this.publish(m.requestId,status,m.operation);
   }finally{this.busy=false;release();}
  }catch(error){if(!this.closed&&m.connection===this.connection())this.send({kind:'login-profiles-notice',connection:m.connection,requestId:m.requestId,text:error.message});}
  finally{if(typeof m.values?.cdKey==='string')m.values.cdKey='';}
 }
 async retire(){this.closed=true;this.reset();if(this.busy)await this.commitDone;}
}
