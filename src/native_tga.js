import {TGALoader} from 'three/addons/loaders/TGALoader.js';

// CResTGA::OnResourceServiced1a4730 keeps file row/column order regardless of
// descriptor origin bits. TGALoader normalizes them; neutralize only those bits
// before decoding, retaining its top-down image + flipY upload convention.
// Do not mutate cached/server resource bytes. Ordinary bottom-left TGAs need
// no additional copy. This is an origin adapter, not a full native codec port.
const loader=new TGALoader();
export function parseNativeTga(input){
 const bytes=input instanceof ArrayBuffer?new Uint8Array(input):new Uint8Array(input.buffer,input.byteOffset,input.byteLength);
 if(bytes.byteLength<18)throw Error('Native TGA header is truncated');
 let buffer;if(bytes[17]&0x30){const copy=bytes.slice();copy[17]&=~0x30;buffer=copy.buffer;}
 else buffer=bytes.byteOffset===0&&bytes.byteLength===bytes.buffer.byteLength?bytes.buffer:bytes.slice().buffer;
 return loader.parse(buffer);
}
