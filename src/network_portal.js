import {decodeGffText} from './gff_text.js';
import {MAX_NETWORK_CHARACTER_BYTES} from './network_character.js';
import {selectionReference} from './network_character_selection.js';

const text=r=>{const value=r.readCExoString();return value.bytes?decodeGffText(value.bytes):'';};
// EE89.8193.37-17 client1407aa6a0 / server1404cd0d0.
export function readPortalActivate(r){
 const address=text(r),password=text(r),waypoint=text(r),seamless=Boolean(r.readBool());
 const endpoint=portalEndpoint(address);
 if(password.includes('\0')||waypoint.includes('\0')||password.length>4096||waypoint.length>4096)throw Error('Invalid native portal fields');
 return{kind:'portal-activate',...endpoint,password,waypoint,seamless};
}
export function portalEndpoint(address){
 if(typeof address!=='string'||!address.length||address.length>261)throw Error('Invalid native portal address');
 const match=/^([A-Za-z0-9._-]+)(?::([0-9]{1,5}))?$/.exec(address),host=match?.[1],port=match?.[2]===undefined?5121:Number(match[2]);
 if(!host||host.length>255||!Number.isInteger(port)||port<1||port>65535)throw Error('Invalid native portal address');
 return{host,port};
}
// Portal controller140842910 requests a character download, not42/2.
export const portalCharacterRequest=()=>Uint8Array.of(112,43,1);
// Client14077b270:43/3 is a server-vault reference and account-vault BOOL;
//43/2 carries a complete local-vault character, using localized names.
export function readPortalCharacter(r,minor){
 if(minor===3){const resref=text(r),source=r.readBool()?17:2;selectionReference(resref);return{kind:'portal-character',resref,source};}
 const localized=()=>r.readBool()?{gender:r.readByte(1),strRef:r.readDword()}:{text:text(r)};
 const firstName=localized(),lastName=localized(),length=r.readDword();
 if(!length||length>MAX_NETWORK_CHARACTER_BYTES||length>r.byteSize40-r.byteCursor44)throw Error('Invalid native portal character size');
 const data=r.readOpaqueBytes(length);if(data===null)throw Error('Invalid native portal character storage');
 return{kind:'portal-character',firstName,lastName,data:Uint8Array.from(data)};
}
