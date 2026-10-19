import {OBJECT_INVALID} from './game_object_array.js';
import {asNWSObject} from './native_object_cast.js';
import {intEntry,rulesetInt} from './combat_stats.js';
import {nativeFloatEntry,nativeFloatEntryByIndex} from './movement_rate.js';
import {itemPropertyPrice,recalculateItemPrice,getItemPrice} from './item_price.js';
import {ItemRepository,repositoryContains} from './item_repository.js';
import {applyItemProperty,importedPropertyEffect,ItemPropertyIds} from './item_property_pool.js';
import {updateItemActiveUseCache,selectItemVisual,setItemCharges} from './item_presentation_state.js';
import {computeItemUnitWeight} from './inventory_weight.js';
import {parse2da} from './area.js';
import {RESOURCE_TYPE,decodeResourceText} from './resource_archive.js';
import {cloneGff,getGffFieldTypes} from './gff.js';
import {readNativeGff} from './native_gff_fields.js';
import {nativeObjectTag} from './object_tag.js';
import {objectTemplateResRef} from './create_object.js';
import {loadItemFromGff,readItemGffField} from './item_gff_load.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';
import {spellStringEntry,nativeStringEntry,talentSpell,savingThrowSpell} from './spell_metadata.js';
import {spellGainWithBonus,spellMinAbilityMet,spellLevelByClass,addKnownSpell,resizeMemorizedSlots} from './spell_book.js';
import {removeBonusSpellOfLevel} from './bonus_spell_slots.js';
import {learnScroll,receiveLearnScrollInput,receiveLearnScrollReply} from './scroll_learning.js';
import {sendCombatFeedback} from './combat_broadcast.js';
import {scriptAppearanceType} from './creature_appearance_state.js';
import {itemActiveUsesLeft} from './item_presentation_state.js';
import {clientItemWield,updateItemQuickbarCount} from './item_quickbar.js';
import {itemPropertyApplied,removeItemProperty,materializeItemProperty,dematerializeItemProperty} from './item_property_mutation.js';
import {itemPropertyApplyHandlers,itemPropertyRemoveHandlers} from './item_property_handlers.js';
import {itemPropertyMaterializers,applyEquippedPropertyList,removeEquippedPropertyList} from './item_property_materializers.js';
import {equipmentCombatEffects,itemArmorClass} from './combat_modifiers.js';
import {creatureRoot} from './creature_rules.js';
import {weaponDamageFlags} from './damage_weapon.js';
import {canUseItem} from './item_use.js';
import {useItem,addItemCastSpellActions} from './item_cast_request.js';
import {usePickpocketSkill} from './skill_action.js';
import {computeSpellRange} from './spell_queue.js';
import {addObjectAction} from './object_actions.js';
import {addMoveToPointBack} from './movement_actions.js';
import {receiveItemInput} from './item_input.js';
import {manageObjectActions} from './object_actions.js';
import {scriptUseItem} from './script_use_item.js';
import {copyNativeItem} from './item_copy.js';
import {scriptCopyItem,scriptCopyItemAndModify} from './script_item_copy.js';
import {modifyCopiedItemAppearance} from './item_appearance_modify.js';
import {baseItemReference} from './base_item_references.js';
import {saveItemProperties,saveNativeItem} from './item_save.js';
import {scriptItemACValue} from './script_checks.js';
import {setItemPossessor} from './item_possession.js';
import {acquireCreatureItem,acquirePlaceableItem,acquireContainerItem} from './item_acquisition.js';
import {getItemPartColor,setItemPartColor} from './item_part_colors.js';
import {addModuleTag} from './module_tag_lookup.js';

export const nativeArmorPartFields=['ArmorPart_RFoot','ArmorPart_LFoot','ArmorPart_RShin','ArmorPart_LShin','ArmorPart_LThigh','ArmorPart_RThigh','ArmorPart_Pelvis','ArmorPart_Torso','ArmorPart_Belt','ArmorPart_Neck','ArmorPart_RFArm','ArmorPart_LFArm','ArmorPart_RBicep','ArmorPart_LBicep','ArmorPart_RShoul','ArmorPart_LShoul','ArmorPart_RHand','ArmorPart_LHand','ArmorPart_Robe'];
export const nativePaletteFields=['Leather1Color','Leather2Color','Cloth1Color','Cloth2Color','Metal1Color','Metal2Color'];
const propertyData=p=>({PropertyName:p.type,Subtype:p.subtype,CostTable:p.costTable,CostValue:p.costValue,Param1:p.param1,Param1Value:p.param1Value,
  UsesPerDay:p.usesPerDay,ChanceAppear:p.chance,Useable:p.remaining,CustomTag:p.customTag});
export function canonicalItemData(item){
  if(!item.nativeItemLoaded)return item.authored;
  const result={...item.authored,Tag:item.tag,TemplateResRef:item.templateResRef,BaseItem:item.baseItem,StackSize:item.stackSize,Charges:item.charges,Identified:item.identified,Dropable:item.droppable,
    Pickpocketable:item.pickpocketable,Plot:item.plot,Stolen:item.stolen,Cursed:item.cursed,Hidden:item.nativeHidden468,Useable:item.nativeUseable264,Cost:item.nativeBasePrice38c,AddCost:item.nativeAddCost394,PropertiesList:[...item.activeProperties,...item.passiveProperties].map(propertyData)};
  for(const[offset,name]of[[0x3e0,'DescIdentified'],[0x3f0,'Description'],[0x420,'LocalizedName']])result[name]=item.nativeItemLocalized[offset];
  for(const[offset,name]of[[0x430,'DisplayName'],[0x400,'DescIdentifiedOverride'],[0x410,'DescriptionOverride']])result[name]=item.nativeItemStrings[offset];
  item.modelParts.forEach((v,i)=>{result[`ModelPart${i+1}`]=v;});nativeArmorPartFields.forEach((name,i)=>{result[name]=item.armorParts[i];});nativePaletteFields.forEach((name,i)=>{result[name]=item.colors[i];});
  item.partColors.forEach((values,ch)=>values?.forEach((v,p)=>{result[`APart_${p}_Col_${ch}`]=v;}));return result;
}

