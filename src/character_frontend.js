import { ABILITIES } from './character.js';
import { CharacterVault } from './character_vault.js';
import { loadCreationRules,initialCreationDraft,ALIGNMENTS,rows,cell,num,classTable,creationAlignmentAllowed,abilityPointCost,
  creationAbilities,initializeCreationAbilities,creationAbilityCanDecrease,creationPointBalance,creationSkillBudget,creationSkillRule,creationSkillBalance,creationGrantedFeats,creationFeatSlots,
  creationFeatListAllows,creationFeatRequirements,creationSpellCount,creationSpellOptions,creationSpellSlots,creationPreparedOptions,creationPortraits,creationVoices,creationPhenotypes,
  creationHeadModels,creationClothes,creationErrors,recommendCreation,createCharacterBic } from './character_creation.js';
import { runtimeDiagnostics } from './runtime_diagnostics.js';
import { TGALoader } from 'three/addons/loaders/TGALoader.js';
import { RESOURCE_TYPE } from './resource_archive.js';

const node=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n;};
const button=(label,action,disabled=false)=>{const b=node('button','game-button',label);b.type='button';b.disabled=disabled;b.addEventListener('click',()=>{void action();});return b;};
const steps=['Gender','Race','Portrait','Class','Alignment','Package','Abilities','Domains & school','Skills','Feats','Spells','Appearance','Voice','Name','Review'];

