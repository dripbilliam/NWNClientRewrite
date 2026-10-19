import {localSpellMessageFields,localSpellMessageReader,receiveSpellCombatMessage} from './client_spell_message.js';
import {OBJECT_INVALID} from './game_object_array.js';
import {intEntry} from './combat_stats.js';
import {setCustomToken} from './custom_tokens.js';
import {scriptStringBytes} from './script_string.js';

const canonicalId=id=>(id>>>0)===OBJECT_INVALID?OBJECT_INVALID:(id&0x7fffffff)>>>0;
export const plainSpellMessage=text=>text.replace(/<c[\s\S]{3}>|<\/c>/g,'');

// Owned local delivery queue: resolve item-name fields at send time, before a
// consumed item can disappear; resolve client names/TLK at presentation time.
// Native packet framing, rich widget layout and network replication remain
// separate owners. Reserved token cells are client-local, never broadcast back.
export class ClientSpellPresentation{
 constructor({session,text,display,report}){Object.assign(this,{session,text,display,report});this.pending=[];this.events=[];this.reported=new Set();}
 receive(event){
  if(event.type!==8)return false;const session=this.session();if(event.recipientId!==session.player?.id)return true;
  try{
   const fields=localSpellMessageFields(event.data,{item:id=>{const o=session.registry.get(id);return o?.objectType===6?o:null;},
    itemName:item=>({localized:item.authored?.LocalizedName??{strRef:0xffffffff,entries:[]},override:item.nativeNameOverride430??''}),warning:(message,data)=>this.report('spell.client-item-message-warning',message,data)});
   this.pending.push({session,recipientId:event.recipientId,fields:structuredClone(fields)});
  }catch(error){this.report('spell.client-message-failed',error.message,{recipientId:event.recipientId,stack:error.stack});}
  return true;
 }
 once(code,message,data){if(!this.reported.has(code)){this.reported.add(code);this.report(code,message,data);}}
 flush(){
  const session=this.session(),text=this.text();
  for(const packet of this.pending.splice(0)){
   if(packet.session!==session||packet.recipientId!==session.player?.id){this.report('spell.client-message-stale','Spell notification belongs to an old session',{});continue;}
   try{
    const client=session.combat.broadcastProviders().client(session.player.id);if(!client)throw new Error('Native spell notification client is unavailable');
    const tlk=ref=>text.strRef(ref>>>0)??'',tokenState=session.talkTable.tokensForClient(client),parse=ref=>session.talkTable.parseClient(tlk(ref),{actor:session.player,gender:0,resolveName:v=>text.resolve(v)}),reader=localSpellMessageReader(packet.fields);
    const handled=receiveSpellCombatMessage({...reader,localizedString:()=>text.resolve(reader.localizedString()),
     spell:id=>{const table=session.characterRules.spells,rows=table.orderedRows??[...table.rows.values()];return id>=0&&id<rows.length?{name:intEntry(table,id,'Name').value,altMessage:intEntry(table,id,'AltMessage').value}:null;},
     sourceName:id=>{const o=session.registry.get(canonicalId(id));return o?o.name??'':null;},player:()=>session.player?{id:(session.player.id|0x80000000)>>>0}:null,
     tlk,token:(id,value)=>setCustomToken(tokenState,id,scriptStringBytes(value)),parse,
     baseItemName:id=>{const table=session.characterRules.baseitems,rows=table?.orderedRows??[];if(id<0||id>=rows.length)throw new Error('Native CC8 base item lookup is unavailable');return tlk(intEntry(table,id,'Name').value);},
     display:(raw,color,unknown,channel,resource)=>{
      const event={sourceId:packet.fields[0].value,spellId:packet.fields[1].value,identified:packet.fields[2].value,casting:packet.fields[3].value,hasItem:packet.fields[4].value,raw,text:plainSpellMessage(raw),color,unknown,channel,resource};this.events.push(event);if(this.events.length>64)this.events.shift();this.display(event.text,event);
      if(raw)this.once('spell.client-richtext-adapter-incomplete','Native spell templates and reserved tokens are active; the log currently displays their plain text without native widget colors/layout',{});
     }});
    if(!handled)throw new Error('Native spell notification read overflow');
   }catch(error){this.report('spell.client-message-failed',error.message,{recipientId:packet.recipientId,stack:error.stack});}
  }
 }
 snapshot(){return{pending:this.pending.length,events:this.events};}
}
