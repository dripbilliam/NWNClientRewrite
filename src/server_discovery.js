// NWN:EE89.8193.37-17: SendBNESDirectMessageToAddress1402507f0,
// HandleBNES1402419c0, HandleBNXI140244230 and HandleBNXR140244ad0.
// Discovery only. These datagrams do not authenticate or join a session.
import {decodeGffText} from './gff_text.js';
const encoder=new TextEncoder();
function portBytes(port){
 if(!Number.isInteger(port)||port<1||port>65535)throw new Error('Invalid server-query UDP port');
 return[port&255,port>>>8];
}
export function serverDiscoveryRequest(port,section=0){
 if(!Number.isInteger(section)||section<0||section>5)throw new Error('Invalid native discovery section');
 return Uint8Array.of(...encoder.encode('BNES'),...portBytes(port),section);
}
// The native server accepts a six-byte BNXI header. Its handler only reads
// the length; authenticated client identity belongs to the later login path.
export const serverInfoRequest=port=>Uint8Array.of(...encoder.encode('BNXI'),...portBytes(port));
// Public BNXR tail, distinct from the authenticated CNWMessage bitstream.
// HandleBNXRMessage140244ad0: extension 2, presence, URL, primary hash,
// then count * (flags, language, hash), all strings prefixed with a byte.
// Remaining bytes belong to other server-info extensions.
export function readServerInfoAdvertisement(bytes){
 if(!(bytes instanceof Uint8Array))throw new Error('Server advertisement bytes are unavailable');
 let at=0;const byte=()=>{if(at>=bytes.length)throw new Error('Truncated native server advertisement');return bytes[at++];};
 if(!bytes.length||byte()!==2)return null;
 if(!byte())return null;
 const string=()=>{const size=byte();if(at+size>bytes.length)throw new Error('Truncated native server advertisement');const value=decodeGffText(bytes.subarray(at,at+size));at+=size;return value;};
 const hash=()=>{const value=string().toLowerCase();if(!/^[0-9a-f]{40}$/.test(value))throw new Error('Invalid native server advertisement manifest hash');return value;};
 const url=string(),primary=hash(),count=byte(),manifests=[];
 for(let i=0;i<count;i++)manifests.push({flags:byte(),language:byte(),hash:hash()});
 return{url,hash:primary,manifests};
}
export function readServerQueryResponse(bytes){
 if(!(bytes instanceof Uint8Array))throw new Error('Server-query bytes are unavailable');
 const requireBytes=(offset,size)=>{if(offset+size>bytes.length)throw new Error('Truncated native server-query response');};
 requireBytes(0,4);const tag=String.fromCharCode(...bytes.subarray(0,4)),string=(offset,length)=>{requireBytes(offset,length);return bytes[offset]===0?'':decodeGffText(bytes.subarray(offset,offset+length));};
 if(tag==='BNER'){
  requireBytes(0,9);if(bytes[7]>5)throw new Error('Invalid native discovery response section');
  return{type:'discovery',protocolMarker:bytes[4],port:bytes[5]|bytes[6]<<8,section:bytes[7],serverName:string(9,bytes[8])};
 }
 if(tag==='BNXR'){
  requireBytes(0,20);if(bytes[6]!==0xfd)throw new Error('Unsupported native server-info version');
  const moduleName=string(20,bytes[19]),at=20+bytes[19];
  return{type:'info',port:bytes[4]|bytes[5]<<8,passwordRequired:bytes[7],minimumLevel:bytes[8],maximumLevel:bytes[9],playerCount:bytes[10],maximumPlayers:bytes[11],
   allowLocalVaultCharacters:bytes[12],pvpSetting:bytes[13],pauseAndPlay:bytes[14],onePartyOnly:bytes[15],enforceLegalCharacters:bytes[16],itemLevelRestrictions:bytes[17],reserved:bytes[18],moduleName,
   // Retain the advertisement for its own native decoder, rather than claim
   // that an unexamined NWSync/resource negotiation has been completed.
   advertisement:bytes.slice(at)};
 }
 throw new Error(`Unsupported native server-query response ${JSON.stringify(tag)}`);
}
