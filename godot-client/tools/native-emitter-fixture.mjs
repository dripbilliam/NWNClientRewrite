// Authored emitter bytes plus existing original-reader observations. Offline
// parsing is an oracle only; no game assets or prepared runtime data copied.
import fs from 'node:fs/promises';import path from 'node:path';import os from 'node:os';import crypto from 'node:crypto';
import {parseModel,parseAsciiMdl} from '../../src/model_parser.js';
import {BINARY_EMITTER_CHANNELS,EMITTER_FLAGS} from '../../src/mdl_emitter.js';
import {parseNativeTga} from '../../src/native_tga.js';
const folder=await fs.mkdtemp(path.join(os.tmpdir(),'nwn-native-emitter-data-')),hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex'),f32=values=>hash(Buffer.from(Float32Array.from(values).buffer));
const original=JSON.parse(await fs.readFile('backups/animations/native-binary-emitter-observations.json','utf8'));
function binary(header,{animated=false,dense=false}={}){
 const b=new ArrayBuffer(16384),v=new DataView(b),bytes=new Uint8Array(b),u=(at,n)=>v.setUint32(at,n,true),f=(at,n)=>v.setFloat32(at,n,true),s=(at,value)=>bytes.set(new TextEncoder().encode(value),at);
 u(4,b.byteLength-12);s(20,'authored_binary');u(84,232);u(88,1);f(176,1);s(180,'NULL');
 const node=244;u(node+108,5);s(node+32,'emitter');
 header.floats.forEach((value,i)=>f(node+112+i*4,value));[124,128,132,312,316,324].forEach((at,i)=>u(node+at,header.ints[i]));v.setUint16(node+320,header.order,true);[136,168,200,232,296].forEach((at,i)=>s(node+at,header.strings[i]));
 const controls=dense?Object.entries(BINARY_EMITTER_CHANNELS).map(([id,channel],i)=>[Number(id),Array.from({length:channel[1]},(_,j)=>(i+1)/4+j/8)]):[[84,[.25]],[88,[4]],[128,[12]],[108,[.2,.4,.8]],[448,[.75]],[452,[.3,.6,.9]]];
 const keys=(at,definition,keyOffset,valueOffset)=>{u(at+84,keyOffset);u(at+88,definition.length);u(at+96,valueOffset);let cursor=0;for(const[i,entry]of definition.entries()){const[id,values,times=[0],bezier=false]=entry,key=12+keyOffset+i*12;u(key,id);v.setUint16(key+4,times.length,true);v.setUint16(key+6,cursor,true);for(const time of times)f(12+valueOffset+cursor++*4,time);v.setUint16(key+8,cursor,true);bytes[key+10]=(values.length/times.length/(bezier?3:1))|(bezier?16:0);for(const value of values)f(12+valueOffset+cursor++*4,value);}u(at+100,cursor);};
 keys(node,controls,1000,2000);
 if(animated){u(132,4000);u(136,1);u(4012,4200);const clip=4212;s(clip+8,'pulse');f(clip+112,1);f(clip+116,.2);s(clip+120,'authored_binary');u(clip+72,4500);u(clip+76,1);const animation=4512;s(animation+32,'emitter');u(animation+108,5);keys(animation,[[88,[2,0,1,8,2,0],[0,1],true],[108,[0,0,0,1,.5,.25],[0,1]],[128,[6,12],[0,1]],[228,[0,1],[0,1]]],5000,6000);u(clip+184,8000);u(clip+188,1);f(8012,.5);s(8016,'authored_event');}
 return b;
}
const staticSamples=[];
for(const[index,row]of original.rows.entries()){
 const bytes=binary(row.case),name='header'+index+'.mdl';await fs.writeFile(path.join(folder,name),Buffer.from(bytes),{flag:'wx'});const model=parseModel(bytes),p=model.nodes[0].properties;
 staticSamples.push({name,sha256:hash(Buffer.from(bytes)),expected:p,originalHeader:{floats:row.floats,ints:row.ints,strings:row.strings,order:row.order},relocations:row.case.controls.map((id,i)=>({disk:id,runtime:row.controllers[i]}))});
}
const clips=model=>model.animations.map(clip=>({name:clip.name,length:clip.length,transition:clip.transition,events:clip.events,tracks:clip.tracks.filter(track=>track.property.startsWith('emitter.')).map(track=>({node:track.node,property:track.property.slice(8),interpolation:track.interpolation,frames:track.frames.length,sha256:f32(track.frames.flatMap(frame=>[frame.time,...frame.value,...frame.in??[],...frame.out??[]]))}))}));
const dense=binary(original.rows[0].case,{animated:true,dense:true});await fs.writeFile(path.join(folder,'channels.mdl'),Buffer.from(dense),{flag:'wx'});const denseModel=parseModel(dense);
const ascii=`newmodel authored_ascii
setsupermodel authored_ascii NULL
setanimationscale 1
beginmodelgeom authored_ascii
node dummy authored_ascii
parent NULL
endnode
node emitter emitter
parent authored_ascii
update Fountain
render Normal
blend Lighten
texture synthetic_texture
birthrate 2
fps 6
lifeexp 2
colorstart .2 .4 .8
colorend .1 .2 .3
sizestart .5
sizeend .1
xgrid 2
ygrid 2
flags 0x22
p2p 1
inherit 0
loop 1
twosidedtex 1
endnode
endmodelgeom authored_ascii
newanim pulse authored_ascii
length 1
transtime .2
node emitter emitter
birthratebezierkey 2
0 2 0 1
1 8 2 0
colorstartkey 2
0 0 0 0
1 1 .5 .25
fpskey
0 6
1 12
endlist
endnode
event .5 authored_event
doneanim pulse authored_ascii
newanim rest authored_ascii
length 0
doneanim rest authored_ascii
`;
await fs.writeFile(path.join(folder,'ascii.mdl'),ascii,{flag:'wx'});const asciiModel=parseAsciiMdl(ascii),asciiProperties={...asciiModel.nodes[1].properties};let flags=asciiProperties.flags>>>0;for(const[name,bit]of Object.entries(EMITTER_FLAGS))if(Object.hasOwn(asciiProperties,name)){if(Number(asciiProperties[name]))flags|=bit;else flags&=~bit;}asciiProperties.flags=flags>>>0;for(const[name,bit]of Object.entries(EMITTER_FLAGS))asciiProperties[name]=Number((flags&bit)!==0);
await fs.writeFile(path.join(folder,'missing.mdl'),ascii.replace('texture synthetic_texture','texture absent_bitmap'),{flag:'wx'});
await fs.writeFile(path.join(folder,'broken.mdl'),ascii.replace('texture synthetic_texture','texture corrupt_bitmap'),{flag:'wx'});
await fs.writeFile(path.join(folder,'corrupt_bitmap.tga'),Buffer.from('invalid TGA payload'),{flag:'wx'});
const tga=Buffer.alloc(34);tga[2]=2;tga.writeUInt16LE(2,12);tga.writeUInt16LE(2,14);tga[16]=32;tga[17]=8;Buffer.from([0,0,255,255,0,255,0,128,255,0,0,64,255,255,255,0]).copy(tga,18);await fs.writeFile(path.join(folder,'synthetic_texture.tga'),tga,{flag:'wx'});const rgba=Buffer.from(parseNativeTga(tga).data),nativeRgba=Buffer.concat([rgba.subarray(8,16),rgba.subarray(0,8)]);
const fixture={scope:'Authored emitter headers/channels plus stored original native-reader observations; no simulation/rendering acceptance',folder,originalBinarySha256:original.binarySha256,staticSamples,dense:{name:'channels.mdl',expected:denseModel.nodes[0].properties,clips:clips(denseModel)},ascii:{name:'ascii.mdl',expected:asciiProperties,clips:clips(asciiModel)},texture:{name:'synthetic_texture',sha256:hash(tga),pixelsSha256:hash(nativeRgba)}};
const file=path.join(folder,'fixture.json');await fs.writeFile(file,JSON.stringify(fixture,null,2),{flag:'wx'});console.log(file);
