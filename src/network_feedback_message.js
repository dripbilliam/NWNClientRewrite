import {decodeGffText} from './gff_text.js';
import {satisfiesNativeBuild} from './network_build.js';
const string=r=>{const s=r.readCExoString();return{text:s.bytes?decodeGffText(s.bytes):''};};
const localized=r=>r.readBool()?{gender:r.readByte(1),strRef:r.readDword()}:string(r);
// Client770c80/CC11 ->777f2f, tables77a6e8/77a65c. Generated grouping from
// isolated native slot traces; this is engine wire layout, not spell/rule data.
const groups=[
 [[1,24,49,110,112,115,116,148,149,182,183,222,242],[["int","integers",0]]],
 [[5,151],[["object","objects",0],["int","integers",0]]],
 [[13,31,32,34,35,36,37,38,39,40,41,42,43,44,46,48,125,126,127,128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,144,145,146,154,155,156,157,158,159,202,203,234,235,241,254,257],[["object","objects",0]]],
 [[62,66,67],[["object","objects",0],["int","integers",0],["int","integers",1]]],
 [[63,64],[["object","objects",0],["int","integers",0]]],
 [[68,69],[["object","objects",0],["int","integers",0]]],
 [[70],[["object","objects",0],["int","integers",0],["int","integers",1]]],
 [[71,108,109,113,114],[["int","integers",0],["int","integers",1]]],
 [[111],[["object","objects",0],["int","integers",0],["int","integers",1]]],
 [[161,162,164,165],[["object","objects",0],["string","strings",1],["int","integers",0],["int","integers",1]]],
 [[163],[["object","objects",0],["string","strings",1],["int","integers",0],["int","integers",1],["string","strings",2],["int","integers",2],["int","integers",3]]],
 [[204],[["string","strings",0]]],
];
const layouts=new Map(groups.flatMap(([types,fields])=>types.map(type=>[type,fields])));
export function readNetworkFeedback(r,serverBuild){
 const type=r.readWord(),data={integers:{},objects:{},strings:{}};
 const atLeast=(revision,postfix)=>satisfiesNativeBuild(serverBuild,{number:8193,revision,postfix});
 const object=slot=>data.objects[slot]=r.readObjectIdClient(),integer=slot=>data.integers[slot]=r.readInt(),text=slot=>data.strings[slot]=string(r);
 if([4,47,50,51].includes(type)){
  if(type===4||type===47)object(0);
  data.strings[0]=r.readBool()?(r.readBool()?localized(r):string(r)):{baseItem:atLeast(36,4)?r.readDword():r.readByte()};
  // The unidentified base-item field widened at server8193.36.4.
 }else if(type===93||type===94){
  object(0);if(type===93)integer(0);else text(0);data.integers[type===93?1:0]=atLeast(36,1)?r.readBool():1;
 }else if(type===160){object(0);text(0);text(1);integer(0);data.strings[2]=atLeast(35,0)?string(r):{text:''};}
 else for(const [kind,family,slot]of layouts.get(type)??[]){data[family][slot]=kind==='object'?r.readObjectIdClient():kind==='int'?r.readInt():string(r);}
 return{kind:'combat-feedback',type,data,color:[62,63,64,66,67].includes(type)?String.fromCharCode(60,99,255,102,1,62):[68,69,70].includes(type)?String.fromCharCode(60,99,204,119,255,62):''};
}
