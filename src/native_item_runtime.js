import {OBJECT_INVALID} from './game_object_array.js';
import {intEntry} from './combat_stats.js';
import {ItemRepository} from './item_repository.js';
import {applyItemProperty,importedPropertyEffect,ItemPropertyIds} from './item_property_pool.js';
import {updateItemActiveUseCache,selectItemVisual} from './item_presentation_state.js';
import {computeItemUnitWeight} from './inventory_weight.js';
import {parse2da} from './area.js';
import {RESOURCE_TYPE,decodeResourceText} from './resource_archive.js';
import {cloneGff} from './gff.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';

export const nativeArmorPartFields=['ArmorPart_RFoot','ArmorPart_LFoot','ArmorPart_RShin','ArmorPart_LShin','ArmorPart_LThigh','ArmorPart_RThigh','ArmorPart_Pelvis','ArmorPart_Torso','ArmorPart_Belt','ArmorPart_Neck','ArmorPart_RFArm','ArmorPart_LFArm','ArmorPart_RBicep','ArmorPart_LBicep','ArmorPart_RShoul','ArmorPart_LShoul','ArmorPart_RHand','ArmorPart_LHand','ArmorPart_Robe'];
export const nativePaletteFields=['Leather1Color','Leather2Color','Cloth1Color','Cloth2Color','Metal1Color','Metal2Color'];
const propertyData=p=>({PropertyName:p.type,Subtype:p.subtype,CostTable:p.costTable,CostValue:p.costValue,Param1:p.param1,Param1Value:p.param1Value,
  UsesPerDay:p.usesPerDay,ChanceAppear:p.chance,Useable:p.remaining,CustomTag:p.customTag});
export function canonicalItemData(item){
  if(!item.nativeItemLoaded)return item.authored;
  return {...item.authored,BaseItem:item.baseItem,StackSize:item.stackSize,Charges:item.charges,Identified:item.identified,Dropable:item.droppable,
    Pickpocketable:item.pickpocketable,Plot:item.plot,Stolen:item.stolen,Cursed:item.cursed,PropertiesList:[...item.activeProperties,...item.passiveProperties].map(propertyData)};
}

