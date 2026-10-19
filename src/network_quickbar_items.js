import {intEntry} from './combat_stats.js';
import {configureItemQuickbar,clientItemWield,updateItemQuickbarCount} from './item_quickbar.js';
import {castingSpell,talentSpell,spellStringEntry} from './spell_metadata.js';

// Native client-only item-widget adapter. CanUse/identified/property-use flags
// come from replication; item use and equipment changes remain server actions.
export function networkItemQuickbarProviders(world,tables,presentation,{notify=()=>{},feedback=()=>{},report=()=>{}}={}){
 const p={controlled:()=>world.registry.get(world.localObjectId),controlledId:()=>world.localObjectId,
  item:id=>{const o=world.registry.get(id),i=o?.item;if(o?.objectType!==6||!i||o.replicationRemoved)return null;return{...i,id:o.id,canonical:o,identified:Number(i.identified),stackSize:i.stackSize??i.field454,activeProperties:(i.properties??[]).map(v=>({...v}))};},
  baseInfo:i=>{if(!tables.baseitems.orderedRows[i.baseItem])return null;const field=name=>intEntry(tables.baseitems,i.baseItem,name).value;return{equipableSlots:field('EquipableSlots')>>>0,container:field('Container'),stacking:field('Stacking'),qbBehaviour:field('QBBehaviour'),weaponType:field('WeaponType'),weaponSize:field('WeaponSize'),weaponWield:field('WeaponWield')};},
  canUse:i=>{if(![0,1,false,true].includes(i.canUse))throw new Error('Replicated CanUseItem flag is unavailable');return Number(i.canUse);},
  property:(i,n)=>i.activeProperties[n]??null,cachedUses:(i,n)=>i.propertyUses?.[n]??i.field351?.[n]??0,
  propertySpell:(i,n)=>{const prop=i.activeProperties[n];if(prop?.type!==15)return-1;const entry=intEntry(tables.iprp_spells,prop.subtype,'SpellIndex');return entry.found?entry.value:-1;},
  spell:id=>{const spell=castingSpell(tables,id);return spell?{...spell,children:talentSpell(tables,id).children}:null;},subRadialSpell:(s,n)=>s.children[n]??-1,
  sizeCategory:actor=>{const e=intEntry(tables.appearance,actor.appearance.appearance,'SIZECATEGORY');return{status:Number(e.found),value:e.value};},
  equippedOwner:i=>{const o=i.canonical,id=o.equipmentOwnerId??(o.inventoryLocation?.channel==='I'?o.inventoryLocation.ownerId:null);return world.registry.get(id)??null;},
  itemIcon:i=>{report('network.quickbar-item-icon-unhandled','Native item icon construction is not connected',{itemId:i.id,baseItem:i.baseItem});return null;},
  feedback,clear:()=>Object.assign(presentation,{icon:null,secondaryIcon:null,uses:'',enabled:true,animation:null}),destroyIcon:()=>Object.assign(presentation,{icon:null,secondaryIcon:null}),icons:(_b,icon,secondaryIcon)=>Object.assign(presentation,{icon,secondaryIcon}),
  createSpellIcon:s=>spellStringEntry(tables.spells,s.id,'IconResRef'),releaseSpellIcon:()=>{},text:(_b,uses)=>presentation.uses=uses,enable:(_b,v)=>presentation.enabled=v!==0,animation:(_b,v)=>presentation.animation=v,notify};
 p.wield=(...a)=>clientItemWield(...a,p);p.refreshCount=b=>updateItemQuickbarCount(b,p);return p;
}
export function configureNetworkItemShortcut(world,tables,previous,binding,options){const presentation={},draft=structuredClone(previous),p=networkItemQuickbarProviders(world,tables,presentation,options);if(!configureItemQuickbar(draft,binding.itemId,binding.intParam??0xff00ff,0,p))return null;return{button:draft,presentation};}
