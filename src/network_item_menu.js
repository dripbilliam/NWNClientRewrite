import {networkItemQuickbarProviders} from './network_quickbar_items.js';
import {itemUseEntries,itemPropertyPage,itemVariantEntries} from './item_radial.js';
import {intEntry} from './combat_stats.js';import {spellStringEntry} from './spell_metadata.js';

// Reuse the original-compared item wheel owners against replicated active
// properties and the active resource tables. No charges or effects resolve here.
export async function prepareNetworkItemMenu(world,itemId,tables,resolve,report,{alive=()=>true,quickbarToken}={}){
 const actor=world.registry.get(world.localObjectId),p=networkItemQuickbarProviders(world,tables,{},{report}),item=p.item(itemId);if(!actor||!item)return()=>[];
 const spell=p.spell,refs=new Set([554,67530,53135,285,278,273]),text=new Map();
 p.spell=id=>{const s=spell(id);return s?{...s,nameRef:intEntry(tables.spells,id,'Name').value}:null;};
 p.propertyInt=(index,column)=>intEntry(tables.iprp_spells,index,column).value;
 p.icon=s=>spellStringEntry(tables.spells,s.id,'IconResRef');p.text=ref=>text.get(ref>>>0)??'';
 p.warning=message=>report('network.item-menu-warning',message,{itemId});
 p.hasLearningClass=()=>(actor.replicated?.stats?.classes??[]).some(c=>intEntry(tables.classes,c.id,'LearnScroll').value!==0);
 for(let i=0;i<item.activeProperties.length;i++){const prop=p.property(item,i);if(prop.type!==15)continue;refs.add(p.propertyInt(prop.subtype,'Name')>>>0);const s=p.spell(p.propertySpell(item,i));if(s){refs.add(s.nameRef>>>0);for(const id of s.children){const child=p.spell(id);if(child)refs.add(child.nameRef>>>0);}}}
 await Promise.all([...refs].map(async ref=>text.set(ref,await resolve({strRef:ref}))));
 const current=()=>alive()?p.item(itemId):null;
 const map=entries=>(entries??[]).map(entry=>{
  const row={...entry};
  if(entry.kind==='more')row.children=()=>({title:'Item powers',entries:current()?map(itemPropertyPage(current(),entry.start,p)):[]});
  else if(entry.kind==='variants')row.children=()=>({title:entry.label,entries:current()?map(itemVariantEntries(current(),entry.index,p)):[]});
  else if(entry.kind==='learn')row.action='item.learn';
  else{const packed=(entry.index|(entry.variant<<16))|0;row.action='item.use';row.binding={actorId:actor.id,itemId,packed};row.quickbarBinding={type:1,itemId,intParam:packed};row.networkQuickbarToken=quickbarToken;}
  return row;
 });
 return()=>current()?map(itemUseEntries(current(),p)):[];
}
