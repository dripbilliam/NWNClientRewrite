import {decodeGffText} from './gff_text.js';
const text=r=>{const s=r.readCExoString();return{text:s.bytes?decodeGffText(s.bytes):''};};
const localized=r=>r.readBool()?{gender:r.readByte(1),strRef:r.readDword()}:text(r);
export const NETWORK_SPEECH_CHANNELS=Object.freeze([1,2,3,4,5,6,7,8,9,10,11,12,14,15,17,18,19,20,22,30]);
export const networkSpeechHasRemoteName=channel=>channel>=0&&channel<31&&Boolean((0x401e4054>>>channel)&1);
export const networkSpeechIsSystem=channel=>channel===5||channel===15;
// Client77c140. Ordinary chat is source ID + string;8/9/10/15 substitute
// a DWORD strref. The native mask adds position and raw/localized speaker
// names for out-of-area sources.11/12 retain their separate one-liner layout.
export function readNetworkSpeech(r,minor){
 if(!NETWORK_SPEECH_CHANNELS.includes(minor))throw new Error('Unsupported native speech channel');
 if(minor===7)return{kind:'script-sound',objectId:r.readObjectIdClient(),sound:text(r).text};
 const out={kind:'server-speech',channel:minor};if(minor===5){out.text=text(r);return out;}
 out.objectId=r.readObjectIdClient();
 if(minor===11||minor===12){
  out.contextId=r.readObjectIdClient();out.text=localized(r);
  const b=r.readCResRef(),end=b.indexOf(0);out.sound=decodeGffText(end<0?b:b.subarray(0,end));out.soundFlag=r.readBool();out.soundObjectId=r.readObjectIdClient();return out;
 }
 out.text=[8,9,10,15].includes(minor)?{strRef:r.readDword()}:text(r);
 if(networkSpeechHasRemoteName(minor)){
  out.position=[r.readFloat(1,32),r.readFloat(1,32),r.readFloat(1,32)];
  out.speakerName=r.readBool()?{firstName:localized(r),lastName:localized(r)}:text(r);
 }
 return out;
}