// Fresh CNWSItem/LoadDataFromGff state. Full Equip/Acquire and saved-effect
// import remain separate owners; this class never manufactures possession.
export class NativeItemRuntime {
  constructor(session){this.session=session;this.propertyIds=new ItemPropertyIds();this.tables=new Map();this.baseTables=new WeakMap();}
  initialize(item){
    if(item.objectType!==6)throw new Error('Native item constructor requires an item');
    item.baseItem??=24;item.identified??=0;item.charges??=50;item.stackSize??=1;item.stolen??=0;
    item.nativePriceDirty398??=1; // CNWSItem ctor14046300b.
    item.droppable??=1;item.pickpocketable??=1;item.plot??=0;item.repositoryX??=0;item.repositoryY??=0;
    item.cursed??=0; // LoadData14046a193..1b4 uses distinct INT450, not plot144.
    item.possessorId=(item.possessorId??item.ownerId??OBJECT_INVALID)>>>0;
    Object.defineProperty(item,'ownerId',{enumerable:true,configurable:true,get(){return this.possessorId;},set(value){this.possessorId=value>>>0;}});
    item.activeProperties??=[];item.passiveProperties??=[];item.effects??=[];item.nativeRepository??=null;
    item.activeUseMask??=0;item.activeUseBytes??=Array(8).fill(0);item.nativeVisual462??=0;
    item.modelParts??=Array(3).fill(0);item.armorParts??=Array(19).fill(0);item.colors??=Array(6).fill(0);
  }
  baseInfo(item){
    const table=this.session.characterRules?.baseitems;if(!table)throw new Error('Native item baseitems ownership is unavailable');
    const base=item.baseItem|0,count=table.orderedRows?.length??table.rows.size;if(base<0||base>=count)return null;
    if(!this.baseTables.has(table))this.baseTables.set(table,new Map());const cache=this.baseTables.get(table);if(cache.has(base))return cache.get(base);
    const read=name=>intEntry(table,base,name).value;
    const requiredFeats=[];for(let index=0;index<5;index++){const feat=intEntry(table,base,`ReqFeat${index}`);if(feat.found)requiredFeats.push(feat.value&65535);}
    const info={modelType:read('ModelType')&255,basePropColumn:read('BasePropColumn')&255,width:read('InvSlotWidth')&255,height:read('InvSlotHeight')&255,
      stacking:read('Stacking')&65535,container:read('Container'),weaponWield:read('WeaponWield')&255,weaponType:read('WeaponType')&255,weaponSize:read('WeaponSize')&255,
      equipableSlots:read('EquipableSlots'),ranged:read('RangedWeapon')&255,arcaneSpellFailure:read('ArcaneSpellFailure')&255,requiredFeats};
    cache.set(base,info);return info;
  }
  async table(name){
    name=String(name).toLowerCase();if(!this.tables.has(name))this.tables.set(name,this.session.resolver.getResource(name,RESOURCE_TYPE.TWO_DA).then(bytes=>parse2da(decodeResourceText(bytes))).catch(error=>{
      runtimeDiagnostics.record('rules.item-table-unavailable',`${name}.2da: ${error.message}`,{resource:name,stack:error.stack});return null;
    }));return this.tables.get(name);
  }
  async weight(item){
    const rules=this.session.characterRules;
    for(const property of item.passiveProperties)if(property.type===11&&!rules.itemCosts?.has(property.costTable)){
      if(!rules.iprp_costtable)throw new Error('Native item weight cost-table definitions are unavailable');
      const row=(rules.iprp_costtable.orderedRows??[...rules.iprp_costtable.rows.values()])[property.costTable],name=row?.Name;
      if(!name||name==='****')throw new Error('Native item weight cost-table resource is unavailable');
      const table=await this.table(name);if(!table)throw new Error('Native item weight cost table failed to load');
      rules.itemCosts??=new Map();rules.itemCosts.set(property.costTable,table);
    }
    return computeItemUnitWeight({...item,authored:canonicalItemData({...item,nativeItemLoaded:true}),temporaryProperties:undefined},rules);
  }
  async costTable(id){
    const rules=this.session.characterRules;if(rules.itemCosts?.has(id))return rules.itemCosts.get(id);
    if(!rules.iprp_costtable)throw new Error('Native item cost-table definitions are unavailable');
    const row=(rules.iprp_costtable.orderedRows??[...rules.iprp_costtable.rows.values()])[id],name=row?.Name;
    if(!name||name==='****')throw new Error(`Native item cost table${id} resource is unavailable`);
    const table=await this.table(name);if(!table)throw new Error(`Native item cost table${id} failed to load`);
    rules.itemCosts??=new Map();rules.itemCosts.set(id,table);return table;
  }
  async activeChanged(item,force){
    const state=updateItemActiveUseCache(item,force);if(!state.updated)return;
    const client=this.session.combat.broadcastProviders().client(item.possessorId);
    if(client)runtimeDiagnostics.record('items.active-use-message-unimplemented','Native active item use cache updated; full/delta client message presentation is unavailable',
      {...this.session.diagnosticContext(item.id),full:state.full,mask:state.mask,changedMask:state.changedMask,uses:state.uses});
  }
  async propertyChanged(item){
    item.nativeUnitWeight45c=await this.weight(item);
    const creature=this.session.registry.get(item.possessorId);
    if(creature?.objectType===5)throw new Error('Native possessed-item property propagation/equipment spell-slot refresh is unavailable');
    item.nativeVisual462=await selectItemVisual(item,this.session.characterRules,{baseInfo:i=>this.baseInfo(i),subtypeTable:name=>this.table(name)});
    if(item.nativeVisual462!==0)runtimeDiagnostics.record('items.visual-unimplemented','Native item visual selected; weapon-attached visual rendering is unavailable',
      {...this.session.diagnosticContext(item.id),visual:item.nativeVisual462});
  }
  async loadData(item,data,{insideContainer=0}={}){
    if(item.nativeItemLoaded)throw new Error('Native item reload/removal of existing property owners is unavailable');
    item.authored=cloneGff(data);item.baseItem=(data.BaseItem??24)>>>0;
    const info=this.baseInfo(item);if(!info)throw new Error('Native item LoadDataFromGff: invalid base item type');
    if(insideContainer!==0&&info.container!==0)throw new Error('Native item LoadDataFromGff: a container cannot be placed inside another container');
    if(data.EffectList?.length)throw new Error('Native saved item effect import is unavailable');
    item.identified=Number((data.Identified??item.identified)!==0);item.stackSize=(data.StackSize??item.stackSize)&65535;
    item.stolen=(data.Stolen??0)&255;item.charges=Math.min((data.Charges??50)&255,250);
    item.plot=Number((data.Plot??0)!==0);item.droppable=Number((data.Dropable??0)!==0);item.pickpocketable=Number((data.Pickpocketable??0)!==0);
    item.cursed=Number((data.Cursed??0)!==0);
    if([0,1,2].includes(info.modelType))item.modelParts=Array.from({length:3},(_,i)=>i===0||info.modelType===2?(data[`ModelPart${i+1}`]??0)&65535:0);
    if(info.modelType===3)item.armorParts=nativeArmorPartFields.map(name=>(data[name]??0)&65535);
    if(info.modelType===1||info.modelType===3)item.colors=nativePaletteFields.map(name=>(data[name]??0)&255);
    if(info.container!==0){item.nativeRepository=new ItemRepository(item.id,7,5,35,0);await this.session.loadInventory(item,data);}
    for(const entry of data.PropertiesList??[]){
      const effect=importedPropertyEffect(entry,(type,integers)=>this.session.effects.create(type,OBJECT_INVALID,integers));
      const consumed=await applyItemProperty(item,effect,this.session.characterRules,{baseInfo:i=>this.baseInfo(i),baseItem:i=>i.baseItem,
        allocatePropertyId:()=>this.propertyIds.next(),appendProperty:(i,p,active)=>(active?i.activeProperties:i.passiveProperties).push(p),
        activeChanged:(...args)=>this.activeChanged(...args),propertyChanged:i=>this.propertyChanged(i)});
      if(consumed===0){const index=item.effects.findIndex(e=>e.type>91);if(index<0)item.effects.push(effect);else item.effects.splice(index,0,effect);}
    }
    await this.activeChanged(item,0);
    if(item.activeProperties.length===0&&item.passiveProperties.length===0)item.identified=1;
    item.nativeUnitWeight45c=await this.weight(item);item.nativeItemLoaded=true;
    // Stack/charge writes in legacy ammunition and UI paths share the same
    // canonical cells instead of creating a second authored/live value.
    for(const [field,cell] of [['BaseItem','baseItem'],['StackSize','stackSize'],['Charges','charges'],['Identified','identified'],['Stolen','stolen']])
      Object.defineProperty(item.authored,field,{enumerable:true,configurable:true,get(){return item[cell];},set(value){item[cell]=value|0;}});
  }
}
