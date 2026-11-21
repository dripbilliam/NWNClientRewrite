import test from 'node:test';
import assert from 'node:assert/strict';
import {GameplayText,richText} from './gameplay-text.mjs';
import {GameplayDelivery} from './gameplay-delivery.mjs';
import {NetworkText} from '../../src/network_text.js';
import {NetworkWorld} from '../../src/network_world.js';
import {decodeGffText} from '../../src/gff_text.js';
const color=(...rgb)=>decodeGffText(Uint8Array.of(60,99,...rgb,62));
const deferred=()=>{let resolve;const promise=new Promise(r=>resolve=r);return{promise,resolve};};
const turn=()=>new Promise(resolve=>setImmediate(resolve));
function fixture(){
 const id=0xffffffff,world=new NetworkWorld();world.localObjectId=id;world.areaId=9;
 world.registry.addObjectAtPos(id,{id,objectType:5,areaId:9,appearance:{gender:0},replicated:{name:{firstName:{text:'Ada'},lastName:{text:'Test'}},stats:{classes:[{id:3,level:20}]}}});
 const tables={stringtokens:'2DA V2.0\n\nToken Action Default A B C D\n0 FirstName 3 -1 -1 -1 -1 -1\n1 StartAction 19 -1 -1 -1 -1 -1\n2 End 22 -1 -1 -1 -1 -1',damagelevels:'2DA V2.0\n\nSTRING_REF\n0 101',effecticons:'2DA V2.0\n\nStrRef\n0 201',baseitems:'2DA V2.0\n\nName\n0 301'};
 const strings=new Map([[101,'Uninjured'],[0x1919,'Friendly'],[10300,'Shout: '],[0x6ce,'End'],[0x6cd,'Continue']]);
 const text=new NetworkText({world,getResource:async name=>{if(!tables[name])throw Error('Missing table '+name);return new TextEncoder().encode(tables[name]);},talkString:async ref=>({text:strings.get(ref)??'ref'+ref}),diagnose:()=>{}});
 const adapter=new GameplayText({world,text}),session={world,areaGeneration:2,closed:false},sent=[],diagnostics=[];
 const delivery=new GameplayDelivery({session,connection:3,text,active:()=>true,send:row=>sent.push(row),diagnose:(...row)=>diagnostics.push(row)});
 return{id,world,text,tables,strings,adapter,session,sent,diagnostics,delivery};
}
test('native token resolver preserves nested byte colors, custom tokens and line breaks through JSON spans',async()=>{
 const f=fixture();f.text.token(7,'server value');
 const raw=color(135,206,235)+'Attuned to '+color(1,255,1)+'Fire</c></c>\n\n<FirstName> <CUSTOM7> [b]literal[/b]';
 const result=JSON.parse(JSON.stringify(await f.adapter.rich({text:raw},f.id)));
 assert.equal(result.text,'Attuned to Fire\n\nAda server value [b]literal[/b]');
 assert.deepEqual(result.spans.slice(0,2),[{text:'Attuned to ',color:'#87ceeb'},{text:'Fire',color:'#01ff01'}]);
 for(let byte=1;byte<256;byte++){const rich=await f.adapter.rich({text:color(byte,60,62)+'<FirstName></c>'},f.id);assert.equal(rich.text,'Ada');assert.equal(rich.spans[0].color,'#'+byte.toString(16).padStart(2,'0')+'3c3e');}
});
test('speech retains authoritative names, channel prefixes and system disclosure instead of echoing drafts',async()=>{
 const f=fixture(),row=await f.adapter.speech({kind:'server-speech',channel:2,objectId:f.id,text:{text:'<StartAction>Rest<End>'}});
 assert.equal(row.name.text,'Ada Test');assert.equal(row.rich.text,'Shout: Rest');assert.equal(row.rich.spans.at(-1).color,'#01fe01');
 assert.equal(await f.adapter.speech({kind:'server-speech',channel:1,objectId:123,text:{text:'absent'}}),null);
 const remote=await f.adapter.speech({kind:'server-speech',channel:2,objectId:123,speakerName:{text:'Remote'},text:{text:'hello'}});assert.equal(remote.name.text,'Remote');
 const system=await f.adapter.speech({kind:'server-speech',channel:5,speakerName:{text:'Spoof'},text:{text:'Server only'}});assert.equal(system.name.text,'');assert.equal(system.system,true);
});
test('dialogue keeps unsigned reply IDs, per-choice colors and original localized end/continue fallbacks',async()=>{
 const f=fixture(),empty=await f.adapter.dialog({kind:'dialog-replies',entryId:0xffffffff,end:true,replies:[]});
 assert.deepEqual(empty.replies,[{id:0xffffffff,rich:richText('End')}]);
 const row=await f.adapter.dialog({kind:'dialog-replies',entryId:3,end:false,tokenObjectId:f.id,replies:[{id:0xfffffffe,text:{text:''}},{id:7,text:{text:color(255,255,1)+'Choose <FirstName></c>'}}]});
 assert.equal(row.replies[0].rich.text,'Continue');assert.equal(row.replies[0].id,0xfffffffe);assert.equal(row.replies[1].rich.text,'Choose Ada');assert.equal(row.replies[1].rich.spans[0].color,'#ffff01');
});
test('examination uses only disclosed server fields and retains descriptions when optional tables fail',async()=>{
 const f=fixture(),message={kind:'examine',targetId:f.id,type:'creature',hasDetails:1,description:{text:'\n'+color(135,206,235)+'Attuned to Fire</c>\nRacial Type: Human'},damageLevel:0,reaction:1,effects:[0],portraitId:65534,portrait:'authored_'};
 const row=await f.adapter.examine(message);assert.equal(row.name.text,'Ada Test');assert.equal(row.condition.text,'Uninjured');assert.equal(row.reaction.text,'Friendly');assert.equal(row.facts.length,0);assert.equal(row.effects[0].text,'ref201');assert.equal(row.description.text,'\nAttuned to Fire\nRacial Type: Human');
 const hidden=await f.adapter.examine({...message,description:{text:'Racial Type: Human'},effects:undefined,hasDetails:0});assert.equal(hidden.condition,undefined);assert.equal(hidden.portrait,undefined);assert.equal(hidden.facts.length,0);assert.ok(!JSON.stringify(hidden).includes('Attuned'));
 delete f.tables.damagelevels;f.text.ruleTables.clear();const partial=await f.adapter.examine(message);assert.equal(partial.description.text,row.description.text);assert.equal(partial.warnings.length,1);
});
test('item property subtype, overridden cost and parameter tables retain the existing rule lookup path',async()=>{
 const f=fixture();Object.assign(f.tables,{
  itempropdef:'2DA V2.0\n\nGameStrRef CostTableResRef Param1ResRef SubTypeResRef\n0 401 0 0 authored_sub',
  authored_sub:'2DA V2.0\n\nName CostTableResRef Param1ResRef\n0 402 1 1',
  iprp_costtable:'2DA V2.0\n\nName\n0 ****\n1 authored_cost',authored_cost:'2DA V2.0\n\nName\n0 403',
  iprp_paramtable:'2DA V2.0\n\nTableResRef\n0 ****\n1 authored_param',authored_param:'2DA V2.0\n\nName\n0 404'});
 const row=await f.adapter.examine({kind:'examine',targetId:f.id,type:'item',identified:1,canUse:0,weight:25,charges:2,minimumLevel:5,value:99,properties:[{type:0,subtype:0,costValue:0,uses:0,usable:0}]});
 assert.equal(row.properties[0].rich.text,'ref401 ref402 ref403 ref404');assert.equal(row.properties[0].usable,false);assert.equal(row.facts.find(r=>r.name==='Weight').rich.text,'2.5');assert.equal(row.facts.find(r=>r.name==='Use').rich.text,'Cannot use');
 const trap=await f.adapter.examine({kind:'examine',targetId:7,type:'trap',success:false});assert.equal(trap.close,true);assert.equal(trap.description,undefined);
});
test('delayed dialogue resolution cannot reopen a closed window; newer entry/replies preserve their pairing',async()=>{
 const f=fixture(),gate=deferred(),old=f.text.resolve.bind(f.text);f.text.resolve=async(value,...args)=>value?.text==='slow'?gate.promise:old(value,...args);
 const work=f.delivery.receive({kind:'dialog-entry',text:{text:'slow'}},2);await turn();await f.delivery.receive({kind:'dialog-close'},2);gate.resolve('late');await work;assert.deepEqual(f.sent.map(x=>x.kind),['dialog-close']);
 await f.delivery.receive({kind:'dialog-entry',text:{text:'new'}},2);await f.delivery.receive({kind:'dialog-replies',entryId:91,replies:[{id:12,text:{text:'yes'}}]},2);
 assert.equal(f.sent.at(-2).rich.text,'new');assert.equal(f.sent.at(-1).entryId,91);assert.equal(f.sent.at(-1).connection,3);
});
test('slow examination and portrait jobs do not block chat and cannot overwrite a newer examination',async()=>{
 const f=fixture(),gate=deferred(),old=f.text.resolve.bind(f.text);f.text.resolve=async(value,...args)=>value?.text==='slow'?gate.promise:old(value,...args);
 const stale=f.delivery.receive({kind:'examine',type:'placeable',targetId:1,description:{text:'slow'}},2);await turn();
 await f.delivery.receive({kind:'server-speech',channel:5,text:{text:'immediate'}},2);assert.equal(f.sent.at(-1).rich.text,'ref10299immediate');
 await f.delivery.receive({kind:'examine',type:'placeable',targetId:2,description:{text:'new'}},2);gate.resolve('old');await stale;assert.deepEqual(f.sent.filter(x=>x.kind==='examine').map(x=>x.targetId),[2]);
 const portrait=deferred();f.delivery.portrait=async()=>portrait.promise;await f.delivery.receive({kind:'examine',type:'creature',targetId:f.id,hasDetails:1,damageLevel:0,reaction:1,portraitId:0},2);
 await f.delivery.receive({kind:'examine',targetId:2,type:'placeable'},2);portrait.resolve('data:image/png;base64,authored');await turn();assert.equal(f.sent.filter(x=>x.kind==='examine-portrait').length,0);
});
test('area change, disconnect and delivery reset discard delayed text completions',async()=>{
 for(const retire of [f=>f.session.areaGeneration++,f=>f.session.world.areaId++,f=>f.session.closed=true,f=>f.delivery.reset()]){
  const f=fixture(),gate=deferred();f.text.resolve=async()=>gate.promise;const work=f.delivery.receive({kind:'server-speech',channel:5,text:{text:'slow'}},2);await turn();retire(f);gate.resolve('retired');await work;assert.deepEqual(f.sent,[]);
 }
});
test('existing script-feedback formatter produces the real overhead prompt and optional history line, including after reset',async()=>{
 const f=fixture(),message={kind:'combat-feedback',type:94,data:{strings:[{text:'Select a slot'}],objects:[f.id],integers:[1]}};
 await f.delivery.receive(message,2);assert.equal(f.sent.find(x=>x.kind==='floating').rich.text,'Select a slot');assert.equal(f.sent.find(x=>x.kind==='chat').rich.text,'Select a slot');
 f.delivery.reset();f.sent.length=0;await f.delivery.receive(message,2);assert.equal(f.sent.length,2);assert.deepEqual(f.diagnostics,[]);
});

