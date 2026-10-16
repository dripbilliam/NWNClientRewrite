// Native class ability collector14098f550 and class page14098fbf0.
// Providers expose the client normal/bonus ownership pools, not server
// conditional HasFeat grants. Physical class/feat order is significant.
export function collectClassAbilities(p){
 const result=[];
 for(let index=0;index<(p.classCount()&255);index++){
  const type=p.classType(index)&255,cls=p.classInfo(type);if(!cls)continue;
  let group=0,firstFeat=65535;
  if(type===2)for(let d=0;d<2;d++){const domain=p.domain(p.classDomain(index,d)&255);if(domain&&domain.castable!==0){group=1;break;}}
  for(let n=0;n<(cls.featCount&65535);n++){
   if(group!==0)break;const feat=p.classFeat(cls,n);if(!feat)break;
   if(feat.onMenu===1&&p.owns(feat.id&65535)&&!(p.grouped()&&(feat.id&65535)===1089)){
    if(firstFeat===65535)firstFeat=feat.id&65535;else group=1;
   }
  }
  if(group!==0||firstFeat!==65535)result.push({group,classIndex:index,firstFeat});
 }
 return result;
}

export function classAbilityPage(index,start,p){
 index&=7;start&=65535;const type=p.classType(index)&255,cls=p.classInfo(type);
 if(!cls)throw new Error('Native class ability storage is unavailable');
 const entries=[];let reserved=0;
 if(start===0&&type===2){
  for(let n=0;n<2;n++){
   const domain=p.domain(p.classDomain(index,n)&255);
   if(!domain)p.warning('CGuiCreatureMenu::CreateClassAbilityMenu() Invalid Domain');
   else if((domain.featId&65535)!==65535&&domain.castable!==0){
    const id=domain.featId&65535,feat=p.feat(id);
    if(feat){const uses=p.remaining(id)&255;entries.push({slot:reserved,featId:id,domain:true,uses,disabled:uses<1});reserved++;}
   }
  }
 }
 const ids=[];
 for(let n=0;n<(cls.featCount&65535);n++){
  const entry=p.classFeat(cls,n);if(!entry)continue;
  if(p.grouped()&&(entry.id&65535)===1089||entry.onMenu!==1)continue;
  let id=entry.id&65535,selected=65535;const visited=new Set();
  while(id!==0){
   if(visited.has(id))throw new Error('Native class feat successor cycle would not terminate');visited.add(id);
   if(!p.owns(id))break;selected=id;const feat=p.feat(id);if(!feat)break;id=feat.successor&65535;
  }
  if(selected!==65535&&!ids.includes(selected))ids.push(selected);
 }
 const remaining=reserved+ids.length-start,limit=remaining===8?8:7,more=remaining>8;
 for(let n=0;n+start<ids.length&&reserved+n<limit;n++)entries.push({slot:reserved+n,featId:ids[n+start],classIndex:255});
 if(more)entries.push({slot:7,next:(limit-reserved+start)&65535,classIndex:index});
 return entries;
}

// The leaf owner follows a signed-positive successor only while it is owned;
// it does not use the server's highest-successor traversal through gaps.
export function featRadialLeaf(requested,p){
 let id=requested&65535;if(!p.owns(id))return null;const visited=new Set();
 for(;;){
  if(visited.has(id))throw new Error('Native radial feat successor cycle would not terminate');visited.add(id);
  const feat=p.feat(id&65535),next=feat?.successor??-1;
  if(next<=0||!p.owns(next&65535))break;id=next;
 }
 const feat=p.feat(id&65535);if(!feat)return null;
 const auxiliary=requested>>>16,packedAuxiliary=auxiliary|(id>>>16),uses=p.remaining(id&65535)&255;
 const disabled=!p.assignment&&(uses===0||feat.targetSelf!==0&&!p.self);
 const spell=p.spell(feat.spellId);
 // Submenus bypass the leaf disabled flag; their children decide separately.
 if(spell?.children.length)return {featId:id&65535,auxiliary:packedAuxiliary,submenu:true};
 let labelRef=feat.nameRef,icon=feat.icon,shownUses=uses===100?null:uses,blocked=disabled,action='feat.use';
 if(id===5&&auxiliary===65001){labelRef=517;icon='IR_CALLEDARM';}
 else if(id===5&&auxiliary===65000){labelRef=518;icon='IR_CALLEDLEG';}
 else if(id===303&&p.familiar){labelRef=523;icon='IFE_POSSESS';shownUses=null;action='associate.possessFamiliar';blocked=!(p.self||p.targetId===p.familiar.id);}
 if(id===947&&p.defensiveStance===1){labelRef=84555;shownUses=null;blocked=false;}
 return {featId:id&65535,auxiliary:packedAuxiliary,labelRef,icon,uses:shownUses,disabled:blocked,action};
}

