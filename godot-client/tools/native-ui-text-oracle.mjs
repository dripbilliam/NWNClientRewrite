// Offline oracle only. Original TLK/assets stay installed; retained outputs are
// string hashes and authored protocol examples, not rendering runtime inputs.
import fs from 'node:fs/promises';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {openServerResourceContext} from '../../electron/server_resource_context.mjs';
import {parse2da} from '../../src/area.js';
import {NetworkText} from '../../src/network_text.js';
import {loadNamedTalkTokens} from '../../src/game_talk_tokens.js';
import {nativeRichText} from '../../src/native_rich_text.js';
import {decodeGffText} from '../../src/gff_text.js';
const run=process.argv.find(a=>a.startsWith('--run='))?.slice(6)??'native-ui-text-oracle-v1';if(!/^[a-z0-9-]+$/.test(run))throw Error('Invalid oracle name');
const install=path.resolve('../FullDecomp/NwnRootInstall'),resolver=await openServerResourceContext({install,module:path.join(install,'data/nwm/Prelude.nwm')});
const raw=await fs.readFile(path.join(install,'lang/en/data/dialog.tlk')),hash=b=>createHash('sha256').update(b).digest('hex'),count=raw.readUInt32LE(12),textOffset=raw.readUInt32LE(16);
function string(ref){if(ref<0||ref>=count)return '';const at=20+ref*40;if(!(raw.readUInt32LE(at)&1))return '';const start=textOffset+raw.readUInt32LE(at+28),size=raw.readUInt32LE(at+32),bytes=raw.subarray(start,start+size),zero=bytes.indexOf(0);return decodeGffText(zero<0?bytes:bytes.subarray(0,zero));}
const tokens=loadNamedTalkTokens(parse2da(decodeGffText(new Uint8Array(await resolver.getResource('stringtokens',2017)))));
const refs=[...new Set([...Array.from({length:100},(_,i)=>i),...tokens.flatMap(t=>[t.defaultRef,...t.refs]).map(v=>v>>>0),5189,10300,10301,10302,10299,10303,66756,0x1918,0x1919,0x1917,0x6ce,0x6cd])].filter(n=>n<count);
const records=refs.map(ref=>({ref,textSha256:hash(string(ref)),storedBytes:raw.readUInt32LE(20+ref*40+32)}));
const object={id:1,areaId:42,objectType:5,appearance:{gender:0},replicated:{name:{firstName:{text:'Native'},lastName:{text:'Tester'}},stats:{racialType:0,classes:[{id:10,level:4}]}}};
const world={registry:{get:id=>id===1?object:null},customTokens:{records:[]},tlkOverrides:new Map(),players:new Map()},owner=new NetworkText({world,getResource:(name,type)=>resolver.getResource(name,type),talkString:async ref=>({text:string(ref)}),diagnose:()=>{}});
owner.token(18,'authored token');
const inputs=['Plain [b]literal[/b]','<<literal>','<CUSTOM18> / <CUSTOM19>','<CUSTOM4294967314>','<UNKNOWN>','<c'+decodeGffText(Uint8Array.of(60,128,255))+'>colored<c'+decodeGffText(Uint8Array.of(1,254,1))+'>nested</c>again</c>done'];
for(const token of tokens)if([0,1,2,3,4,5,6,8,9,10,19,20,21,22].includes(token.action))inputs.push('before <'+decodeGffText(token.name)+'> after');
const cases=[];
for(const gender of [0,1])for(const context of [1,99]){
 object.appearance.gender=gender;
 for(const input of inputs){const resolved=await owner.resolve({text:input},context,{nativeB8:0}),rich=nativeRichText(resolved);cases.push({input,context,gender,expected:rich,resolved});}
}
const richCases=[];
for(let byte=1;byte<256;byte++){const input='<c'+decodeGffText(Uint8Array.of(byte,60,62))+'>text</c>after';richCases.push({input,expected:nativeRichText(input)});}
const sources={};for(const file of ['src/network_text.js','src/native_rich_text.js','src/game_talk_tokens.js','src/talk_tokens.js','src/gff_text.js'])sources[file]=hash(await fs.readFile(file));
await fs.writeFile('godot-client/reports/'+run+'.json',JSON.stringify({install,scope:'Offline text hash and authored token/rich-span oracle; no JS rendering runtime input',tlkSha256:hash(raw),records,object,customTokens:[{id:18,text:'authored token'}],cases,richCases,sources},null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({records:records.length,cases:cases.length,richCases:richCases.length}));
