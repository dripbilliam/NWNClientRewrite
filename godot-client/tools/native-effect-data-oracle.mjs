// Read-only original resources: emit hashes/metadata only, never asset payloads.
import fs from 'node:fs/promises';import path from 'node:path';import {createHash} from 'node:crypto';
import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
import {decodeResourceText} from '../../src/resource_archive.js';import {parse2da} from '../../src/area.js';import {parseModel} from '../../src/model_parser.js';
import {exportNativeAnimation} from './export-native-animation.mjs';import {nativeStringEntry} from '../../src/spell_metadata.js';import {decodeImaWav} from '../../src/ima_adpcm.js';
const hash=b=>createHash('sha256').update(b).digest('hex'),i32=v=>hash(Buffer.from(Int32Array.from(v).buffer)),f32=v=>hash(Buffer.from(Float32Array.from(v).buffer));
const resolver=await openServerResourceContext({install:path.resolve('../FullDecomp/NwnRootInstall')});
const table=parse2da(decodeResourceText(await resolver.getResource('visualeffects',2017))),names=new Set();
for(const visual of [1,69])for(const column of ['Imp_Root_M_Node','Imp_Root_L_Node','Imp_Root_H_Node','Imp_Impact_Node','Imp_HeadCon_Node']){const name=nativeStringEntry(table,visual,column).value;if(name)names.add(name.toLowerCase());}
const storage=node=>({id:node.id34,flags:node.flags98,controllers:i32(node.controllers78.flatMap(c=>[c.displacement0,c.columnsA,c.rows4,c.timeIndex6,c.valueIndex8])),values:f32(node.values88)});
const tree=node=>({...storage(node),children:node.children68.map(tree)}),models=[];
for(const name of names){const bytes=await resolver.getResource(name,2002),model=parseModel(bytes),native=exportNativeAnimation(model);if(!native)continue;models.push({name,sha256:hash(Buffer.from(bytes)),root:native.root,parts:native.parts.map(part=>({...storage(part.node),type:part.type,children:part.children})),clips:Object.fromEntries(Object.entries(native.clips).map(([name,clip])=>[name,clip.root?tree(clip.root):clip]))});}
const waves=[];
for(const channels of [1,2])for(const blocks of [1,2])for(const groups of [1,3,5])for(const trim of [0,3]){
 const block=channels*4+groups*4*channels,available=blocks*(1+groups*8),frames=available-trim,data=Buffer.alloc(block*blocks);let state=channels*100+blocks*20+groups;
 const random=()=>{state=(Math.imul(state,1664525)+1013904223)>>>0;return state;};
 for(let b=0;b<blocks;b++){for(let c=0;c<channels;c++){const at=b*block+c*4;data.writeInt16LE((random()&65535)-32768,at);data[at+2]=random()%89;}for(let at=b*block+channels*4;at<(b+1)*block;at++)data[at]=random()&255;}
 const fmt=Buffer.alloc(20);fmt.writeUInt16LE(17,0);fmt.writeUInt16LE(channels,2);fmt.writeUInt32LE(22050,4);fmt.writeUInt16LE(block,12);fmt.writeUInt16LE(4,14);fmt.writeUInt16LE(2,16);fmt.writeUInt16LE(1+groups*8,18);
 const chunk=(tag,data)=>{const out=Buffer.alloc(8+data.length+(data.length&1));out.write(tag);out.writeUInt32LE(data.length,4);data.copy(out,8);return out;},fact=Buffer.alloc(4);fact.writeUInt32LE(frames);
 const body=Buffer.concat([Buffer.from('WAVE'),chunk('fmt ',fmt),chunk('fact',fact),chunk('data',data)]),bytes=Buffer.alloc(8+body.length);bytes.write('RIFF');bytes.writeUInt32LE(body.length,4);body.copy(bytes,8);
 const decoded=decodeImaWav(bytes),pcm=new Int16Array(frames*channels);for(let f=0;f<frames;f++)for(let c=0;c<channels;c++)pcm[f*channels+c]=Math.round(decoded.samples[c][f]*32768);
 waves.push({label:[channels,blocks,groups,trim].join(':'),bytes:bytes.toString('base64'),channels,frames,sampleRate:22050,sha256:hash(Buffer.from(pcm.buffer))});
}
await fs.writeFile('godot-client/reports/native-effect-data-oracle-v1.json',JSON.stringify({models,waves,scope:'Original controller hashes and authored IMA PCM reference; retained-source comparison, not fresh live binary parity'})+'\n',{flag:'wx'});console.log(JSON.stringify({models:models.length,authoredWaves:waves.length}));
