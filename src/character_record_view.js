import {runtimeDiagnostics} from './runtime_diagnostics.js';
import {portraitImage} from './portrait_image.js';
import {nativeRichText} from './native_rich_text.js';

const el=(tag,cls='',text)=>{const n=document.createElement(tag);n.className=cls;if(text!==undefined)n.textContent=text;return n;};
const value=v=>v===null||v===undefined?'—':String(v);
const tabs=[['Character','ctl_chrtab_char','ir_examine'],['Skills','ctl_chrtab_skils','ir_skillself'],['Feats','ctl_chrtab_feats','ir_attack']];
const skinCache=new WeakMap();
const imageCache=new WeakMap();
const tabImages=new WeakMap();
const describe=(node,text)=>node.replaceChildren(...nativeRichText(text??'').spans.map(s=>{const span=el('span','',s.text);if(s.color)span.style.color=s.color;return span;}));
export function recordImage(assets,name){
 if(!assets||!name||name==='****')return Promise.resolve(null);let cache=imageCache.get(assets);if(!cache)imageCache.set(assets,cache=new Map());
 if(!cache.has(name))cache.set(name,(assets.image?assets.image(name):portraitImage(assets.resolver,name)).then(image=>{const canvas=document.createElement('canvas');canvas.width=image.width;canvas.height=image.height;canvas.getContext('2d').putImageData(new ImageData(new Uint8ClampedArray(image.data),image.width,image.height),0,0);return canvas.toDataURL();}));
 return cache.get(name);
}
async function tabImage(assets,tab){
 if(!assets)return null;let cache=tabImages.get(assets);if(!cache)tabImages.set(assets,cache=new Map());
 if(!cache.has(tab))cache.set(tab,(async()=>{
  const image=new Image();image.src=await recordImage(assets,'gui_char_icons');await image.decode();
  // Regions of the installed128x64 character-icon atlas, observed in the
  // isolated art fixture. The skills figure is stored vertically in the atlas.
  const [x,y,w,h,rotate]=({Character:[0,0,80,25,false],Skills:[80,0,24,60,true],Feats:[0,25,80,14,false]})[tab],scaleX=image.naturalWidth/128,scaleY=image.naturalHeight/64,canvas=document.createElement('canvas');
  canvas.width=rotate?h:w;canvas.height=rotate?w:h;const c=canvas.getContext('2d');if(rotate){c.translate(0,w);c.rotate(-Math.PI/2);}c.drawImage(image,x*scaleX,y*scaleY,w*scaleX,h*scaleY,0,0,w,h);return canvas.toDataURL();
 })());return cache.get(tab);
}
// A missing atlas must not replace a readable fallback with a black tab. Check
// this model's textures, rather than unrelated warnings in the shared asset set.
async function nativeSkin(assets,name,state){
 if(!assets)return null;let cache=skinCache.get(assets);if(!cache)skinCache.set(assets,cache=new Map());const key=name+':'+state;
 if(!cache.has(key))cache.set(key,(async()=>{const model=await assets.model(name);await Promise.all(model.model.materialNames.map(n=>assets.texture(n)));return assets.skin(name,state);})().catch(error=>{runtimeDiagnostics.record('ui.character-record-art-unavailable',error.message,{resource:name});return null;}));
 return cache.get(key);
}