// Variant creator140991230 keeps each physical child slot (including holes)
// and uses the parent feat's target-self and remaining-use state.
export function featRadialVariants(id,p){
 id&=65535;const feat=p.feat(id);if(!feat)return null;
 const spell=p.spell(feat.spellId);if(!spell)return null;
 const entries=[];
 for(let slot=0;slot<spell.children.length;slot++){
  const child=p.spell(spell.children[slot]);if(!child)continue;
  const uses=p.remaining(id)&255;
  entries.push({slot,featId:id,auxiliary:(child.featId>>>16)&65535,labelRef:child.nameRef,icon:child.icon,
   uses:uses===100?null:uses,disabled:!p.assignment&&(uses<1||feat.targetSelf!==0&&!p.self),action:'feat.use'});
 }
 return entries;
}

// Radial callback140998520 differs from the hotbar target initializer. A
// non-self target dispatches input6 directly; self-target menus can reopen
// the targeter. These are native compiled mode and auxiliary rules.
export function selectRadialFeat(packed,p){
 if(!p.controlled)return {mode:'none'};
 if(p.assignment)return {mode:'assign',packed:packed>>>0};
 const id=packed&65535,auxiliary=packed>>>16;
 const modes={28:3,19:4,30:7,204:6,899:6,866:6,389:8,390:9,425:11,947:12};
 if(auxiliary===0&&modes[id]!==undefined)return {mode:'mode',modeId:modes[id]};
 const feat=p.feat(id);if(!feat){p.warning('CGuiCreatureMenu::RadialMenuUseFeat() Invalid Feat');return {mode:'none'};}
 if(p.self&&feat.targetSelf===0)return {mode:'target',featId:id,auxiliary:id===5||id>1072?auxiliary:0};
 return {mode:'use',featId:id,auxiliary};
}

// Ordinary controlled-creature root140994d10 and class entry140991610.
// DM menu construction is a separate owner. Labels/icons are frontend
// providers; the native slot and packed feat decisions stay here.
export function buildFeatAbilityRadial(p,ui){
 const descriptorEntry=(descriptor,slot)=>{
  const index=descriptor.classIndex;
  if(descriptor.group)return {slot,label:ui.className(index),icon:ui.classIcon(index),children:()=>classMenu(index,0)};
  return leafEntry(descriptor.firstFeat,slot,index);
 };
 const decorate=(value,slot,classIndex=255)=>{
  if(!value)return null;
  const {featId,auxiliary}=value;
  if(value.submenu)return {slot,label:ui.featName(featId),icon:p.feat(featId).icon,binding:{featId,auxiliary},children:()=>{
   const entries=featRadialVariants(featId,p);return {title:ui.featName(featId),entries:(entries??[]).map(e=>decorate(e,e.slot)).filter(Boolean)};
  }};
  const label=ui.text(value.labelRef)||ui.featName(featId);
  return {...value,slot,label:classIndex<8?`${label} (${ui.className(classIndex)})`:label,
   binding:{featId,auxiliary},system:value.action==='feat.use'?'feat activation':'familiar possession'};
 };
 const leafEntry=(id,slot,index=255)=>decorate(featRadialLeaf(id,p),slot,index);
 const classMenu=(index,start)=>({title:ui.className(index),entries:classAbilityPage(index,start,p).map(e=>{
  if(e.next!==undefined)return {slot:e.slot,label:ui.moreLabel,icon:'IR_MORE_SP_AB',children:()=>classMenu(index,e.next)};
  if(e.domain){const feat=p.feat(e.featId);return {slot:e.slot,featId:e.featId,label:ui.text(feat.nameRef)||ui.featName(e.featId),icon:feat.icon,uses:e.uses,disabled:e.disabled,action:'feat.use',binding:{featId:e.featId,auxiliary:0}};}
  return leafEntry(e.featId,e.slot);
 }).filter(Boolean)});
 const descriptors=collectClassAbilities(p),entries=[
  {slot:0,label:ui.craftLabel,icon:'ir_craft',action:'skill.use',system:'craft skill input',skillId:22},
  {slot:1,label:ui.tauntLabel,icon:'isk_taunt',action:'skill.use',system:'taunt skill input',skillId:18,disabled:!p.assignment&&p.self},
  {slot:2,label:ui.searchLabel,icon:'isk_search',action:'activity.detect',system:'detect activity input',disabled:!p.assignment&&!p.self},
  {slot:6,label:ui.stealthLabel,icon:'isk_movsilent',action:'activity.stealth',system:'stealth activity input',disabled:!p.assignment&&!p.self}
 ];
 if(descriptors.length<=3&&!p.grouped())entries.push(...descriptors.map(d=>descriptorEntry(d,5-d.classIndex)).filter(Boolean));
 else{
  entries.push({slot:4,label:ui.classAbilitiesLabel,icon:'ir_more_sp_ab',children:()=>({title:ui.classAbilitiesLabel,entries:descriptors.map(d=>descriptorEntry(d,d.classIndex)).filter(Boolean)})});
  if(p.owns(1089)){const entry=leafEntry(1089,3);if(entry)entries.push(entry);}
 }
 if(ui.innateMenu)entries.push({slot:7,label:ui.innateLabel,icon:'IR_MORE_SP_AB',children:ui.innateMenu});
 return {title:ui.title,entries};
}
