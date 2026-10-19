import {OBJECT_INVALID,EXTERNAL_OBJECT} from './game_object_array.js';
const f=Math.fround;
const width=(n,min=0)=>{if(!Number.isInteger(n)||n<min||n>64)throw new Error('Native message bit width is unavailable');return n;};
const unsigned64=value=>BigInt.asUintN(64,BigInt(value));
const cvtt64=value=>Number.isFinite(value)&&value>=-(2**63)&&value<2**63?BigInt(Math.trunc(value)):-(1n<<63n);
const allocation=size=>{
 if(!Number.isInteger(size)||size<0||size>64*1024*1024)throw new Error('Native message allocation is unsupported');
 return{bytes:new Uint8Array(size),defined:new Uint8Array(size)};
};

// CNWMessage ctor1402d4830, CreateWriteMessage1402d54a0, scalar writers
// and GetWriteMessage1402d5880. Bytes and residual bits are separate streams.
// Default allocation's unread bytes are unknown, not native zero-filled memory.
// An explicit allocator lets read-only native fixtures supply known heap bytes.
export class NativeMessageWriter{
 constructor(formatMode28,{allocate=allocation}={}){
  if(!Number.isInteger(formatMode28))throw new Error('Native message format mode is unavailable');
  this.formatMode28=formatMode28|0;this.allocate=allocate;
  this.byteStorage=this.memory(128);this.bitStorage=this.memory(128);
  this.byteLength14=0;this.bitLength24=0;this.total28=4;this.bitOffset2c=0;this.writing30=0;
 }
 memory(size){
  const value=this.allocate(size);
  if(!(value?.bytes instanceof Uint8Array)||!(value?.defined instanceof Uint8Array)||value.bytes.length!==size||value.defined.length!==size)throw new Error('Native message allocation result is unavailable');
  return value;
 }
 grow(which,size,count){
  const key=which==='byte'?'byteStorage':'bitStorage',old=this[key],next=this.memory(size);
  next.bytes.set(old.bytes.subarray(0,count));next.defined.set(old.defined.subarray(0,count));this[key]=next;
 }
 extendByte(extra){this.grow('byte',this.byteStorage.bytes.length+extra+128,this.byteLength14);}
 extendBit(extra){this.grow('bit',this.bitStorage.bytes.length+extra+128,this.bitLength24+Number(this.bitOffset2c>0));}
 create(size,playerId,flag){
  const required=((size>>>0)+7)>>>0;
  this.flag60=flag|0;this.playerId64=playerId>>>0;this.writing30=1;
  this.byteLength14=7;this.bitOffset2c=0;this.bitLength24=0;this.total28=7;
  if(this.byteStorage.bytes.length<required)this.grow('byte',(required+128)|0,7);
  if(this.formatMode28===0)this.writeByte(3,8,0);
  this.writeUnsigned(0n,3);
 }
 // The three envelope bytes belong to the separate native send owner.
 // No game object ID is substituted for a transport PLAYER_ID/header here.
 setPrefix(bytes){
  if(!(bytes instanceof Uint8Array)||bytes.length!==3)throw new Error('Native message envelope prefix is unavailable');
  this.byteStorage.bytes.set(bytes);this.byteStorage.defined.fill(255,0,3);
 }
 raw(value,count){
  if(this.byteLength14+count>this.byteStorage.bytes.length)this.extendByte(count);
  value=unsigned64(value);
  for(let n=0;n<count;n++){this.byteStorage.bytes[this.byteLength14+n]=Number(value>>BigInt(n*8)&255n);this.byteStorage.defined[this.byteLength14+n]=255;}
  this.byteLength14+=count;this.total28+=count;
 }
 writeType(type){if(this.formatMode28===0)this.raw(type&255,1);}
 residual(value,bits){
  // WriteBit1402daaa0; its callers ensure capacity before this leaf owner.
  if(this.formatMode28===0)this.writeByte(1,8,0);
  value=unsigned64(value);
  for(let n=bits-1;n>=0;n--){
   const mask=1<<(7-this.bitOffset2c),index=this.bitLength24;
   if(index>=this.bitStorage.bytes.length)throw new Error('Native residual-bit capacity is unavailable');
   this.bitStorage.bytes[index]=(this.bitStorage.bytes[index]&~mask)|(Number(value>>BigInt(n)&1n)?mask:0);this.bitStorage.defined[index]|=mask;
   if(++this.bitOffset2c===8){this.bitLength24++;this.bitOffset2c=0;}
  }
 }
 writeUnsigned(value,bits){
  width(bits);value=unsigned64(value);const chunks=bits>>3;
  if((bits%8)+this.bitOffset2c>=8&&this.bitLength24+1>=this.bitStorage.bytes.length)this.extendBit(1);
  if(this.byteLength14+chunks>this.byteStorage.bytes.length)this.extendByte(chunks);
  if(bits===64){this.writeType(9);this.raw(value,8);return;}
  let left=bits;
  while(left>=32){left-=32;this.writeDword(Number(value>>BigInt(left)&0xffffffffn),32);}
  while(left>=16){left-=16;this.writeWord(Number(value>>BigInt(left)&65535n),16);}
  while(left>=8){left-=8;this.writeByte(Number(value>>BigInt(left)&255n),8,1);}
  if(left>0)this.residual(value&((1n<<BigInt(left))-1n),left);
 }
 writeSigned(value,bits){
  width(bits,1);value=BigInt.asIntN(64,BigInt(value));
  if(this.bitOffset2c+1>=8&&this.bitLength24+1>=this.bitStorage.bytes.length)this.extendBit(1);
  this.residual(value<0?1n:0n,1);this.writeUnsigned(value<0?-value:value,bits-1);
 }
 writeBool(value){this.writeType(2);this.writeUnsigned(BigInt(value|0),1);}
 writeByte(value,bits=8,tag=1){
  width(bits);value&=255;if(tag!==0&&this.formatMode28===0)this.writeByte(3,8,0);
  if(bits===8)this.raw(value,1);else this.writeUnsigned(BigInt(value),bits);
 }
 writeWord(value,bits=16){
  width(bits);value&=65535;this.writeType(5);if(bits===16)this.raw(value,2);else this.writeUnsigned(BigInt(value),bits);
 }
 writeDword(value,bits=32){
  width(bits);value>>>=0;this.writeType(7);if(bits===32)this.raw(value,4);else this.writeUnsigned(BigInt(value),bits);
 }
 writeInt(value,bits=32){
  width(bits,1);value|=0;this.writeType(8);if(bits===32)this.raw(value,4);else this.writeSigned(BigInt(value),bits);
 }
 writeFloat(value,scale=1,bits=32){
  width(bits);value=f(value);scale=f(scale);this.writeType(11);
  if(scale===1&&bits===32){const bytes=new DataView(new ArrayBuffer(4));bytes.setFloat32(0,value,true);this.raw(bytes.getUint32(0,true),4);}
  else this.writeUnsigned(BigInt.asUintN(32,cvtt64(f(value*scale))),bits);
 }
 rawBytes(bytes,count=bytes?.length??0){
  if(!Number.isInteger(count)||count<0||count>64*1024*1024||count>0&&(!(bytes instanceof Uint8Array)||bytes.length<count))throw new Error('Native message source byte storage is unavailable');
  if(this.byteLength14+count>this.byteStorage.bytes.length)this.extendByte(count);
  if(count)this.byteStorage.bytes.set(bytes.subarray(0,count),this.byteLength14);
  this.byteStorage.defined.fill(255,this.byteLength14,this.byteLength14+count);this.byteLength14+=count;this.total28+=count;
 }
 // Original WriteCExoString consumes its by-value owning temporary, including
 // clearing pointer/length/capacity after copying its stored byte length.
 writeCExoString(owned,bits=32){
  width(bits,1);const length=owned.length|0;
  if(!Number.isInteger(owned.length)||length<0||length>64*1024*1024||length>0&&(!(owned.bytes instanceof Uint8Array)||owned.bytes.length<length))throw new Error('Native owning message string is unavailable');
  this.writeType(14);this.writeType(8);
  if(bits===32)this.raw(length,4);else this.writeSigned(BigInt(length),bits);
  this.rawBytes(owned.bytes,length);owned.bytes=null;owned.length=0;owned.capacity=0;
 }
 writeStringBytes(bytes,bits=32){
  if(!(bytes instanceof Uint8Array))throw new Error('Native message string bytes are unavailable');
  this.writeCExoString({bytes,length:bytes.length},bits);
 }
 writeCResRef(bytes,count=16){this.writeType(13);this.rawBytes(bytes,count);}
 writeObjectIdServer(id){id>>>=0;this.raw(id===OBJECT_INVALID?id:(id|EXTERNAL_OBJECT)>>>0,4);}
 // Client helper1409737f0 copies the client ID unchanged. The receiving
 // ReadOBJECTIDServer clears bit31; it is not a locally allocated server ID.
 writeObjectIdClient(id){this.raw(id>>>0,4);}
 getWriteMessage(){
  this.writing30=0;new DataView(this.byteStorage.bytes.buffer,this.byteStorage.bytes.byteOffset).setUint32(3,this.total28,true);this.byteStorage.defined.fill(255,3,7);
  const bitCount=this.bitLength24+Number(this.bitOffset2c>0),length=this.byteLength14+bitCount;
  if(this.byteStorage.bytes.length<length)this.grow('byte',length+128,this.byteLength14);
  this.bitStorage.bytes[0]=(this.bitStorage.bytes[0]&31)|(this.bitOffset2c<<5);this.bitStorage.defined[0]|=224;
  this.byteStorage.bytes.set(this.bitStorage.bytes.subarray(0,bitCount),this.byteLength14);this.byteStorage.defined.set(this.bitStorage.defined.subarray(0,bitCount),this.byteLength14);
  const status=Number(!(this.byteLength14===7&&this.bitOffset2c===3));
  return{status,length,data:status?this.byteStorage.bytes.subarray(0,length):null,defined:status?this.byteStorage.defined.subarray(0,length):null,
   prefixPending:!this.byteStorage.defined.subarray(0,3).every(mask=>mask===255)};
 }
}

