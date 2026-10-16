import {encodeGffText} from './gff_text.js';

// Western GFF decoding is bijective over all256 byte values; re-encoding the
// parsed entry preserves its byte length, embedded zeros and extended bytes.
export function localizedMessageValue(value){
 if(!value||!Number.isInteger(value.strRef)||!Array.isArray(value.entries))throw new Error('Native localized message value is unavailable');
 const entries=[];
 for(const e of value.entries){
  if(!Number.isInteger(e.languageId)||typeof e.text!=='string')throw new Error('Native localized message entry is unavailable');
  // GFF read loop1401a1080..1401a10aa splits the raw key with signed INT
  // division/remainder; SetString1401696e0 normalizes language0/gender and
  // replaces duplicates in place through140169ee0 (new entries append).
  const raw=e.languageId|0,language=Math.trunc(raw/2),gender=(raw%2)&255,key=(language*2+(language===0?0:gender))>>>0;
  const bytes=copyString(encodeGffText(e.text)),prior=entries.find(e=>e.key===key);
  if(prior)prior.bytes=bytes;else entries.push({key,bytes});
 }
 return{strRef:value.strRef>>>0,entries};
}

// CNWSArea ctor14035a068/14035a470..47e and LoadAreaHeader14035ffe0..
// 14036002a. Preserve the localized object instead of the display-label flatten.
export function initializeAreaMessageName(area,are){
 area.nativeName188=localizedMessageValue(are.Name??{strRef:0xffffffff,entries:[]});
 area.nativeCustomName358=null;area.nativeCustomNameLength360=0;
}

// GetPlayerLanguage140560e20 uses first matching transport client, otherwise0.
export function playerMessageLanguage(clients,playerId){
 for(const client of clients){
  if(!Number.isInteger(client.nativePlayerId48))throw new Error('Native language client PLAYER_ID is unavailable');
  if((client.nativePlayerId48>>>0)===(playerId>>>0)){
   if(!Number.isInteger(client.nativeLanguage4c))throw new Error('Native client language is unavailable');
   return client.nativeLanguage4c|0;
  }
 }
 return 0;
}
// GetModuleLanguage140560bc0 is a constant-zero owner in this target build.
export const serverMessageLanguage=()=>0;
const copyString=bytes=>{
 if(!(bytes instanceof Uint8Array))throw new Error('Native localized entry bytes are unavailable');
 return bytes.length===0||bytes[0]===0?new Uint8Array():bytes.slice();
};

// ReadCExoLocStringClient1409735f0..1409737b4. TLK lookup and its shared
// gender state remain supplied owners. Optional outputs mirror the native
// ResRef and FLOAT pointers; defaults are written before reading the BOOL.
export async function readLocalizedClient(message,p,{soundRef=null,duration=null}={}){
 if(soundRef)soundRef.value=new Uint8Array(17);
 if(duration)duration.value=0;
 if(message.readBool()===0)return message.readCExoString(32);
 const gender=message.readByte(1,1),strRef=message.readDword(32);
 await p.setGender(gender);const entry=await p.talkString(strRef);
 if(!Number.isInteger(entry?.status))throw new Error('Native client talk-table lookup status is unavailable');
 if(entry.status===0){await p.warning('strRef');return{bytes:null,length:0,capacity:0};}
 if(soundRef){
  if(!(entry.soundRef instanceof Uint8Array)||entry.soundRef.length<17)throw new Error('Native client talk-table sound reference is unavailable');
  soundRef.value=entry.soundRef.slice(0,17);
 }
 if(duration){if(typeof entry.duration!=='number')throw new Error('Native client talk-table duration is unavailable');duration.value=Math.fround(entry.duration);}
 const bytes=copyString(entry.bytes);
 return bytes.length?{bytes,length:bytes.length,capacity:bytes.length+1}:{bytes:null,length:0,capacity:0};
}

// WriteCExoLocStringServer140476160..1404763dd. Native linked-list order and
// language/gender fallback are preserved; embedded entries take precedence
// over StrRef, even when the selected entry is empty. No TLK lookup here.
export async function writeLocalizedServer(message,value,gender,p){
 gender&=255;const server=await p.server();
 if(!server){await p.warning('client');return;}
 const languages=[];
 for(const language of [await p.playerLanguage(server,message.playerId64),0,await p.serverLanguage(await p.server())]){
  if(!Number.isInteger(language))throw new Error('Native message fallback language is unavailable');
  const key=language|0;if(!languages.includes(key))languages.push(key);
 }
 if(!value||!Number.isInteger(value.strRef)||!Array.isArray(value.entries))throw new Error('Native localized message state is unavailable');
 let selected=null;
 outer:for(const language of languages)for(const sex of [gender,Number(gender===0)]){
  // English language0 deliberately ignores gender in GetString140169b60.
  const key=(language*2+(language===0?0:sex))>>>0;
  const entry=value.entries.find(e=>(e.key>>>0)===key);
  if(entry){selected=copyString(entry.bytes);break outer;}
 }
 if(selected===null&&value.entries.length>0)selected=copyString(value.entries[0].bytes);
 if(selected===null&&(value.strRef>>>0)!==0xffffffff){
  if(message.byteLength14+9>message.byteStorage.bytes.length)message.extendByte(9);
  message.writeBool(1);message.writeByte(gender,1,1);message.writeDword(value.strRef,32);return;
 }
 const hadEntry=selected!==null;selected??=new Uint8Array();
 // The chosen/fallback string branches reserve storedLength+4 before BOOL.
 const extra=selected.length+(hadEntry?4:0);
 if(message.byteLength14+extra>message.byteStorage.bytes.length)message.extendByte(extra);
 message.writeBool(0);message.writeStringBytes(selected,32);
}
