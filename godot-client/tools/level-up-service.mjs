import {ABILITIES} from '../../src/character.js';
import {rows,cell,num} from '../../src/character_creation.js';
import {loadLevelUpRules,initialLevelUpDraft,levelUpTotal,levelUpClassLevel,levelUpAbilities,levelUpSkillRule,levelUpSkillBalance,levelUpGrantedFeats,levelUpFeatSlots,levelUpFeatRequirement,levelUpFeatAllows,levelUpSpellOptions,levelUpSpellCount,levelUpErrors,levelUpProposal} from '../../src/character_level_up.js';
import {networkLevelUpSnapshot} from '../../src/network_level_up.js';
const steps=['Class','Abilities','Skills','Feats','Spells','Companions','Review'];
const stamp=v=>JSON.stringify(v);

// Native presentation adapter for the existing progression helpers and session
// transaction. A draft never mutates the live actor, XP, spells or class levels.
export class LevelUpService{
 constructor({actions,loadRules=null,restore=async()=>{},onRequest=()=>{},onResult=()=>{}}){Object.assign(this,{actions,loadRules,restore,onRequest,onResult});this.serial=0;this.epoch=0;this.renderEpoch=0;this.reset();}
 get session(){return this.actions.session;}
 capture(){return{...this.actions.capture(),world:this.session.world};}
 owned(s){return s?.world===this.session.world&&this.actions.owned(s);}
 base(s){return{areaId:s.areaId,areaGeneration:s.areaGeneration,actorId:s.actorId};}
 reset(){this.epoch++;this.renderEpoch++;this.opened=false;this.phase='closed';this.view=null;this.draft=null;this.scope=null;this.snapshot=null;this.snapshotKey=null;this.token=null;this.available=null;this.replication=null;this.availability=null;}
 rules(){if(!this.rulesWork)this.rulesWork=Promise.resolve().then(()=>this.loadRules?this.loadRules():loadLevelUpRules({getResource:(...args)=>this.session.getResource(...args)})).catch(error=>{this.rulesWork=null;throw error;});return this.rulesWork;}
 emit(row){this.actions.emit(row);}
 async name(table,id,column='Name'){const row=rows(this.ruleData[table])[id],ref=cell(row,column);return ref&&ref!=='****'?await this.actions.text.resolve({strRef:Number(ref)>>>0},this.scope.actorId)||cell(row,'Label')||`${table} ${id}`:cell(row,'Label')||`${table} ${id}`;}
 async observe(){
  const s=this.capture();if(!this.owned(s))return;
  if(this.replication&&(!this.owned(this.replication.scope)||levelUpTotal({classes:s.actor.replicated?.stats?.classes??[]})>this.replication.before))this.replication=null;
  const available=Boolean(s.actor.playerState?.combat?.canLevelUp)&&!this.replication;
  const classes=s.actor.replicated?.stats?.classes??[],level=classes.length?levelUpTotal({classes}):null;
  const key=stamp([s.actorId,available,this.opened,classes]);if(key!==this.availability){this.availability=key;this.emit({kind:'level-availability',available,opened:this.opened,level,classes});}
  if(available&&!this.rulesWork)void this.rules().catch(error=>this.actions.diagnose('godot.level-rules-unavailable',error.message));
  if(!this.opened)return;
  if(!this.owned(this.scope)){this.reset();this.emit({kind:'level-closed'});return;}
  if(this.phase==='editing'&&this.snapshotKey!==this.liveSnapshot()){this.phase='stale';this.status='The character changed. Close and reopen Level Up.';await this.render();}
  if(this.phase==='uncertain'&&!this.session.pendingLevelUp&&!this.session.levelUpUncertain){this.phase='finished';this.status='The server finished processing. Close and reopen to review the character.';await this.render();}
 }
 liveSnapshot(){try{return stamp(networkLevelUpSnapshot(this.scope.actor));}catch{return null;}}
 async open(){
  if(this.opened){await this.render();return;}
  if(this.replication)throw Error('Waiting for the updated character statistics');
  const s=this.capture();if(!this.owned(s))throw Error('Level-up owner is unavailable');
  const epoch=++this.epoch;this.scope=s;this.opened=true;this.phase='loading';this.status='Requesting available classes from the server…';this.step=0;this.group=null;this.filter='';this.showUnavailable=false;this.kind='bonus';this.spellLevel=1;this.draft=null;
  await this.render();let response;
  try{
   const server=this.session.levelUp({...this.base(s),operation:'begin'}).then(value=>{response=value;this.onRequest({operation:'begin',token:value.token,available:value.available,beforeLevel:levelUpTotal(value.snapshot),snapshot:structuredClone(value.snapshot)});return value;});
   const [result,rules]=await Promise.all([server,this.rules()]);
   if(epoch!==this.epoch||!this.opened||!this.owned(s)){if(this.owned(s)&&this.session.levelUpDraft?.token===result.token)await this.session.levelUp({...this.base(s),operation:'cancel'});return;}
   this.ruleData=rules;this.snapshot=result.snapshot;this.snapshotKey=stamp(result.snapshot);this.token=result.token;this.available=result.available;
   const id=this.snapshot.classes.find(c=>this.available[c.id])?.id??this.available.findIndex(Boolean);if(id<0)throw Error('The server has no available classes');
   this.selectClass(id);this.phase='editing';this.status='';await this.render();
  }catch(error){if(epoch===this.epoch&&this.opened&&this.owned(s)){this.phase=this.session.pendingLevelUp?'uncertain':'error';this.status=error.message;await this.render();}else if(response&&this.owned(s)&&this.session.levelUpDraft?.token===response.token)await this.session.levelUp({...this.base(s),operation:'cancel'});}
 }
 selectClass(id){if(!this.available[id]||!rows(this.ruleData.classes)[id])throw Error('That class is unavailable');this.draft=initialLevelUpDraft(this.snapshot,id);const cls=rows(this.ruleData.classes)[id];this.draft.hitDie=num(cls,'HitDie',1);this.group=null;this.spellLevel=1;if(num(cls,'LearnScroll')&&levelUpClassLevel(this.snapshot,id)===0)this.draft.known[0]=levelUpSpellOptions(this.snapshot,this.draft,this.ruleData,0).map(s=>s.id);}
 current(id){const v=this.view;if(!this.opened||!v||v.id!==id||!this.owned(v.scope)||this.phase!=='editing'||this.liveSnapshot()!==this.snapshotKey)throw Error('Level-up choices are stale');return v;}
 texts(v,texts=[]){if(!Array.isArray(texts)||texts.length>4||new Set(texts.map(v=>v.controlId)).size!==texts.length)throw Error('Invalid level-up text fields');for(const row of texts){const c=v.controls.get(row.controlId);if(c?.type!=='input'||c.disabled||typeof row.value!=='string'||row.value.length>c.maxLength)throw Error('Invalid level-up text field');}for(const row of texts)v.controls.get(row.controlId).change(row.value);}
 async navigate({viewId,step,texts=[]}){const v=this.current(viewId);if(!Number.isInteger(step)||step<0||step>=steps.length)throw Error('Invalid level-up page');this.texts(v,texts);this.view=null;this.step=step;await this.render();}
 async edit({viewId,controlId,value,texts=[]}){const v=this.current(viewId),c=v.controls.get(controlId);if(!c||c.disabled)throw Error('Level-up control is unavailable');if(c.type==='input'&&(typeof value!=='string'||value.length>c.maxLength)||c.type==='toggle'&&typeof value!=='boolean'||c.type==='select'&&(!Number.isInteger(value)||value<0||value>=c.options.length))throw Error('Invalid level-up value');this.texts(v,texts);this.view=null;try{c.change(value);}finally{await this.render();}}
 async restoreHud(s){try{if(this.owned(s))await this.restore(s);}catch(error){this.actions.diagnose('godot.level-hud-restore-unavailable',error.message);}}
 async cancel(){if(['submitting','uncertain'].includes(this.phase))throw Error('Waiting for the server level-up reply');const s=this.scope;this.reset();if(s&&this.owned(s)){await this.session.levelUp({...this.base(s),operation:'cancel'});this.onRequest({operation:'cancel'});await this.restoreHud(s);}this.emit({kind:'level-closed'});}
 async submit({viewId}){
  this.current(viewId);if(this.step!==6)throw Error('Review the choices before finishing');const s=this.scope,epoch=this.epoch,beforeLevel=levelUpTotal(this.snapshot),proposal=levelUpProposal(this.snapshot,this.draft,this.ruleData);
  this.phase='submitting';this.status='Waiting for server confirmation…';await this.render();
  try{const result=await this.session.levelUp({...this.base(s),operation:'submit',token:this.token,proposal});this.onRequest({operation:'submit',proposal:structuredClone(proposal)});this.onResult({...result,...this.base(s),beforeLevel,classId:proposal.classId});
   if(epoch!==this.epoch||!this.opened||!this.owned(s))return;
   if(result.accepted){await this.restoreHud(s);if(epoch!==this.epoch||!this.owned(s))return;this.reset();this.replication={scope:s,before:beforeLevel};this.emit({kind:'level-complete',accepted:true});}
   else{this.phase='rejected';this.status='The server rejected these choices. Close and reopen Level Up; see feedback in chat.';await this.render();}
  }catch(error){if(epoch===this.epoch&&this.opened&&this.owned(s)){this.phase=this.session.pendingLevelUp||this.session.levelUpUncertain?'uncertain':'error';this.status=error.message;await this.render();}}
 }
 async render(){
  if(!this.opened||!this.owned(this.scope))return;const revision=++this.renderEpoch,s=this.scope,controls=new Map(),items=[],d=this.draft,r=this.ruleData,snapshot=this.snapshot;
  const text=(label,tag='')=>items.push({type:'text',label,tag});
  const add=(type,label,change,{disabled=false,...fields}={})=>{const controlId=controls.size;controls.set(controlId,{type,change,disabled,...fields});items.push({type,label,controlId,disabled,...fields});};
  const choose=(label,options,current,change,tag)=>{const optionsIndex=options.findIndex(v=>v.id===current);add('select',label,value=>{if(!Number.isInteger(value)||!options[value])throw Error('Invalid level-up selection');change(options[value].id);},{options:options.map(v=>v.label),value:optionsIndex,tag});};
  const editing=this.phase==='editing';
  if(editing){const cls=rows(r.classes)[d.classId];
   if(this.step===0){for(const[id,row]of rows(r.classes).entries())if(this.available[id])add('button',`${await this.name('classes',id)} (${levelUpClassLevel(snapshot,id)+1})`,()=>this.selectClass(id),{selected:d.classId===id,tag:'class',value:id});}
   if(this.step===1){const due=(levelUpTotal(snapshot)+1)%4===0,abilities=levelUpAbilities(snapshot,d,r);text(due?'Choose one ability to increase.':'No ability increase at this level.');for(const[id,key]of ABILITIES.entries())add('button',`${['Strength','Dexterity','Constitution','Intelligence','Wisdom','Charisma'][id]}: ${abilities[key]}`,()=>{d.ability=id;},{disabled:!due,selected:d.ability===id,tag:'ability',value:id});}
   if(this.step===2){text(`Skill points remaining: ${levelUpSkillBalance(snapshot,d,r)}`,'skill-balance');for(const[id,row]of rows(r.skills).entries()){const rule=levelUpSkillRule(snapshot,d,r,id);if(!rule.allowed||id>=d.skills.length)continue;const title=`${await this.name('skills',id)}${rule.classSkill?'':' (cross-class)'} · ${snapshot.skills[id]+d.skills[id]}/${rule.max}`;text(title,'skill');add('button','−',()=>{d.skills[id]--;},{disabled:d.skills[id]<=0,tag:'skill-minus',value:id});add('button','+',()=>{d.skills[id]++;},{disabled:snapshot.skills[id]+d.skills[id]>=rule.max||levelUpSkillBalance(snapshot,d,r)<rule.cost||d.skills[id]>=127,tag:'skill-plus',value:id,cost:rule.cost});}}
   if(this.step===3){
    for(const[index,f]of d.feats.entries())add('button',`${f.kind==='bonus'?'Class bonus':'General'}: ${await this.name('feat',f.id,'FEAT')} · Remove`,()=>{d.feats.splice(index,1);},{tag:'feat-remove',value:f.id});
    text('Automatic feats: '+((await Promise.all(levelUpGrantedFeats(snapshot,d,r).map(id=>this.name('feat',id,'FEAT')))).join(', ')||'None'));
    const slots=levelUpFeatSlots(snapshot,d,r),kinds=['bonus','normal'].filter(kind=>d.feats.filter(f=>f.kind===kind).length<slots[kind]);
    if(!kinds.length)text('All feat choices complete.');else{
     if(!kinds.includes(this.kind))this.kind=kinds[0];choose('Feat slot',kinds.map(id=>({id,label:id==='bonus'?'Class bonus':'General'})),this.kind,id=>{this.kind=id;this.group=null;},'feat-kind');
     add('toggle','Show unavailable feats',value=>{if(typeof value!=='boolean')throw Error('Invalid feat filter');this.showUnavailable=value;},{value:this.showUnavailable,tag:'feat-unavailable'});
     add('input','Filter feats',value=>{if(typeof value!=='string'||value.length>128)throw Error('Invalid feat filter');this.filter=value;},{value:this.filter,maxLength:128,tag:'feat-filter'});
     const entries=[],groups=new Map();for(const[id,row]of rows(r.feat).entries()){if(!levelUpFeatAllows(d,r,id,this.kind))continue;const reason=levelUpFeatRequirement(snapshot,d,r,id);if(reason&&!this.showUnavailable)continue;const label=await this.name('feat',id,'FEAT'),groupId=num(row,'MASTERFEAT',-1),group=rows(r.masterfeats)[groupId],groupName=group?await this.name('masterfeats',groupId,'STRREF'):'';if(this.filter&&!`${label} ${groupName}`.toLowerCase().includes(this.filter.toLowerCase()))continue;const entry={id,label,reason};if(group){if(!groups.has(groupId))groups.set(groupId,{id:groupId,label:groupName,entries:[]});groups.get(groupId).entries.push(entry);}else entries.push(entry);}
     const pick=e=>add('button',e.label+(e.reason?' · '+e.reason:''),()=>{d.feats.push({id:e.id,kind:this.kind});},{disabled:Boolean(e.reason),tag:'feat',value:e.id});
     if(groups.has(this.group)){add('button','‹ All feats',()=>{this.group=null;},{tag:'feat-back'});for(const e of groups.get(this.group).entries.sort((a,b)=>a.label.localeCompare(b.label)))pick(e);}
     else for(const e of [...entries,...[...groups.values()].map(g=>({...g,group:true}))].sort((a,b)=>a.label.localeCompare(b.label))){if(e.group)add('button',e.label+' ›',()=>{this.group=e.id;},{tag:'feat-group',value:e.id});else pick(e);}
    }
   }
   if(this.step===4){const levels=Array.from({length:10},(_,l)=>l).filter(l=>levelUpSpellCount(snapshot,d,r,l)>0);if(!levels.length)text('This level has no new spell choices.');else{if(!levels.includes(this.spellLevel))this.spellLevel=levels[0];choose('Spell level',levels.map(id=>({id,label:'Level '+id})),this.spellLevel,id=>{this.spellLevel=id;},'spell-level');const level=this.spellLevel,count=levelUpSpellCount(snapshot,d,r,level),shared=num(cls,'LearnScroll')&&levelUpClassLevel(snapshot,d.classId)>0,total=shared?Object.values(d.known).reduce((n,a)=>n+a.length,0):(d.known[level]??[]).length;text(`${shared?'New spells across all levels':'New spells'}: ${total} / ${count}`);for(const spell of levelUpSpellOptions(snapshot,d,r,level)){const selected=(d.known[level]??[]).includes(spell.id);add('button',await this.name('spells',spell.id),()=>{const list=d.known[level]??=[];if(selected)list.splice(list.indexOf(spell.id),1);else list.push(spell.id);},{disabled:!selected&&total>=count,selected,tag:'spell',value:spell.id});}}
    if(num(cls,'PickDomains')&&levelUpClassLevel(snapshot,d.classId)===0)for(let i=0;i<2;i++)choose('Domain '+(i+1),await Promise.all(rows(r.domains).map(async(row,id)=>({id,label:await this.name('domains',id)}))),d.domains[i]??-1,id=>{d.domains[i]=id;},'domain-'+i);
    if(num(cls,'PickSchool')&&levelUpClassLevel(snapshot,d.classId)===0)choose('School',await Promise.all(rows(r.spellschools).map(async(row,id)=>({id,label:await this.name('spellschools',id)}))),d.school,id=>{d.school=id;d.known={};},'school');
   }
   if(this.step===5){let any=false;const feats=[...snapshot.feats,...levelUpGrantedFeats(snapshot,d,r),...d.feats.map(f=>f.id)];for(const[key,label,table,name,id]of[['fieldE34','Familiar','hen_familiar','fieldE48',303],['fieldE30','Animal companion','hen_companion','fieldE38',199]]){if(!feats.includes(id))continue;any=true;const options=[{id:255,label:'None'}];for(const[id,row]of rows(r[table]).entries())if(num(row,'PLAYER',1))options.push({id,label:await this.name(table,id,'STRREF')});choose(label,options,d[key],value=>{d[key]=value;},key);add('input',label+' name',value=>{if(typeof value!=='string'||value.length>63)throw Error('Invalid companion name');d[name]=value;},{value:d[name],maxLength:63,tag:name});}if(!any)text('No familiar or animal-companion choices at this level.');}
   if(this.step===6){text(`${await this.name('classes',d.classId)} ${levelUpClassLevel(snapshot,d.classId)+1}`);text(`Hit die: ${d.hitDie} · Skill points saved: ${levelUpSkillBalance(snapshot,d,r)}`);if(d.ability<6)text('Ability increase: '+['Strength','Dexterity','Constitution','Intelligence','Wisdom','Charisma'][d.ability]);for(const[id,change]of d.skills.entries())if(change)text(`${await this.name('skills',id)}: ${snapshot.skills[id]} → ${snapshot.skills[id]+change}`);text('New feats: '+((await Promise.all([...levelUpGrantedFeats(snapshot,d,r),...d.feats.map(f=>f.id)].map(id=>this.name('feat',id,'FEAT')))).join(', ')||'None'));for(const[level,list]of Object.entries(d.known))if(list.length)text(`Level ${level} spells: `+(await Promise.all(list.map(id=>this.name('spells',id)))).join(', '));if(num(cls,'PickDomains'))text('Domains: '+(await Promise.all(d.domains.map(id=>this.name('domains',id)))).join(', '));if(num(cls,'PickSchool'))text('School: '+await this.name('spellschools',d.school));text('The server validates and applies these choices.');}
  }
  if(revision!==this.renderEpoch||!this.opened||!this.owned(s))return;
  const errors=editing?levelUpErrors(snapshot,d,r):[],id=++this.serial;this.view={id,scope:s,controls};
  this.emit({kind:'level-view',viewId:id,step:this.step,steps,phase:this.phase,status:this.status,items,errors,canEdit:editing,canBack:editing&&this.step>0,canNext:editing&&this.step<6,canFinish:editing&&this.step===6&&!errors.length,canCancel:!['submitting','uncertain'].includes(this.phase),level:snapshot?levelUpTotal(snapshot)+1:null,classId:d?.classId});
 }
}
