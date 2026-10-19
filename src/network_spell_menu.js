import {RESOURCE_TYPE,decodeResourceText} from './resource_archive.js';
import {parse2da} from './area.js';
import {intEntry} from './combat_stats.js';
import {nativeStringEntry,talentSpell} from './spell_metadata.js';
import {spellLevelByClass,metamagicLevelCost} from './spell_book.js';
import {networkSpellGain} from './network_spell_gain.js';
import {networkSpellUsesLeft} from './network_spellbook.js';
import {buildSpellRadial} from './spell_radial.js';
import {buildSpellLikeRadial} from './spell_like_radial.js';
import {featRadialProviders} from './feat_radial_rules.js';
import {buildFeatAbilityRadial} from './feat_radial.js';
import {featInfo} from './feat_uses.js';
const caches=new WeakMap();

export function replicatedSpellActor(actor,rules){
 const classes=actor.replicated?.stats?.classes??[],books=actor.playerState?.spellbooks??{};
 return{id:actor.id,objectType:5,areaId:actor.areaId,authored:{ClassList:classes.map(c=>({Class:c.id,ClassLevel:c.level,School:c.school??0,Domain1:c.domains?.[0]??0,Domain2:c.domains?.[1]??1})),FeatList:(actor.playerState?.feats??[]).map(Feat=>({Feat}))},nativeBonusFeats20:[...(actor.playerState?.bonusFeats??[])],
  nativeTalentClasses:classes.map((c,index)=>{const book=books[index],known=Array.from({length:10},()=>[]),memorized=Array.from({length:10},(_,level)=>(book?.memorized?.[level]??[]).map(s=>s?{id:s.spell,ready:s.ready,domain:s.domain,metamagic:s.metamagic}:null));for(const id of book?.known??[]){const level=spellLevelByClass(rules,id,c.id);if(level<10)known[level].push(id);}return{known,memorized};}),
  nativeSpellLikeAbilities:(actor.playerState?.specialAbilities??[]).map(a=>{if(!a)throw new Error('Replicated innate ability record is unavailable');return{id:a.spell,casterLevel:a.level,remaining:a.state};})};
}
export async function prepareNetworkSpellMenus(actor,target,base,resolver,resolve,report,{filter=65535,familiar=null}={}){
 let cache=caches.get(base);if(!cache){cache={tables:new Map()};caches.set(base,cache);}const classes=actor.replicated?.stats?.classes??[],wanted=new Set();
 for(const cls of classes)for(const key of ['SpellGainTable','StatGainTable','FeatsTable']){const name=nativeStringEntry(base.classes,cls.id,key).value.toLowerCase();if(name)wanted.add(name);}
 for(const name of wanted)if(!cache.tables.has(name))cache.tables.set(name,resolver.getResource(name,RESOURCE_TYPE.TWO_DA).then(b=>parse2da(decodeResourceText(b))));
 const rules={...base,classTables:new Map(await Promise.all([...wanted].map(async name=>[name,await cache.tables.get(name)])))},spellIds=new Set(),ownedFeatIds=new Set([...(actor.playerState?.feats??[]),...(actor.playerState?.bonusFeats??[])]),featIds=new Set(ownedFeatIds),text=new Map(),labels=new Map();
 const addSpell=id=>{if(spellIds.has(id))return;const s=talentSpell(rules,id);if(!s)return;spellIds.add(id);for(const child of s.children)addSpell(child);};
 for(const book of Object.values(actor.playerState?.spellbooks??{})){for(const id of book.known)addSpell(id);for(const slots of Object.values(book.memorized))for(const slot of slots)if(slot)addSpell(slot.spell);}
 for(const a of actor.playerState?.specialAbilities??[])if(a)addSpell(a.spell);
 for(const c of classes){if(intEntry(rules.classes,c.id,'MemorizesSpells').value===0&&intEntry(rules.classes,c.id,'SpellbookRestricted').value===0)for(let id=0;id<rules.spells.orderedRows.length;id++)if(spellLevelByClass(rules,id,c.id)<10)addSpell(id);for(const domain of c.domains??[]){const entry=intEntry(rules.domains,domain,'GrantedFeat');if(entry.found&&(entry.value&65535)!==65535)featIds.add(entry.value&65535);}}
 for(const id of featIds){const s=intEntry(rules.feat,id,'SpellId');if(s.found&&s.value>=0)addSpell(s.value);}
 const refs=new Set([84543,342,4848,4850,7471,427,517,518,523,84555]);for(const [table,ids,column]of [['classes',classes.map(c=>c.id),'Name'],['spells',[...spellIds],'Name'],['feat',[...featIds],'FEAT']])for(const id of ids){const e=intEntry(rules[table],id,column);if(e.found){labels.set(table+':'+id,e.value>>>0);refs.add(e.value>>>0);}}
 for(const id of featIds){const ref=intEntry(rules.feat,id,'FEAT');if(ref.found)refs.add(ref.value>>>0);}
 await Promise.all([...refs].map(async ref=>text.set(ref,await resolve({strRef:ref}))));const name=(table,id)=>text.get(labels.get(table+':'+id))||`${table==='feat'?'Feat':table==='classes'?'Class':'Spell'} ${id}`;
 const view=replicatedSpellActor(actor,rules),book={level:(id,type)=>spellLevelByClass(rules,id,type),metamagicCost:mask=>metamagicLevelCost(rules,mask),uses:(_view,id,index,domain,meta)=>networkSpellUsesLeft(actor,rules,id,index,domain,meta)};
 const spellProviders={name,hasFeat:(_view,id)=>ownedFeatIds.has(id),spellGain:(_view,index,level)=>networkSpellGain(actor,rules,index,level),readyForConversion:(_view,index,level)=>{const slots=actor.playerState?.spellbooks?.[index]?.memorized?.[level]??[];return slots.slice(0,slots.length&255).some(s=>s&&s.ready!==0&&s.domain===0);}};
 const innateMenu=()=>buildSpellLikeRadial(replicatedSpellActor(actor,rules),target,rules,{name},{filter});
 const abilityMenu=()=>{
  report('network.feat-menu-state-incomplete','Replicated combat mode is not yet projected into the ability menu',{actorId:actor.id});
  const p=featRadialProviders(replicatedSpellActor(actor,rules),target,rules,{familiar,remaining:id=>actor.playerState?.featUses?.[id]??(featInfo(rules,id)?.uses===0?100:0),warning:message=>report('network.feat-menu-warning',message,{actorId:actor.id})});
  return buildFeatAbilityRadial(p,{text:ref=>text.get(ref>>>0)||'',featName:id=>name('feat',id),className:index=>name('classes',classes[index].id),classIcon:index=>nativeStringEntry(rules.classes,classes[index].id,'Icon').value,title:'Special abilities',craftLabel:text.get(84543)||'Craft',tauntLabel:text.get(342)||'Taunt',searchLabel:text.get(4848)||'Search',stealthLabel:text.get(4850)||'Stealth',classAbilitiesLabel:text.get(7471)||'Class abilities',moreLabel:text.get(427)||'More abilities',innateLabel:'Innate abilities',innateMenu:view.nativeSpellLikeAbilities.length?innateMenu:null});
 };
 return{castMenu:()=>buildSpellRadial(replicatedSpellActor(actor,rules),target,rules,book,spellProviders,{filter}),abilityMenu,rules};
}