// SetReadMessage receives the packet after its three-byte transport envelope.
// Physical storage and declared size are separate: the native residual-bit
// reader permits one byte beyond the declared fragment size. Unknown physical
// bytes are diagnosed and rejected instead of synthesizing heap contents.
export class NativeMessageReader{
 constructor(formatMode28,{diagnose=()=>{}}={}){
  if(!Number.isInteger(formatMode28))throw new Error('Native message format mode is unavailable');
  this.formatMode28=formatMode28|0;this.diagnose=diagnose;
  this.bytes38=null;this.byteSize40=0;this.byteCursor44=0;this.fragments48=null;
  this.fragmentSize50=0;this.fragmentCursor54=0;this.fragmentOffset58=0;this.curReadBit5c=0;this.lastByteBits5d=0;
 }
 unknown(index,storage){
  this.diagnose({kind:'unknownPhysicalByte',index,storage});throw new Error('Native message physical read byte is unavailable');
 }
 physical(bytes,index,storage){return bytes&&index<bytes.length?bytes[index]:this.unknown(index,storage);}
 setReadMessage(bytes,length,playerId,flag){
  if(bytes!==null&&!(bytes instanceof Uint8Array))throw new Error('Native message input storage is unavailable');
  this.bytes38=bytes;this.byteCursor44=0;this.fragmentSize50=0;this.fragmentCursor54=0;
  this.flag60=flag|0;this.byteSize40=length>>>0;this.playerId64=playerId>>>0;
  if(this.byteSize40===0){this.curReadBit5c=this.lastByteBits5d;return 1;}
  this.byteCursor44=4;
  let boundary=0;for(let i=0;i<4;i++)boundary|=this.physical(bytes,i,'bytes')<<(8*i);
  this.fragmentOffset58=(boundary-3)>>>0;
  if(this.fragmentOffset58>=this.byteSize40){this.diagnose({kind:'fragmentOffset'});return 0;}
  this.byteSize40=this.fragmentOffset58;this.fragments48=bytes?.subarray(this.fragmentOffset58)??null;
  this.fragmentSize50=((length>>>0)-this.fragmentOffset58)>>>0;this.curReadBit5c=0;
  this.expectType(3);this.lastByteBits5d=Number(this.readUnsigned(3))&255;return 1;
 }
 raw(count){
  const cursor=this.byteCursor44;this.byteCursor44=(cursor+count)>>>0;
  if(cursor+count>this.byteSize40)return 0n;
  let value=0n;for(let i=0;i<count;i++)value|=BigInt(this.physical(this.bytes38,cursor+i,'bytes'))<<BigInt(8*i);
  return value;
 }
 expectType(expected){
  if(this.formatMode28!==0)return;
  const actual=Number(this.raw(1));if(actual!==(expected|0))this.diagnose({kind:'typeMismatch',expected:expected|0,actual});
 }
 readBit(bit){
  if(this.fragments48===null){this.fragmentCursor54=1;this.fragmentSize50=0;return 0;}
  if(this.fragmentCursor54>this.fragmentSize50)return 0;
  return this.physical(this.fragments48,this.fragmentCursor54,'fragments')>>((7-(bit&255))&31)&1;
 }
 readBits(bits){
  width(bits);this.expectType(1);let result=0n;
  for(let i=0;i<bits;i++){
   let value=0;
   if(this.fragments48===null){this.fragmentCursor54=1;this.fragmentSize50=0;}
   else if(this.fragmentCursor54<=this.fragmentSize50)value=this.readBit(this.curReadBit5c);
   result=unsigned64(result*2n+BigInt(value));this.curReadBit5c=(this.curReadBit5c+1)&255;
   if(this.curReadBit5c===8){this.curReadBit5c=0;this.fragmentCursor54=(this.fragmentCursor54+1)>>>0;}
  }
  return result;
 }
 readUnsigned(bits){
  width(bits);
  if(bits===64){
   if(this.byteCursor44+8>this.byteSize40)return this.raw(8);
   this.expectType(9);return this.raw(8);
  }
  let result=0n,left=bits;
  for(const [size,type]of [[4,7],[2,5],[1,3]]){
   while(left>=size*8){
    if(this.byteCursor44+size>this.byteSize40){this.byteCursor44=(this.byteCursor44+size)>>>0;return 0n;}
    this.expectType(type);result=unsigned64(result<<BigInt(size*8)|this.raw(size));left-=size*8;
   }
  }
  if(left>0){
   const candidate=(this.fragmentCursor54+(((this.curReadBit5c-1+left)>>3)&255))>>>0;
   if(candidate>this.fragmentSize50){this.fragmentCursor54=candidate;return 0n;}
   result=unsigned64(result<<BigInt(left)|this.readBits(left));
  }
  return result;
 }
 readSigned(bits){
  width(bits,1);if(this.fragmentCursor54>this.fragmentSize50)return 0n;
  const sign=this.readBits(1),magnitude=this.readUnsigned(bits-1);
  return BigInt.asIntN(64,sign?(magnitude===0n?1n<<63n:-magnitude):magnitude);
 }
 readBool(){this.expectType(2);return Number(this.readUnsigned(1))&255;}
 // ReadCHAR2d98d0/ReadSHORT2da110 use a distinct type tag and map signed
 // negative-zero to the destination type's minimum value for reduced widths.
 readChar(bits=8){width(bits,1);this.expectType(4);const n=bits===8?this.raw(1):this.readSigned(bits);return Number(BigInt.asIntN(8,n===-(1n<<63n)?-128n:n));}
 readShort(bits=16){width(bits,1);this.expectType(6);const n=bits===16?this.raw(2):this.readSigned(bits);return Number(BigInt.asIntN(16,n===-(1n<<63n)?-32768n:n));}
 readByte(bits=8,tag=1){width(bits);if(tag!==0)this.expectType(3);return Number(BigInt.asUintN(8,bits>=8?this.raw(1):this.readUnsigned(bits)));}
 readWord(bits=16){width(bits);this.expectType(5);return Number(BigInt.asUintN(16,bits===16?this.raw(2):this.readUnsigned(bits)));}
 readDword(bits=32){width(bits);this.expectType(7);return Number(BigInt.asUintN(32,bits===32?this.raw(4):this.readUnsigned(bits)));}
 readDword64(bits=64){width(bits);this.expectType(9);return bits===64?this.raw(8):BigInt.asUintN(32,this.readUnsigned(bits));}
 readInt(bits=32){width(bits,1);this.expectType(8);return Number(BigInt.asIntN(32,bits===32?this.raw(4):this.readSigned(bits)));}
 rawFloat(){const value=new DataView(new ArrayBuffer(4));value.setUint32(0,Number(this.raw(4)),true);return value.getFloat32(0,true);}
 readFloat(scale=1,bits=32){
  width(bits);scale=f(scale);this.expectType(11);
  if(scale===1&&bits===32)return this.rawFloat();
  return f(Number(BigInt.asUintN(32,this.readUnsigned(bits)))/scale);
 }
 readFloatRange(min,max,bits){
  width(bits);min=f(min);max=f(max);this.expectType(11);if(bits===32)return this.rawFloat();
  const value=Number(BigInt.asIntN(64,this.readUnsigned(bits))),denominator=((1<<(bits&31))-1)|0;
  return f(value*f(f(max-min)/f(denominator))+min);
 }
 readCExoString(bits=32){
  width(bits,1);this.expectType(14);this.expectType(8);
  const length=Number(BigInt.asUintN(32,bits===32?this.raw(4):this.readSigned(bits))),cursor=this.byteCursor44,end=(cursor+length)>>>0;
  this.byteCursor44=end;
  if(end>this.byteSize40||length===0)return{bytes:null,length:0,capacity:0};
  // CExoString(ptr,length) normalizes a leading NUL to empty, while retaining
  // subsequent embedded NUL bytes and the supplied length otherwise.
  if(this.physical(this.bytes38,cursor,'bytes')===0)return{bytes:null,length:0,capacity:0};
  if(length>64*1024*1024){this.diagnose({kind:'unsupportedStringLength',length});throw new Error('Native message string allocation is unavailable');}
  const bytes=new Uint8Array(length);for(let i=0;i<length;i++)bytes[i]=this.physical(this.bytes38,cursor+i,'bytes');
  return{bytes,length,capacity:length+1};
 }
 readCResRef(count=16,{nativeTail=null}={}){
  if(!Number.isInteger(count)||count<0)throw new Error('Native resource reference width is unavailable');
  this.expectType(13);count=Math.min(count,16);
  const cursor=this.byteCursor44,end=(cursor+count)>>>0,bytes=new Uint8Array(17);this.byteCursor44=end;
  if(end>this.byteSize40)return bytes;
  for(let i=0;i<16;i++){
   let value;
   if(i<count)value=this.physical(this.bytes38,cursor+i,'bytes');
   else if(nativeTail instanceof Uint8Array&&i-count<nativeTail.length)value=nativeTail[i-count];
   else{this.diagnose({kind:'unknownResRefStackByte',index:i});throw new Error('Native resource reference stack byte is unavailable');}
   if(value===0)break;bytes[i]=value;
  }
  return bytes;
 }
 readObjectIdServer(){return Number(this.raw(4))&0x7fffffff;}
 // ReadOBJECTIDClient1409737c0 preserves the wire namespace bit. Client
 // proxies use these IDs; server/local canonical lookup is a separate owner.
 readObjectIdClient(){return Number(this.raw(4))>>>0;}
 messageReadOverflow(){
  if(this.byteCursor44>this.byteSize40||this.fragmentCursor54>this.fragmentSize50){this.diagnose({kind:'overflow'});return 1;}return 0;
 }
 messageReadUnderflow(){
  const remaining=(this.fragmentSize50-this.fragmentCursor54)>>>0;
  if(this.byteCursor44<this.byteSize40||remaining>1||(remaining===1&&this.curReadBit5c<this.lastByteBits5d)){this.diagnose({kind:'underflow'});return 1;}return 0;
 }
}

