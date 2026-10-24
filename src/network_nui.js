import {decodeUbjson,encodeUbjson} from './ubjson.js';
import {NativeMessageWriter} from './native_message.js';
import {decodeGffText} from './gff_text.js';
import {scriptStringBytes} from './script_string.js';
const string=r=>{const s=r.readCExoString();return s.bytes?decodeGffText(s.bytes):'';};
export function readNuiJson(r){r.expectType(16);const n=r.readDword();if(n>r.byteSize40-r.byteCursor44)throw Error('Truncated native NUI JSON');const bytes=r.readOpaqueBytes(n);if(!bytes)throw Error('Invalid native NUI JSON');return decodeUbjson(bytes);}
export function writeNuiJson(w,v){w.writeType(16);const bytes=encodeUbjson(v);w.writeDword(bytes.length);w.writeOpaqueBytes(bytes);}
const count=r=>{const n=r.readInt();if(n<0||n>Math.floor((r.byteSize40-r.byteCursor44)/8))throw Error('Invalid native NUI batch count');return n;};
export function readNetworkNui(r,minor){
 if(minor===1){const token=r.readInt(),id=string(r),format=r.readInt();if(format===1)return{kind:'nui-create',token,id,format,layout:readNuiJson(r)};if(format===0){const raw=r.readCResRef(),end=raw.indexOf(0);return{kind:'nui-create',token,id,format,resref:decodeGffText(end<0?raw:raw.subarray(0,end))};}throw Error('Unsupported native NUI layout format');}
 if(minor===2)return{kind:'nui-destroy',token:r.readInt()};
 if(minor===4)return{kind:'nui-binds',updates:Array.from({length:count(r)},()=>({token:r.readInt(),bind:string(r),value:readNuiJson(r)}))};
 if(minor===5)return{kind:'nui-layout',token:r.readInt(),element:string(r),layout:readNuiJson(r)};
 throw Error('Unsupported native NUI server subtype');
}
const int=v=>Number.isInteger(v)&&v>=-2147483648&&v<=2147483647;
export function nuiInputRequest({events=[],binds=[]},{indexedBinds=true}={}){
 if(!Array.isArray(events)||!Array.isArray(binds)||events.length&&binds.length||events.length+binds.length<1||events.length+binds.length>65535)throw Error('Invalid native NUI input batch');const w=new NativeMessageWriter(1);w.create(64,0xffffffff,1);const entries=events.length?events:binds,minor=events.length?3:4;w.writeInt(entries.length);
 for(const e of entries){if(!int(e.token)||e.token===0||!int(e.index??-1))throw Error('Invalid native NUI input identity');w.writeInt(e.token);if(minor===3){if(typeof e.type!=='string'||typeof e.element!=='string')throw Error('Invalid native NUI event');w.writeStringBytes(scriptStringBytes(e.type));w.writeStringBytes(scriptStringBytes(e.element));w.writeInt(e.index??-1);writeNuiJson(w,e.payload??null);}else{if(typeof e.bind!=='string'||!e.bind)throw Error('Invalid native NUI bind');w.writeStringBytes(scriptStringBytes(e.bind));writeNuiJson(w,e.value);if(indexedBinds)w.writeInt(e.index??-1);}}
 w.setPrefix(Uint8Array.of(112,55,minor));return Uint8Array.from(w.getWriteMessage().data);
}
