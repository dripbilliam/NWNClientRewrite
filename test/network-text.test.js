import test from 'node:test';
import assert from 'node:assert/strict';
import {NetworkText} from '../src/network_text.js';
import {NetworkWorld} from '../src/network_world.js';
import {decodeGffText} from '../src/gff_text.js';
import {nativeRichText} from '../src/native_rich_text.js';
const bytes=s=>new TextEncoder().encode(s);
const tokens='2DA V2.0\n\nToken Action Default A B C D\n0 Class 8 -1 -1 -1 -1 -1\n1 class 9 -1 -1 -1 -1 -1\n2 Level 10 -1 -1 -1 -1 -1\n3 Race 5 -1 -1 -1 -1 -1\n4 race 6 -1 -1 -1 -1 -1\n5 FirstName 3 -1 -1 -1 -1 -1';
function fixture(){
 const world=new NetworkWorld(),id=0xffffffff,actor={id,objectType:5,appearance:{gender:1},replicated:{name:{firstName:{text:'Ada'}},stats:{racialType:1,classes:[{id:2,level:3},{id:1,level:20}]}}};world.registry.addObjectAtPos(id,actor);
 const requests=[],diagnostics=[],tables={stringtokens:tokens,classes:'2DA V2.0\n\nName Lower\n0 10 11\n1 12 13\n2 14 15',racialtypes:'2DA V2.0\n\nConverName ConverNameLower\n0 20 21\n1 22 23'};
 const text=new NetworkText({world,getResource:async name=>{requests.push(name);return bytes(tables[name]);},talkString:async(ref,gender)=>({text:ref===0xffffffff?'':`${ref}/${gender}`}),diagnose:(...v)=>diagnostics.push(v)});
 return{world,id,actor,text,requests,diagnostics,tables};
}
test('network class/race tokens use active rules and first replicated class, preserving gender for subsequent tokens',async()=>{
 const f=fixture();assert.equal(await f.text.resolve({text:'<Class> <class> <Level> <Race> <race> <FirstName>'},f.id),'14/0 15/0 3 22/0 23/0 Ada');assert.deepEqual(f.diagnostics,[]);
 f.actor.replicated.stats.classes.reverse();assert.equal(await f.text.resolve({text:'<class> <Level>'},f.id),'13/0 20');assert.equal(f.requests.filter(n=>n==='classes').length,1);
});
test('rule token text follows server TLK overrides and a new module/session uses its selected tables',async()=>{
 const f=fixture();assert.equal(await f.text.resolve({text:'<class>'},f.id),'15/0');f.world.apply({kind:'tlk-overrides',entries:[{strRef:15,text:'custom class'}]});assert.equal(await f.text.resolve({text:'<class>'},f.id),'custom class');f.world.apply({kind:'tlk-overrides',entries:[{strRef:15,text:''}]});assert.equal(await f.text.resolve({text:'<class>'},f.id),'15/0');
 const g=fixture();g.tables.classes='2DA V2.0\n\nName Lower\n0 100 101\n1 102 103\n2 104 105';assert.equal(await g.text.resolve({text:'<class>'},g.id),'105/0');
});
test('missing replicated class/rules are diagnosed rather than guessed from a local character',async()=>{
 const f=fixture();f.actor.replicated.stats.classes=[];assert.equal(await f.text.resolve({text:'<class> <FirstName>'},f.id),'<UNIMPLEMENTED TOKEN> Ada');assert.equal(f.diagnostics[0][2].action,9);
 const g=fixture();g.tables.classes='2DA V2.0\n\nName Lower\n0 10 11';assert.equal(await g.text.resolve({text:'<class>'},g.id),'<UNIMPLEMENTED TOKEN>');assert.equal(g.diagnostics.length,1);
});

const color=(...rgb)=>decodeGffText(Uint8Array.of(60,99,...rgb,62));
test('network descriptions preserve native color controls and newlines while resolving actual talk tokens',async()=>{
 const f=fixture(),blue=color(135,206,235),green=color(1,255,1),yellow=color(255,255,1),raw=blue+'Racial Type: '+green+'Human</c></c>\n\n'+blue+'Strength: '+yellow+'Average</c></c>\n'+blue+'Dexterity: '+green+'Very High</c></c>\n<FirstName> <CUSTOM7>';
 f.text.token(7,'server value');const resolved=await f.text.resolve({text:raw},f.id,{nativeB8:0});
 assert.equal(resolved,raw.replace('<FirstName>','Ada').replace('<CUSTOM7>','server value'));
 assert.deepEqual(nativeRichText(resolved),{text:'Racial Type: Human\n\nStrength: Average\nDexterity: Very High\nAda server value',spans:[{text:'Racial Type: ',color:'#87ceeb'},{text:'Human',color:'#01ff01'},{text:'\n\n',color:null},{text:'Strength: ',color:'#87ceeb'},{text:'Average',color:'#ffff01'},{text:'\n',color:null},{text:'Dexterity: ',color:'#87ceeb'},{text:'Very High',color:'#01ff01'},{text:'\nAda server value',color:null}]});assert.deepEqual(f.diagnostics,[]);
});

test('fixed-width native RGB bytes cannot be mistaken for angle-bracket delimiters or named tokens',async()=>{
 const f=fixture();for(let byte=1;byte<256;byte++){
  const control=color(byte,60,62),raw=control+'<FirstName></c> normal';
  const resolved=await f.text.resolve({text:raw},f.id);assert.equal(resolved,control+'Ada</c> normal');assert.equal(nativeRichText(resolved).text,'Ada normal');assert.equal(nativeRichText(resolved).spans[0].color,'#'+byte.toString(16).padStart(2,'0')+'3c3e');
 }assert.deepEqual(f.diagnostics,[]);
});

test('rich network parsing retains named token colors, suppression and nonrecursive custom substitutions',async()=>{
 const f=fixture();f.tables.stringtokens+='\n6 StartAction 19 -1 -1 -1 -1 -1\n7 End 22 -1 -1 -1 -1 -1\n8 StartCheck 20 -1 -1 -1 -1 -1';
 const rich=await f.text.resolve({text:'<StartAction>Action <FirstName><End> plain'},f.id,{nativeB8:0});assert.equal(nativeRichText(rich).text,'Action Ada plain');assert.equal(nativeRichText(rich).spans[0].color,'#01fe01');
 assert.equal(await f.text.resolve({text:'<StartCheck>'+color(60,62,255)+'hidden</c><End>visible'},f.id,{nativeB8:0,nativeBC:1}),'visible');
 f.text.token(7,color(32,112,32)+'<FirstName></c>');assert.equal(nativeRichText(await f.text.resolve({text:'<CUSTOM7>'},f.id)).text,'<FirstName>');
 assert.equal(await f.text.resolve({text:'<<FirstName> <NotAToken>'},f.id),'<FirstName> <UNRECOGNIZED TOKEN>');assert.equal(f.diagnostics.length,1);assert.equal(f.diagnostics[0][2].token,'NotAToken');
});

