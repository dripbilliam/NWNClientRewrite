import {isNetworkBytes} from './network_bytes.js';

// Original constructor2381c0 / FrameSend23d1e0: reflected CRC32 table,
// initial value0, no final xor, low16 stored in big-endian order.
const table=Uint32Array.from({length:256},(_,i)=>{let crc=i;for(let n=0;n<8;n++)crc=crc&1?(crc>>>1)^0xedb88320:crc>>>1;return crc>>>0;});
export function nativeFrameChecksum(bytes){let crc=0;for(let i=3;i<bytes.length;i++)crc=(crc>>>8)^table[(crc^bytes[i])&255];return crc&65535;}
export function frameNumberBetween(first,candidate,end){return(first<=candidate&&candidate<end)||(end<first&&(first<=candidate||candidate<end));}
const word=(value,label)=>{if(!Number.isInteger(value)||value<0||value>65535)throw new Error(`Invalid native frame ${label}`);return value;};
export function writeReliableFrame({kind=0,sequence=0,expected=0,compression=false,frame=null}){
 if(!Number.isInteger(kind)||kind<0||kind>2)throw new Error('Invalid native frame kind');
 word(sequence,'sequence');word(expected,'expected sequence');
 if(kind===0&&(!isNetworkBytes(frame)||frame.length<12||frame.length>65466))throw new Error('Invalid native data frame');
 const bytes=kind===0?Uint8Array.from(frame):new Uint8Array(12),view=new DataView(bytes.buffer);
 bytes[0]=77;view.setUint16(3,sequence,false);view.setUint16(5,(expected-1)&65535,false);
 bytes[7]=(bytes[7]&0x8f)|(kind<<4)|(compression?64:0);view.setUint16(1,nativeFrameChecksum(bytes),false);return bytes;
}
export function readReliableFrame(bytes){
 if(!isNetworkBytes(bytes)||bytes.length<12||bytes.length>65466||bytes[0]!==77)throw new Error('Invalid native reliable frame envelope');
 const view=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);
 if(view.getUint16(1,false)!==nativeFrameChecksum(bytes))throw new Error('Native reliable frame checksum mismatch');
 const kind=(bytes[7]>>>4)&3;if(kind===3)throw new Error('Unsupported native reliable frame kind');
 return{kind,sequence:view.getUint16(3,false),acknowledgement:view.getUint16(5,false),highPriority:Boolean(bytes[7]&8),compression:Boolean(bytes[7]&64),bytes:Uint8Array.from(bytes)};
}
