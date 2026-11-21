const test=require('node:test'),assert=require('node:assert/strict');
const {shortcutReconnectComplete,shortcutPhaseComplete}=require('./shortcut-reconnect-evidence.cjs');
function fixture(){
 const r={nativeLoaded:[],presentations:[],rendererErrors:[],actionRequests:[],skillDialogs:[],inventoryResults:[],shortcutPreparedUpdates:[],shortcutPhases:[],shortcutExports:[],characterReads:[],characterSaves:[],gameplayTest:{completed:true,checks:Array.from({length:16},()=>({passed:true}))},gameplayText:{examine:1,'dialog-entry':3,'dialog-close':2,floating:1},commands:[{kind:'examine'},...Array.from({length:3},()=>({kind:'reply'}))]};
 for(const [phase,connection]of [1,3].entries()){
  const actorId=9+phase,armor=20+phase*20,potion=21+phase*20;
  const bindings=Array.from({length:36},()=>({type:0}));
  for(const [index,type,intParam]of [[0,42,22],[12,3,4],[28,3,22],[29,3,10],[33,2,100],[34,1,0xff0000],[35,1,0xff00ff]])bindings[index]={type,intParam,...(type===1?{itemId:index===34?potion:armor}:{})};
  const t={completed:true,restored:Boolean(phase),checks:Array.from({length:phase?15:21},()=>({passed:true})),rows:bindings.map((b,index)=>({empty:b.type===0,label:'Slot'+index})),observations:{keyboardSlots:phase?[35,35,34,33,28]:[],before:{potion:3-phase,light:2},after:{potion:2-phase,light:1}}};
  const p={connection,actorId,test:t,bindings,serverStartLight:2,lightUses:1,items:[{index:34,id:potion,location:{channel:'R',ownerId:actorId,x:0,y:0},stack:2-phase},{index:35,id:armor,location:{channel:'I',ownerId:actorId,slot:2}}]};
  r.shortcutPreparedUpdates.push({connection,changes:[{ready:1},{ready:1}]});r.shortcutPhases.push(p);r.actionRequests.push({connection,operation:'useItem',itemId:potion,propertyIndex:0,variant:255},{connection,operation:'castSpell',spellId:100,beforeUses:2},{connection,operation:'useSkill',packedSkill:22,targetId:actorId});
  for(const kind of ['dialog-entry','dialog-replies','dialog-close'])r.skillDialogs.push({connection,kind});
  for(const operation of ['equip','unequip'])r.inventoryResults.push({connection,itemId:armor,operation,success:true});
  r.nativeLoaded.push({connection,areaId:7,generation:1});r.presentations.push({connection,areaId:7,generation:1,screenshot:'authored.png',distance:1,cameraFollow:true,animation:{changed_local_parts:1,maximum_local_skin_vertex_delta:0.1}});
  for(let i=0;i<(phase?1:2);i++){
   const sha256='hash'+r.characterSaves.length;r.characterSaves.push({connection,id:'isolated',sha256});
   const rows=bindings.map(b=>({QBObjectType:b.type,QBINTParam1:b.intParam}));
   Object.assign(rows[33],{QBMultiClass:0,QBMetaType:0,QBDomainLevel:0});
   Object.assign(rows[34],{QBCastPropIndex:0,QBCastSubPropIdx:255,QBItemInvSlot:0xffffffff,QBItemReposX:0,QBItemReposY:0});
   Object.assign(rows[35],{QBCastPropIndex:255,QBCastSubPropIdx:255,QBItemInvSlot:2,QBItemReposX:255,QBItemReposY:255});
   r.shortcutExports.push({connection,sha256,rows,lightPrepared:[0,1]});
  }
 }
 r.characterReads.push({connection:3,source:'vault',sha256:r.characterSaves[1].sha256});return r;
}
test('shortcut reconnect acceptance needs both actual phases, independent exports and the saved-character read',()=>{
 const r=fixture();assert.equal(shortcutReconnectComplete(r),true);
 for(const mutate of [v=>v.shortcutPhases.pop(),v=>v.shortcutExports.pop(),v=>v.characterReads[0].sha256='other',v=>v.characterSaves[2].id='other',v=>v.shortcutPhases[1].connection=1]){const c=structuredClone(r);mutate(c);assert.equal(shortcutReconnectComplete(c),false);}
});
test('restored item shortcuts must resolve current owned inventory and retain exact property indices',()=>{
 const r=fixture();for(const mutate of [p=>p.items[0].id=21,p=>p.items[0].location.ownerId=9,p=>p.bindings[34].intParam=1,p=>p.bindings[35].intParam=0,p=>p.test.checks[0].passed=false,p=>p.test.observations.keyboardSlots.pop()]){const p=structuredClone(r.shortcutPhases[1]);mutate(p);assert.equal(shortcutPhaseComplete(r,p),false);}
});
test('UI completion cannot substitute for actual skill, item, cast and server-dialog records',()=>{
 const r=fixture();for(const mutate of [v=>v.actionRequests.pop(),v=>v.actionRequests[0].propertyIndex=1,v=>v.skillDialogs.pop(),v=>v.inventoryResults.pop(),v=>v.shortcutPhases[1].lightUses=0]){const c=structuredClone(r);mutate(c);assert.equal(shortcutReconnectComplete(c),false);}
});
test('saved quickbar records must retain family fields, cleared move sources and inventory locations',()=>{
 const r=fixture();for(const mutate of [v=>v.shortcutExports[2].rows[28].QBINTParam1=4,v=>v.shortcutExports[0].rows[31].QBObjectType=3,v=>v.shortcutExports[1].rows[34].QBCastSubPropIdx=0,v=>v.shortcutExports[2].rows[35].QBItemInvSlot=4]){const c=structuredClone(r);mutate(c);assert.equal(shortcutReconnectComplete(c),false);}
});
test('shortcut acceptance rejects restored uses, missing native movement and shutdown leaks',()=>{
 const r=fixture();for(const mutate of [v=>v.shortcutPhases[1].test.observations.before.light=3,v=>v.presentations[1].animation.maximum_local_skin_vertex_delta=0,v=>v.nativeErrors='ObjectDB instances were leaked',v=>v.nativeExit=1,v=>v.rejectedCommands=[{}],v=>v.shortcutPreparedUpdates[1].changes[0].ready=0]){const c=structuredClone(r);mutate(c);assert.equal(shortcutReconnectComplete(c),false);}
});
