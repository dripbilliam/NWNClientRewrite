import {originalBrowserSort,selectBrowserColumn,compareBrowserRows,stepBrowserSelection} from './server-browser-sort.mjs';
import {browserFilters,matchesBrowserFilters} from './server-browser-filters.mjs';
import {browserRow} from './server-browser-store.mjs';import {serverEndpoint,serverKey} from './server-endpoint.mjs';
const TABS=['Direct','Internet','History','Favorites'],SORTS=['Name','Module','Players','Latency'];
const REFRESH_COOLDOWN_MS=2000;
export class ServerBrowserService{
 constructor({lobby,policy,store,query,discover,settings,send,playerName=null,onEvent=()=>{},now=()=>performance.now()}){if(playerName!==null&&(typeof playerName!=='string'||!playerName.trim()||playerName.length>64||/[\x00-\x1f]/.test(playerName)))throw Error('Invalid player name');Object.assign(this,{lobby,policy,store,query,discover,settings,send,playerName,onEvent,now});this.serial=0;this.epoch=0;this.tasks=new Set();this.internetRows=[];this.internetLoaded=false;this.refreshReadyAt=0;this.reset();}
 reset(){this.inspectSerial=(this.inspectSerial??0)+1;this.inspectActive=false;this.inspectViewId=null;this.observedRows=new Map();this.inspectController?.abort(new Error('Server browser closed'));this.controller?.abort(new Error('Server browser closed'));this.controller=new AbortController();this.joining=false;this.epoch++;this.opened=false;this.busy=false;this.view=null;this.firstViewId=null;this.rows=[];this.page=0;this.tab='Direct';this.filter='';this.sort='Players';this.sourcePage=false;this.sourceSorts=Object.fromEntries(['Internet','History','Favorites'].map(tab=>[tab,originalBrowserSort(tab)]));this.filters={local:true,server:true,password:true};this.selected=null;this.details=null;this.status='';this.reopen=false;}
 owned(epoch=this.epoch){return!this.closed&&this.opened&&this.connection===this.lobby.connection&&epoch===this.epoch;}
 emit(value){if(!this.closed)this.send({...value,connection:this.lobby.connection});}
 async retire(){const joining=this.joining;this.closed=true;this.reset();if(joining&&this.lobby.snapshot().canCancelJoin)await this.lobby.cancelJoin({connection:this.lobby.connection}).catch(()=>{});await Promise.allSettled([...this.tasks]);await this.store.settled();return{closed:true,pending:this.tasks.size};}
 async command(message){let work;try{if(this.closed||message.connection!==this.lobby.connection)throw Error('Server browser belongs to an old connection');work=Promise.resolve().then(()=>this.perform(message));this.tasks.add(work);return await work;}catch(error){
  // Rejected current-view input still needs an authoritative retry view. The
  // native sender disabled its controls while submitting; a generic lobby
  // notice cannot restore those controls or certify their current capabilities.
  // Never unlock another pending operation or revive a retired presentation.
  if(this.owned()&&!this.busy&&this.view?.id===message.viewId&&!['open','close'].includes(message.operation)){this.status=error.message;await this.render();}
  throw error;
 }finally{if(message.values&&typeof message.values==='object'){message.values.password='';message.values.cdKey='';}this.tasks.delete(work);}}
 current(id){if(!this.owned()||!this.view||id!==this.view.id||this.busy)throw Error('Server browser choices are stale');return this.view;}
 entry(id){const row=this.view?.entries.get(id);if(!row)throw Error('Select a server from the current list');return row;}
 async perform(m){
  if(m.on!==undefined&&(m.operation!=='favorite'||typeof m.on!=='boolean'))throw Error('Invalid favorite state');
  if(m.leaveMultiplayer!==undefined&&(m.operation!=='close'||typeof m.leaveMultiplayer!=='boolean'))throw Error('Invalid multiplayer dismissal');
  if(m.listTab!==undefined&&(m.operation!=='open'||!['Internet','History','Favorites'].includes(m.listTab)))throw Error('Invalid browser return page');
  if(['inspect','join','favorite'].includes(m.operation)&&m.direct!==undefined&&typeof m.direct!=='boolean')throw Error('Invalid server selection');
  if(m.operation==='close'){const joining=this.joining;if(m.leaveMultiplayer&&!this.saved?.profileDefault){this.profileName=undefined;if(this.lastAttempt)this.lastAttempt={...this.lastAttempt,name:''};}this.reset();this.emit({kind:'browser-closed'});if(joining&&this.lobby.snapshot().canCancelJoin)await this.lobby.cancelJoin({connection:this.lobby.connection});return;}
  if(m.operation==='return-menu'){
   // Cancel can overtake the busy view emitted by a query. Accept any view
   // from this presentation, but never a handle from an earlier opening.
   if(!this.owned()||!Number.isSafeInteger(m.viewId)||this.firstViewId===null||m.viewId<this.firstViewId||m.viewId>this.view.id)throw Error('Server browser choices are stale');
   const joining=this.joining;this.reset();const epoch=this.epoch;this.opened=true;this.connection=this.lobby.connection;
   if(joining&&this.lobby.snapshot().canCancelJoin)await this.lobby.cancelJoin({connection:this.lobby.connection});
   if(this.closed||!this.opened||epoch!==this.epoch)return;this.connection=this.lobby.connection;await this.render();return;
  }
  if(m.operation==='cancel-inspect'){if(!this.owned()||!Number.isSafeInteger(m.viewId)||this.inspectViewId===null||m.viewId<this.inspectViewId||m.viewId>this.view.id)throw Error('Server details choices are stale');if(this.inspectActive){this.inspectController.abort(new Error('Server details closed'));this.inspectSerial++;this.inspectActive=false;this.busy=false;this.status='';await this.render();}else if(!this.busy)await this.render();return;}
  if(m.operation==='open'){if(this.connection!==this.lobby.connection)this.reset();if(this.busy||this.joining)throw Error('Wait for the current connection operation');this.reset();if(m.listTab!==undefined){this.tab=m.listTab;this.sourcePage=true;}this.connection=this.lobby.connection;this.opened=true;const epoch=this.epoch;try{const[state,status]=await Promise.all([this.store.load(),this.settings()]);if(!this.owned(epoch))return;this.saved=state;await this.adoptLoginProfile(status,false);this.advanced=state.browserFilters;this.hasSavedCdKey=Boolean(status.hasSavedCdKey);this.status=this.lobby.error||'';this.direct=this.lastAttempt??{...state.last,name:this.profileName??(this.playerName!==null?this.playerName.trim():state.profileDefault)};await this.renderOrDiscover();}catch(e){if(this.owned(epoch))this.emit({kind:'browser-notice',text:e.message});}return;}
  this.current(m.viewId);const epoch=this.epoch;
  if(m.operation==='profile'){
   const v=m.values;if(!v||typeof v.name!=='string'||!v.name||v.name.length>32||/[\x00-\x1f]/.test(v.name)||typeof v.saveDefault!=='boolean')throw Error('Invalid player profile');
   this.busy=true;await this.render();
   try{if(v.saveDefault){const saved=await this.store.profile(v.name);if(!this.owned(epoch))return;this.saved=saved;}if(!this.owned(epoch))return;
    this.profileName=v.name;this.direct={...this.direct,name:v.name};if(this.lastAttempt)this.lastAttempt={...this.lastAttempt,name:v.name};
    this.emit({kind:'browser-profile-result',requestViewId:m.viewId,accepted:true,name:v.name,savedDefault:v.saveDefault});this.status='';
   }catch(e){if(this.owned(epoch)){this.emit({kind:'browser-profile-result',requestViewId:m.viewId,accepted:false,text:e.message});this.status=e.message;}}
   finally{if(this.owned(epoch)){this.busy=false;await this.render();}}return;
  }
  if(m.operation==='advanced-filter'){const values=browserFilters(m.values);this.busy=true;await this.render();try{const saved=await this.store.filters(values);if(this.owned(epoch)){this.saved=saved;this.advanced=saved.browserFilters;this.page=0;this.selected=null;this.status='';}}catch(e){if(this.owned(epoch))this.status=e.message;}finally{if(this.owned(epoch)){this.busy=false;await this.render();}}return;}
  if(m.operation==='game-type'){if(this.tab!=='Internet'||m.gameType!==null&&(!Number.isInteger(m.gameType)||m.gameType<0||m.gameType>32767))throw Error('Invalid server game type');this.gameType=m.gameType;this.page=0;this.selected=null;this.details=null;this.status='';await this.render();return;}
  if(m.operation==='tab'){if(!TABS.includes(m.tab)||m.sourcePage!==undefined&&typeof m.sourcePage!=='boolean')throw Error('Invalid server browser tab');this.tab=m.tab;this.sourcePage=m.sourcePage??this.sourcePage;this.page=0;this.selected=null;this.details=null;this.status='';await this.renderOrDiscover();return;}
  if(m.operation==='sort-column'){if(!this.sourcePage||this.tab==='History'||!this.sourceSorts[this.tab]||!Number.isInteger(m.column)||m.column<0||m.column>5)throw Error('Invalid original browser sort');this.sourceSorts[this.tab]=selectBrowserColumn(this.sourceSorts[this.tab],m.column);await this.render();return;}
  if(m.operation==='filter'){if(typeof m.filter!=='string'||m.filter.length>128||!SORTS.includes(m.sort)||!m.filters||['local','server','password'].some(k=>typeof m.filters[k]!=='boolean'))throw Error('Invalid server filters');this.filter=m.filter;this.sort=m.sort;this.filters=Object.fromEntries(['local','server','password'].map(k=>[k,m.filters[k]]));this.page=0;this.selected=null;await this.render();return;}
  if(m.operation==='page'){if(!Number.isInteger(m.page)||m.page<0||m.page>=this.view.pages)throw Error('Invalid server browser page');this.page=m.page;this.selected=null;await this.render();return;}
  if(m.operation==='select'){const row=this.entry(m.entryId);this.selected=serverKey(row);this.details=row;await this.render({requestViewId:m.viewId,...serverEndpoint(row)});return;}
  if(m.operation==='selection-step'){
   if(![-1,1].includes(m.direction)||!this.sourcePage||!['Internet','History','Favorites'].includes(this.tab))throw Error('Invalid server selection direction');
   // CGuiListBox::HandleKeyEvent1e9790 consumes boundary presses without
   // wrapping. Transport pagination is not an original list boundary.
   const rows=this.catalogRows(),index=rows.findIndex(row=>serverKey(row)===this.selected),next=stepBrowserSelection(index,rows.length,m.direction);
   if(next>=0&&next<rows.length){this.selected=serverKey(rows[next]);this.details=rows[next];this.page=Math.floor(next/128);}
   await this.render(next>=0&&next<rows.length?{requestViewId:m.viewId,...serverEndpoint(rows[next])}:null);return;
  }
  if(m.operation==='favorite'){const endpoint=m.direct?serverEndpoint(m.values):null,row=endpoint?(this.details&&serverKey(this.details)===serverKey(endpoint)?this.details:endpoint):this.entry(m.entryId);this.busy=true;await this.render();try{const saved=await this.store.favorite(row,m.on??!this.saved.favorites.some(r=>serverKey(r)===serverKey(row)));if(this.owned(epoch))this.saved=saved;}finally{if(this.owned(epoch)){this.busy=false;await this.render();}}return;}
  if(m.operation==='refresh'){await this.refreshInternet();return;}
  if(m.operation==='inspect'){const row=m.direct?serverEndpoint(m.values):this.entry(m.entryId);if(!m.direct)this.selected=serverKey(row);await this.inspectRow(row,m.viewId);return;}
  if(m.operation==='details-step'){if(![-1,1].includes(m.direction))throw Error('Invalid server details direction');const rows=this.catalogRows(),index=rows.findIndex(row=>serverKey(row)===this.selected),next=index+m.direction;if(index<0||next<0||next>=rows.length)throw Error('No adjacent server');const row=rows[next];this.selected=serverKey(row);this.page=Math.floor(next/128);this.details=row;if(!this.policy.permits(row)){this.status='This server is not enabled for this session';await this.render();return;}await this.inspectRow(row,m.viewId);return;}
  if(m.operation==='join'){
   const values=m.values??{},endpoint=this.policy.require(m.direct?values:this.entry(m.entryId));
   if(typeof values.name!=='string'||!values.name.trim()||values.name.length>64||typeof values.password!=='string'||values.password.length>255||typeof values.cdKey!=='string'||values.cdKey.length>41)throw Error('Enter a player name and valid login fields');
   if(!this.lobby.snapshot().canJoin)throw Error('Disconnect the current game before joining another server');
   this.lastAttempt={...endpoint,name:values.name===this.profileName?values.name:values.name.trim()};this.direct=this.lastAttempt;this.busy=true;this.status='Connecting…';await this.render();
   try{const status=await this.settings();if(!this.owned(epoch))return;if(!values.cdKey&&!status.hasSavedCdKey)throw Error('Enter a CD key or save one in Main Menu Options');
    const credentials={password:values.password,cdKey:values.cdKey};values.password='';values.cdKey='';
    this.joining=true;try{await this.lobby.join({connection:this.connection,details:{...endpoint,name:this.direct.name,credentials}});}finally{if(epoch===this.epoch)this.joining=false;credentials.password='';credentials.cdKey='';}
    if(this.closed||!this.opened||epoch!==this.epoch)return;
    if(this.lobby.error||!this.lobby.session||this.lobby.session.closed){this.connection=this.lobby.connection;this.reopen=true;this.status=this.lobby.error||'Connection was cancelled';this.busy=false;await this.render();return;}
    const row=this.details&&serverKey(this.details)===serverKey(endpoint)?this.details:endpoint;try{await this.store.remember(row,this.direct.name);}catch{this.onEvent({operation:'history-save-failed',...endpoint});}if(this.closed||!this.opened||epoch!==this.epoch)return;this.reset();this.emit({kind:'browser-closed'});this.onEvent({operation:'join',...endpoint});
   }catch(e){if(this.opened&&!this.closed&&epoch===this.epoch){this.connection=this.lobby.connection;this.reopen=true;this.busy=false;this.status=e.message;await this.render();}}finally{values.password='';values.cdKey='';}return;
  }
  throw Error('Invalid server browser operation');
 }
 async renderOrDiscover(){
  // Cached results are immediately reusable across tabs/openings. The first
  // permitted Internet view starts discovery without a separate refresh click.
  if(this.tab==='Internet'&&this.policy.internet&&!this.internetLoaded&&this.now()>=this.refreshReadyAt)await this.refreshInternet();
  else await this.render();
 }
 async adoptLoginProfile(status,publish=true){
  if(!Object.hasOwn(status,'activeProfileId'))return;
  const previous=this.activeLoginProfileId;this.activeLoginProfileId=status.activeProfileId;
  this.loginProfile=(status.loginProfiles??[]).find(p=>p.id===status.activeProfileId)??null;
  if(this.loginProfile){this.profileName=this.loginProfile.playerName;this.direct={...this.direct,name:this.profileName};if(this.lastAttempt)this.lastAttempt={...this.lastAttempt,name:this.profileName};}
  else if(previous!=null){this.profileName=undefined;const name=this.saved?.profileDefault||this.saved?.last?.name||'';this.direct={...this.direct,name};if(this.lastAttempt)this.lastAttempt={...this.lastAttempt,name};}
  if(publish&&this.owned()&&!this.busy)await this.render();
 }
 async refreshInternet(){
  if(this.tab!=='Internet')throw Error('Select Internet to refresh the server list');
  if(!this.policy.internet)throw Error('Internet discovery is not enabled for this session');
  if(this.now()<this.refreshReadyAt)throw Error('Wait two seconds between server refreshes');
  const epoch=this.epoch,controller=this.controller;
  // Keep this deadline across resets, tab changes and connection retirement.
  this.refreshReadyAt=this.now()+REFRESH_COOLDOWN_MS;
  this.busy=true;this.status='Reading the Internet server list…';await this.render();
  if(!this.owned(epoch))return;
  try{
   const data=await this.discover({signal:controller.signal});
   if(!Array.isArray(data)||data.length>10000)throw Error('Invalid Internet server list');
   const rows=[],seen=new Set();
   for(const value of data){try{const row=browserRow(value),key=serverKey(row);if(!seen.has(key)){seen.add(key);rows.push(row);}}catch{}}
   if(this.owned(epoch)){this.internetRows=rows;this.internetLoaded=true;this.page=0;this.status=`${rows.length} servers`;}
  }catch(e){if(this.owned(epoch)){this.status=e.message;throw e;}}
  finally{if(this.owned(epoch)){this.busy=false;await this.render();}}
 }
 catalogRows(){const source=this.tab==='Internet'?this.internetRows:this.tab==='Favorites'?this.saved.favorites:this.tab==='History'?this.saved.history:[],search=this.filter.toLocaleLowerCase();
  const all=source.map(row=>this.observedRows.get(serverKey(row))??row).filter(r=>(this.tab!=='Internet'||this.gameType==null||r.gameType===this.gameType)&&matchesBrowserFilters(r,this.advanced,this.filters)&&`${r.serverName} ${r.moduleName} ${r.host}`.toLocaleLowerCase().includes(search));
  if(this.sourcePage&&this.sourceSorts[this.tab])all.sort((a,b)=>compareBrowserRows(a,b,this.sourceSorts[this.tab]));else all.sort((a,b)=>this.sort==='Players'?(b.playerCount??-1)-(a.playerCount??-1):this.sort==='Latency'?(a.latency??Infinity)-(b.latency??Infinity):String(this.sort==='Module'?a.moduleName:a.serverName).localeCompare(String(this.sort==='Module'?b.moduleName:b.serverName))||serverKey(a).localeCompare(serverKey(b)));
  return all;
 }
 async inspectRow(row,viewId){const endpoint=this.policy.require(row),epoch=this.epoch,request=++this.inspectSerial;this.inspectViewId=viewId;this.inspectActive=true;const controller=new AbortController();this.inspectController=controller;const signal=AbortSignal.any([this.controller.signal,controller.signal]);this.details=row;this.busy=true;this.status='Contacting server…';await this.render();const current=()=>this.owned(epoch)&&request===this.inspectSerial;if(!current())return;try{const info=browserRow({...row,...await this.query({...endpoint,extended:true,signal}),...endpoint});if(current()){this.details=info;this.observedRows.set(serverKey(info),info);if(this.selected===serverKey(info)){const at=this.catalogRows().findIndex(value=>serverKey(value)===this.selected);if(at>=0)this.page=Math.floor(at/128);}this.status='Server information received';this.onEvent({operation:'query',...endpoint,localAllowed:info.allowLocalVaultCharacters});}}catch(e){if(current())this.status=e.message+' · You can still try Connect.';}finally{if(current()){this.inspectActive=false;this.busy=false;await this.render();}}}
 async render(selectionAck=null){if(!this.owned())return;const all=this.catalogRows(),position=all.findIndex(row=>serverKey(row)===this.selected);
  const pages=Math.max(1,Math.ceil(all.length/128));this.page=Math.min(this.page,pages-1);const rows=all.slice(this.page*128,(this.page+1)*128),entries=new Map(rows.map((row,id)=>[id,row])),id=++this.serial;this.view={id,entries,pages};this.firstViewId??=id;
  this.emit({kind:'browser-view',reopen:this.reopen,viewId:id,selectionAck,tab:this.tab,sourcePage:this.sourcePage,sourceSort:this.sourceSorts[this.tab]??null,gameType:this.gameType??null,filter:this.filter,sort:this.sort,filters:this.filters,advancedFilters:this.advanced,page:this.page,pages,total:all.length,busy:this.busy,inspecting:this.inspectActive,refreshCooldownMs:Math.max(0,Math.ceil(this.refreshReadyAt-this.now())),detailsPosition:{index:position,total:all.length,canPrevious:position>0,canNext:position>=0&&position+1<all.length},localOnly:this.policy.localOnly,canDiscover:this.policy.internet,canJoin:this.lobby.snapshot().canJoin,hasSavedCdKey:this.hasSavedCdKey,hasSessionProfile:typeof this.profileName==='string'&&this.profileName.length>0,activeLoginProfile:this.loginProfile?{id:this.loginProfile.id,label:this.loginProfile.label,playerName:this.loginProfile.playerName}:null,activeProfileId:this.activeLoginProfileId??null,direct:this.direct,status:this.status,details:this.details?{...this.details,allowed:this.policy.permits(this.details)}:null,rows:rows.map(({description,serverVersion,...row},entryId)=>({...row,entryId,selected:this.selected===serverKey(row),favorite:this.saved.favorites.some(f=>serverKey(f)===serverKey(row)),allowed:this.policy.permits(row)}))});
 }
}
