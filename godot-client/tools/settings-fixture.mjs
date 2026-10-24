import fs from 'node:fs/promises';import path from 'node:path';import {createHash} from 'node:crypto';
import {ClientSettings} from '../../electron/client_settings.mjs';import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
const key=Array(7).fill('AAAAA').join('-');
function hak(name,text){const data=Buffer.from(text),b=Buffer.alloc(192+data.length);b.write('HAK V1.0');b.writeUInt32LE(1,16);b.writeUInt32LE(160,24);b.writeUInt32LE(184,28);b.write(name,160,16);b.writeUInt16LE(2017,180);b.writeUInt32LE(192,184);b.writeUInt32LE(data.length,188);b.set(data,192);return b;}
const digest=b=>createHash('sha256').update(b).digest('hex');
export async function settingsFixture({directory,encryption,profileFile}){
 const mods=path.join(directory,'mods'),other=path.join(directory,'alternate'),profile=path.join(directory,'profile'),install=path.join(directory,'install'),file=path.join(profile,'client-settings.json');
 for(const[root,id,name]of[[mods,'11','native_opts_one'],[mods,'22','native_opts_two'],[other,'33','native_opts_alt']]){const folder=path.join(root,id,'hak');await fs.mkdir(folder,{recursive:true});await fs.writeFile(path.join(folder,'Authored_'+id+'.hak'),hak(name,'2DA V2.0\n\nValue\n0 authored_'+id+'\n'));}
 const emptyKey=Buffer.alloc(64);emptyKey.write('KEY V1  ');emptyKey.writeUInt32LE(64,16);emptyKey.writeUInt32LE(64,20);await fs.mkdir(path.join(install,'data'),{recursive:true});await fs.writeFile(path.join(install,'data/nwn_base.key'),emptyKey);
 const store=new ClientSettings({directory:profile,encryption,modsDirectory:mods}),before=await fs.readFile(profileFile).catch(e=>{if(e.code!=='ENOENT')throw e;return null;}),evidence={windowsProtected:process.platform==='win32'&&encryption.isEncryptionAvailable(),saves:[],userProfileUnchanged:false,globalHakEnabled:false,disabledHakUnavailable:false};
 return{store,evidence,mods,other,async saved(flags){
  const fresh=new ClientSettings({directory:profile,encryption,modsDirectory:mods}),status=await fresh.status(),bytes=await fs.readFile(file),saved=JSON.parse(bytes),row={...flags,persistent:status.modsDirectory===(await store.status()).modsDirectory&&JSON.stringify(status.disabledMods)===JSON.stringify((await store.status()).disabledMods),containsNoPlaintext:!bytes.toString().includes(key),protected:Boolean(saved.protectedCdKey),roundTrip:false};
  if(status.hasSavedCdKey)row.roundTrip=await fresh.cdKey()===key;
  evidence.saves.push(row);
  if(status.modsDirectory===mods&&status.disabledMods.includes('22')){
   const context=await openServerResourceContext({install,modsDirectory:status.modsDirectory,disabledMods:status.disabledMods});
   evidence.globalHakEnabled=new TextDecoder().decode(await context.getResource('native_opts_one',2017)).includes('authored_11');
   try{await context.getResource('native_opts_two',2017);}catch(error){evidence.disabledHakUnavailable=error.code==='RESOURCE_NOT_FOUND';}
  }
 },async finish(){const after=await fs.readFile(profileFile).catch(e=>{if(e.code!=='ENOENT')throw e;return null;});evidence.userProfileUnchanged=before===null?after===null:after!==null&&digest(before)===digest(after);return evidence;}};
}
