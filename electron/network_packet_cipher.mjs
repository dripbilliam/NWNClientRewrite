import {isNetworkBytes} from '../src/network_bytes.js';

// CExoNetInternal::SendMessageA140176fa0: BN discovery/key exchange pass
// through; BN C/V login families and all other peer data use session encryption.
export function requiresSessionEncryption(bytes){
 if(!isNetworkBytes(bytes))throw new Error('Native packet bytes are unavailable');
 return bytes.length<4||bytes[0]!==66||bytes[1]!==78||bytes[2]===67||bytes[2]===86;
}
export class NetworkPacketCipher{
 constructor(crypto,identity){if(!Number.isInteger(identity)||identity<0||identity>0xffffffff)throw new Error('Invalid native cryptographic identity');this.crypto=crypto;this.identity=identity;}
 async encode(bytes){
  if(!requiresSessionEncryption(bytes))return Buffer.from(bytes);
  const encrypted=await this.crypto.seal(bytes),out=Buffer.alloc(encrypted.length+5);out[0]=73;out.writeUInt32LE(this.identity,1);out.set(encrypted,5);return out;
 }
 async decode(bytes){
  if(!isNetworkBytes(bytes)||bytes.length<41||bytes[0]!==73)throw new Error('Invalid native encrypted peer envelope');
  if(new DataView(bytes.buffer,bytes.byteOffset+1,4).getUint32(0,true)!==this.identity)throw new Error('Native encrypted peer identity mismatch');
  return this.crypto.open(bytes.subarray(5));
 }
}
