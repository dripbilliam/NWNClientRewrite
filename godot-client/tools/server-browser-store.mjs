import {browserFilters,defaultBrowserFilters} from './server-browser-filters.mjs';
import fs from 'node:fs/promises';import path from 'node:path';import crypto from 'node:crypto';import {serverEndpoint,serverKey} from './server-endpoint.mjs';
const string=(v,max)=>typeof v==='string'?v.slice(0,max):'';
export function browserRow(value){
 const result={...serverEndpoint(value),serverName:string(value.serverName,256),moduleName:string(value.moduleName,256),description:string(value.description,65535)};
 if(typeof value.serverVersion==='string')result.serverVersion=string(value.serverVersion,256);
 if(Number.isInteger(value.gameType)&&value.gameType>=-1&&value.gameType<=32767)result.gameType=value.gameType;
 for(const key of ['playerCount','maximumPlayers','minimumLevel','maximumLevel','pvpSetting','latency'])if(Number.isFinite(value[key])&&(key==='latency'||Number.isInteger(value[key]))&&value[key]>=0&&value[key]<=65535)result[key]=value[key];
 for(const key of ['passwordRequired','allowLocalVaultCharacters','pauseAndPlay','onePartyOnly','enforceLegalCharacters','itemLevelRestrictions','extendedReceived','syncAvailable'])if([true,false,0,1].includes(value[key]))result[key]=Boolean(value[key]);
 if(value.sync!==undefined||value.advertisement)result.sync=Boolean(value.sync??value.advertisement?.hash);return result;
}
const unique=values=>{const seen=new Set();return values.flatMap(v=>{try{const row=browserRow(v),key=serverKey(row);if(seen.has(key))return[];seen.add(key);return[row];}catch{return[];}}).slice(0,100);};
const initial=()=>({version:1,history:[],favorites:[],browserFilters:defaultBrowserFilters(),profileDefault:'',last:{host:'127.0.0.1',port:5121,name:'GodotLocalTest'}});
export class ServerBrowserStore{
 constructor(file,{importLegacy=async()=>({})}={}){this.file=file;this.importLegacy=importLegacy;this.queue=Promise.resolve();}
 async load(){if(!this.loading)this.loading=(async()=>{let raw;try{raw=JSON.parse(await fs.readFile(this.file,'utf8'));if(raw.version!==1||!Array.isArray(raw.history)||!Array.isArray(raw.favorites))throw Error('Saved server browser data is invalid');}catch(e){if(e.code!=='ENOENT')throw e;const legacy=await this.importLegacy();raw={...initial(),history:legacy.history??[],favorites:legacy.favorites??[]};}const name=string(raw.last?.name,64).trim()||'GodotLocalTest';this.state={version:1,history:unique(raw.history),favorites:unique(raw.favorites),browserFilters:raw.browserFilters===undefined?defaultBrowserFilters():browserFilters(raw.browserFilters),last:{...serverEndpoint(raw.last??initial().last),name},profileDefault:typeof raw.profileDefault==='string'?string(raw.profileDefault,32):name};})();await this.loading;return structuredClone(this.state);}
 update(change){const work=this.queue.then(async()=>{const before=await this.load(),next=change(before);await fs.mkdir(path.dirname(this.file),{recursive:true});const temporary=this.file+'.'+crypto.randomUUID()+'.tmp';try{const out=await fs.open(temporary,'wx');try{await out.writeFile(JSON.stringify(next)+'\n');await out.sync();}finally{await out.close();}await fs.rename(temporary,this.file);}catch(e){await fs.unlink(temporary).catch(()=>{});throw e;}this.state=next;return structuredClone(next);});this.queue=work.catch(()=>{});return work;}
 favorite(row,on){const value=browserRow(row),key=serverKey(value);return this.update(s=>({...s,favorites:on?[value,...s.favorites.filter(r=>serverKey(r)!==key)].slice(0,100):s.favorites.filter(r=>serverKey(r)!==key)}));}
 remember(row,name){const value=browserRow(row),key=serverKey(value);return this.update(s=>({...s,last:{...serverEndpoint(value),name:string(name,64)},history:[value,...s.history.filter(r=>serverKey(r)!==key)].slice(0,100)}));}
 profile(name){if(typeof name!=='string'||!name||name.length>32||/[\x00-\x1f]/.test(name))throw Error('Invalid default player name');return this.update(s=>({...s,profileDefault:name}));}
 filters(values){const value=browserFilters(values);return this.update(s=>({...s,browserFilters:value}));}
 async settled(){await this.queue;}
}
