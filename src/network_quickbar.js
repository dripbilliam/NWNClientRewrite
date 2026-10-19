import {OBJECT_INVALID} from './game_object_array.js';
import {decodeGffText,encodeGffText} from './gff_text.js';
import {readNetworkItem} from './network_object_updates.js';
import {NativeMessageWriter} from './native_message.js';
const noParams=new Set([0,6,7,19,20,21,22,23,24,25,35,36,38,40,41]),ints=new Set([3,4,8,10,27,28,31,32,33,34,37,42,43,45,46,47,48]);
const text=r=>{const v=r.readCExoString();return v.bytes?decodeGffText(v.bytes):'';},ref=r=>{const b=r.readCResRef();return decodeGffText(b.subarray(0,b.indexOf(0)<0?b.length:b.indexOf(0)));};
const index=v=>{if(!Number.isInteger(v)||v<0||v>=36)throw new Error('Invalid native quickbar index');return v;};

// Native sender4d9da0, dispatcher79d980 and complete entry owner79db00.
// Embedded items are parsed by the same appearance/active-property owners used
// by inventory. They are registered separately from inventory ownership.
export function readNetworkQuickbar(r,minor,build,p){
 const entries=[],start=minor===1?0:index(r.readByte()),end=minor===1?36:start+1;
 for(let i=start;i<end;i++){
  const type=r.readByte(),b={type},items=[];
  if(type===1){
   b.itemId=b.secondaryItemId=OBJECT_INVALID;b.intParam=0xff0000;
   if(r.readBool()){b.itemId=r.readObjectIdClient();b.intParam=r.readInt();items.push({id:b.itemId,item:readNetworkItem(r,build,p)});}
   if(r.readBool()){b.secondaryItemId=r.readObjectIdClient();items.push({id:b.secondaryItemId,item:readNetworkItem(r,build,p)});}
  }else if(type===2){b.classIndex=r.readByte();b.intParam=r.readDword();b.metamagic=r.readByte();b.domainLevel=r.readByte();}
  else if(ints.has(type))b.intParam=r.readInt();
  else if(type>=11&&type<=17){b.resRef=ref(r);b.toolTip=text(r);}
  else if(type===18){b.commandLabel=text(r);b.commandLine=text(r);}
  else if(type===29||type===30)b.resRef=ref(r);
  else if(type===39){b.intParam=r.readInt();b.associateType=r.readWord();b.associateId=r.readObjectIdClient();}
  else if(type===44){b.intParam=r.readDword();b.domainLevel=r.readByte();}
  else if(!noParams.has(type))throw new Error(`Native quickbar type ${type} is unavailable`);
  entries.push({index:i,button:b,items});
 }
 return{kind:'quickbar',full:minor===1,entries};
}

// Native player->server major30/minor2, receiver452030/4521d0.
// Assigning a shortcut sends a request; the server owns the actual button.
export function quickbarAssignmentRequest({index:slot,button}){
 index(slot);const b=button??{type:0};if(!Number.isInteger(b.type)||b.type<0||b.type>48)throw new Error('Invalid native quickbar type');
 const uint=v=>Number.isInteger(v)&&v>=0&&v<=0xffffffff,byte=v=>Number.isInteger(v)&&v>=0&&v<=255,integer=v=>Number.isInteger(v)&&v>=-2147483648&&v<=2147483647;
 const w=new NativeMessageWriter(1);w.create(64,0xffffffff,1);w.writeByte(slot);w.writeByte(b.type);
 const string=v=>{if(typeof v!=='string')throw new Error('Invalid native quickbar text');w.writeStringBytes(encodeGffText(v));},resource=v=>{if(typeof v!=='string')throw new Error('Invalid native quickbar resource');const bytes=new Uint8Array(16);bytes.set(encodeGffText(v.split('\0')[0]).subarray(0,16));w.writeCResRef(bytes);};
 if(b.type===1){if(!uint(b.itemId)||!uint(b.secondaryItemId??OBJECT_INVALID)||!integer(b.intParam))throw new Error('Invalid native quickbar item');w.writeObjectIdClient(b.itemId);w.writeInt(b.intParam);w.writeBool(Number((b.secondaryItemId??OBJECT_INVALID)!==OBJECT_INVALID));if((b.secondaryItemId??OBJECT_INVALID)!==OBJECT_INVALID)w.writeObjectIdClient(b.secondaryItemId);}
 else if(b.type===2){if(![b.classIndex,b.metamagic,b.domainLevel].every(byte)||!uint(b.intParam))throw new Error('Invalid native quickbar spell');w.writeByte(b.classIndex);w.writeDword(b.intParam);w.writeByte(b.metamagic);w.writeByte(b.domainLevel);}
 else if(ints.has(b.type)){if(!integer(b.intParam))throw new Error('Invalid native quickbar integer');w.writeInt(b.intParam);}
 else if(b.type>=11&&b.type<=17){resource(b.resRef);string(b.toolTip);}
 else if(b.type===18){string(b.commandLabel);string(b.commandLine);}
 else if(b.type===29||b.type===30)resource(b.resRef);
 else if(b.type===39){if(!integer(b.intParam)||!uint(b.associateId)||!Number.isInteger(b.associateType)||b.associateType<0||b.associateType>65535)throw new Error('Invalid native quickbar associate');w.writeInt(b.intParam);w.writeWord(b.associateType);w.writeObjectIdClient(b.associateId);}
 else if(b.type===44){if(!uint(b.intParam)||!byte(b.domainLevel))throw new Error('Invalid native quickbar ability');w.writeDword(b.intParam);w.writeByte(b.domainLevel);}
 else if(!noParams.has(b.type))throw new Error('Unsupported native quickbar assignment type');
 w.setPrefix(Uint8Array.of(112,30,2));return Uint8Array.from(w.getWriteMessage().data);
}
