import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';
import {NativeMessageWriter} from '../src/native_message.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {presentSpellCombatMessage,spellMessageColors} from '../src/client_spell_message.js';
import {NetworkFeedbackView} from '../src/network_feedback_view.js';
import {NetworkWorld} from '../src/network_world.js';import {NetworkText} from '../src/network_text.js';
import {scriptStringBytes} from '../src/script_string.js';import {decodeGffText} from '../src/gff_text.js';
import {parse2da} from '../src/area.js';
const load=f=>JSON.parse(fs.readFileSync(new URL('../backups/animations/'+f,import.meta.url))),wire=load('native-network-spell-feedback-wire.json'),native=load('native-client-spell-message-observations.json');
function packet(fields,localizedInline=false){const w=new NativeMessageWriter(1);w.create(9,0xffffffff,1);w.writeObjectIdClient(fields.sourceId);w.writeDword(fields.spellId);w.writeBool(fields.identified);w.writeBool(fields.casting);w.writeBool(fields.hasItem);if(fields.hasItem){if(!fields.identified)w.writeByte(fields.baseItem);else{w.writeBool(fields.itemName.strRef!==undefined||localizedInline);if(localizedInline)w.writeBool(0);if(fields.itemName.strRef!==undefined){w.writeBool(1);w.writeByte(fields.itemName.gender,1);w.writeDword(fields.itemName.strRef);}else{const b=scriptStringBytes(fields.itemName.text);w.writeCExoString({bytes:b,length:b.length});}}}w.setPrefix(Uint8Array.of(80,18,8));return Uint8Array.from(w.getWriteMessage().data);}
const decode=p=>decodeServerGameMessage(p),bytes=h=>Uint8Array.from(Buffer.from(h,'hex'));

test('180 original whole CC8 writers with real wire codecs match native field selection and client decoding',()=>{
 assert.equal(wire.cases.length,180);assert.equal(wire.target,native.binarySha256);
 for(const row of wire.cases){const c=row.case,p=bytes(row.packet),m=decode(p),hasItem=Number(c.item!=='none'),sourceId=c.sourceId===0x7f000000?c.sourceId:(c.sourceId|0x80000000)>>>0;
  assert.equal(m.kind,'spell-feedback');assert.equal(m.sourceId,sourceId);assert.equal(m.spellId,c.spellId);assert.equal(m.identified,c.identified);assert.equal(m.casting,c.casting);assert.equal(m.hasItem,hasItem);
  if(hasItem&&!c.identified)assert.equal(m.baseItem,c.baseItem&255);
  if(hasItem&&c.identified)assert.deepEqual(m.itemName,c.item==='localized-ref'?{gender:0,strRef:123}:{text:decodeGffText(bytes(row.itemTextHex))});
  const expected=Uint8Array.from(p),actual=packet(m,c.item!=='override'&&c.item!=='localized-ref'),used=expected.at(-1)>>>5;if(used){const mask=(255<<(8-used))&255;expected[expected.length-1]&=mask;actual[actual.length-1]&=mask;}assert.deepEqual(actual,expected,'Unowned final padding excluded');
  for(let n=3;n<p.length;n++)assert.throws(()=>decode(p.subarray(0,n)));assert.throws(()=>decode(Uint8Array.from([...p,0,0])));
 }
});

test('asynchronous presentation preserves all 512 successful original CC8 branch call sequences and token state',async()=>{
 let checked=0;
 for(const row of native.rows.filter(r=>r.case.fail===0)){const c=row.case,tokens={1:'old1',2:'old2'},calls=[],add=(name,fn)=>(...args)=>{calls.push([name,...args]);return Promise.resolve(fn(...args));};
  const fields={sourceId:0x80000063,spellId:37,identified:c.identified,casting:c.casting,hasItem:c.hasItem,baseItem:8,itemName:c.localized?'ItemLoc':'ItemOverride'};
  await presentSpellCombatMessage(fields,{spell:add('spell',()=>c.spell?{name:123,altMessage:c.alt}:null),sourceName:add('name',()=>c.name?'Caster':null),player:add('player',()=>c.player?{id:c.playerId}:null),tlk:add('tlk',ref=>'T'+ref),token:add('token',(id,text)=>tokens[id]=text),baseItemName:add('baseItem',()=> 'Base'),parse:add('parse',ref=>ref===0xf721?`Item(${tokens[0]??''})`:ref===0x28f2?`${tokens[0]??''} ${tokens[1]??''} ${tokens[2]??''}`:`Alt(${tokens[0]??''})`),display:add('display',()=>{})});
  assert.deepEqual(calls,row.calls.filter(c=>!['object','dword','bool','overflow','byte','string','localized'].includes(c[0])));assert.deepEqual(tokens,row.tokens);checked++;
 }
 assert.equal(checked,512);
});