export class CharacterFrontend {
  constructor(viewport,{text,onCapture,onSelected,onPreview}={}){
    Object.assign(this,{getText:text,onCapture,onSelected,onPreview});this.vault=new CharacterVault();this.active=false;this.rules=null;this.portraits=new Map();this.palettes=new Map();
    this.root=node('div','character-frontend');this.root.id='character-frontend';this.root.hidden=true;viewport.append(this.root);
    for(const event of ['pointerdown','pointerup','click','dblclick','wheel','contextmenu'])this.root.addEventListener(event,e=>e.stopPropagation());
    window.addEventListener('keydown',e=>{if(!this.active)return;if(e.key==='Escape'){e.preventDefault();if(this.mode==='create'){this.mode='select';this.render();}else this.finish(null);}e.stopImmediatePropagation();},true);
    this.files=node('input');this.files.type='file';this.files.accept='.bic';this.files.multiple=true;this.files.hidden=true;this.files.id='vault-character-files';
    this.folder=node('input');this.folder.type='file';this.folder.webkitdirectory=true;this.folder.multiple=true;this.folder.hidden=true;this.folder.id='vault-character-folder';
    viewport.append(this.files,this.folder);
    for(const input of [this.files,this.folder])input.addEventListener('change',async()=>{await this.importFiles([...input.files],true);input.value='';if(this.active)this.render();});
  }
  async importFiles(files,persist=false){
    let count=0;for(const file of files.filter(f=>/\.bic$/i.test(f.name))){try{const entry=await this.vault.add(await file.arrayBuffer(),file.name,{persist,source:persist?'Local vault':'Installed character'});if(persist||!this.selected)this.selected=entry;count++;}catch(error){runtimeDiagnostics.error(error,'character.vault-import-failed',{file:file.name});if(persist)this.error=`${file.name}: ${error.message}`;}}
    return count;
  }
  async choose(resolver,{files=[],selected=null,moduleName='',create=false}={}){
    if(this.active)throw new Error('Character selection is already open');
    this.active=true;this.root.hidden=false;this.onCapture?.(true);this.moduleName=moduleName;this.mode='loading';this.error='';this.render();
    const result=new Promise(resolve=>{this.resolve=resolve;});
    this.previousFocus=document.activeElement;
    try{
      try{await this.vault.open();}catch(error){runtimeDiagnostics.error(error,'character.vault-open-failed');this.error=`Local character storage: ${error.message}`;}
      await this.importFiles(files);
      if(!this.active)return result;
      if(selected)this.selected=await this.vault.add(selected.bytes,selected.name);
      this.rules=await loadCreationRules(resolver);if(this.resolver!==resolver){this.portraits.clear();this.palettes.clear();}this.resolver=resolver;
      if(!this.active)return result;
      this.mode=create?'create':'select';this.step=0;if(create)this.draft=initialCreationDraft(this.rules);this.render();
    }catch(error){runtimeDiagnostics.error(error,'character.creation-data-failed');this.mode='error';this.error=error.message;this.render();}
    return result;
  }
  finish(entry){
    this.active=false;this.mode='closed';this.root.dataset.mode='closed';this.root.hidden=true;this.root.replaceChildren();this.previewVersion=(this.previewVersion??0)+1;
    this.onCapture?.(false);const resolve=this.resolve;this.resolve=null;if(entry)this.onSelected?.(entry);resolve?.(entry);this.previousFocus?.focus?.();
  }
  name(table,id,key='Name'){
    const row=rows(this.rules?.[table])[id],value=cell(row,key),text=this.getText?.();
    return value&&value!=='****'&&Number.isFinite(Number(value))?(text?.strRef(Number(value))??cell(row,'Label')??`${table} ${id}`):cell(row,'Label')??cell(row,'NAME')??`${table} ${id}`;
  }
  description(row){const ref=num(row,'Description',-1);return ref>=0?this.getText?.()?.strRef(ref)??'':'';}
  render(){
    this.root.replaceChildren();this.root.dataset.mode=this.mode;this.root.dataset.step=steps[this.step]??'';
    const panel=node('section','character-panel');panel.setAttribute('role','dialog');panel.setAttribute('aria-modal','true');panel.setAttribute('aria-labelledby','character-heading');this.root.append(panel);
    const header=node('header','character-header'),title=node('h2','',this.mode==='create'?'Create Character':'Select Character');title.id='character-heading';
    header.append(title,button('Cancel',()=>this.finish(null)));panel.append(header);
    if(this.moduleName)panel.append(node('p','character-destination',`Entering ${this.moduleName}`));
    if(this.error){const error=node('p','character-error',this.error);error.setAttribute('role','alert');panel.append(error);}
    if(this.mode==='loading'){panel.append(node('p','','Reading characters and active creation rules…'));return;}
    if(this.mode==='error')return;
    if(this.mode==='select')this.renderSelector(panel);else this.renderCreator(panel);
  }
  renderSelector(panel){
    const actions=node('div','character-actions');actions.append(button('Create Character',()=>{this.draft=initialCreationDraft(this.rules);this.step=0;this.mode='create';this.error='';this.render();}),button('Import Characters',()=>this.files.click()),button('Open Local Vault Folder',()=>this.folder.click()));panel.append(actions);
    const list=node('div','character-list');list.setAttribute('role','listbox');list.setAttribute('aria-label','Characters');panel.append(list);
    for(const entry of this.vault.entries.values()){
      const b=button('',()=>{this.selected=entry;this.render();});b.classList.add('character-card');b.dataset.characterId=entry.id;b.setAttribute('role','option');b.setAttribute('aria-selected',String(entry.id===this.selected?.id));
      const portrait=node('img','character-portrait');portrait.alt='';b.append(portrait);void this.portrait(entry.portrait,portrait);
      const info=node('div');info.append(node('strong','',entry.displayName),node('p','',`${this.name('racialtypes',entry.raceId)} · ${entry.classes.map(c=>`${this.name('classes',c.id)} ${c.level}`).join(' / ')}`),node('small','',`${entry.source} · ${entry.name}`));b.append(info);list.append(b);
    }
    if(!list.children.length)list.append(node('p','','No characters yet. Create a character or import a BIC from your local vault.'));
    const footer=node('footer','character-footer');footer.append(node('span','character-selected-name',this.selected?`Selected: ${this.selected.displayName}`:'Select a character'),button('Export BIC',()=>this.download(this.selected),!this.selected),button(this.moduleName?'Play':'Select Character',()=>this.finish(this.selected),!this.selected));panel.append(footer);
  }
  renderCreator(panel){
    const layout=node('div','character-creation-layout'),nav=node('nav','character-steps');nav.setAttribute('aria-label','Character creation steps');layout.append(nav);
    steps.forEach((label,i)=>{const b=button(`${i+1}. ${label}`,()=>{this.step=i;this.error='';this.render();});b.dataset.step=label;b.setAttribute('aria-current',i===this.step?'step':'false');nav.append(b);});
    const body=node('div','character-step-body');body.append(node('h3','',steps[this.step]));layout.append(body);panel.append(layout);
    const d=this.draft,r=this.rules,cls=rows(r.classes)[d.classId];
    if(num(cls,'LearnScroll'))d.known[0]=creationSpellOptions(d,r,0).map(s=>s.id);
    if(this.step===0)this.choiceList(body,rows(r.gender).slice(0,2).map((row,id)=>({id,label:this.name('gender',id,'NAME'),row})),d.gender,id=>{d.gender=id;d.portrait='';d.soundset=creationVoices(d,r)[0]?.id??0;d.head=creationHeadModels(d,r)[0]??1;});
    if(this.step===1){this.choiceList(body,rows(r.racialtypes).flatMap((row,id)=>num(row,'PlayerRace')?[{id,label:this.name('racialtypes',id),row}]:[]),d.raceId,id=>{d.raceId=id;d.age=num(rows(r.racialtypes)[id],'AGE',18);initializeCreationAbilities(d,r);this.resetChoices();d.head=creationHeadModels(d,r)[0]??1;});this.input(body,'Subrace','subrace');}
    if(this.step===2){const grid=node('div','character-portrait-grid');body.append(grid);for(const p of creationPortraits(d,r)){const b=button('',()=>{d.portrait=p.resref;this.render();});b.setAttribute('aria-label',p.resref);b.setAttribute('aria-pressed',String(d.portrait===p.resref));const img=node('img');img.alt=p.row.BaseResRef;b.append(img);grid.append(b);void this.portrait(p.resref,img);}}
    if(this.step===3)this.choiceList(body,rows(r.classes).flatMap((row,id)=>num(row,'PlayerClass')?[{id,label:this.name('classes',id),row,disabled:row.PreReqTable&&row.PreReqTable!=='****',reason:'Custom class prerequisite validation is not available for first-level creation'}]:[]),d.classId,id=>{d.classId=id;d.packageId=num(rows(r.classes)[id],'Package');const a=ALIGNMENTS.find(a=>creationAlignmentAllowed(rows(r.classes)[id],a.goodEvil,a.lawChaos));if(a){d.goodEvil=a.goodEvil;d.lawChaos=a.lawChaos;}initializeCreationAbilities(d,r);this.resetChoices();});
    if(this.step===4)this.choiceList(body,ALIGNMENTS.map(a=>({...a,disabled:!creationAlignmentAllowed(cls,a.goodEvil,a.lawChaos),reason:'Class alignment restriction'})),ALIGNMENTS.find(a=>a.goodEvil===d.goodEvil&&a.lawChaos===d.lawChaos)?.id,id=>{const a=ALIGNMENTS[id];d.goodEvil=a.goodEvil;d.lawChaos=a.lawChaos;});
    if(this.step===5){this.choiceList(body,rows(r.packages).flatMap((row,id)=>num(row,'ClassID',-1)===d.classId&&num(row,'PlayerClass')?[{id,label:this.name('packages',id),row}]:[]),d.packageId,id=>{d.packageId=id;});body.append(button('Use Recommended Choices',()=>this.recommend()),node('p','','A package supplies starting equipment, gold and recommendations. You can customize every choice.'));}
    if(this.step===6){body.append(node('p','character-points',`Ability points remaining: ${creationPointBalance(d,r)}`));const values=creationAbilities(d,r);for(const a of ABILITIES)this.counter(body,`${a} · total ${values[a]}`,d.abilities[a],delta=>{d.abilities[a]+=delta;this.resetChoices();this.render();},!creationAbilityCanDecrease(d,r,a),abilityPointCost(d.abilities[a]+1,r)-abilityPointCost(d.abilities[a],r)>creationPointBalance(d,r));body.append(node('p','','Displayed totals include racial adjustments. Changing abilities clears skill, feat and spell choices.'));}
    if(this.step===7){
      if(num(cls,'PickDomains'))for(let slot=0;slot<2;slot++)this.select(body,`Domain ${slot+1}`,rows(r.domains).map((row,id)=>({id,label:this.name('domains',id)})),d.domains[slot]??'',id=>{d.domains[slot]=id;d.feats=[];this.render();},true);
      if(num(cls,'PickSchool'))this.select(body,'Spell school',rows(r.spellschools).map((row,id)=>({id,label:this.name('spellschools',id,'StringRef')})),d.school,id=>{d.school=id;d.known={};this.render();});
      if(!num(cls,'PickDomains')&&!num(cls,'PickSchool'))body.append(node('p','','This class does not select domains or a spell school.'));
    }
    if(this.step===8){body.append(node('p','character-points',`Skill points remaining: ${creationSkillBalance(d,r)} / ${creationSkillBudget(d,r)}`));for(const [id,row]of rows(r.skills).entries()){const s=creationSkillRule(d,r,id);if(!s.allowed||num(row,'HideFromLevelUp'))continue;this.counter(body,`${this.name('skills',id)} · ${s.classSkill?'class':'cross-class'} · ${s.cost} point${s.cost===1?'':'s'}/rank`,d.skills[id]??0,delta=>{d.skills[id]=(d.skills[id]??0)+delta;d.feats=[];this.render();},!(d.skills[id]>0),(d.skills[id]??0)>=s.max||creationSkillBalance(d,r)<s.cost);}}
    if(this.step===9)this.renderFeats(body);
    if(this.step===10)this.renderSpells(body);
    if(this.step===11){
      const appearance=node('div','character-appearance-layout'),settings=node('div');body.append(appearance);appearance.append(settings);
      this.select(settings,'Body type',creationPhenotypes(r).map(p=>({id:p.id,label:this.name('phenotype',p.id)})),d.phenotype,id=>{d.phenotype=id;d.head=creationHeadModels(d,r)[0]??1;this.render();});
      this.select(settings,'Head',creationHeadModels(d,r).map(id=>({id,label:`Head ${id}`})),d.head,id=>{d.head=id;this.render();});
      this.select(settings,'Clothing',creationClothes(d,r).map(c=>({id:c.id,label:`Clothing ${c.id+1}`})),d.clothes,id=>{d.clothes=id;this.render();});
      for(const [key,label]of [['skin','Skin'],['hair','Hair'],['tattoo1','Tattoo 1'],['tattoo2','Tattoo 2']])this.colourPicker(settings,label,key);
      if(this.onPreview){const image=node('img','character-model-preview');image.alt='Character appearance preview';appearance.append(image);const v=this.previewVersion=(this.previewVersion??0)+1;void this.onPreview(structuredClone(d),r).then(url=>{if(this.active&&this.previewVersion===v&&image.isConnected)image.src=url;}).catch(e=>{runtimeDiagnostics.error(e,'character.preview-failed');if(image.isConnected)image.replaceWith(node('p','character-error',e.message));});}
    }
    if(this.step===12)this.choiceList(body,creationVoices(d,r).map(v=>({id:v.id,label:this.name('soundset',v.id,'STRREF'),row:v.row})),d.soundset,id=>{d.soundset=id;});
    if(this.step===13){for(const[key,label]of [['firstName','First name'],['lastName','Last name'],['age','Age'],['deity','Deity'],['biography','Biography']])this.input(body,label,key,{type:key==='age'?'number':key==='biography'?'textarea':'text',min:1});
      const feats=creationGrantedFeats(d,r);if(feats.includes(303)){this.select(body,'Familiar',rows(r.hen_familiar).map((row,id)=>({id,label:this.name('hen_familiar',id,'STRREF')})),d.familiar,id=>{d.familiar=id;});this.input(body,'Familiar name','familiarName');}
      if(feats.includes(199)){this.select(body,'Animal companion',rows(r.hen_companion).map((row,id)=>({id,label:this.name('hen_companion',id,'STRREF')})),d.companion,id=>{d.companion=id;});this.input(body,'Companion name','companionName');}}
    const errors=creationErrors(d,r);
    if(this.step===14){body.append(node('h4','',[d.firstName,d.lastName].join(' ').trim()||'Unnamed character'),node('p','',`${this.name('racialtypes',d.raceId)} · ${this.name('classes',d.classId)} 1`),node('p','',Object.entries(creationAbilities(d,r)).map(([a,v])=>`${a} ${v}`).join(' · ')),node('p','',`Feats: ${[...creationGrantedFeats(d,r),...d.feats.map(f=>f.id)].map(id=>this.name('feat',id,'FEAT')).join(', ')}`));if(errors.length){body.append(node('h4','','Complete these choices:'));const ul=node('ul','character-validation');errors.forEach(e=>ul.append(node('li','',e)));body.append(ul);}else body.append(node('p','','Your character is ready. Save it to the local vault, then select it to enter the module.'));}
    const footer=node('footer','character-footer');footer.append(button('Back',()=>{if(this.step>0){this.step--;this.render();}else{this.mode='select';this.render();}}),button('Recommended',()=>this.recommend()));
    if(this.step<steps.length-1)footer.append(button('Next',()=>{this.step++;this.render();}));else footer.append(button(this.saving?'Saving…':'Save Character',()=>this.save(),errors.length>0||this.saving));panel.append(footer);
  }
  resetChoices(){this.draft.skills={};this.draft.feats=[];this.draft.known={};this.draft.memorized={};}
  async recommend(){try{await recommendCreation(this.draft,this.rules);this.error='';this.render();}catch(error){this.fail(error,'character.recommendation-failed');}}
  choiceList(body,options,selected,onChange){const list=node('div','character-choices');body.append(list);for(const o of options){const b=button(o.label,()=>{onChange(o.id);this.render();},Boolean(o.disabled));b.dataset.choiceId=o.id;b.setAttribute('aria-pressed',String(selected===o.id));b.title=o.reason??this.description(o.row);list.append(b);}}
  select(body,label,options,selected,onChange,empty=false){const wrap=node('label','character-field');wrap.append(node('span','',label));const input=node('select');input.setAttribute('aria-label',label);if(empty)input.append(new Option('Select…',''));for(const o of options)input.append(new Option(o.label,String(o.id)));input.value=String(selected);input.addEventListener('change',()=>{if(input.value!=='')onChange(Number(input.value));});wrap.append(input);body.append(wrap);return input;}
  input(body,label,key,{type='text',min,max,rerender=false}={}){const wrap=node('label','character-field');wrap.append(node('span','',label));const input=node(type==='textarea'?'textarea':'input');if(type!=='textarea')input.type=type;if(min!==undefined)input.min=min;if(max!==undefined)input.max=max;if(type==='text')input.maxLength=32;input.value=this.draft[key];input.setAttribute('aria-label',label);input.addEventListener('input',()=>{this.draft[key]=type==='number'?Number(input.value):input.value;});input.addEventListener('change',()=>{if(rerender)this.render();});wrap.append(input);body.append(wrap);}
  counter(body,label,value,onChange,minusDisabled,plusDisabled){const row=node('div','character-counter');row.append(node('span','',label));const minus=button('−',()=>onChange(-1),minusDisabled),plus=button('+',()=>onChange(1),plusDisabled);minus.setAttribute('aria-label',`Decrease ${label}`);plus.setAttribute('aria-label',`Increase ${label}`);row.append(minus,node('output','',String(value)),plus);body.append(row);}
  renderFeats(body){
    const d=this.draft,r=this.rules,slots=creationFeatSlots(d,r),owned=[...creationGrantedFeats(d,r),...d.feats.map(f=>f.id)];
    body.append(node('p','',`Automatic feats: ${creationGrantedFeats(d,r).map(id=>this.name('feat',id,'FEAT')).join(', ')}`));
    for(const choice of d.feats)body.append(button(`${choice.kind==='bonus'?'Class bonus':'General'}: ${this.name('feat',choice.id,'FEAT')} · Remove`,()=>{d.feats.splice(d.feats.indexOf(choice),1);this.render();}));
    const kinds=['bonus','normal'].filter(kind=>d.feats.filter(f=>f.kind===kind).length<slots[kind]);
    if(!kinds.length){body.append(node('p','','All feat slots filled.'));return;}
    this.featKind=kinds.includes(this.featKind)?this.featKind:kinds[0];
    this.select(body,'Feat slot',kinds.map((k,i)=>({id:i,label:`${k==='bonus'?'Class bonus':'General'} (${slots[k]-d.feats.filter(f=>f.kind===k).length} remaining)`})),kinds.indexOf(this.featKind),i=>{this.featKind=kinds[i];this.render();});
    const search=node('input');search.type='search';search.placeholder='Filter feats';search.setAttribute('aria-label','Filter feats');search.value=this.featSearch??'';search.addEventListener('change',()=>{this.featSearch=search.value;this.render();});body.append(search);
    const list=node('div','character-choices');body.append(list);
    for(const [id,row]of rows(r.feat).entries()){
      if(!creationFeatListAllows(d,r,id,this.featKind))continue;const name=this.name('feat',id,'FEAT');if(this.featSearch&&!name.toLowerCase().includes(this.featSearch.toLowerCase()))continue;
      const reason=creationFeatRequirements(d,r,id,owned),b=button(reason?`${name} — ${reason}`:name,()=>{d.feats.push({id,kind:this.featKind});this.render();},Boolean(reason));b.dataset.featId=id;b.title=this.description(row);list.append(b);
    }
  }
  renderSpells(body){
    const d=this.draft,r=this.rules,cls=rows(r.classes)[d.classId];let choices=false;
    for(let l=0;l<10;l++){const count=creationSpellCount(d,r,l);if(!count)continue;choices=true;body.append(node('h4','',`Level ${l} · ${(d.known[l]??[]).length} / ${count} known`));
      if(l===0&&num(cls,'LearnScroll')){body.append(node('p','',`Automatic cantrips: ${creationSpellOptions(d,r,0).map(s=>this.name('spells',s.id)).join(', ')}`));continue;}
      const list=node('div','character-choices');body.append(list);for(const s of creationSpellOptions(d,r,l)){const selected=(d.known[l]??[]).includes(s.id),b=button(this.name('spells',s.id),()=>{const known=d.known[l]??=[];if(selected)known.splice(known.indexOf(s.id),1);else known.push(s.id);d.memorized={};this.render();},!selected&&(d.known[l]??[]).length>=count);b.setAttribute('aria-pressed',String(selected));b.dataset.spellId=s.id;b.title=this.description(s.row);list.append(b);}}
    if(!choices)body.append(node('p','',num(cls,'SpellCaster')?'This class receives its spell list automatically.':'This class does not learn spells at first level.'));
    if(num(cls,'MemorizesSpells'))for(let level=0;level<10;level++){
      const count=creationSpellSlots(d,r,level);if(!count)continue;body.append(node('h4','',`Prepare level ${level} spells`));
      for(let slot=0;slot<count;slot++){const domain=Boolean(num(cls,'PickDomains')&&level>0&&slot===count-1),options=creationPreparedOptions(d,r,level,domain);this.select(body,domain?'Domain slot':`Slot ${slot+1}`,[{id:-1,label:'Unprepared'},...options.map(id=>({id,label:this.name('spells',id)}))],d.memorized[level]?.[slot]??-1,id=>{const list=d.memorized[level]??=[];while(list.length<=slot)list.push(null);list[slot]=id===-1?null:id;});}
    }
  }
  async save(){if(this.saving)return;this.saving=true;this.render();try{const bytes=await createCharacterBic(this.draft,this.rules),name=(`${this.draft.firstName}_${this.draft.lastName}`.replace(/[^a-z0-9_-]/gi,'').slice(0,24)||'character')+'.bic';this.selected=await this.vault.add(bytes,name,{persist:true,source:'Created character'});this.mode='select';this.error='';}catch(error){this.fail(error,'character.creation-save-failed');}finally{this.saving=false;this.render();}}
  fail(error,category){runtimeDiagnostics.error(error,category);this.error=error.message;this.render();}
  download(entry){if(!entry)return;const url=URL.createObjectURL(new Blob([entry.bytes],{type:'application/octet-stream'})),a=node('a');a.href=url;a.download=entry.name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}
  colourPicker(body,label,key){
    const wrap=node('div','character-field'),picker=button(`Colour ${this.draft[key]}`,()=>{this.activePalette=this.activePalette===key?null:key;this.render();});wrap.append(node('span','',label),picker);body.append(wrap);
    const name=key==='skin'?'pal_skin01':key==='hair'?'pal_hair01':'pal_tattoo01';
    if(!this.palettes.has(name))this.palettes.set(name,this.resolver.getResource(name,RESOURCE_TYPE.TGA).then(bytes=>new TGALoader().parse(bytes)));
    const grid=this.activePalette===key?node('div','character-colour-grid'):null;if(grid){grid.setAttribute('aria-label',`${label} colours`);body.append(grid);}
    void this.palettes.get(name).then(image=>{if(!picker.isConnected)return;const colour=index=>{const p=((image.height-1-index)*image.width+Math.min(160,image.width-1))*4;return `rgb(${image.data[p]},${image.data[p+1]},${image.data[p+2]})`;};picker.style.borderLeft=`16px solid ${colour(this.draft[key])}`;if(grid?.isConnected)for(let i=0;i<Math.min(256,image.height);i++){const b=button('',()=>{this.draft[key]=i;this.activePalette=null;this.render();});b.style.background=colour(i);b.setAttribute('aria-label',`${label} colour ${i}`);b.setAttribute('aria-pressed',String(this.draft[key]===i));grid.append(b);}}).catch(error=>{runtimeDiagnostics.error(error,'character.palette-failed',{resource:name});});
  }
  async portrait(resref,img){
    if(!resref)return;
    try{if(!this.portraits.has(resref))this.portraits.set(resref,(async()=>{const image=new TGALoader().parse(await this.resolver.getResource(`${resref}m`,RESOURCE_TYPE.TGA)),canvas=node('canvas');canvas.width=image.width;canvas.height=Math.min(image.height,Math.round(image.width*100/64));canvas.getContext('2d').putImageData(new ImageData(new Uint8ClampedArray(image.data),image.width,image.height),0,0);return canvas.toDataURL();})());const url=await this.portraits.get(resref);if(img.isConnected)img.src=url;}
    catch(error){runtimeDiagnostics.error(error,'character.portrait-failed',{resref});}
  }
}
