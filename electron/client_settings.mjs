import fs from 'node:fs/promises';import path from 'node:path';import {randomUUID} from 'node:crypto';

export async function defaultModsDirectory(install,{steamDirectory=path.join(process.env['ProgramFiles(x86)']??'C:/Program Files (x86)','Steam')}={}){
 const candidates=[];for(let directory=path.resolve(install),i=0;i<6;i++){candidates.push(path.join(directory,'steamapps/workshop/content/704450'));const parent=path.dirname(directory);if(parent===directory)break;directory=parent;}
 try{const text=await fs.readFile(path.join(steamDirectory,'steamapps/libraryfolders.vdf'),'utf8');for(const m of text.matchAll(/"path"\s*"([^"]+)"/g))candidates.push(path.join(m[1].replaceAll('\\\\','\\'),'steamapps/workshop/content/704450'));}catch(error){if(error.code!=='ENOENT')throw error;}
 candidates.push(path.join(steamDirectory,'steamapps/workshop/content/704450'));for(const directory of [...new Set(candidates)]){try{if((await fs.stat(directory)).isDirectory())return path.resolve(directory);}catch(error){if(error.code!=='ENOENT')throw error;}}return'';
}

// Only metadata leaves this main-process store. The OS-protected key is never
// sent back to the renderer, placed in localStorage, or written as plaintext.
export class ClientSettings{
 #file;#encryption;#default;#state;#queue=Promise.resolve();
 constructor({directory,encryption,modsDirectory=''}){this.#file=path.join(directory,'client-settings.json');this.#encryption=encryption;this.#default=modsDirectory;}
 async #load(){if(this.#state)return this.#state;try{const s=JSON.parse(await fs.readFile(this.#file,'utf8'));if(![1,2].includes(s.version)||typeof s.modsDirectory!=='string'||s.modsDirectory.length>4096||s.modsDirectory.includes('\0')||s.modsDirectory&&!path.isAbsolute(s.modsDirectory)||s.disabledMods!==undefined&&(!Array.isArray(s.disabledMods)||s.disabledMods.length>10000||s.disabledMods.some(id=>typeof id!=='string'||!/^(?:local|[0-9]{1,32})$/.test(id)))||!protectedValue(s.protectedCdKey))throw Error();
  const profiles=s.loginProfiles??[];if(!Array.isArray(profiles)||profiles.length>64||profiles.some(p=>!p||!profileId(p.id)||!profileLabel(p.label)||!playerName(p.playerName)||!protectedValue(p.protectedCdKey))||new Set(profiles.map(p=>p.id)).size!==profiles.length||s.activeProfileId!=null&&!profiles.some(p=>p.id===s.activeProfileId))throw Error();this.#state={...s,loginProfiles:profiles,activeProfileId:s.activeProfileId??null};
 }catch(error){if(error.code!=='ENOENT')throw Error('Saved client settings could not be read');this.#state={version:2,modsDirectory:this.#default,loginProfiles:[],activeProfileId:null};}return this.#state;}
 async status(){await this.#queue;const s=await this.#load(),active=s.loginProfiles.find(p=>p.id===s.activeProfileId);return{modsDirectory:s.modsDirectory,defaultModsDirectory:this.#default,disabledMods:[...(s.disabledMods??[])],hasSavedCdKey:Boolean(active?active.protectedCdKey:s.protectedCdKey),hasLegacyCdKey:Boolean(s.protectedCdKey),protectedStorageAvailable:Boolean(this.#encryption.isEncryptionAvailable()),activeProfileId:s.activeProfileId,loginProfiles:s.loginProfiles.map(({id,label,playerName,protectedCdKey})=>({id,label,playerName,hasSavedCdKey:Boolean(protectedCdKey)}))};}
 #protect(value){const key=value.trim().toUpperCase();if(!/^[A-Z0-9]{5}(?:-[A-Z0-9]{5}){6}$/.test(key))throw Error('Enter a CD key with seven groups of five characters');if(!this.#encryption.isEncryptionAvailable())throw Error('Windows-protected key storage is unavailable');return this.#encryption.encryptString(key).toString('base64');}
 #change(change){const work=this.#queue.then(async()=>{const s=structuredClone(await this.#load());await change(s);s.version=2;
  await fs.mkdir(path.dirname(this.#file),{recursive:true});const temporary=this.#file+'.'+randomUUID()+'.tmp';try{await fs.writeFile(temporary,JSON.stringify(s)+'\n',{mode:0o600});await fs.rename(temporary,this.#file);}finally{await fs.rm(temporary,{force:true});}this.#state=s;
 });this.#queue=work.catch(()=>{});return work.then(()=>this.status());}
 update(request){return this.#change(async s=>{if(!request||typeof request!=='object'||Object.keys(request).some(k=>!['modsDirectory','disabledMods','cdKey','removeCdKey'].includes(k)))throw Error('Invalid client settings');
  if(request.modsDirectory!==undefined){const directory=request.modsDirectory;if(typeof directory!=='string'||directory.length>4096||directory.includes('\0')||directory&&!path.isAbsolute(directory))throw Error('Select a valid mods folder');if(directory&&!(await fs.stat(directory)).isDirectory())throw Error('Select a valid mods folder');const selected=directory?path.resolve(directory):'';if(selected!==s.modsDirectory)s.disabledMods=[];s.modsDirectory=selected;}
  if(request.disabledMods!==undefined){if(!Array.isArray(request.disabledMods)||request.disabledMods.length>10000||request.disabledMods.some(id=>typeof id!=='string'||!/^(?:local|[0-9]{1,32})$/.test(id)))throw Error('Invalid mod selection');s.disabledMods=[...new Set(request.disabledMods)];}
  if(request.removeCdKey!==undefined&&typeof request.removeCdKey!=='boolean')throw Error('Invalid key removal option');if(request.removeCdKey&&request.cdKey)throw Error('Choose key replacement or removal');
  if(request.cdKey!==undefined&&typeof request.cdKey!=='string')throw Error('Invalid CD-key format');const target=s.loginProfiles.find(p=>p.id===s.activeProfileId)??s;if(request.cdKey)target.protectedCdKey=this.#protect(request.cdKey);if(request.removeCdKey)delete target.protectedCdKey;
 });}
 saveProfile(request){return this.#change(s=>{if(!request||typeof request!=='object'||Array.isArray(request)||Object.keys(request).some(k=>!['id','label','playerName','cdKey'].includes(k))||!profileLabel(request.label)||!playerName(request.playerName)||request.cdKey!==undefined&&typeof request.cdKey!=='string')throw Error('Enter a profile name and player name (up to 32 characters)');
  if(request.id!==undefined&&!profileId(request.id))throw Error('This login profile no longer exists');
  let p;if(request.id){p=s.loginProfiles.find(p=>p.id===request.id);if(!p)throw Error('This login profile no longer exists');}else{if(s.loginProfiles.length>=64)throw Error('You can save up to 64 login profiles');p={id:randomUUID()};}
  if(request.cdKey)p.protectedCdKey=this.#protect(request.cdKey);
  else if(!p.protectedCdKey&&s.loginProfiles.length===0&&s.protectedCdKey)p.protectedCdKey=s.protectedCdKey;
  if(!p.protectedCdKey)throw Error('Enter a CD key for this login profile');
  if(s.loginProfiles.some(other=>other.id!==p.id&&other.label.toLocaleLowerCase()===request.label.trim().toLocaleLowerCase()))throw Error('Choose a unique profile name');
  p.label=request.label.trim();p.playerName=request.playerName.trim();if(!request.id)s.loginProfiles.push(p);s.activeProfileId=p.id;
 });}
 selectProfile(id){return this.#change(s=>{if(id!==null&&!s.loginProfiles.some(p=>p.id===id&&p.protectedCdKey))throw Error('Select a saved login profile with a CD key');s.activeProfileId=id;});}
 deleteProfile(id){return this.#change(s=>{if(!profileId(id)||!s.loginProfiles.some(p=>p.id===id))throw Error('This login profile no longer exists');s.loginProfiles=s.loginProfiles.filter(p=>p.id!==id);if(s.activeProfileId===id)s.activeProfileId=null;});}
 async cdKey(){await this.#queue;const s=await this.#load(),target=s.loginProfiles.find(p=>p.id===s.activeProfileId)??s;if(!target.protectedCdKey)throw Error('Save or enter a CD key before connecting');if(!this.#encryption.isEncryptionAvailable())throw Error('Windows-protected key storage is unavailable');try{return this.#encryption.decryptString(Buffer.from(target.protectedCdKey,'base64'));}catch{throw Error('The saved CD key could not be unlocked for this Windows user');}}
 toJSON(){return{kind:'client-settings'};}
}
const protectedValue=v=>v===undefined||typeof v==='string'&&v.length<=16384&&/^[A-Za-z0-9+/]*={0,2}$/.test(v);
const profileId=v=>typeof v==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(v);
const profileLabel=v=>typeof v==='string'&&v.trim().length>0&&v.length<=32&&!/[\x00-\x1f\x7f]/.test(v);
const playerName=profileLabel;
