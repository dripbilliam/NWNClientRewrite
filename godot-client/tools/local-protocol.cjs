const {EventEmitter}=require('node:events');
const MAX_FRAME=1024*1024;
class JsonLines extends EventEmitter{
 constructor(socket){super();this.socket=socket;this.buffer=Buffer.alloc(0);socket.on('data',data=>this.receive(data));socket.on('error',()=>this.emit('transportError'));}
 receive(data){
  this.buffer=Buffer.concat([this.buffer,data]);
  while(this.buffer.length){const end=this.buffer.indexOf(10);if(end<0){if(this.buffer.length>MAX_FRAME)this.reject();return;}if(end>MAX_FRAME){this.reject();return;}
   const line=this.buffer.subarray(0,end);this.buffer=this.buffer.subarray(end+1);
   try{const value=JSON.parse(line.toString('utf8'));if(!value||Array.isArray(value)||typeof value!=='object')throw Error();this.emit('message',value);}catch{this.reject();return;}
  }
 }
 reject(){this.buffer=Buffer.alloc(0);this.socket.destroy();this.emit('invalid');}
 send(value){if(!this.socket.destroyed){const frame=JSON.stringify(value)+'\n';if(Buffer.byteLength(frame)>MAX_FRAME)throw Error('Native bridge frame too large');this.socket.write(frame);}}
 sendParticles(scope,result){if(!this.socket.destroyed){const{particlePackets}=require('./particle-wire.cjs');for(const packet of particlePackets(scope,result))this.socket.write(packet);}}
}
function validateCommand(message,current){
 if(message.kind==='client-feedback-options'){
  const values=message.values;
  if(!current||message.connection!==current.connection||!values||Array.isArray(values)||typeof values!=='object'||Object.keys(values).length!==2||Object.keys(values).some(k=>!['floatingFeedback','damageTotalsOnly'].includes(k))||typeof values.floatingFeedback!=='boolean'||typeof values.damageTotalsOnly!=='boolean')throw Error('Invalid native feedback preferences');
  return;
 }
 if(message.kind==='creation-audio-observed'){
  const serial=v=>Number.isSafeInteger(v)&&v>=0;
  if(!current||message.connection!==current.connection||!serial(message.owner)||!serial(message.sequence)||!['playing','error'].includes(message.state))throw Error('Invalid native voice observation');
  if(message.state==='playing'&&(!['pcm16','mp3','ogg'].includes(message.codec)||!Number.isInteger(message.bytes)||message.bytes<1||message.bytes>64*1024*1024||!Number.isFinite(message.duration)||message.duration<=0||typeof message.sha256!=='string'||!/^[a-f0-9]{64}$/.test(message.sha256)||typeof message.driver!=='string'||message.driver.length>64)||message.state==='error'&&(typeof message.reason!=='string'||message.reason.length>1024))throw Error('Invalid native voice decoder observation');
  return;
 }
 if(message.kind==='browser-input'){
  const serial=v=>Number.isSafeInteger(v)&&v>=0,op=message.operation;
  if(!current||message.connection!==current.connection||!['open','close','return-menu','advanced-filter','sort-column','cancel-inspect','details-step','selection-step','tab','filter','page','select','favorite','refresh','inspect','join','profile'].includes(op))throw Error('Invalid native server browser operation');
  if(!['open','close'].includes(op)&&!serial(message.viewId))throw Error('Invalid native browser view');
  if(message.leaveMultiplayer!==undefined&&(op!=='close'||typeof message.leaveMultiplayer!=='boolean'))throw Error('Invalid native multiplayer dismissal');
  if(message.listTab!==undefined&&(op!=='open'||!['Internet','History','Favorites'].includes(message.listTab)))throw Error('Invalid native browser return page');
  if(message.on!==undefined&&(op!=='favorite'||typeof message.on!=='boolean')||message.sourcePage!==undefined&&(op!=='tab'||typeof message.sourcePage!=='boolean')||op==='sort-column'&&(!Number.isInteger(message.column)||message.column<0||message.column>5))throw Error('Invalid native original browser action');
  if(op==='tab'&&!['Direct','Internet','History','Favorites'].includes(message.tab)||op==='page'&&!serial(message.page))throw Error('Invalid native server browser page');
  if(op==='filter'&&(typeof message.filter!=='string'||message.filter.length>128||!['Name','Module','Players','Latency'].includes(message.sort)||!message.filters||['local','server','password'].some(k=>typeof message.filters[k]!=='boolean')))throw Error('Invalid native server browser filters');
  if((op==='select'||op==='favorite'&&!message.direct)&&!serial(message.entryId))throw Error('Invalid native server choice');
  if(['details-step','selection-step'].includes(op)&&![-1,1].includes(message.direction))throw Error('Invalid native server selection direction');
  if(op==='advanced-filter'){const v=message.values;if(!v||Array.isArray(v)||typeof v!=='object'||Object.keys(v).length!==3||Object.keys(v).some(k=>!['hideEmpty','hideFull','module'].includes(k))||typeof v.hideEmpty!=='boolean'||typeof v.hideFull!=='boolean'||typeof v.module!=='string'||v.module.length>1024||/[\x00-\x1f]/.test(v.module))throw Error('Invalid native advanced server filters');}
  if(op==='profile'){const v=message.values;if(!v||Array.isArray(v)||typeof v!=='object'||Object.keys(v).some(k=>!['name','saveDefault'].includes(k))||typeof v.name!=='string'||!v.name||v.name.length>32||/[\x00-\x1f]/.test(v.name)||typeof v.saveDefault!=='boolean')throw Error('Invalid native player profile');}
  if(['join','inspect'].includes(op)||op==='favorite'&&message.direct){
   if(typeof message.direct!=='boolean'||!message.direct&&!serial(message.entryId))throw Error('Invalid native server selection');
   const v=message.values;if((message.direct||op==='join')&&(!v||Array.isArray(v)||typeof v!=='object'))throw Error('Invalid native connection fields');
   if(v&&Object.keys(v).some(k=>!['host','port','name','password','cdKey'].includes(k)))throw Error('Invalid native connection field');
   if(message.direct&&(typeof v.host!=='string'||v.host.length>255||!Number.isInteger(v.port)||v.port<1||v.port>65535))throw Error('Invalid native server address');
   if(op==='join'&&(typeof v.name!=='string'||!v.name.trim()||v.name.length>64||typeof v.password!=='string'||v.password.length>255||typeof v.cdKey!=='string'||v.cdKey.length>41))throw Error('Invalid native login fields');
  }return;
 }
 if(message.kind==='creation-input'){
  const serial=v=>Number.isSafeInteger(v)&&v>=0;
  if(!current||message.connection!==current.connection||!['open','cancel','page','control','recommend','submit','voice','preview'].includes(message.operation))throw Error('Invalid native character creation operation');
  if(!['open','cancel'].includes(message.operation)&&!serial(message.viewId))throw Error('Invalid native creation view');
  if(message.operation==='page'&&(!Number.isInteger(message.step)||message.step<0||message.step>14)||['control','voice'].includes(message.operation)&&!serial(message.controlId))throw Error('Invalid native creation control');
  if(message.texts!==undefined&&(!Array.isArray(message.texts)||message.texts.length>10||message.texts.some(v=>!v||!serial(v.controlId)||typeof v.value!=='string'||v.value.length>32768)))throw Error('Invalid native creation text fields');
  return;
 }
 if(message.kind==='login-profile-input'){
  const serial=v=>Number.isSafeInteger(v)&&v>=0,id=v=>typeof v==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(v),name=v=>typeof v==='string'&&v.trim().length>0&&v.length<=32&&!/[\x00-\x1f\x7f]/.test(v);
  if(!current||message.connection!==current.connection||!serial(message.requestId)||!['open','close','save','select','delete'].includes(message.operation))throw Error('Invalid native login-profile operation');
  if(!['open','close'].includes(message.operation)&&!serial(message.viewId))throw Error('Invalid native login-profile view');
  if(message.operation==='save'){const v=message.values;if(!v||Array.isArray(v)||typeof v!=='object'||Object.keys(v).some(k=>!['id','label','playerName','cdKey'].includes(k))||v.id!==undefined&&!id(v.id)||!name(v.label)||!name(v.playerName)||v.cdKey!==undefined&&(typeof v.cdKey!=='string'||v.cdKey.length>41))throw Error('Invalid native login-profile values');}
  if(message.operation==='select'&&message.profileId!==null&&!id(message.profileId)||message.operation==='delete'&&!id(message.profileId))throw Error('Invalid native login-profile selection');return;
 }
 if(message.kind==='client-settings'||message.kind==='client-debug-request'){
  const serial=v=>Number.isSafeInteger(v)&&v>=0;
  if(!current||message.connection!==current.connection)throw Error('Settings belong to an old connection');
  if(message.kind==='client-debug-request')return;
  if(!serial(message.requestId)||!['open','scan','save','close'].includes(message.operation))throw Error('Invalid native settings operation');
  if(message.operation==='scan'&&(typeof message.directory!=='string'||message.directory.length>4096||message.directory.includes('\0')))throw Error('Invalid native mods folder');
  if(message.operation==='save'){
   const v=message.values;if(!serial(message.viewId)||!v||typeof v!=='object'||Array.isArray(v)||Object.keys(v).some(k=>!['disabled','cdKey','removeCdKey'].includes(k))||v.cdKey!==undefined&&(typeof v.cdKey!=='string'||v.cdKey.length>41)||v.removeCdKey!==undefined&&typeof v.removeCdKey!=='boolean'||v.disabled!==undefined&&(!Array.isArray(v.disabled)||v.disabled.length>10000||v.disabled.some(n=>!serial(n))))throw Error('Invalid native settings values');
  }return;
 }
 if(message.kind==='nui-input'){
  const serial=v=>Number.isSafeInteger(v)&&v>=0;
  if(!current||message.connection!==current.connection||!serial(message.windowId)||!['open','close','event','change','range','geometry','collapse','fragment'].includes(message.operation))throw Error('Invalid native NUI input');
  if(['event','change','range'].includes(message.operation)&&!serial(message.controlId))throw Error('Invalid native NUI control');
  if(message.value!==undefined&&typeof message.value==='string'&&message.value.length>1000000)throw Error('Native NUI text exceeds transport capacity');return;
 }
 if(!current||current.connection!==undefined&&message.connection!==current.connection||message.areaId!==current.areaId||message.generation!==current.generation)throw Error('Stale native area input');
 const vector=(value,size=3)=>Array.isArray(value)&&value.length===size&&value.every(v=>Number.isFinite(v)&&Math.abs(v)<=100000);
 const id=value=>Number.isInteger(value)&&value>=0&&value<=0xffffffff;
 const serial=value=>Number.isSafeInteger(value)&&value>=0;
 const entry=()=>{if(!serial(message.viewId)||!serial(message.entryId))throw Error('Invalid native spellbook entry');};
 const shortcut=()=>{if(!Number.isInteger(message.index)||message.index<0||message.index>=36)throw Error('Invalid native shortcut slot');};
 if(['world-audio-resource','world-audio-observed'].includes(message.kind)){
  if(!serial(message.transferId))throw Error('Invalid native audio world ticket');
  if(message.kind==='world-audio-resource'&&(!serial(message.resourceId)||message.resourceId<1||typeof message.name!=='string'||message.name.length<1||message.name.length>16||/[\\/:\0]/.test(message.name)))throw Error('Invalid private native audio resource');
  if(message.kind==='world-audio-observed'&&(!serial(message.soundId)||message.soundId<1||!Number.isSafeInteger(message.resourceId)||message.resourceId < -1||!serial(message.effectId)||!['playing','stopped','retired','parked','finished','stereo-rejected','out-of-range','failed'].includes(message.stage)||typeof message.driver!=='string'||message.driver.length>128))throw Error('Invalid native audio observation');
 }else if(message.kind==='client-dummy-probe'){
  if(!serial(message.transferId))throw Error('Invalid private dummy probe scope');
 }else if(message.kind==='client-dummy-status'){
  if(!id(message.id)||message.id>=0x7effffff||!serial(message.token)||message.token<1||!serial(message.transferId)||!['ready','expired','failed'].includes(message.stage))throw Error('Invalid native private client dummy status');
 }else if(['visual-status','visual-diagnostic','visual-model-created','visual-model-release'].includes(message.kind)){
  if(!serial(message.effectId)||message.kind!=='visual-diagnostic'&&message.effectId<1)throw Error('Invalid native visual owner');
  if(message.kind==='visual-status'&&!['started','phase','retired','canceled','failed'].includes(message.stage))throw Error('Invalid native visual status');
  if(message.kind==='visual-diagnostic'&&(typeof message.code!=='string'||message.code.length>128||typeof message.detail!=='string'||message.detail.length>1024))throw Error('Invalid native visual diagnostic');
  if(message.kind.startsWith('visual-model-')&&(!serial(message.modelId)||message.modelId<1||message.kind==='visual-model-created'&&(typeof message.resource!=='string'||!/^[a-z0-9_]{1,16}$/i.test(message.resource))))throw Error('Invalid native visual model');
 }else if(['weather-create','weather-release'].includes(message.kind)){
  if(!serial(message.transferId)||!serial(message.batchId)||message.batchId<1)throw Error('Invalid native weather batch');
  if(message.kind==='weather-create'&&(!serial(message.resourceId)||message.resourceId<1||!Number.isInteger(message.type)||message.type<1||message.type>255||!Array.isArray(message.ids)||message.ids.length!==6||new Set(message.ids).size!==6||message.ids.some(v=>!serial(v)||v<1||v>1e9)))throw Error('Invalid native weather model owners');
 }else if(message.kind==='particles-start'){
  const p=message.layout;if(!serial(message.epoch)||!p||p.vertexStride!==12||p.attributeStride!==12||p.colorOffset!==0||p.uvOffset!==4)throw Error('Invalid native particle layout');
 }else if(message.kind==='particle-frame'){
  const matrix=value=>Array.isArray(value)&&value.length===16&&value.every(Number.isFinite);
  if(!serial(message.epoch)||!serial(message.sequence)||!Number.isFinite(message.delta)||message.delta<0||message.delta>10||!matrix(message.camera)||!Array.isArray(message.poses)||message.poses.length>4096||message.poses.some(row=>!serial(row.id)||!matrix(row.matrix)||!matrix(row.rootMatrix)||row.referenceMatrix!==undefined&&row.referenceMatrix!==null&&!matrix(row.referenceMatrix)))throw Error('Invalid native particle frame');
 }else if(['party-menu','party-target','party-rest'].includes(message.kind)){
  if(!serial(message.viewId)||message.kind!=='party-rest'&&!serial(message.entryId)||message.kind==='party-menu'&&!serial(message.requestId)||message.kind==='party-target'&&!serial(message.token))throw Error('Invalid native party selection');
 }else if(message.kind==='players-attitude'){
  if(!serial(message.viewId)||!serial(message.entryId)||typeof message.likes!=='boolean')throw Error('Invalid native player attitude');
 }else if(['map-open','map-close','journal-open','journal-close','players-open','players-close'].includes(message.kind)){
 }else if(message.kind==='journal-page'){
  if(!serial(message.viewId)||!Number.isInteger(message.page)||message.page<0||message.page>3)throw Error('Invalid native journal category');
 }else if(['inventory-open','inventory-close'].includes(message.kind)){
 }else if(message.kind==='sheet-close'){
 }else if(['level-open','level-cancel'].includes(message.kind)){
 }else if(['level-page','level-control','level-submit'].includes(message.kind)){
  if(!serial(message.viewId))throw Error('Invalid native level-up view');
  if(message.kind==='level-page'&&(!Number.isInteger(message.step)||message.step<0||message.step>6))throw Error('Invalid native level-up page');
  if(message.kind==='level-control'&&!serial(message.controlId))throw Error('Invalid native level-up control');
  if(message.texts!==undefined&&(!Array.isArray(message.texts)||message.texts.length>4||message.texts.some(v=>!serial(v.controlId)||typeof v.value!=='string'||v.value.length>128)))throw Error('Invalid native level-up text fields');
 }else if(['sheet-open','sheet-page','sheet-assign'].includes(message.kind)){
  if(message.kind!=='sheet-open'&&!serial(message.viewId))throw Error('Invalid native character record view');
  if(message.kind==='sheet-assign'){entry();shortcut();}
  else if(!Number.isInteger(message.page)||message.page<0||message.page>2)throw Error('Invalid native character record page');
 }else if(message.kind==='inventory-store'){
  if(!serial(message.viewId)||!['close','panel','page','buy','sell','identify'].includes(message.operation))throw Error('Invalid native store request');
  if(['buy','sell','identify'].includes(message.operation)&&!serial(message.entryId))throw Error('Invalid native store item');
  if(message.operation==='panel'&&(!Number.isInteger(message.panel)||message.panel<0||message.panel>=5))throw Error('Invalid native store category');
  if(message.operation==='page'&&(!Number.isInteger(message.page)||message.page<0||message.page>255))throw Error('Invalid native store page');
 }else if(message.kind==='inventory-container'){
  if(!serial(message.viewId)||!['close','next','previous'].includes(message.operation))throw Error('Invalid native container selection');
 }else if(message.kind==='radial-shortcut'){
  shortcut();if(!serial(message.quickbarId)||!serial(message.menuId)||message.menuId<1||!serial(message.requestId)||!Number.isInteger(message.slot)||message.slot<0||message.slot>7)throw Error('Invalid native radial shortcut owner');
 }else if(message.kind==='inventory-shortcut'){
  entry();shortcut();if(!serial(message.quickbarId))throw Error('Invalid native item shortcut owner');
 }else if(['inventory-page','inventory-action','inventory-activate','inventory-menu'].includes(message.kind)){
  if(!serial(message.viewId)||message.kind!=='inventory-page'&&!serial(message.entryId))throw Error('Invalid native inventory selection');
  if(message.kind==='inventory-page'&&(!Number.isInteger(message.page)||message.page<0||message.page>5))throw Error('Invalid native inventory page');
  if(message.kind==='inventory-menu'&&!serial(message.requestId))throw Error('Invalid native inventory menu');
  if(message.kind==='inventory-action'&&!['toggle','equip','unequip','move','drop','examine'].includes(message.operation))throw Error('Invalid native inventory operation');
 }else if(['spellbook-open','spellbook-close'].includes(message.kind)){
 }else if(message.kind==='spellbook-query'){
  if(!Number.isInteger(message.classIndex)||message.classIndex<0||message.classIndex>=8||!Number.isInteger(message.level)||message.level<0||message.level>9||![0,1,2,4,8,16,32].includes(message.metamagic))throw Error('Invalid native spellbook query');
 }else if(['book-family','book-inspect','book-activate','book-prepare','book-clear','quickbar-assign'].includes(message.kind)){
  entry();if(message.kind==='book-prepare'&&message.destinationId!==undefined&&!serial(message.destinationId))throw Error('Invalid native preparation destination');if(message.kind==='quickbar-assign')shortcut();
 }else if(message.kind==='book-family-back'){
  if(!serial(message.viewId))throw Error('Invalid native spell-family page');
 }else if(message.kind==='quickbar-menu'){
  shortcut();if(!serial(message.quickbarId)||!serial(message.requestId))throw Error('Invalid native shortcut menu owner');
 }else if(['quickbar-clear','quickbar-move','quickbar-activate'].includes(message.kind)){
  shortcut();if(!serial(message.quickbarId)||message.kind==='quickbar-move'&&(!Number.isInteger(message.sourceIndex)||message.sourceIndex<0||message.sourceIndex>=36))throw Error('Invalid native shortcut owner');
 }else if(message.kind==='radial-open'){
  if(!serial(message.requestId)||message.targetId!==null&&!id(message.targetId)||!vector(message.position))throw Error('Invalid native context menu request');
 }else if(['radial-select','radial-back','radial-cancel'].includes(message.kind)){
  if(!serial(message.requestId)||message.kind!=='radial-cancel'&&(!serial(message.menuId)||message.menuId<1)||message.kind==='radial-select'&&(!Number.isInteger(message.slot)||message.slot<0||message.slot>7))throw Error('Invalid native context menu selection');
 }else if(['target-hover','target-select','target-cancel'].includes(message.kind)){
  if(!serial(message.token)||message.kind!=='target-cancel'&&message.targetId!==null&&!id(message.targetId)||message.kind==='target-select'&&!vector(message.position))throw Error('Invalid native target selection');
 }else if(message.kind==='cursor-request'){
  if(!Number.isInteger(message.cursorId)||message.cursorId<1||message.cursorId>292)throw Error('Invalid native cursor ID');
 }else if(message.kind==='drive'||message.kind==='drive-preview-request'){
  if(!id(message.actorId)||!Number.isSafeInteger(message.requestId)||message.requestId<0||!Number.isInteger(message.lifetime)||message.lifetime<1||!['drive','stop','turn'].includes(message.operation))throw Error('Invalid native drive owner');
  if(message.operation==='drive'&&(!vector(message.position)||!vector(message.render)||!vector(message.orientation)||!Number.isInteger(message.heading)||message.heading<0||message.heading>=3600||!Number.isInteger(message.flags)||message.flags<1||message.flags>63||typeof message.transmit!=='boolean'||!Array.isArray(message.poses)||message.poses.length>128||message.poses.some(row=>!id(row.id)||!vector(row.position))))throw Error('Invalid native drive request');
  if(message.operation==='turn'&&!vector(message.position,2))throw Error('Invalid native turn request');
  if(message.kind==='drive-preview-request'&&(message.operation!=='drive'||message.transmit!==false))throw Error('Collision retry cannot transmit drive input');
 }else if(message.kind==='path'){
  const s=message.state;
  if(!id(message.actorId)||!Number.isSafeInteger(message.requestId)||!Number.isSafeInteger(message.revision)||!s||!vector(s.render)||!Array.isArray(s.path)||s.path.length>4096||s.path.some(point=>!vector(point))||!Number.isInteger(s.cursor)||s.cursor<0||s.cursor>s.path.length||![0,1].includes(s.script)||!Number.isInteger(s.lastSequence)||s.lastSequence<0||s.lastSequence>255)throw Error('Invalid native path admission request');
 }else if(message.kind==='walk'){
  if(!Array.isArray(message.position)||message.position.length!==3||message.position.some(v=>!Number.isFinite(v)||Math.abs(v)>100000))throw Error('Invalid native destination');
 }else if(message.kind==='interact'||message.kind==='examine'){
  if(!Number.isInteger(message.targetId)||message.targetId<0||message.targetId>0xffffffff)throw Error('Invalid native target');
 }else if(message.kind==='chat'){
  if(typeof message.text!=='string'||!message.text.trim()||message.text.length>1000)throw Error('Invalid native chat');
  const channel=message.channel??1;
  if(![1,2,3,4,6,14].includes(channel)||channel===4&&(typeof message.recipient!=='string'||!message.recipient.trim()||message.recipient.length>128)||channel!==4&&message.recipient!==undefined)throw Error('Invalid native chat channel or recipient');
 }else if(message.kind==='reply'){
  if(!Number.isInteger(message.entryId)||!Number.isInteger(message.replyId)||message.entryId<0||message.entryId>0xffffffff||message.replyId<0||message.replyId>0xffffffff||typeof message.abort!=='boolean')throw Error('Invalid native conversation reply');
 }else throw Error('Unsupported native command');
 return message;
}
module.exports={JsonLines,validateCommand,MAX_FRAME};
