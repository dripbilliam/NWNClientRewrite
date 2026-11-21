import path from 'node:path';
import fs from 'node:fs/promises';
import {workshopContent} from '../../electron/workshop_content.mjs';

// Only safe metadata leaves the existing OS-protected store. Native controls
// submit private catalog handles; paths are selected explicitly and validated.
export class SettingsService{
 constructor({store,connection,locked,send,invalidateResources=()=>{},onSave=()=>{}}){Object.assign(this,{store,connection,locked,send,invalidateResources,onSave});this.serial=0;this.epoch=0;this.view=null;this.closed=false;this.busy=false;}
 reset(){this.epoch++;this.view=null;}
 async retire(){this.closed=true;this.reset();if(this.busy)await this.commitDone;return{closed:true,pendingSave:this.busy?1:0};}
 scope(){return{connection:this.connection(),epoch:++this.epoch};}
 current(s){return!this.closed&&s.epoch===this.epoch&&s.connection===this.connection();}
 emit(s,value){if(this.current(s))this.send({...value,connection:s.connection});}
 async directory(value){if(typeof value!=='string'||value.length>4096||value.includes('\0')||value&&!path.isAbsolute(value))throw Error('Select a valid mods folder');if(value){try{if(!(await fs.stat(value)).isDirectory())throw Error();}catch{throw Error('Select an existing mods folder');}}return value?path.resolve(value):'';}
 async open({requestId,directory}){
  const connection=this.connection();if(this.busy)await this.commitDone;if(connection!==this.connection()||this.closed)return;
  const s=this.scope(),status=await this.store.status();if(!this.current(s))return;
  const selected=directory===undefined?status.modsDirectory:await this.directory(directory);
  if(this.locked()&&selected!==status.modsDirectory)throw Error('Disconnect before changing mods');
  const mods=await workshopContent(selected,{disabledMods:selected===status.modsDirectory?status.disabledMods:[]}).mods();if(!this.current(s))return;
  const id=++this.serial;this.view={id,scope:s,status,directory:selected,mods};
  this.emit(s,{kind:'settings-begin',requestId,viewId:id,status:{modsDirectory:selected,defaultModsDirectory:status.defaultModsDirectory,hasSavedCdKey:status.hasSavedCdKey,protectedStorageAvailable:status.protectedStorageAvailable,resourcesLocked:Boolean(this.locked())},count:mods.length});
  for(let at=0;at<mods.length;at+=128)this.emit(s,{kind:'settings-mods',requestId,viewId:id,rows:mods.slice(at,at+128).map((m,i)=>({entryId:at+i,label:m.label,id:m.id,enabled:m.enabled,directory:m.directory,content:m.content}))});
  this.emit(s,{kind:'settings-commit',requestId,viewId:id});
 }
 async save(m){
  const v=this.view;if(this.busy||!v||v.id!==m.viewId||!this.current(v.scope))throw Error('Settings view is no longer available');
  const values=m.values;if(!values||typeof values!=='object'||Array.isArray(values)||Object.keys(values).some(k=>!['disabled','cdKey','removeCdKey'].includes(k)))throw Error('Invalid settings request');
  try{
   if(values.cdKey!==undefined&&typeof values.cdKey!=='string'||values.cdKey?.length>41||values.removeCdKey!==undefined&&typeof values.removeCdKey!=='boolean')throw Error('Invalid protected-key request');
   const request={};if(values.disabled!==undefined){if(!Array.isArray(values.disabled)||values.disabled.length>10000||values.disabled.some(n=>!Number.isInteger(n)||n<0||n>=v.mods.length)||new Set(values.disabled).size!==values.disabled.length)throw Error('Invalid mod selection');
    const disabled=values.disabled.map(n=>v.mods[n].id),known=new Set(v.mods.map(m=>m.id));if(v.directory===v.status.modsDirectory)disabled.push(...v.status.disabledMods.filter(id=>!known.has(id)));
    if(v.directory!==v.status.modsDirectory)request.modsDirectory=v.directory;
    if(request.modsDirectory!==undefined||JSON.stringify([...disabled].sort())!==JSON.stringify([...v.status.disabledMods].sort()))request.disabledMods=disabled;
   }else if(v.directory!==v.status.modsDirectory)throw Error('Save the selected mod catalog before changing folders');
   const changed=request.modsDirectory!==undefined||request.disabledMods!==undefined;if(changed&&this.locked())throw Error('Disconnect before changing mods');
   if(values.cdKey)request.cdKey=values.cdKey;if(values.removeCdKey)request.removeCdKey=true;
   this.busy=true;
   let release;this.commitDone=new Promise(resolve=>release=resolve);
   try{if(Object.keys(request).length){await this.store.update(request);if(changed)this.invalidateResources();}await this.onSave({resourcesChanged:changed,keyReplaced:Boolean(values.cdKey),keyRemoved:Boolean(values.removeCdKey)});}
   finally{if(typeof request.cdKey==='string')request.cdKey='';this.busy=false;release();}
   if(this.current(v.scope))await this.open({requestId:m.requestId});
  }finally{if(typeof values?.cdKey==='string')values.cdKey='';}
 }
 async command(m){try{if(m.operation==='open'||m.operation==='scan')await this.open({requestId:m.requestId,...(m.operation==='scan'?{directory:m.directory}:{})});else if(m.operation==='save')await this.save(m);else if(m.operation==='close')this.reset();else throw Error('Unsupported settings operation');}
  catch(error){if(m.connection===this.connection())this.send({kind:'settings-notice',connection:m.connection,requestId:m.requestId,text:error.message});}
  finally{if(typeof m.values?.cdKey==='string')m.values.cdKey='';}
 }
}