// CNWSMessage140442e10 invokes the base constructor then sets role68=1.
export class NativeServerMessage extends NativeMessageWriter{
 constructor(...args){super(...args);this.role68=1;}
}

// SendServerToPlayerMessage1404dc490..1404dcb46, with profiling disabled.
// Name/log/net-layer/transport and allocation are explicit lower owners. The
// caller must supply a transport PLAYER_ID; a game OBJECT_ID is not equivalent.
export async function sendServerToPlayerMessage(message,playerId,major,minor,data,length,p){
 if(!Number.isInteger(message.role68))throw new Error('Native message sender role is unavailable');
 playerId>>>=0;major&=255;minor&=255;length>>>=0;
 const name=await p.messageName(major,minor);
 await p.log({role:(message.role68|0)===0?'Client':'Server',playerId,name,length});
 const temporary=length===0;
 if(temporary){data=await p.allocate(3);message.playerId64=0xffffffff;}
 const sendLength=temporary?3:length;
 if(data===null)return 0;
 if(!(data instanceof Uint8Array)||data.length<3||data.length<sendLength)throw new Error('Native outgoing message physical storage is unavailable');
 data.set([80,major,minor]);
 if(message instanceof NativeMessageWriter&&data.buffer===message.byteStorage.bytes.buffer&&data.byteOffset===message.byteStorage.bytes.byteOffset)message.byteStorage.defined.fill(255,0,3);
 const server=await p.server(),netLayer=await p.netLayer(server),result=await p.send(netLayer,playerId,data,sendLength,0);
 if(temporary)await p.free(data);
 return result|0;
}

// Shared scalar owners for decoded send coordinators such as ClientArea. Full
// area packing and actual transport remain required, independently supplied.
export function nativeMessageProviders(sendOwners){
 return{
  create:(message,...args)=>message.create(...args),writeInt:(message,...args)=>message.writeInt(...args),
  writeFloat:(message,...args)=>message.writeFloat(...args),writeBool:(message,...args)=>message.writeBool(...args),
  payload:message=>message.getWriteMessage(),send:(...args)=>sendServerToPlayerMessage(...args,sendOwners),
 };
}