function damageFixture(){
 const f=fixture();f.tables.damagetypes='2DA V2.0\n\nDamageTypeGroup\n0 0\n1 1';f.tables.damagetypegroups='2DA V2.0\n\nColorR ColorG ColorB FeedbackStrref\n0 255 1 1 401\n1 1 255 1 402';
 const damage=Array(32).fill(-1);damage[0]=3;damage[1]=5;
 return{...f,message:{kind:'damage-feedback',sourceId:f.id,targetId:f.id,damage,debug:null}};
}
test('native delivery applies live combat feedback options to original grouped/total numbers while retaining chat and script prompts',async()=>{
 const f=damageFixture();let options={enabled:true,total:false};f.delivery.feedbackOptions=()=>options;
 await f.delivery.receive(f.message,2);assert.deepEqual(f.sent.filter(v=>v.kind==='floating').map(v=>v.rich.text),['3','5']);assert.equal(f.sent.filter(v=>v.kind==='chat').length,1);
 options={enabled:true,total:true};f.sent.length=0;await f.delivery.receive(f.message,2);assert.deepEqual(f.sent.filter(v=>v.kind==='floating').map(v=>v.rich.text),['8']);
 options={enabled:false,total:true};f.sent.length=0;await f.delivery.receive(f.message,2);assert.equal(f.sent.filter(v=>v.kind==='floating').length,0);assert.equal(f.sent.filter(v=>v.kind==='chat').length,1);
 await f.delivery.receive({kind:'combat-feedback',type:94,data:{strings:[{text:'Select a slot'}],objects:[f.id],integers:[1]}},2);assert.equal(f.sent.find(v=>v.kind==='floating').rich.text,'Select a slot');
 f.delivery.reset();options={enabled:true,total:false};f.sent.length=0;await f.delivery.receive(f.message,2);assert.deepEqual(f.sent.filter(v=>v.kind==='floating').map(v=>v.rich.text),['3','5']);assert.deepEqual(f.diagnostics,[]);
});
test('changing combat feedback during a pending original-table lookup affects emission without retiring ordinary chat',async()=>{
 const f=damageFixture(),gate=deferred(),read=f.text.getResource.bind(f.text);let enabled=true,waiting=false;
 f.delivery.feedbackOptions=()=>({enabled,total:false});f.text.getResource=async(...args)=>{if(args[0]==='damagetypes'){waiting=true;await gate.promise;}return read(...args);};
 const work=f.delivery.receive(f.message,2);await turn();assert.ok(waiting);enabled=false;gate.resolve();await work;
 assert.equal(f.sent.filter(v=>v.kind==='floating').length,0);assert.equal(f.sent.filter(v=>v.kind==='chat').length,1);assert.deepEqual(f.diagnostics,[]);
});
test('the same live preference suppresses original critical-attack overhead text while preserving attack history',async()=>{
 const f=fixture();let enabled=true;f.delivery.feedbackOptions=()=>({enabled,total:true});
 const message={kind:'attack-feedback',minor:5,sourceId:f.id,targetId:f.id,modifier:2,roll:20,result:3,attackType:null,combatMode:0,offhand:0,sneakAttack:0,deathAttack:0,specialMinus534:0,coupDeGrace:0,threatened:0,confirmation:null,concealmentChance:0,debug:null};
 await f.delivery.receive(message,2);assert.equal(f.sent.filter(v=>v.kind==='floating').length,1);assert.equal(f.sent.filter(v=>v.kind==='chat').length,1);
 enabled=false;f.sent.length=0;await f.delivery.receive(message,2);assert.equal(f.sent.filter(v=>v.kind==='floating').length,0);assert.equal(f.sent.filter(v=>v.kind==='chat').length,1);assert.deepEqual(f.diagnostics,[]);
});