// Shared presentation for local rules results and server-owned sheet records.
// This class never computes combat stats or changes a creature's game state.
export class CharacterRecordView{
 constructor({onTab=()=>{},close=null,assets=()=>null,icon=async()=>null,source=null}={}){
  Object.assign(this,{onTab,close,assets,icon,source});this.host=el('section','character-record');this.host.setAttribute('aria-label','Character Record');this.selected={};this.scroll=new Map();this.version=0;
 }
 reset(){this.version++;this.identity=null;this.selected={};this.scroll.clear();this.host.replaceChildren();}
 saveScroll(){if(this.host.isConnected)for(const node of this.host.querySelectorAll('[data-record-scroll]'))this.scroll.set(this.tab+':'+node.dataset.recordScroll,node.scrollTop);}
 async art(node,name,state='up'){const skin=await nativeSkin(this.assets(),name,state);if(node.isConnected&&skin?.url){node.style.backgroundImage=`url("${skin.url}")`;node.dataset.nativeModel=name;node.classList.add('record-native-art');}}
 image(node,name){if(!name||name==='****')return;void this.icon(name).then(url=>{if(url&&node.isConnected){const img=el('img');img.alt='';img.draggable=false;img.src=url;node.replaceChildren(img);}}).catch(error=>runtimeDiagnostics.record('ui.character-record-icon-unavailable',error.message,{resource:name}));}
 tabImage(node,tab,fallback){void tabImage(this.assets(),tab).then(url=>{if(url&&node.isConnected){const img=el('img');img.alt='';img.draggable=false;img.src=url;node.replaceChildren(img);}}).catch(()=>this.image(node,fallback));}
 render(model,tab='Character'){
  this.saveScroll();if(this.identity!==model.identity){this.identity=model.identity;this.selected={};this.scroll.clear();}this.tab=tab;this.model=model;const version=++this.version;
  const title=el('header','record-title'),heading=el('span','',`Character Record, ${model.name||'—'}`);title.append(heading);
  if(this.close){const close=el('button','record-close game-close','×');close.type='button';close.setAttribute('aria-label','Close Character Record');close.addEventListener('click',this.close);title.append(close);queueMicrotask(()=>void this.art(close,'ctl_btn_x'));}
  const nav=el('nav','record-tabs');nav.setAttribute('aria-label','Character Record pages');nav.setAttribute('role','tablist');
  for(const [label,name,fallback]of tabs){const b=el('button','record-tab');b.type='button';b.setAttribute('role','tab');b.setAttribute('aria-label',label);b.setAttribute('aria-selected',String(tab===label));b.title=label;
   const glyph=el('span','record-tab-glyph',label);b.append(glyph);b.addEventListener('click',()=>this.onTab(label));nav.append(b);
   queueMicrotask(()=>{if(version!==this.version)return;this.tabImage(glyph,label,fallback);void this.art(b,name,tab===label?'checkedup':'uncheckedup');});
  }
  const body=tab==='Character'?this.statistics(model):this.list(model,tab);this.host.replaceChildren(title,nav,body,el('div','record-resize','◆'));this.host.dataset.tab=tab;this.host.dataset.identity=String(model.identity);
  for(const node of this.host.querySelectorAll('[data-record-scroll]'))node.scrollTop=this.scroll.get(tab+':'+node.dataset.recordScroll)??0;
  return this.host;
 }
 statistics(m){
  const body=el('div','record-statistics'),top=el('div','record-overview'),portrait=el('div','record-portrait');
  if(m.portrait){const img=el('img');img.alt=`Portrait of ${m.name}`;img.draggable=false;img.src=m.portrait;portrait.append(img);}else portrait.append(el('span','record-unavailable','Portrait unavailable'));
  const stats=el('div','record-stat-grid'),identity=el('div','record-identity');identity.append(el('div','',[m.race,m.alignment].filter(Boolean).join(', ')||'—'));
  for(const line of m.classes??[])identity.append(el('div','',line));stats.append(identity);
  for(const a of m.abilities??[]){const row=el('div','record-ability');row.dataset.ability=a.key;const icon=el('span','record-ability-icon'),score=el('span','record-score',value(a.score)),mod=el('span','record-modifier',value(a.modifier));if(a.adjustment)score.dataset.adjustment=Math.sign(a.adjustment);if(a.modifierAdjustment)mod.dataset.adjustment=Math.sign(a.modifierAdjustment);row.append(el('span','record-ability-label',a.label),icon,score,mod);queueMicrotask(()=>this.image(icon,'gui_chrsht_'+a.key.toLowerCase()));stats.append(row);}
  top.append(portrait,stats);const foot=el('div','record-vitals'),left=el('div','record-health'),right=el('div','record-experience');left.append(el('div','',`AC   ${value(m.armorClass)}`),el('div','',`HP   ${value(m.currentHP)}/${value(m.maximumHP)}`));right.append(el('div','',`${m.labels?.experience??'Experience'}: ${value(m.experience)}`),el('div','',`${m.labels?.nextLevel??'Next Level'}: ${value(m.nextExperience)}`));foot.append(left,right);
  const details=el('div','record-details');details.dataset.recordScroll='details';details.tabIndex=0;details.setAttribute('aria-label','Combat and character statistics');
  for(const detail of m.details??[]){const line=el('div','record-detail');if(detail.tone)line.dataset.tone=detail.tone;if(detail.label)line.append(el('span','record-detail-label',detail.label.replace(/:\s*$/,'')+': '));for(const part of detail.parts??[{text:value(detail.value)}]){const span=el('span','',part.text);if(part.color)span.style.color=part.color;line.append(span);}details.append(line);}
  body.append(top,foot,details);return body;
 }
 list(m,tab){
  const body=el('div','record-list-page'),description=el('div','record-description');description.dataset.recordScroll='description';description.tabIndex=0;description.setAttribute('aria-label',tab==='Skills'?'Skill description':'Feat description');
  const list=el('div','record-entries');list.dataset.recordScroll='entries';list.setAttribute('role','listbox');list.setAttribute('aria-label',tab);const entries=tab==='Skills'?m.skills:m.feats;
  const select=entry=>{this.selected[tab]=entry.id;for(const b of list.children)b.setAttribute('aria-selected',String(b.dataset.recordId===String(entry.id)));describe(description,entry.description);description.scrollTop=0;};
  for(const entry of entries??[]){const row=el('button','record-entry');row.type='button';row.dataset.recordId=entry.id;row.setAttribute('role','option');row.setAttribute('aria-selected',String(this.selected[tab]===entry.id));const icon=el('span','record-entry-icon');row.append(icon,el('span','record-entry-name',entry.name));if(tab==='Skills')row.append(el('span','record-entry-value',value(entry.value)));row.addEventListener('click',()=>select(entry));if(entry.binding)this.source?.(row,entry.binding);list.append(row);queueMicrotask(()=>this.image(icon,entry.icon));}
  const selected=entries?.find(e=>e.id===this.selected[tab]);if(selected)describe(description,selected.description);
  if(!entries?.length)list.append(el('p','record-unavailable',m.waiting?.[tab]??`No ${tab.toLowerCase()} available.`));body.append(description,list);return body;
 }
}
