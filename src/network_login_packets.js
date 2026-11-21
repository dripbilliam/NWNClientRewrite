import {encodeGffText,decodeGffText} from './gff_text.js';
import {isNetworkBytes} from './network_bytes.js';

// Pinned EE89.8193.37-17 SendBNCS2502f0/SendBNVS250fd0 and
// HandleBNCR23edf0/HandleBNVR243180. Packet fields, not a complete login session.
class Writer{
 constructor(tag){this.bytes=[...tag].map(c=>c.charCodeAt(0));}
 byte(value){this.bytes.push(value&255);}
 word(value){this.byte(value);this.byte(value>>>8);}
 int(value){for(let i=0;i<4;i++)this.byte(value>>>(8*i));}
 string(value){if(typeof value!=='string')throw new Error('Native login string is unavailable');const bytes=encodeGffText(value);if(bytes.length>255)throw new Error('Native login string exceeds its wire length');this.byte(bytes.length);this.bytes.push(...bytes);}
 finish(){return Uint8Array.from(this.bytes);}
}
class Reader{
 constructor(bytes,tag){if(!isNetworkBytes(bytes))throw new Error('Native login packet bytes are unavailable');this.bytes=bytes;this.at=0;this.need(4);if(String.fromCharCode(...bytes.subarray(0,4))!==tag)throw new Error('Unexpected native login packet type');this.at=4;}
 need(size){if(this.at+size>this.bytes.length)throw new Error('Truncated native login packet');}
 byte(){this.need(1);return this.bytes[this.at++];}
 word(){return this.byte()|this.byte()<<8;}
 int(){this.need(4);const value=new DataView(this.bytes.buffer,this.bytes.byteOffset+this.at,4).getUint32(0,true);this.at+=4;return value;}
 string(){const length=this.byte();this.need(length);const bytes=this.bytes.subarray(this.at,this.at+length);this.at+=length;return bytes[0]===0?'':decodeGffText(bytes);}
}
const integer=(value,label)=>{if(!Number.isInteger(value))throw new Error(`Native login ${label} is unavailable`);return value;};
export function connectRequest({port,connectionType,build,language,applicationId,name,publicKey,legacyPublicKey,platformId,platformIdentifier}){
 const w=new Writer('BNCS');w.word(integer(port,'port'));w.byte(integer(connectionType,'connection type'));w.int(integer(build.number,'build'));
 w.word(3);w.byte(integer(language,'language'));w.int(integer(applicationId,'application ID'));
 w.string(name);w.string(publicKey);w.string(legacyPublicKey);w.byte(integer(platformId,'platform ID'));w.string(platformIdentifier);
 w.int(integer(build.revision,'revision'));w.string(build.commit);w.int(integer(build.postfix,'postfix'));return w.finish();
}
export function validationResponse({keyResponse,communityResponse,passwordResponse}){
 if([keyResponse,communityResponse,passwordResponse].some(v=>typeof v!=='string'))throw new Error('Native validation response fields are unavailable');
 const w=new Writer('BNVS');w.byte(passwordResponse.length?80:86);w.byte(Number(keyResponse.length!==0));
 if(keyResponse.length)w.string(keyResponse);w.string(communityResponse);if(passwordResponse.length)w.string(passwordResponse);return w.finish();
}
// SendBNDMMessage2505b0, invoked by DisconnectFromSession239f60. The lower
// packet policy deliberately sends this four-byte disconnect request raw.
export const disconnectRequest=()=>Uint8Array.from([66,78,68,77]);
// HandleBNDPMessage 1402408b0: optional TLK strref, then bounded uint16 text.
// Legacy short packets and invalid optional text are accepted by the native client.
export function readDisconnectResponse(bytes){
 const r=new Reader(bytes,'BNDP');let strRef=null,text='';
 if(bytes.length>=8)strRef=r.int();
 if(r.at+2<=bytes.length){const length=r.word();if(length<0x400&&r.at+length<=bytes.length)text=decodeGffText(bytes.subarray(r.at,r.at+length));}
 return{strRef,text};
}
export function readConnectResponse(bytes){
 const r=new Reader(bytes,'BNCR');r.need(4);const port=r.word(),status=String.fromCharCode(r.byte());
 if(status==='R'){
  const reason=r.byte(),known=[2,3,4,5,6,8,9,10,11,12,13,14,15,16,17,18,19];
  return{kind:'rejected',port,reason,connectionError:known.includes(reason)?reason:1};
 }
 if(status!=='P'&&status!=='V')throw new Error('Unsupported native connection response status');
 const passwordChallenge=status==='P'?r.string():'',keyChallenge=r.string(),communityChallenge=r.string();
 return{kind:'challenge',port,passwordRequired:status==='P',passwordChallenge,keyChallenge,communityChallenge,trailingBytes:bytes.length-r.at};
}
export function readValidationResponse(bytes){
 const r=new Reader(bytes,'BNVR');r.need(2);const status=String.fromCharCode(r.byte());
 if(status==='R')return{kind:'rejected',connectionError:r.byte()};
 if(status!=='A')throw new Error('Unsupported native validation response status');
 const applicationId=r.int();let number=0,revision=0,postfix=0;
 if(bytes.length>=17){number=r.int();revision=r.int();}if(bytes.length>=21)postfix=r.int();
 return{kind:'accepted',applicationId,build:{number,revision,postfix}};
}
