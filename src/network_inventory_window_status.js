// Original4ccd90 ->79d4f0, server13/1. These are raw protocol fields;
// primary/alternate visibility and local container mode belong to native UI.
export function readInventoryWindowStatus(reader){
 return {kind:'inventory-window-status',open:reader.readBool()!==0,ownerId:reader.readObjectIdClient()};
}

const INVALID=0x7f000000;
const empty=role=>({role,ownerId:INVALID,actorId:INVALID,areaId:INVALID,open:false,serial:0,receiptSerial:0,rawOwnerId:INVALID,receivedOpen:false,source:'uninitialized'});
// Protocol-owned window/repository relationships only. Native857cd0 visibility,
// focus, layout and local container-mode state are handled in Godot.
export class NetworkInventoryWindows{
 constructor(){this.primary=empty('primary');this.alternate=empty('alternate');this.serial=0;this.receiptSerial=0;this.rejected=null;}
 observe(world,message){
  if(typeof message.open!=='boolean'||!Number.isInteger(message.ownerId)||message.ownerId<0||message.ownerId>0xffffffff)throw Error('Invalid native inventory status');
  const raw=message.ownerId,role=raw===INVALID||raw===world.localObjectId?'primary':'alternate',previous=this[role],receipt=++this.receiptSerial;
  if(role==='alternate'){
   const creature=world.registry.get(raw);
   if(creature?.objectType!==5||creature.replicationRemoved){this.rejected={ownerId:raw,open:message.open,receiptSerial:receipt,actorId:world.localObjectId,areaId:world.areaId};return true;}
  }
  this.rejected=null;
  const duplicate=message.open?previous.open&&previous.ownerId===raw:!previous.open;
  const ownerId=message.open?(raw===INVALID?world.localObjectId:raw):previous.ownerId;
  this[role]={...previous,ownerId,actorId:world.localObjectId,areaId:world.areaId,open:message.open,serial:duplicate?previous.serial:++this.serial,receiptSerial:receipt,rawOwnerId:raw,receivedOpen:message.open,source:'server13/1'};
  if(role==='alternate'&&message.open)this.bindAlternate(world,previous.ownerId!==ownerId&&previous.ownerId!==INVALID);
  return true;
 }
 bindAlternate(world,replace){
  const owner=this.alternate.ownerId,creature=world.registry.get(owner);if(creature?.objectType!==5||creature.replicationRemoved)return;
  for(const channel of ['r','i']){
   let view=world.inventories.get(channel);if(!view){view={entries:[],ownerId:owner};world.inventories.set(channel,view);}
   if(replace){for(const entry of view.entries??[]){const item=world.registry.get(entry.id);if(item?.inventoryLocation?.channel===channel)item.inventoryLocationStatus='last-disclosed';}view.entries=[];delete view.stats;}
   view.ownerId=owner;
   for(const entry of view.entries??[]){const item=world.registry.get(entry.id);if(item?.objectType===6&&item.inventoryLocation?.channel===channel)item.inventoryLocation.ownerId=owner;}
   if(view.stats)Object.assign(creature.inventoryStats??={},view.stats);
  }
 }
 alternateOwner(world){const owner=this.alternate.ownerId,creature=world.registry.get(owner);return creature?.objectType===5&&!creature.replicationRemoved?owner:null;}
 requireAlternate(world,actor,ownerId,serial,receipt){
  const current=this.alternate;
  if(!current.open||current.actorId!==actor.id||current.areaId!==world.areaId||current.ownerId!==ownerId||current.serial!==serial||current.receiptSerial!==receipt||this.alternateOwner(world)!==ownerId)throw Error('Native alternate inventory window is retired');
  return {ownerId,serial,receiptSerial:receipt,actorId:actor.id};
 }
 closeAlternate(world,actor,token){this.requireAlternate(world,actor,token.ownerId,token.serial,token.receiptSerial);this.alternate={...this.alternate,open:false,serial:++this.serial,source:'client-close'};}
 snapshot(){return {primary:{...this.primary},alternate:{...this.alternate},rejected:this.rejected?{...this.rejected}:null};}
}
