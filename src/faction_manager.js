import { NativeIdList } from './native_id_list.js';
import { OBJECT_INVALID } from './game_object_array.js';

const integer=(v,name)=>{if(!Number.isInteger(v))throw new Error(`Native faction ${name} is unavailable`);return v|0;};
const id=v=>{if(!Number.isInteger(v)||v<0||v>0xffffffff)throw new Error('Native faction OBJECT_ID is unavailable');return v>>>0;};
const required=(p,name)=>{if(typeof p[name]!=='function')throw new Error(`Native faction provider ${name} is unavailable`);return p[name];};
const emptyFaction=()=>({members:new NativeIdList(),name:'',field18:0,global:1});

// CFactionManager1403572c0, GetFaction140357900, DeleteFaction140357770.
// Slots are references to faction owners, not game objects. Delete leaves a
// null slot: neither IDs nor count compact, and the next append never reuses it.
export class NativeFactionManager {
  constructor(){this.slots=[];this.count=0;this.capacity=0;this.npcCount=0;
    this.defaultPC=null;this.defaultHostile=null;this.defaultCommoner=null;this.defaultMerchant=null;this.defaultDefender=null;}
  append(faction){
    // CExoArrayList<CNWSFaction*>::Add1404ad640 (16, then doubling).
    if(this.count===this.capacity){this.capacity=this.capacity===0?16:this.capacity*2;this.slots.length=this.capacity;}
    faction.id=this.count;this.slots[this.count++]=faction;return faction;
  }
  get(value){value=integer(value,'index');return value>=0&&value<this.count?this.slots[value]:null;}
  isNPC(value){value=integer(value,'NPC index');return value>0&&value<=this.npcCount;}
  delete(value){value=integer(value,'deleted index');if(value<0||value>=this.count)throw new Error('Native faction delete index is out of range');this.slots[value]=null;}
  create(){const faction=this.append(emptyFaction());if(faction.id>0)this.npcCount++;return faction;}
  load(entries){
    if(this.count!==0||!Array.isArray(entries))throw new Error('Native FAC faction load requires an empty manager');
    // LoadFactions140357d20..140357f32; physical FAC order determines IDs.
    for(let index=0;index<entries.length;index++){
      const entry=entries[index],faction=this.create();
      faction.name=String(entry.FactionName??'');faction.parentId=(entry.FactionParentID??0)>>>0;
      faction.global=entry.FactionGlobal===undefined?1:integer(entry.FactionGlobal,'global flag')&65535;
      if(index===1)this.defaultHostile=faction;
      else if(index===2)this.defaultCommoner=faction;
      else if(index===3)this.defaultMerchant=faction;
      else if(index===4)this.defaultDefender=faction;
    }
  }
  createDefaults(){
    if(this.count!==0)throw new Error('Native default factions require an empty manager');
    // CreateDefaultFactions140357570. Its commoner/defender indices differ
    // from loaded FAC pointers. Parent +14 is not written by these ctors.
    this.defaultPC=this.create();this.defaultHostile=this.create();this.defaultMerchant=this.create();
    this.defaultDefender=this.create();this.defaultCommoner=this.create();
  }
  members(actor){const faction=this.get(actor.factionId);if(!faction)throw new Error('Native creature faction owner is unavailable');return faction.members;}
  member(faction,start,pcOnly,creature){
    // GetFactionMember1404ae1b0 updates +18 ONLY after a successful result.
    // Exhaustion retains the prior cursor, so live appends remain visible.
    start=integer(start,'iterator index');pcOnly=integer(pcOnly,'iterator PC filter');
    if(start<0)throw new Error('Native faction iterator index would underflow');
    for(let index=start;index<faction.members.count;index++){
      const member=creature(faction.members.ids[index]);
      if(member&&(pcOnly===0||integer(member.nativeStatsIsPCb0,'member stats PC flag')!==0)){
        faction.field18=index+1;return faction.members.ids[index];
      }
    }
    return OBJECT_INVALID;
  }
  async createForObject(objectId,p){
    // CNWSFaction(uint32)1404ad3e0..1404ad516. Old GetFaction is queried
    // twice; RemoveMember can itself construct a private faction.
    const actor=required(p,'creature')(id(objectId));if(!actor)throw new Error('Native private faction creature is unavailable');
    const faction=emptyFaction();
    if(this.get(actor.factionId))await this.removeMember(this.get(actor.factionId),objectId,p);
    faction.members.append(id(objectId));this.append(faction);
    if(integer(required(p,'pc')(actor),'object PC')===0&&integer(required(p,'possessed')(actor),'possession')===0)this.npcCount++;
    actor.factionId=faction.id;await required(p,'bringAssociates')(actor,faction.id);return faction;
  }
  async addMember(faction,objectId,suppressUpdate,p){
    // AddMember1404ad6b0..1404ad959. All loops observe live member storage.
    objectId=id(objectId);suppressUpdate=integer(suppressUpdate,'update flag');
    if(!faction)throw new Error('Native destination faction is unavailable');
    const actor=required(p,'creature')(objectId);if(!actor){required(p,'warning')('Native AddMember creature lookup failed');return;}
    const previous=this.get(actor.factionId);if(previous===faction)return;
    if(previous)await this.removeMember(previous,objectId,p);
    const joining=required(p,'client')(objectId);
    if(faction.members.count>0&&joining){
      for(let i=0;i<faction.members.count;i++){
        const memberId=faction.members.ids[i],member=required(p,'creature')(memberId);
        if(member&&(integer(required(p,'pc')(member),'member PC')!==0||integer(required(p,'possessed')(member),'member possession')!==0))
          await required(p,'setLikes')(actor,memberId,1,1);
        const client=required(p,'client')(memberId);
        if(client){await required(p,'attitude')(joining,client,1);await required(p,'attitude')(client,joining,1);}
      }
    }
    if(suppressUpdate===0)for(let i=0;i<faction.members.count;i++){
      const client=required(p,'client')(faction.members.ids[i]);
      if(client)await required(p,'partyList')(client,[objectId],3,faction.members.ids[i]);
    }
    if(faction.members.indexOf(objectId)<0)faction.members.append(objectId);
    actor.factionId=faction.id;await required(p,'bringAssociates')(actor,faction.id);
    if(joining)await required(p,'partyList')(joining,faction.members.view(),1,objectId);
  }
  async removeMember(faction,objectId,p){
    // RemoveMember1404af120..1404af5ac. Contains protects the private ctor's
    // recursive old-faction RemoveMember after the ID has already been removed.
    objectId=id(objectId);if(!faction)throw new Error('Native source faction is unavailable');
    const actor=required(p,'creature')(objectId);if(!actor||faction.members.indexOf(objectId)<0)return;
    const leaving=required(p,'client')(objectId);
    if(faction.members.count>1&&leaving)for(let i=0;i<faction.members.count;i++){
      const memberId=faction.members.ids[i];if(memberId===objectId)continue;
      const member=required(p,'creature')(memberId);
      if(member&&(integer(required(p,'pc')(member),'member PC')!==0||integer(required(p,'possessed')(member),'member possession')!==0)&&id(member.masterId)!==objectId)
        await required(p,'setLikes')(member,objectId,1,1);
      const client=required(p,'client')(memberId);
      if(client){await required(p,'attitude')(leaving,client,1);await required(p,'attitude')(client,leaving,1);}
    }
    faction.members.remove(objectId);
    if(integer(required(p,'pc')(actor),'object PC')!==0||integer(required(p,'possessed')(actor),'possession')!==0){
      const privateFaction=await this.createForObject(objectId,p);
      for(let i=0;i<privateFaction.members.count;i++){
        const memberId=privateFaction.members.ids[i],client=required(p,'client')(memberId);
        if(client)await required(p,'partyList')(client,privateFaction.members.view(),1,memberId);
      }
    }
    if(faction.members.count===0){
      if(!this.isNPC(faction.id)&&integer(required(p,'statsPC')(actor),'stats PC')===1)this.delete(faction.id);
    }else for(let i=0;i<faction.members.count;i++){
      const client=required(p,'client')(faction.members.ids[i]);
      if(client)await required(p,'partyList')(client,[objectId],4,OBJECT_INVALID);
    }
  }
}

// PostProcess14039b5af..14039b736, ordinary NPC and private-PC branches.
// DM and auto-party/reprocessing owners remain explicit providers.
export async function initializeCreatureFaction(actor,manager,p){
  if(!(manager instanceof NativeFactionManager))throw new Error('Native faction manager is unavailable');
  if(integer(required(p,'dm')(actor),'DM')===1)throw new Error('Native DM PostProcess faction initialization is not implemented');
  if(integer(required(p,'pc')(actor),'object PC')!==0||integer(required(p,'possessed')(actor),'possession')!==0){
    const faction=await manager.createForObject(actor.id,p);actor.factionId=faction.id;actor.originalFactionId=faction.id;
    await required(p,'reprocessAssociates')(actor);await required(p,'autoParty')(actor,manager);
  }else{
    const imported=integer(actor.factionId,'imported index');actor.factionId=-1;
    if(manager.isNPC(imported)){await manager.addMember(manager.get(imported),actor.id,0,p);actor.originalFactionId=imported;}
    else await manager.addMember(manager.defaultHostile,actor.id,0,p);
  }
}
