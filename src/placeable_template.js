import {nativeItemTag} from './item_stack_compare.js';
const empty=()=>({strRef:0xffffffff,entries:[]}),INVALID=0x7f000000;

// Complete LoadPlaceable1404b4900..1404b6702. Typed GFF, strings, tag
// sanitation, inventory and the five visual loaders are explicit boundaries.
// Position/orientation belong to the caller, not this data owner.
export async function loadPlaceableData(object,loading,newTag,p){
 const R=async(kind,name,fallback)=>(await p.read(kind,name,fallback)).value;
 const F=(offset)=>p.field(object,offset);
 const W=(offset,value,width=4)=>p.field(object,offset,value,width);
 const field=async(kind,name,offset,fallback=0,width=4)=>W(offset,await R(kind,name,fallback),width);
 const string=async(name,offset)=>p.string(object,offset,await R('string',name,''));
 const resref=async(name,offset)=>p.resref(object,offset,await R('resref',name,''));
 let tag=newTag;
 if(tag===null||nativeItemTag(tag).length===0)tag=await p.asTag(await R('string','Tag',''));
 await p.setTag(object,tag);
 await resref('TemplateResRef',0x568);await p.setTemplate(object,await p.resref(object,0x568));
 await p.localized(object,0x308,await R('localized','LocName',empty()));
 await field('bool','AutoRemoveKey',0x3a4);await field('dword','Faction',0x350);await string('DisplayName',0x318);
 let plot=await p.read('bool','Invulnerable',F(0xfc)&255);
 if((plot.status|0)===0)plot=await p.read('bool','Plot',F(0xfc)&255);
 await field('byte','OpenLockDC',0x3a8,0,1);await string('KeyName',0x380);
 for(const[kind,name,offset,width]of[
  ['bool','TrapDisarmable',0x3bc,4],['bool','TrapDetectable',0x3c0,4],['byte','DisarmDC',0x3b8,1],
  ['byte','TrapDetectDC',0x3b0,1],['bool','TrapFlag',0x3b4,4],['bool','TrapOneShot',0x3c4,4],
 ])await field(kind,name,offset,0,width);
 await field('byte','TrapType',0x3d0,F(0x3d0)&255,1);
 await field('bool','TrapRecoverable',0x3c8,F(0x3c8)&255);await field('bool','TrapActive',0x3d4,F(0x3d4)&255);
 await field('dword','TrapFaction',0x3d8);await field('dword','TrapCreator',0x3ac,INVALID);await field('dword','LootCreature',0x510,INVALID);
 await field('bool','IsBodyBag',0x514);await field('bool','Useable',0x264);
 const fixed=await p.read('bool','Static',0),isStatic=F(0x5a4)===1?0:(fixed.status|0)!==0?fixed.value:Number(F(0x264)!==1);
 W(0x5a0,isStatic);W(0xfc,isStatic===1?1:plot.value);
 await field('dword','Appearance',0x32c,0,2);await field('short','HP',0xe4);await field('short','CurrentHP',0xe0);
 for(const[name,offset]of[['Hardness',0x370],['Fort',0x4e0],['Will',0x4e1],['Ref',0x4e2]])await field('byte',name,offset,0,1);
 for(const[name,offset]of[['Lockable',0x500],['Locked',0x378],['HasInventory',0x4f8],['KeyRequired',0x3a0]])await field('bool',name,offset);
 await string('KeyRequiredFeedbackMessage',0x390);await field('byte','CloseLockDC',0x3a9,0,1);
 const portrait=await R('word','PortraitId',65535);
 if(portrait<65534)await p.portraitId(object,portrait);else await p.portrait(object,await R('resref','Portrait',''));
 await resref('Conversation',0x354);await field('byte','BodyBag',0x59c,F(0x59c)&255,1);await field('bool','DieWhenEmpty',0x504);
 await R('bool','GroundPile',F(0x368)&255);W(0x368,1);
 const light=await R('bool','LightState',(await p.light(object))&255);
 if(F(0x594)!==light&&(await p.lightColor(F(0x32c)&65535,'LightColor')).status!==0){W(0x594,light);W(0x598,1);}
 await p.localized(object,0x330,await R('localized','Description',empty()));
 await string('DescriptionOverride',0x340);await string('Portal',0x580);
 for(const[name,offset]of[
  ['OnClosed',0x3e0],['OnDamaged',0x3f0],['OnDeath',0x400],['OnDisarm',0x410],['OnHeartbeat',0x420],
  ['OnInvDisturbed',0x430],['OnLock',0x440],['OnMeleeAttacked',0x450],['OnOpen',0x460],['OnSpellCastAt',0x470],
  ['OnUnlock',0x490],['OnUsed',0x4a0],['OnUserDefined',0x4b0],['OnDialog',0x4c0],['OnTrapTriggered',0x480],['OnClick',0x4d0],
 ])await p.string(object,offset,await R('resref',name,''));
 const script=await p.getScript(object,10);
 if(script===null||nativeItemTag(await p.getScript(object,10)).length===0||
    (await p.getScript(object,10)).split('\0')[0]==='default')await p.string(object,0x480,await p.trapScript(F(0x3d0)&255,'TrapScript'));
 let animation=await p.read('int','Animation',0);
 if((animation.status|0)!==0)await p.animation(object,animation.value);
 else{animation=await p.read('byte','AnimationState',0);if((animation.status|0)!==0)await p.animation(object,[0,75,76,72,73,74][animation.value]??0);}
 const list=await p.list('ItemList');
 if(list.status===1)for(let i=0,count=await p.count(list);i<count;i++){
  const row=await p.element(list,i),id=loading!==0?(await p.readItem(row,'dword','ObjectId',INVALID)).value:INVALID;
  const item=await p.newItem(id);if(!item)continue;
  if((await p.loadItem(item,row,loading,0))===0){await p.destroyItem(item,1);continue;}
  const x=(await p.readItem(row,'word','Repos_PosX',65535)).value&255,y=(await p.readItem(row,'word','Repos_Posy',65535)).value&255;
  await p.acquire(object,{item},INVALID,x,y,1);
 }
 await field('dword','AnimationDay',0xcc);await field('dword','AnimationTime',0xd0);
 for(const owner of[0x140497bb0,0x140496ea0,0x140497990,0x1404969c0,0x1404972b0])await p.visual(object,owner);
 await p.loadUUID(object);await p.addTag(object);return 1;
}