// Fresh CNWSItem/LoadDataFromGff state. Full Equip/Acquire and saved-effect
// import remain separate owners; this class never manufactures possession.
export class NativeItemRuntime {
  constructor(session){this.session=session;this.propertyIds=new ItemPropertyIds();this.tables=new Map();this.baseTables=new WeakMap();}
  saveProperties(item,root){
    try{
      if(item?.objectType!==6||!item.nativeItemLoaded)throw new Error('Native property save requires a loaded item');
      return saveItemProperties(item,{properties:(o,active)=>active?o.activeProperties:o.passiveProperties},root);
    }catch(error){this.session.report(error,this.session.diagnosticContext(item?.id));throw error;}
  }
  async save(item,flag=0,root){
    const s=this.session,fields={0x40:'baseItem',0x360:'identified',0x454:'stackSize',0x458:'stolen',0x468:'nativeHidden468',0x448:'droppable',0x44c:'pickpocketable',0x450:'cursed',0x388:'charges',0x144:'plot',0x398:'nativePriceDirty398',0x390:'nativeUnidentifiedPrice390',0x394:'nativeAddCost394',0x38c:'nativeBasePrice38c',0x2ac:'nativeUseable264',0x3d8:'repositoryX',0x3d9:'repositoryY'};
    try{
      if(item?.objectType!==6||!item.nativeItemLoaded)throw new Error('Native item save requires a loaded canonical item');
      const p={scalar:(i,o)=>{const value=i[fields[o]];return typeof value==='boolean'?Number(value):value;},writeScalar:(i,o,v)=>{i[fields[o]]=v;},
        string:(i,o)=>o===0x68?i.tag:o===0x78?i.templateResRef:i.nativeItemStrings[o],localized:(i,o)=>i.nativeItemLocalized[o],resref:objectTemplateResRef,
        baseInfo:i=>this.baseInfo(i),appearance:(i,kind,n)=>i[kind][n],partColor:getItemPartColor,calculateBaseCosts:i=>this.priceProviders().recalculate(i),
        repository:i=>i.nativeRepository,head:r=>r.head,next:(_r,n)=>n.next,value:(_r,n)=>n.id,item:id=>{const o=s.registry.get(id);return o?.objectType===6?o:null;},
        properties:(i,active)=>active?i.activeProperties:i.passiveProperties,itemProperties:(i,r)=>this.saveProperties(i,r),objectState:(i,r)=>s.objectState.save(i,r),
        float:(i,o)=>[i.position?.[0],i.position?.[2]===undefined?undefined:-i.position[2],i.position?.[1],i.orientation?.[0],i.orientation?.[2]===undefined?undefined:-i.orientation[2],i.orientation?.[1]][(o-0xec)/4],
      };
      for(const owner of ['visualTransform','materialOverrides','textureOverrides','animationOverrides','miscVisuals','uuid'])p[owner]=(i,r)=>s.objectVisuals.saveOwner(i,r,owner);
      return await saveNativeItem(item,flag,p,root);
    }catch(error){s.report(error,{...s.diagnosticContext(item?.id),operation:'native-item-save'});throw error;}
  }
  quickbarProviders(presentation,{actor=this.session.player,canUse,notify=()=>{}}={}){
    const s=this.session;
    const p={controlled:()=>s.player===actor?actor:null,controlledId:()=>s.player.id,
      item:id=>{const o=s.registry.get(id);return o?.objectType===6?o:null;},baseInfo:i=>this.baseInfo(i),
      canUse:()=>canUse,property:(i,n)=>i.activeProperties[n]??null,
      propertySpell:(i,n)=>{const prop=i.activeProperties[n];if(!prop||(prop.type&65535)!==15)return -1;const entry=intEntry(s.characterRules.iprp_spells,prop.subtype&65535,'SpellIndex');return entry.found?entry.value:-1;},
      spell:id=>{const spell=s.spellBook.castingSpell(id);return spell?{...spell,children:talentSpell(s.characterRules,id).children}:null;},
      subRadialSpell:(spell,n)=>spell.children[n]??-1,
      sizeCategory:o=>{const entry=intEntry(s.characterRules.appearance,scriptAppearanceType(o),'SIZECATEGORY');return{status:Number(entry.found),value:entry.value};},
      // Client25c is the equipped creature, distinct from possessor264. The
      // local client derives it from canonical slot membership, not ownerId.
      equippedOwner:i=>{const owner=s.registry.get(i?.possessorId);return owner?.objectType===5&&owner.nativeEquipment?.contains(i)?owner:null;},
      itemIcon:i=>{runtimeDiagnostics.record('ui.item-icon-unimplemented','Native client item icon238 construction is unavailable; shortcut uses its text label',{itemId:i.id,baseItem:i.baseItem});return null;},
      cachedUses:itemActiveUsesLeft,feedback:code=>s.spells.feedback(actor,code),
      clear:()=>Object.assign(presentation,{icon:null,secondaryIcon:null,uses:'',enabled:true,animation:null}),
      destroyIcon:()=>{presentation.icon=null;presentation.secondaryIcon=null;},
      icons:(_b,icon,second)=>Object.assign(presentation,{icon,secondaryIcon:second}),
      createSpellIcon:spell=>spellStringEntry(s.characterRules.spells,spell.id,'IconResRef'),releaseSpellIcon:()=>{},
      text:(_b,text)=>{presentation.uses=text;},enable:(_b,value)=>{presentation.enabled=value!==0;},
      animation:(_b,animation)=>{presentation.animation=animation;},notify};
    p.wield=(...args)=>clientItemWield(...args,p);p.refreshCount=b=>updateItemQuickbarCount(b,p);return p;
  }
  castProviders(){
    const s=this.session,c=s.combat;
    const p={item:id=>{const o=s.registry.get(id);return o?.objectType===6?o:null;},object:id=>s.registry.get(id)??null,
      asCreature:o=>o.objectType===5?o:null,asItem:o=>o.objectType===6?o:null,position:o=>[Math.fround(o.position[0]),Math.fround(-o.position[2]),Math.fround(o.position[1])],
      canUse:(o,i,ignore)=>canUseItem(o,i,ignore,s.itemUseProviders()),activeProperty:(i,index)=>{
        if(!Array.isArray(i.activeProperties))throw new Error('Native active item property storage is unavailable');
        index|=0;return index>=0&&index<i.activeProperties.length?i.activeProperties[index]:null;
      },
      visibility:(o,id)=>o.perception.get(id)??null,baseInfo:i=>this.baseInfo(i),equipped:(o,i)=>o.nativeEquipment.contains(i),feedback:(...a)=>s.spells.feedback(...a),
      possessed:o=>Number((o.associateType&65535)===3&&Boolean(c.broadcastProviders().client(o.id))),dm:o=>Number(Boolean(o.isDM)),area:o=>s.registry.get(o.areaId)??null,
      spellIndex:id=>{if(!s.characterRules.iprp_spells)throw new Error('Native item cast iprp_spells metadata is unavailable');return intEntry(s.characterRules.iprp_spells,id,'SpellIndex').value;},
      spell:id=>s.spellBook.castingSpell(id),range:(o,spell,id)=>computeSpellRange(o,spell.range,id,{ranges:s.spells.ranges(o),personalSpace:o=>o.nativePathInfo.field4,creature:id=>{const a=s.registry.get(id);return a?.objectType===5?a:null;}}),
      queue:(o,id,group,params,front)=>addObjectAction(o.objectActionState,id,group,params,front),
      move:(o,group,point,...args)=>addMoveToPointBack(o,group,[point[0],point[2],-point[1]],...args,{setLock:(...a)=>c.setLock(...a)}),
      useSkill:(...args)=>usePickpocketSkill(...args,s.skills.providers()),
      addTrap:()=>{throw new Error('Native AddTrapActions1403808c0 item trap owner is unavailable');}};
    p.addCast=(o,r)=>addItemCastSpellActions(o,r,p);return p;
  }
  use(...args){return useItem(...args,this.castProviders());}
  scriptProviders(){
    const s=this.session;
    return{creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},
      item:id=>{const o=s.registry.get(id);return o?.objectType===6?o:null;},
      activeCount:i=>{if(!Array.isArray(i.activeProperties))throw new Error('Native script item active property storage is unavailable');return i.activeProperties.length;},
      activeProperty:(i,n)=>i.activeProperties[n],area:o=>s.registry.get(o.areaId)??null,use:(...args)=>this.use(...args),
      // Decoded VM values are JS-owned copies. Releasing a local structure
      // scope drops its reference; it must not mutate the canonical property.
      release:()=>{}};
  }
  async scriptReader(ordinal,frame,read){
    let popError;
    const result=await scriptUseItem(ordinal,frame.self,{...this.scriptProviders(),pop:type=>{
      try{return{ok:true,value:read(type)};}catch(error){popError=error;return{ok:false};}
    }});
    if(result===-639)throw popError??new Error('Native ActionUseItem argument decoding failed (-639)');return result;
  }
  script(ordinal,args,frame){let cursor=0;return this.scriptReader(ordinal,frame,()=>{if(cursor>=args.length)throw new Error('Native ActionUseItem VM argument is unavailable');return args[cursor++];});}
  scriptStack(ordinal,vm,frame){return this.scriptReader(ordinal,frame,type=>vm.pop(frame,type));}
  learningProviders(){
    const s=this.session,rules=s.characterRules,root=creatureRoot,book=(o,n,l)=>{
      const list=o.nativeTalentClasses?.[n]?.known?.[l];if(!Array.isArray(list))throw new Error('Native scroll known-spell storage is unavailable');return list;
    };
    return{item:id=>{const o=s.registry.get(id);return o?.objectType===6?o:null;},activeProperty:(i,n)=>i.activeProperties[n]??null,
      propertySpell:prop=>intEntry(rules.iprp_spells,prop.subtype&65535,'SpellIndex').value,
      spell:id=>s.spellBook.castingSpell(id),object:id=>s.registry.get(id)??null,asCreature:o=>o.objectType===5?o:null,asItem:o=>o.objectType===6?o:null,
      repository:o=>o.nativeRepository,contains:(repo,item,n)=>repositoryContains(repo,item,n,{object:id=>s.registry.get(id),baseInfo:i=>this.baseInfo(i),repository:o=>o.nativeRepository}),
      classCount:o=>root(o).ClassList.length,classType:(o,n)=>root(o).ClassList[n].Class,canLearn:id=>intEntry(rules.classes,id,'LearnScroll').value,
      spellLevel:(spell,id)=>spellLevelByClass(rules,spell.id,id),spellGain:(o,n,l)=>spellGainWithBonus(o,n,l,rules,s.spellBook.providers(o)),
      minimumAbility:(o,n,l)=>spellMinAbilityMet(o,n,l,rules,s.spellBook.providers(o)),classSchool:(o,n)=>root(o).ClassList[n].School??0,
      opposition:id=>{const e=intEntry(rules.spellschools,id,'Opposition');return{status:Number(e.found),value:e.value};},spellSchool:spell=>savingThrowSpell(rules,spell.id).school,
      knownCount:(o,n,l)=>book(o,n,l).length,known:(o,n,l,k)=>book(o,n,l)[k],addKnown:(o,n,id)=>addKnownSpell(o,n,id,rules,s.spellBook.providers(o)),
      removeItem:(...args)=>s.itemAcquisitionProviders().removeCreatureItem(...args),destroyItem:i=>s.lifecycle.destroy(i),
      feedbackData:()=>({type:0,integers:[]}),feedbackInteger:(data,n,value)=>{data.integers[n]=value|0;},feedback:(o,code,data)=>sendCombatFeedback(o,code,data,s.combat.broadcastProviders())};
  }
  async learn(actor,itemId){const result=await learnScroll(actor,itemId,this.learningProviders());this.lastLearnScroll={actorId:actor.id,itemId,result};return result;}
  learnReply(itemId){
    const s=this.session;
    return receiveLearnScrollReply({readObjectId:()=>itemId,readBool:()=>0,inventory:()=>s,controlled:()=>s.player,
      repositoryUI:()=>true,overflow:()=>0,underflow:()=>0,objectArray:()=>s.registry,object:id=>s.registry.get(id)??null,asItem:o=>o.objectType===6?o:null,
      // GameUi's canonical inventory snapshot drives its existing widget
      // refresh. Native GUI pointer layout/refresh ownership is not emulated.
      refreshItem:()=>{}});
  }
  inputLearn(request){
    const s=this.session;
    return receiveLearnScrollInput({overflow:()=>0,underflow:()=>0,readObjectId:()=>request.itemId,message:()=>s,clientObject:()=>s.player,
      asCreature:o=>o?.objectType===5?o:null,learn:(...args)=>this.learn(...args),
      // This decoded local reply needs no transport PLAYER_ID. Preserve an
      // actual one if supplied; never substitute the creature's object ID.
      clientId:()=>s.combat.broadcastProviders().client(s.player.id)?.nativePlayerId48,
      reply:(_message,_client,id)=>this.learnReply(id)});
  }
  input(request){
    const s=this.session,c=s.combat;let objectIndex=0,byteIndex=0,boolIndex=0,axis=0;
    return receiveItemInput(null,{clientObject:()=>s.player,asCreature:o=>o?.objectType===5?o:null,overflow:()=>0,underflow:()=>0,
      readObjectId:()=>objectIndex++===0?request.itemId:request.targetId,readByte:()=>byteIndex++===0?request.propertyIndex:request.variant,
      readBool:()=>[request.variant!==0?1:0,request.targetId!==OBJECT_INVALID?1:0,request.location!==0?1:0][boolIndex++],readFloat:()=>request.position[axis++],
      actionManager:(o,n)=>manageObjectActions(o,n,{hasClient:o=>Boolean(c.broadcastProviders().client(o.id)),clearActions:o=>c.clearActions(o)}),
      use:(...a)=>this.use(...a),feedback:(...a)=>s.spells.feedback(...a)});
  }
  setCharges(item,value,update){return setItemCharges(item,value,update);}
  initialize(item){
    if(item.objectType!==6)throw new Error('Native item constructor requires an item');
    item.baseItem??=24;item.identified??=0;item.charges??=50;item.stackSize??=1;item.stolen??=0;
    item.nativePriceDirty398??=1; // CNWSItem ctor14046300b.
    item.nativeBasePrice38c??=0;item.nativeUnidentifiedPrice390??=0;item.nativeAddCost394??=0;item.nativeBaseArmor35c??=0;item.nativeInfinite444??=0; // ctor140462ff9..3029.
    item.nativeInventoryObservers364??=0; // CNWSItem ctor140462f85.
    item.nativeBaseHPE0??=1;item.nativeMaxHPE4??=1;item.nativeTemporaryHPE8??=0; // Common ctor14048ba08/12; item object subobject+48.
    item.droppable??=1;item.pickpocketable??=1;item.plot??=0;item.repositoryX??=0;item.repositoryY??=0;
    item.cursed??=0; // LoadData14046a193..1b4 uses distinct INT450, not plot144.
    item.possessorId=(item.possessorId??item.ownerId??OBJECT_INVALID)>>>0;
    item.nativeLastHolder464??=OBJECT_INVALID; // CNWSItem ctor14046304f.
    Object.defineProperty(item,'ownerId',{enumerable:true,configurable:true,get(){return this.possessorId;},set(value){this.possessorId=value>>>0;}});
    item.activeProperties??=[];item.passiveProperties??=[];item.effects??=[];item.nativeRepository??=null;
    item.activeUseMask??=0;item.activeUseBytes??=Array(8).fill(0);item.nativeVisual462??=0;
    item.nativeItemPending240??=0; // Local client item-menu pending projection.
    item.modelParts??=Array(3).fill(0);item.armorParts??=Array(19).fill(0);item.colors??=Array(6).fill(0);
    item.partColors??=Array(6).fill(null); // CNWItem six optional channel arrays.
    item.nativeHidden468??=0; // item ctor14046304f; typed Hidden load1404698ff..923.
    item.nativeUseable264??=1; // CNWSObject ctor14048b760, generic264/item2ac.
    item.nativeItemLocalized??=Object.fromEntries([0x3e0,0x3f0,0x420].map(o=>[o,{strRef:0xffffffff,entries:[]}]));
    item.nativeItemStrings??={0x430:'',0x400:'',0x410:''};
  }
  async copyInto(destination,source,copyVariables=0){
    const s=this.session,scalars={0x3c8:'possessorId',0x394:'nativeAddCost394',0x388:'charges',0x35c:'nativeBaseArmor35c',0x444:'nativeInfinite444',0x454:'stackSize',0x45c:'nativeUnitWeight45c',0x360:'identified',0x144:'plot',0x458:'stolen',0x468:'nativeHidden468',0x40:'baseItem'};
    const result=await copyNativeItem(destination,source,copyVariables,{
      repository:i=>i.nativeRepository,repositoryCount:r=>r.length,
      localized:(i,o,v)=>{if(v!==undefined)i.nativeItemLocalized[o]=structuredClone(v);return i.nativeItemLocalized[o];},
      string:(i,o,v)=>{const key=o===0x68?'tag':o===0x78?'templateResRef':null;if(v!==undefined){if(key)i[key]=String(v);else i.nativeItemStrings[o]=String(v);}return key?i[key]??'':i.nativeItemStrings[o];},
      scalar:(i,o,v)=>{const key=scalars[o];if(!key)throw new Error(`Native copied item field ${o.toString(16)} is unavailable`);if(v!==undefined)i[key]=key==='possessorId'?v>>>0:v|0;if(!Number.isInteger(i[key]))throw new Error(`Native copied item ${key} is unavailable`);return i[key]|0;},
      byte:(i,o,v)=>{const index=o-0x351;if(o===0x350){if(v!==undefined)i.activeUseMask=v&255;return i.activeUseMask;}if(v!==undefined)i.activeUseBytes[index]=v&255;return i.activeUseBytes[index];},
      appearance:(i,kind,index,v)=>{if(v!==undefined)i[kind][index]=v&(kind==='colors'?255:65535);return i[kind][index];},
      removeTag:i=>s.lifecycle.removeTag(i),addTag:i=>addModuleTag(s.tags,i.tag,i.id),
      constructRepository:(i,r)=>{i.nativeRepository=new ItemRepository(i.id,r.width,r.height,r.boundary,0,message=>s.combat.warning(i,message));},
      copyVariables:(d,a)=>{if(d.locals===a.locals)return;for(const entry of a.locals.entries.values())if(entry.cswy!==null||entry.json!==null)s.combat.unsupported(a,'Native CopyScriptVars structured JSON/Cassowary value ownership is unavailable');d.locals.copyFrom(a.locals);},
      properties:(i,active)=>i[active?'activeProperties':'passiveProperties'],assignProperties:(i,a,active)=>{i[active?'activeProperties':'passiveProperties']=structuredClone(a);},
      effects:i=>i.effects,copyEffectFresh:e=>s.effects.assignFresh(e),hasPartColors:(i,ch)=>i.partColors[ch]!==null,getPartColor:getItemPartColor,setPartColor:setItemPartColor,
      updateVisual:i=>this.visualChanged(i),
    });
    if(result!==0){destination.nativeItemLoaded=true;destination.name=source.name;}
    return result;
  }
  async copy(source,copyVariables=0){
    const s=this.session,item=s.register('item',`runtime:item:${s.registry.nextObjectId[0]}`,{authored:{},equipmentSlot:null,deferTagLookup:true});
    if(await this.copyInto(item,source,copyVariables)===0){await s.lifecycle.destroy(item);return null;}return item;
  }
  copyCommandProviders(){
    const s=this.session,acquisition=s.itemAcquisitionProviders();return{
      item:id=>{const o=s.registry.get(id);return o?.objectType===6?o:null;},object:id=>s.registry.get(id)??null,
      construct:()=>s.register('item',`runtime:item:${s.registry.nextObjectId[0]}`,{authored:{},equipmentSlot:null,deferTagLookup:true}),
      copy:(...args)=>this.copyInto(...args),destroy:o=>s.lifecycle.destroy(o),setPossessor:(...args)=>setItemPossessor(...args,s.itemOwnershipProviders()),
      asWorld:asNWSObject,asCreature:o=>o.objectType===5?o:null,asPlaceable:o=>o.objectType===9?o:null,asItem:o=>o.objectType===6?o:null,asStore:o=>o.objectType===14?o:null,
      position:o=>[Math.fround(o.position[0]),Math.fround(-o.position[2]),Math.fround(o.position[1])],area:o=>{const a=s.registry.get(o.areaId);return a?.objectType===4?a:null;},addToArea:(...args)=>s.lifecycle.addItemArea(...args),
      acquireCreature:(...args)=>acquireCreatureItem(...args,acquisition),acquirePlaceable:(...args)=>acquirePlaceableItem(...args,acquisition),acquireContainer:(...args)=>acquireContainerItem(...args,acquisition),acquireStore:(...args)=>s.worldTemplates.stores.acquire(...args),
    };
  }
  modificationProviders(){
    const s=this.session,partTables=['parts_foot','parts_foot','parts_shin','parts_shin','parts_legs','parts_legs','parts_pelvis','parts_chest','parts_belt','parts_neck','parts_forearm','parts_forearm','parts_bicep','parts_bicep','parts_shoulder','parts_shoulder','parts_hand','parts_hand','parts_robe'];
    return{baseInfo:i=>this.baseInfo(i),warning:line=>runtimeDiagnostics.record('items.appearance-modification-warning','Native CopyItemAndModify validation warning',{sourceLine:line}),
      modelReference:(...args)=>baseItemReference(args[0],false,...args.slice(1)),iconReference:(...args)=>baseItemReference(args[0],true,...args.slice(1)),exists:(name,type)=>s.resolver.hasResource(name,type),
      partTable:index=>partTables[index]?this.table(partTables[index]):null,rowCount:table=>(table.orderedRows??[...table.rows.values()]).length,
      armor:item=>itemArmorClass({data:canonicalItemData(item)},s.characterRules),weight:async item=>{item.nativeUnitWeight45c=await this.weight(item);},
      partColor:(item,...args)=>{setItemPartColor(item,...args);if(item.partColors.some(channel=>channel?.some(value=>value!==255)))runtimeDiagnostics.record('items.part-colors-rendering-unimplemented','Native per-part item palette values are preserved; rendering those overrides is unavailable',s.diagnosticContext(item.id));},
      cloakTable:()=>this.table('cloakmodel'),cloakIcon:(table,index)=>intEntry(table,index,'ICON').value,
    };
  }
  async copyCommandReader(argc,read,modify=false){
    let result=OBJECT_INVALID,popError;const p=this.copyCommandProviders(),appearance=this.modificationProviders();
    const status=await (modify?scriptCopyItemAndModify:scriptCopyItem)(argc,{...p,
      pop:type=>{try{return{ok:true,value:read(type)};}catch(error){popError=error;return{ok:false};}},push:id=>{result=id;return true;},warning:appearance.warning,modify:(...args)=>modifyCopiedItemAppearance(...args,appearance),
    });
    if(status===-639)throw popError??new Error('Native CopyItem argument decoding failed (-639)');
    if(status!==0)throw new Error(`Native CopyItem result push failed (${status})`);return result;
  }
  copyCommand(args){let cursor=0;return this.copyCommandReader(args.length,()=>{if(cursor>=args.length)throw new Error('Native CopyItem VM argument is unavailable');return args[cursor++];});}
  copyCommandStack(vm,frame,argc){return this.copyCommandReader(argc,type=>vm.pop(frame,type));}
  modifyCommand(args){let cursor=0;return this.copyCommandReader(args.length,()=>{if(cursor>=args.length)throw new Error('Native CopyItemAndModify VM argument is unavailable');return args[cursor++];},true);}
  modifyCommandStack(vm,frame,argc){return this.copyCommandReader(argc,type=>vm.pop(frame,type),true);}
  async armorCommandReader(read){
    let result=0,popError;const s=this.session,status=await scriptItemACValue({
      pop:type=>{try{return{ok:true,value:read(type)};}catch(error){popError=error;return{ok:false};}},push:value=>{result=value;return true;},
      item:id=>{const item=s.registry.get(id);return item?.objectType===6?item:null;},baseArmor:item=>item.nativeBaseArmor35c,passiveCount:item=>item.passiveProperties.length,passive:(item,index)=>item.passiveProperties[index]??null,
    });
    if(status===-639)throw popError??new Error('Native GetItemACValue argument decoding failed (-639)');if(status!==0)throw new Error(`Native GetItemACValue result push failed (${status})`);return result;
  }
  armorCommand(args){let cursor=0;return this.armorCommandReader(()=>{if(cursor>=args.length)throw new Error('Native GetItemACValue VM argument is unavailable');return args[cursor++];});}
  armorCommandStack(vm,frame){return this.armorCommandReader(type=>vm.pop(frame,type));}
  baseInfo(item){
    const table=this.session.characterRules?.baseitems;if(!table)throw new Error('Native item baseitems ownership is unavailable');
    const base=item.baseItem|0,count=table.orderedRows?.length??table.rows.size;if(base<0||base>=count)return null;
    if(!this.baseTables.has(table))this.baseTables.set(table,new Map());const cache=this.baseTables.get(table);if(cache.has(base))return cache.get(base);
    const read=name=>intEntry(table,base,name).value;
    const acEnchant=intEntry(table,base,'AC_Enchant'); // loader14029fd38..14029fd5c defaults BYTE to255 on failure.
    const ranged=intEntry(table,base,'RangedWeapon'); // loader14029ec9e..14029ecb6 writes0 on failed lookup.
    const requiredFeats=[];for(let index=0;index<5;index++){const feat=intEntry(table,base,`ReqFeat${index}`);if(feat.found)requiredFeats.push(feat.value&65535);}
    const info={modelType:read('ModelType')&255,basePropColumn:read('PropColumn')&255,width:read('InvSlotWidth')&255,height:read('InvSlotHeight')&255,
      stacking:read('Stacking')&65535,container:read('Container'),weaponWield:read('WeaponWield')&255,weaponType:read('WeaponType')&255,weaponSize:read('WeaponSize')&255,
      equipableSlots:read('EquipableSlots'),qbBehaviour:read('QBBehaviour')&255,ranged:ranged.found?ranged.value&255:0,arcaneSpellFailure:read('ArcaneSpellFailure')&255,acEnchant:acEnchant.found?acEnchant.value&255:255,requiredFeats,
      category:read('Category')&255,baseCost:nativeFloatEntry(table,base,'BaseCost').value,itemMultiplier:nativeFloatEntry(table,base,'ItemMultiplier').value,storePanel:read('StorePanel')&255,storePanelSort:read('StorePanelSort')&255,ilrStackSize:read('ILRStackSize')&255,
      itemClass:spellStringEntry(table,base,'ItemClass').split('\0')[0].slice(0,10),genderSpecific:read('GenderSpecific')&255,defaultIcon:objectTemplateResRef(spellStringEntry(table,base,'DefaultIcon')),defaultModel:objectTemplateResRef(spellStringEntry(table,base,'DefaultModel'))};
    cache.set(base,info);return info;
  }
  priceProviders(){
    const rules=this.session.characterRules,table=value=>{
      const result=typeof value==='string'?rules?.[{definition:'itempropdef',armor:'armor',spells:'iprp_spells'}[value]]:value;
      if(!result)throw new Error(`Native item pricing table ${typeof value==='string'?value:'owner'} is unavailable`);return result;
    };
    const p={baseInfo:o=>this.baseInfo(o),
      float:(t,row,column)=>{const entry=nativeFloatEntry(table(t),row,column);return{status:Number(entry.found),value:entry.value};},
      floatColumn:(t,row,column)=>{const entry=nativeFloatEntryByIndex(table(t),row,column);return{status:Number(entry.found),value:entry.value};},
      string:(t,row,column)=>{const entry=nativeStringEntry(table(t),row,column);return{status:Number(entry.found),value:entry.value};},
      int:(t,row,column)=>{const entry=intEntry(table(t),row,column);return{status:Number(entry.found),value:entry.value};},
      namedTable:(name,flag)=>{if(flag!==0)throw new Error('Native pricing table load flag is unavailable');return this.table(name);},
      costTable:async id=>{id&=255;const definitions=rules?.iprp_costtable;if(!definitions)throw new Error('Native pricing cost-table definitions are unavailable');const count=(definitions.orderedRows??[...definitions.rows.values()]).length&255;if(id===0||id>=count)return null;const name=spellStringEntry(definitions,id,'Name');return name?this.table(name):null;},
      column:(t,name)=>table(t).columns.findIndex(column=>column.toLowerCase()===name.toLowerCase()),
      rule:(label,fallback)=>rulesetInt(rules,label,fallback),propertyPrice:(o,property)=>itemPropertyPrice(o,property,p),recalculate:o=>recalculateItemPrice(o,p),
    };return p;
  }
  price(item,stack=0,identified=1,ilr=0,overridePlot=0){return getItemPrice(item,stack,identified,ilr,overridePlot,this.priceProviders());}
  async table(name){
    name=String(name).toLowerCase();if(!this.tables.has(name))this.tables.set(name,this.session.resolver.getResource(name,RESOURCE_TYPE.TWO_DA).then(bytes=>parse2da(decodeResourceText(bytes))).catch(error=>{
      runtimeDiagnostics.record('rules.item-table-unavailable',`${name}.2da: ${error.message}`,{resource:name,stack:error.stack});return null;
    }));return this.tables.get(name);
  }
  propertyFactoryProviders(){
    const s=this.session,wrap=(table,name)=>table?{table,name,count:(table.orderedRows??[...table.rows.values()]).length}:null;
    return{
      create:(type,id,integers)=>s.effects.create(type,id,integers),
      definition:()=>{const table=s.characterRules?.itempropdef;if(!table)throw new Error('Native ITEMPROPDEF factory table is unavailable');return wrap(table,'itempropdef');},
      int:(t,row,column)=>{const entry=intEntry(t.table,row,column);return{status:Number(entry.found),value:entry.value};},
      string:(t,row,column)=>{const value=spellStringEntry(t.table,row,column),available=row>=0&&row<t.count&&t.table.columns.some(c=>c.toLowerCase()===column.toLowerCase());return{status:Number(available&&value.length!==0),value};},
      table:async name=>wrap(await this.table(name),name),
      cost:async id=>{
        const table=s.characterRules?.iprp_costtable;if(!table)throw new Error('Native IPRP_COSTTABLE factory definitions are unavailable');
        const rows=table.orderedRows??[...table.rows.values()];
        // LoadIPRPCostTables1402ba03c stores the physical count as BYTE;
        // GetIPRPCostTable1402b38a0 rejects0 and indices >= that cache count.
        if(id===0||id>=(rows.length&255)){runtimeDiagnostics.record('rules.item-cost-table-invalid',`Native item property cost table ID ${id} is invalid`,{tableId:id});return null;}
        const name=spellStringEntry(table,id,'Name');return name?wrap(await this.table(name),name):null;
      },
    };
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
  async visualChanged(item){
    if(item.partColors?.some(channel=>channel?.some(value=>value!==255)))runtimeDiagnostics.record('items.part-colors-rendering-unimplemented','Native per-part item palette values are preserved; rendering those overrides is unavailable',this.session.diagnosticContext(item.id));
    item.nativeVisual462=await selectItemVisual(item,this.session.characterRules,{baseInfo:i=>this.baseInfo(i),subtypeTable:name=>this.table(name)});
    if(item.nativeVisual462!==0)runtimeDiagnostics.record('items.visual-unimplemented','Native item visual selected; weapon-attached visual rendering is unavailable',
      {...this.session.diagnosticContext(item.id),visual:item.nativeVisual462});
  }
  propertyMutationProviders(){
    const s=this.session;
    return{weight:async item=>{item.nativeUnitWeight45c=await this.weight(item);},creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},
      equipped:(o,item)=>o.nativeEquipment.contains(item),slot:(o,item)=>o.nativeEquipment.slot(item),ai:()=>this,
      applyProperty:(_ai,...args)=>this.materialize(...args),removeProperty:(_ai,...args)=>this.dematerialize(...args),
      combatInformation:o=>{this.refreshProjection(o);s.updateNativeCombatInformation(o);},contentsWeight:repo=>s.combat.contentsWeight(repo),encumbrance:(...args)=>s.combat.encumbrance(...args),
      visual:item=>this.visualChanged(item),activeChanged:(...args)=>this.activeChanged(...args),
      removeActive:(item,i)=>item.activeProperties.splice(i,1),removePassive:(item,i)=>item.passiveProperties.splice(i,1)};
  }
  propertyChanged(item,property,effect){return itemPropertyApplied(item,property,effect,this.propertyMutationProviders());}
  applyProperty(item,effect){return applyItemProperty(item,effect,this.session.characterRules,{
    baseInfo:i=>this.baseInfo(i),baseItem:i=>i.baseItem,allocatePropertyId:()=>this.propertyIds.next(),
    appendProperty:(i,p,active)=>{
      // Fail an unfinished equipped materializer before adding a property
      // whose owning effect could not then be retained or expire.
      const owner=this.session.registry.get(i.possessorId);
      if(owner?.objectType===5&&owner.nativeEquipment.contains(i)!==0)this.propertyApplyHandler(p.type);
      (active?i.activeProperties:i.passiveProperties).push(p);
    },activeChanged:(...args)=>this.activeChanged(...args),
    propertyChanged:(...args)=>this.propertyChanged(...args)});}
  removeProperty(item,effect){return removeItemProperty(item,effect,this.propertyMutationProviders());}
  bonusSpellSlotProviders(owner){const s=this.session;return{
    classes:o=>creatureRoot(o).ClassList,classType:(o,i)=>creatureRoot(o).ClassList[i].Class,
    state:(o,i)=>o.nativeTalentClasses?.[i],memorizes:type=>intEntry(s.characterRules.classes,type,'MemorizesSpells').value,
    gain:(o,i,level)=>spellGainWithBonus(o,i,level,s.characterRules,s.spellBook.providers(o)),
    resize:(o,i,level,count,deleteSlots)=>{const state=o.nativeTalentClasses?.[i];if(!state)throw new Error('Native bonus spell slot pool is unavailable');return resizeMemorizedSlots(state,level,count,deleteSlots,s.spellBook.providers(o));},
    warning:message=>s.spellBook.warning(owner,message)};}
  materializerProviders(){
    const s=this.session,required=table=>{if(!table)throw new Error('Native item-property materializer table is unavailable');return table;};
    return{bonusSlots:o=>this.bonusSpellSlotProviders(o),base:item=>this.baseInfo(item),create:(...args)=>s.effects.create(...args),creator:(e,id)=>s.effects.setCreator(e,id),
      copy:(e,mode)=>mode==='constructor'?s.effects.copyConstruct(e):structuredClone(e),
      has:(item,type,subtype)=>Number([...item.activeProperties,...item.passiveProperties].some(p=>(p.type&65535)===(type&65535)&&(subtype===0||(p.subtype&65535)===(subtype&65535)))),
      melee:()=>required(s.characterRules.iprp_meleecost),
      hasStats:owner=>owner.stats!==null&&owner.stats!==undefined,feats:async()=>required(await this.table('iprp_feats')),
      saveElements:()=>s.characterRules.iprp_saveelement??null,
      cost:async id=>{const table=await this.propertyFactoryProviders().cost(id);return table?.table??null;},
      count:table=>(required(table).orderedRows??[...table.rows.values()]).length,
      int:(table,row,column)=>{const entry=intEntry(required(table),row,column);return{status:Number(entry.found),value:entry.value};},
      damageFlags:item=>{const value=weaponDamageFlags({id:item.id,data:canonicalItemData(item)},s.characterRules);for(const warning of value.warnings)runtimeDiagnostics.record(warning.code,warning.reason,{...s.diagnosticContext(item.id),...warning});return value.flags;},
      apply:(owner,e,loading,flag=0)=>{if(flag!==0)throw new Error('Native equipped property ApplyEffect fourth-flag loading owner is unavailable');return s.effects.applyNative(e,owner.id,undefined,loading);},release:()=>{},
      warning:kind=>runtimeDiagnostics.record('items.materializer-slot-warning',`Native item property ${kind} warning`,{operation:'item-property-materializer'})};
  }
  propertyApplyHandler(type){
    const apply=itemPropertyMaterializers.get(type);
    if(apply)return(...args)=>apply(...args,this.materializerProviders());
    const address=itemPropertyApplyHandlers.get(type);if(address)throw new Error(`Native item property ${type} materializer ${address} is unavailable`);return null;
  }
  projectionItems(owner,items=this.session.equippedItems(owner)){
    if(!owner.materializedItemProperties?.size)return items;
    return items.map(record=>{
      const item=this.session.registry.get(record.id);if(!item?.nativeItemLoaded)return record;
      const properties=[...item.activeProperties,...item.passiveProperties];
      return{...record,data:{...record.data,PropertiesList:record.data.PropertiesList.filter((_p,i)=>!owner.materializedItemProperties.has(properties[i]?.propertyId))}};
    });
  }
  combatProjection(owner,items){return equipmentCombatEffects(this.projectionItems(owner,items),this.session.characterRules,{root:creatureRoot(owner)});}
  refreshProjection(owner){owner.itemCombatEffects=this.combatProjection(owner);}
  async materialize(item,property,owner,slot,loading){await materializeItemProperty(this,item,property,owner,slot,loading,{
    handler:(_handler,type)=>this.propertyApplyHandler(type),
    warning:kind=>runtimeDiagnostics.record('items.effect-materialization-warning',`Native item property effect ${kind} warning`,{...this.session.diagnosticContext(item.id),propertyId:property.propertyId})});
    if(property&&itemPropertyApplyHandlers.has(property.type&65535))(owner.materializedItemProperties??=new Set()).add(property.propertyId);
  }
  propertyRemoveHandler(type){if(type===13)return(item,property,owner,slot)=>removeBonusSpellOfLevel(item,property,owner,slot,this.bonusSpellSlotProviders(owner));const address=itemPropertyRemoveHandlers.get(type);if(address)throw new Error(`Native item property ${type} removal handler ${address} is unavailable`);return null;}
  async dematerialize(item,property,owner,slot){await dematerializeItemProperty(item,property,owner,slot,{
    remove:(o,e)=>this.session.effects.removeOne(o.id,e.id,undefined,e),
    handler:type=>this.propertyRemoveHandler(type)});
    if(property)owner.materializedItemProperties?.delete(property.propertyId);
  }
  applyEquipped(item,owner,slot,loading){
    for(const property of item.passiveProperties)this.propertyApplyHandler(property.type&65535);
    return applyEquippedPropertyList(item,owner,slot,loading,{ai:()=>this,count:i=>i.passiveProperties.length,property:(i,n)=>i.passiveProperties[n],apply:(_ai,...args)=>this.materialize(...args)});
  }
  removeEquipped(item,owner,slot){
    for(const property of item.passiveProperties)this.propertyRemoveHandler(property.type&65535);
    return removeEquippedPropertyList(item,owner,slot,{ai:()=>this,count:i=>i.passiveProperties.length,property:(i,n)=>i.passiveProperties[n],remove:(_ai,...args)=>this.dematerialize(...args),removeCreator:(o,id)=>this.session.effects.removeCreator(o.id,id)});
  }
  scriptPropertyProviders(context){
    const s=this.session;
    return{object:id=>s.registry.get(id),asItem:o=>o.objectType===6?o:null,release:()=>{},apply:(o,e)=>s.effects.applyNative(e,o.id,context),
      ilrSetting:()=>{if(!Number.isInteger(s.nativeItemLevelRestriction134))throw new Error('Native server item-level restriction setting134 is unavailable');return s.nativeItemLevelRestriction134;},
      creature:id=>{const o=s.registry.get(id);return o?.objectType===5?o:null;},hasStats:o=>Boolean(o.stats),equipmentLocked:o=>o.nativeEquipmentLock97c,
      slot:(o,item)=>o.nativeEquipment.slot(item),level:o=>{if(!Number.isInteger(o.stats?.level))throw new Error('Native item-property owner level is unavailable');return o.stats.level;},
      minimumLevel:()=>{throw new Error('Native item minimum equip level/pricing owner is unavailable');},unequip:(...args)=>s.unequipItem(...args),
      repositoryAdd:()=>{throw new Error('Native property-induced unequip repository insertion owner is unavailable');},
      event:(...args)=>s.combat.enqueueEvent(...args)};
  }
  async loadFromGff(item,data,{loading=0,insideContainer=0}={}){
    const s=this.session,result=await loadItemFromGff(item,data,loading,insideContainer,{
      read:readItemGffField,loadTemplate:(o,reference)=>s.loadItemTemplate(o,reference,''),
      field:(o,offset,value)=>{if(offset===0x448)o.droppable=value|0;else if(offset===0x44c)o.pickpocketable=value|0;else throw new Error('Native item wrapper field is unavailable');},
      loadData:async(o,entry,flag,last)=>{o.name=typeof entry.LocalizedName==='string'?entry.LocalizedName:entry.LocalizedName?.entries?.[0]?.text??'';await this.loadData(o,entry,{loading:flag,insideContainer:last});return 1;},
      savedState:(o,entry)=>this.loadSavedState(o,entry),addTag:o=>s.addNativeItemTag(o),visual:o=>this.visualChanged(o),
    });
    if(result!==0)item.nativeItemFromGffLoaded=true;return result;
  }
  loadSavedState(item,data){return this.session.objectState.load(item,data);}
  async loadData(item,data,{insideContainer=0,loading=0}={}){
    if(item.nativeItemLoaded)throw new Error('Native item reload/removal of existing property owners is unavailable');
    item.nativeUseable264=readItemGffField(data,'bool','Useable',1).value; // LoadDataFromGff: failed/missing typed read leaves1.
    item.authored=cloneGff(data);const typed=Boolean(getGffFieldTypes(data));
    for(const[offset,name]of[[0x3e0,'DescIdentified'],[0x3f0,'Description'],[0x420,'LocalizedName']])item.nativeItemLocalized[offset]=structuredClone(typed?readNativeGff(data,name,12,{strRef:0xffffffff,entries:[]}).value:data[name]??{strRef:0xffffffff,entries:[]});
    for(const[offset,name]of[[0x430,'DisplayName'],[0x400,'DescIdentifiedOverride'],[0x410,'DescriptionOverride']])item.nativeItemStrings[offset]=readItemGffField(data,'string',name,'').value;
    item.nativeHidden468=readItemGffField(data,'bool','Hidden',0).value;
    item.baseItem=typed?readNativeGff(data,'BaseItem',5,item.baseItem).value:(data.BaseItem??24)>>>0;
    const info=this.baseInfo(item);if(!info)throw new Error('Native item LoadDataFromGff: invalid base item type');
    if(insideContainer!==0&&info.container!==0)throw new Error('Native item LoadDataFromGff: a container cannot be placed inside another container');
    item.tag=nativeObjectTag(typed?readNativeGff(data,'Tag',10,item.tag??'').value:String(data.Tag??item.tag??'')); // 140469603..610.
    item.templateResRef=objectTemplateResRef(typed?readNativeGff(data,'TemplateResRef',11,'').value:String(data.TemplateResRef??'')); // 140469819..8f1.
    item.nativeBasePrice38c=(typed?readNativeGff(data,'Cost',4,0).value:(data.Cost??0))>>>0;
    const addCost=(typed?readNativeGff(data,'AddCost',4,0).value:(data.AddCost??0))|0;item.nativeAddCost394=addCost>0?addCost:0; // 14046a0e9..a133.
    item.identified=Number((data.Identified??item.identified)!==0);item.stackSize=(data.StackSize??item.stackSize)&65535;
    item.stolen=(data.Stolen??0)&255;item.charges=Math.min((data.Charges??50)&255,250);
    item.plot=Number((data.Plot??0)!==0);item.droppable=Number((data.Dropable??0)!==0);item.pickpocketable=Number((data.Pickpocketable??0)!==0);
    item.cursed=Number((data.Cursed??0)!==0);
    if([0,1,2].includes(info.modelType))item.modelParts=Array.from({length:3},(_,i)=>i===0||info.modelType===2?(data[`ModelPart${i+1}`]??0)&65535:0);
    if(info.modelType===3)item.armorParts=nativeArmorPartFields.map(name=>(data[name]??0)&65535);
    if(info.modelType===1||info.modelType===3)item.colors=nativePaletteFields.map(name=>(data[name]??0)&255);
    if(info.modelType===3)for(let part=0;part<19;part++)for(let channel=0;channel<6;channel++)setItemPartColor(item,channel,part,readItemGffField(data,'byte',`APart_${part}_Col_${channel}`,getItemPartColor(item,channel,part)).value);
    if(info.container!==0){item.nativeRepository=new ItemRepository(item.id,7,5,35,0);await this.session.loadInventory(item,data,{loading});}
    for(const entry of data.PropertiesList??[]){
      const effect=importedPropertyEffect(entry,(type,integers)=>this.session.effects.create(type,OBJECT_INVALID,integers));
      const consumed=await this.applyProperty(item,effect);
      if(consumed===0){const index=item.effects.findIndex(e=>e.type>91);if(index<0)item.effects.push(effect);else item.effects.splice(index,0,effect);}
    }
    await this.activeChanged(item,0);
    if(item.activeProperties.length===0&&item.passiveProperties.length===0)item.identified=1;
    item.nativeBaseArmor35c=itemArmorClass({data:canonicalItemData({...item,nativeItemLoaded:true})},this.session.characterRules);
    item.nativeUnitWeight45c=await this.weight(item);
    // Native LoadDataFromGff14046a727..77a uses the common object subobject,
    // then UUID; this record keeps the same canonical ID for both views.
    await this.session.objectVisuals.load(item,data);if(typed)await this.session.loadNativeUUID(item,data);
    item.nativeItemLoaded=true;
    // Stack/charge writes in legacy ammunition and UI paths share the same
    // canonical cells instead of creating a second authored/live value.
    for(const [field,cell] of [['BaseItem','baseItem'],['StackSize','stackSize'],['Charges','charges'],['Identified','identified'],['Stolen','stolen']])
      Object.defineProperty(item.authored,field,{enumerable:true,configurable:true,get(){return item[cell];},set(value){item[cell]=value|0;}});
  }
}
