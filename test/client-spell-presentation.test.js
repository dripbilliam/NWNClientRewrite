import test from 'node:test';
import assert from 'node:assert/strict';
import {ClientSpellPresentation,plainSpellMessage} from '../src/client_spell_presentation.js';
import {OBJECT_INVALID} from '../src/game_object_array.js';
function fixture(){
 const player={id:99,name:'Caster',objectType:5},item={id:100,objectType:6,authored:{LocalizedName:{strRef:0xffffffff,entries:[{languageId:0,text:'Original item'}]}}},objects=new Map([[99,player],[100,item]]),client={object:player},tokens={records:[]},messages=[],diagnostics=[];
 const spells={columns:['Name','AltMessage'],orderedRows:[{Name:'123',AltMessage:'0'}],defaultValue:'****'},baseitems={columns:['Name'],orderedRows:[{Name:'321'}],defaultValue:'****'},session={player,registry:{get:id=>objects.get(id)},characterRules:{spells,baseitems},combat:{broadcastProviders:()=>({client:()=>client})},talkTable:{tokensForClient:()=>tokens,parseClient:text=>text.replace(/<CUSTOM(\d+)>/g,(_m,id)=>new TextDecoder('windows-1252').decode(tokens.records.find(r=>r.id===Number(id))?.bytes??new Uint8Array()))}};
 const text={strRef:ref=>({123:'Spell',321:'Base item',8127:'casting',1501:'casts',1502:'unknown spell',63264:'uses',63265:'a <CUSTOM0>',10482:'<CUSTOM0> <CUSTOM1> <CUSTOM2>'})[ref],resolve:v=>v.entries?.[0]?.text??''},p=new ClientSpellPresentation({session:()=>session,text:()=>text,display:(text,event)=>messages.push({text,event}),report:(code,message)=>diagnostics.push({code,message})});
 return{p,player,item,objects,tokens,messages,diagnostics};
}
test('queued item notification snapshots authored localized name before consumption; client reserved tokens leave server objects untouched',()=>{
 const f=fixture();f.p.receive({type:8,recipientId:99,data:{objects:[99,100],integers:[0,1,0]}});f.item.authored.LocalizedName.entries[0].text='Changed';f.objects.delete(100);assert.equal(f.p.pending.length,1);f.p.flush();assert.equal(f.messages[0].text,'Caster uses Original item');assert.equal(f.player.id,99);assert.equal(f.tokens.records.length,3);assert.equal(f.diagnostics.filter(d=>d.code==='spell.client-message-failed').length,0);
});
test('ordinary start/release and unidentified messages use native TLK templates and do not expose spell names for unidentified recipients',()=>{
 const f=fixture();for(const [identified,casting]of [[1,1],[1,0],[0,1]])f.p.receive({type:8,recipientId:99,data:{objects:[99,OBJECT_INVALID],integers:[0,identified,casting]}});f.p.flush();assert.deepEqual(f.messages.map(m=>m.text),['Caster casting Spell','Caster casts Spell','Caster casting unknown spell']);assert.equal(f.diagnostics.filter(d=>d.code==='spell.client-richtext-adapter-incomplete').length,1);
});
test('recipient filtering, native malformed-item overflow and markup stripping retain diagnostics without interpreting HTML',()=>{
 const f=fixture();assert.equal(f.p.receive({type:7}),false);f.p.receive({type:8,recipientId:100,data:{}});assert.equal(f.p.pending.length,0);
 f.objects.delete(100);f.p.receive({type:8,recipientId:99,data:{objects:[99,100],integers:[0,1,0]}});f.p.flush();assert.equal(f.messages.length,0);assert.ok(f.diagnostics.some(d=>d.code==='spell.client-message-failed'));assert.ok(f.diagnostics.some(d=>d.code==='spell.client-item-message-warning'));
 assert.equal(plainSpellMessage('<c\u0099\u00ff\u00ff><img src=x></c>'),'<img src=x>');
});