function fixture(){
 const world=new NetworkWorld(),rows=[],reports=[],spells=parse2da('2DA V2.0\n\nName AltMessage\n0 700 0\n1 701 702\n'),baseitems=parse2da('2DA V2.0\n\nName\n0 703\n'),strings=new Map([[700,'Active spell'],[701,'Alternate spell'],[702,'Alternate <CUSTOM0>'],[703,'Active item type'],[8127,'starts casting'],[1501,'casts'],[63264,'uses'],[1502,'Unknown spell'],[63265,'Unidentified <CUSTOM0>'],[10482,'<CUSTOM0> <CUSTOM1> <CUSTOM2>'],[8349,'Unknown caster'],[53122,'Penalty <CUSTOM0>, Failure <CUSTOM1>']]);
 world.registry.addObjectAtPos(0xffffffff,{id:0xffffffff,objectType:5,replicated:{name:{firstName:{text:'Local'},lastName:{text:'Caster'}}},hp:20});world.localObjectId=0xffffffff;
 const text=new NetworkText({world,getResource:async()=>scriptStringBytes('2DA V2.0\n\nToken Default StrRef0\n'),talkString:async ref=>({text:strings.get(ref)??''}),diagnose:(...v)=>reports.push(v)});
 const view=new NetworkFeedbackView({world:()=>world,text:()=>text,tables:()=>({spells,baseitems}),display:r=>rows.push(r),report:(...v)=>reports.push(v)});
 return{world,text,view,rows,reports,strings,spells};
}
const ordinary={kind:'spell-feedback',sourceId:0xffffffff,spellId:0,identified:1,casting:1,hasItem:0,itemName:''};

test('network spell notices use active metadata/TLK, canonical local/other names and nested native colors',async()=>{
 const f=fixture(),before=JSON.stringify([...f.world.registry.objects]);await f.view.receive(ordinary);
 assert.equal(f.rows[0].text,'Local Caster starts casting Active spell');assert.ok(f.rows[0].richText.some(s=>s.text==='Local Caster'&&s.color==='#99ffff'));assert.equal(f.rows[0].richText.at(-1).color,'#cc77ff');
 f.world.registry.addObjectAtPos(0xfffffffe,{id:0xfffffffe,objectType:5,appearance:{name:{firstName:{text:'Other'},lastName:{text:'Caster'}}}});await f.view.receive({...ordinary,sourceId:0xfffffffe,casting:0,identified:0});assert.equal(f.rows[1].text,'Other Caster casts Unknown spell');assert.ok(f.rows[1].richText.some(s=>s.text==='Other Caster'&&s.color==='#cc99cc'));
 await f.view.receive({...ordinary,sourceId:0x7f000000,spellId:1});assert.equal(f.rows.at(-1).text,'Alternate Unknown caster');assert.equal(decodeGffText(f.world.customTokens.records.find(r=>r.id===1).bytes),'casts');
 f.world.registry.delete(0xfffffffe);assert.equal(JSON.stringify([...f.world.registry.objects]),before);assert.deepEqual(f.reports,[]);
 f.spells.orderedRows[0].Name='704';f.strings.set(704,'Replacement rules spell');await f.view.receive(ordinary);assert.equal(f.rows.at(-1).text,'Local Caster starts casting Replacement rules spell');
});

test('consumed item names come from the packet, unidentified names from baseitems, and invalid spells display nothing',async()=>{
 const f=fixture();await f.view.receive({...ordinary,hasItem:1,itemName:{text:'Already consumed potion'}});assert.equal(f.rows.at(-1).text,'Local Caster uses Already consumed potion');
 await f.view.receive({...ordinary,hasItem:1,identified:0,baseItem:0});assert.equal(f.rows.at(-1).text,'Local Caster uses Unidentified Active item type');
 await f.view.receive({...ordinary,spellId:0xffffffff});assert.equal(f.rows.length,2);assert.deepEqual(f.reports,[]);
});

test('CC11 and CC8 share ordered client tokens and server TLK overrides without gameplay mutation',async()=>{
 const f=fixture(),before=JSON.stringify([...f.world.registry.objects]);await f.view.receive({type:71,data:{integers:{0:12,1:34}}});
 await f.view.receive({...ordinary,spellId:1});assert.equal(decodeGffText(f.world.customTokens.records.find(r=>r.id===1).bytes),'12');assert.equal(f.rows.at(-1).text,'Alternate Local Caster');
 f.world.apply({kind:'tlk-overrides',entries:[{strRef:10482,text:'Server template <CUSTOM2> / <CUSTOM0>'}]});await f.view.receive(ordinary);assert.equal(f.rows.at(-1).text,'Server template Active spell / Local Caster');assert.equal(JSON.stringify([...f.world.registry.objects]),before);assert.deepEqual(f.reports,[]);
});

test('disconnect during an async name fetch cannot leak token writes or messages into a replacement connection',async()=>{
 const f=fixture(),oldRaw=f.text.raw.bind(f.text);let release;f.text.raw=v=>v?.text==='Local'?new Promise(r=>release=r):oldRaw(v);
 const pending=f.view.receive(ordinary);while(!release)await Promise.resolve();f.view.reset();release('Stale');await pending;assert.equal(f.rows.length,0);assert.deepEqual(f.world.customTokens.records,[]);
});
