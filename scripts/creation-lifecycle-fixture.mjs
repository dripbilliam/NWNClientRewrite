import {CharacterFrontend} from '../src/character_frontend.js';
import {recommendCreation,creationErrors} from '../src/character_creation.js';
import {parseCharacter} from '../src/character.js';
import {NetworkLobby} from '../src/network_lobby.js';
const check=(v,message)=>{if(!v)throw Error(message);},deferred=()=>{let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});return{promise,resolve,reject};},tick=()=>new Promise(r=>setTimeout(r,0));
const base={getResource:async(name,type)=>{const r=await lifecycleFixture.resource(name,type);if(!r.ok)throw Object.assign(Error(r.message),{code:r.code});return r.bytes;},resourceNames:()=>lifecycleFixture.models(),portraitNames:()=>[],portraitAvailability:refs=>lifecycleFixture.portraitAvailability(refs)};
const contextual=label=>({label,reads:[],async getResource(name,type){this.reads.push({name,type});const bytes=await base.getResource(name,type);if(name==='classes'&&type===2017)return new TextEncoder().encode(new TextDecoder().decode(bytes).replace(/\bBarbarian\b/g,'Fixture'+label+'Barbarian')).buffer;return bytes;},resourceNames:base.resourceNames,portraitNames:base.portraitNames,portraitAvailability:base.portraitAvailability});
const wait=async(p,label)=>{let timer;try{return await Promise.race([p,new Promise((_,reject)=>timer=setTimeout(()=>reject(Error(label+' timed out')),15000))]);}finally{clearTimeout(timer);}};
function fixture(){
 const host=document.createElement('div');document.querySelector('#viewport').append(host);const selected=[],adds=[],ui=new CharacterFrontend(host,{text:()=>({strRef:ref=>'String '+ref}),onSelected:e=>selected.push(e)});
 ui.vault={entries:new Map(),open:async()=>{},async add(bytes,name){adds.push(name);const entry={id:name,name,bytes,displayName:name,classes:[]};this.entries.set(name,entry);return entry;}};
 const start=resolver=>{const result=ui.choose(resolver,{create:true,createOnly:true,moduleName:'Context '+resolver.label});return{result,work:ui.choiceWork};};
 const ready=async job=>{await wait(job.work,'Creator loading');check(ui.mode==='create',ui.error||'Creator did not become ready');};
 const current=(resolver,error='')=>{check(ui.active&&ui.mode==='create','Replacement chooser was closed');check(ui.resolver===resolver&&ui.rules.creationResolver===resolver,'Rules/resolver crossed contexts');check(ui.rules.classes.orderedRows[0].Label==='Fixture'+resolver.label+'Barbarian','Class table crossed contexts');check(ui.error===error,'Late operation changed current error');};
 const cancel=async job=>{ui.finish(null);const v=await Promise.race([job.result,new Promise((_,reject)=>setTimeout(()=>reject(Error('Cancel waited for pending IO')),1000))]);check(v===null,'Wrong chooser resolved');};
 const valid=async name=>{await recommendCreation(ui.draft,ui.rules);ui.draft.firstName=name;ui.draft.lastName='Fixture';check(creationErrors(ui.draft,ui.rules).length===0,'Recommended fixture character is invalid');};
 return{ui,start,ready,current,cancel,valid,selected,adds,cleanup(){if(ui.active)ui.finish(null);host.remove();}};
}
window.runCreationLifecycle=async()=>{
 const results=[];
 for(const reject of[false,true]){
  const f=fixture(),a=contextual('A'),b=contextual('B'),gate=deferred(),entered=deferred(),get=a.getResource.bind(a);let first=true;
  a.getResource=async(...args)=>{if(first){first=false;entered.resolve();await gate.promise;}return get(...args);};
  const old=f.start(a);await wait(entered.promise,'Deferred operation entry');await f.cancel(old);const next=f.start(b);await f.ready(next);f.ui.error='B remains current';
  if(reject)gate.reject(Error('Old context resource failure'));else gate.resolve();await wait(old.work,'Old rules settling');f.current(b,'B remains current');check(!f.selected.length,'Old load selected a character');results.push({case:reject?'late rules rejection':'late rules success',isolated:true,cancelIndependentOfIO:true});f.cleanup();await next.result;
 }
 for(const reject of[false,true]){
  const f=fixture(),a=contextual('A'),b=contextual('B'),gate=deferred(),entered=deferred();
  a.portraitAvailability=async refs=>{entered.resolve();await gate.promise;return base.portraitAvailability(refs);};
  const old=f.start(a);await wait(entered.promise,'Deferred portrait catalog');await f.cancel(old);const next=f.start(b);await f.ready(next);f.ui.error='B catalog remains current';
  if(reject)gate.reject(Error('Old portrait catalog failure'));else gate.resolve();await wait(old.work,'Old portrait catalog settling');f.current(b,'B catalog remains current');check(!f.selected.length,'Old portrait catalog selected a character');results.push({case:reject?'late portrait catalog rejection':'late portrait catalog success',isolated:true});f.cleanup();await next.result;
 }
 for(const stage of['file-read','selected-entry']){
  const f=fixture(),a=contextual('A'),b=contextual('B'),gate=deferred(),entered=deferred();let old;
  if(stage==='file-read')old={result:f.ui.choose(a,{create:true,createOnly:true,files:[{name:'old.bic',arrayBuffer:async()=>{entered.resolve();return gate.promise;}}]}),work:f.ui.choiceWork};
  else{const add=f.ui.vault.add.bind(f.ui.vault);f.ui.vault.add=async(bytes,name,...args)=>{if(name==='old.bic'){entered.resolve();await gate.promise;}return add(bytes,name,...args);};old={result:f.ui.choose(a,{create:true,createOnly:true,selected:{name:'old.bic',bytes:new ArrayBuffer(0)}}),work:f.ui.choiceWork};}
  await wait(entered.promise,'Deferred operation entry');await f.cancel(old);const next=f.start(b);await f.ready(next);f.ui.selected={id:'B selection'};gate.resolve(new ArrayBuffer(0));await wait(old.work,'Old import settling');f.current(b);check(f.ui.selected.id==='B selection','Old import replaced selection');if(stage==='file-read')check(!f.adds.length,'Cancelled file read reached vault add');results.push({case:stage,isolated:true});f.cleanup();await next.result;
 }
 {
  const f=fixture(),a=contextual('A'),b=contextual('B'),gate=deferred(),entered=deferred(),get=a.getResource.bind(a);const old=f.start(a);await f.ready(old);await f.valid('Old');let blocked=false;
  a.getResource=async(name,type)=>{if(type===2025&&!blocked){blocked=true;entered.resolve();await gate.promise;}return get(name,type);};
  const saving=f.ui.save();await wait(entered.promise,'Deferred operation entry');await f.cancel(old);const next=f.start(b);await f.ready(next);gate.resolve();await wait(saving,'Old BIC settling');f.current(b);check(!f.adds.length&&!f.selected.length,'Cancelled BIC save selected/persisted');results.push({case:'cancel during BIC resource read',isolated:true});f.cleanup();await next.result;
 }
 {
  const f=fixture(),a=contextual('A'),b=contextual('B'),gateA=deferred(),gateB=deferred(),enteredA=deferred(),enteredB=deferred(),add=f.ui.vault.add.bind(f.ui.vault);
  f.ui.vault.add=async(bytes,name,...args)=>{if(name.startsWith('Old_')){enteredA.resolve();await gateA.promise;}else if(name.startsWith('New_')){enteredB.resolve();await gateB.promise;}return add(bytes,name,...args);};
  const old=f.start(a);await f.ready(old);await f.valid('Old');const saveA=f.ui.save();await wait(enteredA.promise,'Old vault entry');await f.cancel(old);
  const next=f.start(b);await f.ready(next);await f.valid('New');const saveB=f.ui.save();await wait(enteredB.promise,'New vault entry');gateA.resolve();await wait(saveA,'Old vault write settling');f.current(b);check(f.ui.saving,'Old save cleared new saving state');check(!f.selected.length,'Old save selected in new context');
  gateB.resolve();await wait(saveB,'New vault write settling');const entry=await next.result;check(f.selected.length===1&&f.selected[0]===entry&&entry.name.startsWith('New_'),'New chooser selected old save');const character=parseCharacter(entry.bytes);check(character.FirstName.entries[0].text==='New','Wrong BIC submitted');results.push({case:'overlapping vault save callbacks',isolated:true,selectedName:'New',oldWriteCannotSubmit:true});f.cleanup();
 }
 {
  const f=fixture(),a=contextual('A'),b=contextual('B'),gate=deferred(),entered=deferred();const old=f.start(a);await f.ready(old);const load=f.ui.rules.loadCreationTable;let blocked=false;
  f.ui.rules.loadCreationTable=async(...args)=>{if(!blocked){blocked=true;entered.resolve();await gate.promise;}return load(...args);};const recommending=f.ui.recommend();await wait(entered.promise,'Deferred operation entry');await f.cancel(old);const next=f.start(b);await f.ready(next);f.ui.error='B recommendation untouched';gate.reject(Error('Old preference table failed'));await recommending;f.current(b,'B recommendation untouched');results.push({case:'late recommendation failure',isolated:true});f.cleanup();await next.result;
 }
 {
  const f=fixture(),a=contextual('A'),b=contextual('B'),gate=deferred(),entered=deferred(),get=a.getResource.bind(a);const old=f.start(a);await f.ready(old);
  a.getResource=async(name,type)=>{if(type===2060){entered.resolve();return gate.promise;}return get(name,type);};f.ui.step=12;f.ui.render();const button=f.ui.root.querySelector('.character-choices button');check(button,'No voice fixture choice');button.dispatchEvent(new MouseEvent('dblclick',{bubbles:true}));await wait(entered.promise,'Deferred operation entry');await f.cancel(old);const next=f.start(b);await f.ready(next);f.ui.error='B voice untouched';gate.reject(Error('Old SSF failed'));await tick();await tick();f.current(b,'B voice untouched');results.push({case:'late voice failure',isolated:true});f.cleanup();await next.result;
 }
 {
  const f=fixture(),a=contextual('A'),b=contextual('B'),gate=deferred(),entered=deferred();const old=f.start(a);await f.ready(old);const get=a.getResource.bind(a);let imageReads=0;
  a.getResource=async(name,type)=>{if(name.startsWith('fixtureportrait')){imageReads++;if(imageReads===1){entered.resolve();await gate.promise;throw Object.assign(Error('Try next size'),{code:'RESOURCE_NOT_FOUND'});}const bytes=new Uint8Array(21);bytes[2]=2;bytes[12]=bytes[14]=1;bytes[16]=24;bytes[20]=255;return bytes.buffer;}return get(name,type);};
  const img=document.createElement('img');f.ui.root.append(img);const portrait=f.ui.portrait('fixtureportrait',img);await wait(entered.promise,'Deferred operation entry');await f.cancel(old);const next=f.start(b);await f.ready(next);const before=b.reads.length;gate.resolve();await portrait;f.current(b);check(imageReads>=2&&b.reads.length===before,'Portrait fallback crossed resolver');check(!img.src,'Detached portrait was painted');results.push({case:'portrait suffix fallback',isolated:true,readsStayWithOriginalResolver:true});f.cleanup();await next.result;
 }
 {
  const f=fixture(),a=contextual('A'),b=contextual('B'),old=f.start(a);await f.ready(old);let next;
  f.ui.onCapture=capture=>{if(!capture&&!next)next=f.start(b);};await f.cancel(old);await f.ready(next);f.current(b);check(typeof f.ui.resolve==='function','Finishing old chooser stole new resolver');f.ui.onCapture=null;f.cleanup();check(await next.result===null,'New result was resolved by old finish');results.push({case:'reentrant capture callback',isolated:true});
 }
 {
  const f=fixture(),a=contextual('A'),job=f.start(a),gate=deferred(),entered=deferred();await f.ready(job);const load=f.ui.rules.loadCreationTable;let blocked=false;
  f.ui.rules.loadCreationTable=async(...args)=>{if(!blocked){blocked=true;entered.resolve();await gate.promise;}return load(...args);};const recommending=f.ui.recommend();await wait(entered.promise,'Preference table entry');f.ui.draft.firstName='Edited';f.ui.draft.abilities.Str=12;const edited=JSON.stringify(f.ui.draft);gate.resolve();await recommending;check(JSON.stringify(f.ui.draft)===edited,'Recommendation overwrote intervening edits');check(!f.ui.error,'Stale recommendation showed error');results.push({case:'edit during recommendation',editsPreserved:true});f.cleanup();await job.result;
 }
 for(const stage of['resource','vault']){
  const f=fixture(),a=contextual('A'),job=f.start(a),gate=deferred(),entered=deferred();await f.ready(job);await f.valid('Before');
  if(stage==='resource'){const get=a.getResource.bind(a);let blocked=false;a.getResource=async(name,type)=>{if(type===2025&&!blocked){blocked=true;entered.resolve();await gate.promise;}return get(name,type);};}
  else{const add=f.ui.vault.add.bind(f.ui.vault);f.ui.vault.add=async(...args)=>{entered.resolve();await gate.promise;return add(...args);};}
  const saving=f.ui.save();await wait(entered.promise,'Save entry');f.ui.draft.firstName='After';gate.resolve();await wait(saving,'Edited save settling');f.current(a);check(f.ui.draft.firstName==='After'&&!f.ui.saving,'Edited draft lost or save remained busy');check(!f.selected.length,'Edited draft submitted an old character');check(!f.ui.root.textContent.includes('Saving…'),'Stale saving UI');if(stage==='resource')check(!f.adds.length,'Edited BIC reached vault');results.push({case:'edit during '+stage+' save',editsPreserved:true,staleSubmission:false});f.cleanup();await job.result;
 }
 {
  const f=fixture(),a=contextual('A'),job={result:f.ui.choose(a,{create:true,createOnly:false}),work:f.ui.choiceWork};await f.ready(job);await f.valid('Local');await f.ui.save();check(f.ui.active&&f.ui.mode==='select'&&f.ui.root.dataset.mode==='select','Local save did not render selector');check(f.ui.root.querySelectorAll('.character-card').length===1,'Local saved entry missing');check(!f.ui.saving,'Local save stayed busy');results.push({case:'ordinary local save returns to selector',saved:true});f.cleanup();await job.result;
 }
 const lobbyFixture=()=>{
  const host=document.createElement('div'),button=document.createElement('button');host.append(button);document.body.append(host);const errors=[],previews=[];
  const frontend={id:'A',button,bridge:{previewLocalCharacter:async(id,bytes)=>{previews.push({id,bytes});return{classes:[],firstName:{text:'Local'},lastName:{text:''}};}}},lobby=new NetworkLobby(frontend);lobby.view='characters';lobby.error=e=>errors.push(e.message);let draws=0;lobby.drawCharacters=()=>{draws++;};
  const switchSession=()=>{frontend.id='B';lobby.reset();lobby.view='characters';lobby.selectedCharacter={id:'B selection'};lobby.status.textContent='B remains current';};
  const intact=()=>{check(lobby.selectedCharacter.id==='B selection','Old local file replaced new selection');check(!errors.length&&lobby.status.textContent==='B remains current','Old lobby error reached new view');};
  return{lobby,frontend,previews,errors,switchSession,intact,cleanup(){lobby.reset();lobby.root.remove();lobby.menuButton.remove();host.remove();}};
 };
 {
  const f=lobbyFixture(),gate=deferred(),entered=deferred();const loading=f.lobby.selectLocalFile({name:'old.bic',arrayBuffer:async()=>{entered.resolve();return gate.promise;}});await wait(entered.promise,'Deferred operation entry');f.switchSession();const bytes=new Uint8Array([1,2,3]);gate.resolve(bytes.buffer);await loading;f.intact();check(!f.previews.length&&bytes.every(v=>v===0),'Stale local file reached preview or retained bytes');results.push({case:'lobby file read crosses session',isolated:true});f.cleanup();
 }
 {
  const f=lobbyFixture(),gate=deferred(),entered=deferred();f.frontend.bridge.previewLocalCharacter=async(id,bytes)=>{f.previews.push({id,bytes});entered.resolve();return gate.promise;};const loading=f.lobby.selectLocalFile({name:'old.bic',arrayBuffer:async()=>new Uint8Array([1,2,3]).buffer});await wait(entered.promise,'Deferred operation entry');f.switchSession();gate.reject(Error('Old preview failed'));await loading;f.intact();check(f.previews[0].bytes.every(v=>v===0),'Stale preview retained bytes');results.push({case:'lobby preview rejection crosses session',isolated:true});f.cleanup();
 }
 {
  const f=lobbyFixture(),gate=deferred();const old=f.lobby.selectLocalFile({name:'old.bic',arrayBuffer:()=>gate.promise});await f.lobby.selectLocalFile({name:'new.bic',arrayBuffer:async()=>new Uint8Array([4,5,6]).buffer});const selected=f.lobby.selectedCharacter;gate.resolve(new Uint8Array([1,2,3]).buffer);await old;check(f.lobby.selectedCharacter===selected&&selected.firstName.text==='Local','Older file replaced newer selection');check(f.previews.length===1&&f.previews[0].bytes[0]===4,'Old file was previewed after new selection');results.push({case:'latest lobby file read wins',isolated:true});f.cleanup();
 }
 {
  const f=lobbyFixture(),gate=deferred(),entered=deferred();f.frontend.bridge.savedCharacters=()=>{entered.resolve();return gate.promise;};const loading=f.lobby.loadLocalEntries();await wait(entered.promise,'Deferred operation entry');f.switchSession();gate.reject(Error('Old vault failed'));await loading;f.intact();results.push({case:'lobby vault error crosses session',isolated:true});f.cleanup();
 }
 {
  const f=lobbyFixture(),gate=deferred();f.lobby.bindSession=()=>gate.promise;f.lobby.characterScreen({localVaultAllowed:false});f.switchSession();gate.reject(Error('Old font/table binding failed'));await tick();await tick();f.intact();check(Object.keys(f.lobby.tables).length===0,'Reset retained old rule tables');results.push({case:'lobby binding error crosses session',isolated:true});f.cleanup();
 }
 return{success:true,scope:'Actual Chromium creator/lobby lifecycle methods with installed local rule/UTI bytes; synthetic distinct class labels and explicitly deferred IO/vault/preview providers; lobby draw/error callbacks captured; no server connections or disk vault writes',cases:results};
};
