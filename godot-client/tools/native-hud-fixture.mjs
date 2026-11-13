// Authored scripts for the owned two-player localhost HUD test. All effects,
// HP changes and expiry are executed by the unchanged original server.
import assert from 'node:assert/strict';
import {parseNcs} from '../../src/ncs.js';
export function addNativeHudScripts(entries,api,header){
 const code=[],patches=[];
 const integer=n=>{const b=Buffer.alloc(4);b.writeInt32BE(n);code.push(4,3,...b);};
 const real=n=>{const b=Buffer.alloc(4);b.writeFloatBE(n);code.push(4,4,...b);};
 const string=s=>{const b=Buffer.from(s,'ascii');code.push(4,5,b.length>>>8,b.length&255,...b);};
 const action=(name,count)=>{const row=api.find(v=>v.name===name);assert.ok(row,name);assert.equal(row.args.length,count,name);code.push(5,0,row.id>>>8,row.id&255,count);};
 const constant=name=>{const m=new RegExp('^int\\s+'+name+'\\s*=\\s*([0-9]+)\\s*;','m').exec(header);assert.ok(m,name);return Number(m[1]);};
 const command=(name,emit)=>{
  string('-native-hud-'+name);action('GetPCChatMessage',0);code.push(0x0b,0x23);const at=code.length;code.push(0x1f,0,0,0,0,0);
  emit();string('NATIVE_HUD_ACK:'+name);action('GetPCChatSpeaker',0);action('SendMessageToPC',2);code.push(0x20,0);patches.push({at,to:code.length});
 };
 const apply=(duration,emit)=>{real(duration);action('GetPCChatSpeaker',0);emit();integer(constant(duration?'DURATION_TYPE_TEMPORARY':'DURATION_TYPE_INSTANT'));action('ApplyEffectToObject',4);};
 // Execute these scripts as the actual PC, rather than queueing actions on
 // the module's chat-event OBJECT_SELF. The original server owns the queue.
 const installScript=(name,emit)=>{const begin=code.length;emit();code.push(0x20,0);const body=Buffer.from(code.splice(begin)),script=Buffer.alloc(13+body.length);script.write('NCS V1.0');script[8]=0x42;script.writeUInt32BE(script.length,9);script.set(body,13);parseNcs(script);entries.set(name+':2010',script);};
 const self=()=>code.push(4,6,0,0,0,0); // Original NCS CONST OBJECT_SELF.
 installScript('native_hud_queue',()=>{self();integer(1);action('ClearAllActions',2);integer(0);integer(0);string('native_speaker');action('GetObjectByTag',2);action('ActionAttack',2);});
 installScript('native_hud_qstop',()=>{self();integer(1);action('ClearAllActions',2);});
 for(const[name,script]of [['queue-start','native_hud_queue'],['queue-stop','native_hud_qstop']])command(name,()=>{action('GetPCChatSpeaker',0);string(script);action('ExecuteScript',2);});
 command('icon',()=>apply(8,()=>{integer(25);action('EffectIcon',1);}));
 command('temporary',()=>apply(6,()=>{integer(7);action('EffectTemporaryHitpoints',1);}));
 command('damage',()=>apply(0,()=>{integer(constant('DAMAGE_POWER_NORMAL'));integer(constant('DAMAGE_TYPE_MAGICAL'));integer(1);action('EffectDamage',3);}));
 command('heal',()=>apply(0,()=>{integer(1);action('EffectHeal',1);}));
 const bubbles=[['bubble-replace',1,'NATIVE_HUD_REPLACE'],['bubble-prefix',2,'<c\x01\xff\x01>NATIVE_HUD_PREFIX</c>\n'],['bubble-suffix',3,'\n<c\xff\x01\x01>NATIVE_HUD_SUFFIX</c>'],['bubble-clear',0,'']];
 for(const[name,mode,text]of bubbles)command(name,()=>{string(text);integer(mode);action('GetPCChatSpeaker',0);action('SetObjectTextBubbleOverride',3);});
 const objects=[['object-replace',1,'NATIVE_OBJECT_REPLACE'],['object-prefix',2,'NATIVE_OBJECT_PREFIX\n'],['object-suffix',3,'\nNATIVE_OBJECT_SUFFIX'],['object-hide',1,''],['object-clear',0,'']];
 for(const[name,mode,text]of objects)command(name,()=>{string(text);integer(mode);integer(0);string('native_chest');action('GetObjectByTag',2);action('SetObjectTextBubbleOverride',3);});
 const items=[['item-replace',1,'<c\x01\xff\x01>NATIVE_ITEM_REPLACE</c>'],['item-prefix',2,'NATIVE_ITEM_PREFIX\n'],['item-suffix',3,'\nNATIVE_ITEM_SUFFIX'],['item-hide',1,''],['item-clear',0,'']];
 for(const[name,mode,text]of items)command(name,()=>{string(text);integer(mode);action('GetPCChatSpeaker',0);integer(constant('INVENTORY_SLOT_CHEST'));action('GetItemInSlot',2);action('SetObjectTextBubbleOverride',3);});
 command('merchant-prefix',()=>{string('NATIVE_MERCHANT_PREFIX\n');integer(2);integer(0);string('native_stock_0');action('GetObjectByTag',2);action('SetObjectTextBubbleOverride',3);});
 // Original OnApplyPoison/OnApplyDisease roll a save before publishing any
 // status. The stock level15 fighter usually saves against Nightshade DC10.
 // Only this owned fixture PC receives a short saving-throw penalty and eight
 // original applications, so a natural20 does not normally mask HUD coverage.
 // Success still requires actual received flags; no effect is predicted.
 for(const [name,effect,type]of [['poison','EffectPoison','POISON_NIGHTSHADE'],['disease','EffectDisease','DISEASE_BLINDING_SICKNESS']])command(name,()=>{
  apply(1,()=>{integer(constant('SAVING_THROW_TYPE_ALL'));integer(100);integer(constant('SAVING_THROW_ALL'));action('EffectSavingThrowDecrease',3);});
  for(let i=0;i<8;i++)apply(6,()=>{integer(constant(type));action(effect,1);});
 });
 code.push(...entries.get('godot_chat:2010').subarray(13));const body=Buffer.from(code);for(const p of patches)body.writeInt32BE(p.to-p.at,p.at+2);
 const script=Buffer.alloc(13+body.length);script.write('NCS V1.0');script[8]=0x42;script.writeUInt32BE(script.length,9);script.set(body,13);parseNcs(script);entries.set('godot_chat:2010',script);
 return{commands:['queue-start','queue-stop','icon','temporary','damage','heal','poison','disease',...bubbles.map(row=>row[0]),...objects.map(row=>row[0]),...items.map(row=>row[0]),'merchant-prefix'],queue:{start:'native_hud_queue',stop:'native_hud_qstop',targetTag:'native_speaker',scope:'Original ActionAttack/ClearAllActions run as the actual PC; no authored queue replication or client-side action state.'},bubbles:bubbles.map(([command,mode,text])=>({command,mode,text})),objects:objects.map(([command,mode,text])=>({command,mode,text,targetTag:'native_chest'})),items:items.map(([command,mode,text])=>({command,mode,text,slot:'INVENTORY_SLOT_CHEST'})),merchant:{targetTag:'native_stock_0',mode:2,text:'NATIVE_MERCHANT_PREFIX\n'},icon:25,temporaryHitPoints:7,damage:1,statusFixture:{savingThrowPenalty:100,penaltySeconds:1,originalApplications:8},expirySeconds:{icon:8,temporary:6,poison:6,disease:6},scope:'Original-server scripts affect only their actual test PC speaker, its chest item or fixed owned chest/merchant fixtures; no fabricated replication or client-side effects.'};
}
