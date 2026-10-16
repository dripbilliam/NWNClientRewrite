const integer=(v,n)=>{if(!Number.isInteger(v))throw new Error(`Native item radial ${n} is unavailable`);return v|0;};
const property=(item,index,p)=>p.property(item,index);
const commonBase=base=>[49,54,75,104].includes(base|0);
const titleRef=(item,assignment)=>assignment&&!commonBase(item.baseItem)?67530:554;
const uses=(item,index,p)=>(index<8?integer(p.cachedUses(item,index),'cached uses')&65535:0);
const label=(ref,name,p)=>`${p.text(ref)} : ${p.text(name)}`;
const count=item=>{if(!Array.isArray(item.activeProperties))throw new Error('Native item radial active properties are unavailable');return item.activeProperties.length;};

// InitializeItemUseEntries1409a71a0. These are the use-related entries of the
// actual item wheel, not a replacement for its equipment/store/drop owners.
export function itemUseEntries(item,p,{assignment=false}={}){
 const entries=[],base=p.baseInfo(item);if(!base)return entries;
 const first=property(item,0,p);if(!first)return entries;
 const type=integer(first.type,'first property type')&65535;
 const special=({70:['IR_TRAP',285],55:['ISK_OLOCK',278],80:['IR_HEAL',273]})[type];
 if(special)return[{slot:3,kind:'use',icon:special[0],label:label(554,special[1],p),index:0,variant:255,disabled:false}];
 if((integer(base.stacking,'maximum stack')&65535)!==1&&!(count(item)===1&&[1,7,13].includes(first.costValue&65535)))p.warning('Stackable items are only allowed to have single or infinite use properties on them.');
 let total=0;for(let i=0;i<count(item);i++){const prop=property(item,i,p);if(prop&&(prop.type&65535)===15)total++;}
 // Original does two separate scans before its actual entry traversal.
 let remaining=0;for(let i=0;i<count(item);i++){const prop=property(item,i,p);if(prop&&(prop.type&65535)===15)remaining++;}
 let ordinal=0;
 for(let i=0;i<count(item);i++){
  const prop=property(item,i,p);if(!prop||(prop.type&65535)!==15)continue;
  if(remaining>3&&ordinal===2)break;
  const id=p.propertyInt(prop.subtype&65535,'SpellIndex')>>>0,name=p.propertyInt(prop.subtype&65535,'Name'),spell=p.spell(id);
  const slot=[3,5,7][ordinal++];if(!spell)continue;
  const icon=p.icon(spell);if(!icon)continue;
  const cost=prop.costValue&65535,badge=cost===7||cost===13?'*':commonBase(item.baseItem)?null:String(uses(item,i,p));
  entries.push({slot,kind:spell.children.length?'variants':'use',icon,label:label(titleRef(item,assignment),name,p),index:i,variant:spell.children.length?0:255,spellId:id,uses:badge,disabled:prop.remaining===0&&!assignment});
 }
 if(total>3)entries.push({slot:7,kind:'more',icon:'IR_USE',label:p.text(titleRef(item,assignment)),start:2,disabled:false});
 if(item.baseItem===75&&p.hasLearningClass()){
  // SetEntry replaces an existing entry at this slot.
  const previous=entries.findIndex(e=>e.slot===5);if(previous>=0)entries.splice(previous,1);
  entries.push({slot:5,kind:'learn',icon:'IR_LEARNSCROLL',label:p.text(53135),disabled:false});
 }
 return entries;
}

// Property page creator1409a6450. Start counts cast properties, not physical
// property slots. Seven entries plus More; payload retains physical index.
export function itemPropertyPage(item,start,p,{assignment=false}={}){
 start=integer(start,'page start');const entries=[];let skipped=0,slot=0;
 for(let i=0;i<count(item);i++){
  const prop=property(item,i,p);if((prop.type&65535)!==15)continue;
  if(skipped<start){skipped++;continue;}
  if(slot===7){entries.push({slot:7,kind:'more',icon:'IR_USE',label:p.text(assignment?67530:554),start:start+7,disabled:false});break;}
  const id=p.propertyInt(prop.subtype&65535,'SpellIndex')>>>0,name=p.propertyInt(prop.subtype&65535,'Name'),spell=p.spell(id),entrySlot=slot++;
  if(!spell)continue;const icon=p.icon(spell);if(!icon)continue;
  const cost=prop.costValue&65535,badge=cost===7||cost===13?'*':String(uses(item,i,p));
  entries.push({slot:entrySlot,kind:spell.children.length?'variants':'use',icon,label:label(assignment?67530:554,name,p),index:i,variant:spell.children.length?0:255,spellId:id,uses:badge,disabled:prop.remaining===0});
 }
 return entries;
}

// Variant creator1409a5fe0. Each child's index is encoded in the high WORD;
// child spell names/icons/target metadata remain distinct from its parent.
export function itemVariantEntries(item,index,p,{assignment=false}={}){
 index=integer(index,'variant property index');const prop=property(item,index,p);if(!prop)return null;
 const id=p.propertySpell(item,index)>>>0,spell=p.spell(id);if(!spell)return null;
 const entries=[];
 for(let i=0;i<(spell.children.length&255);i++){
  const child=p.spell(p.subRadialSpell(spell,i&255)>>>0);if(!child)continue;
  const icon=p.icon(child);if(!icon)continue;
  const cost=prop.costValue&65535,badge=cost===7||cost===13?'*':String(uses(item,index,p));
  entries.push({slot:i,kind:'use',icon,label:label(titleRef(item,assignment),child.nameRef,p),index,variant:i,spellId:child.id>>>0,uses:badge,disabled:prop.remaining===0});
 }
 return entries;
}
