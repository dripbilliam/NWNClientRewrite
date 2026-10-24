import {networkPortrait} from './network_portrait.js';
import {runtimeDiagnostics} from './runtime_diagnostics.js';
import {networkSpeechHasRemoteName,networkSpeechIsSystem} from './network_speech.js';
import {nativeRichText,setNativeRichText} from './native_rich_text.js';
const el=(tag,text)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;return n;};
const prefixRef=channel=>({2:10300,9:10300,18:10300,3:10301,10:10301,19:10301,4:10302,20:10302,5:10299,15:10299,6:10303,22:10303,14:66756,30:66756})[channel];

// Only authoritative received messages enter history. The entry sends native
// requests; it does not echo drafts, run chat scripts or manufacture speakers.
export class NetworkSpeechView{
 constructor(viewport,{world,resolve,send=null,canSend=()=>true,canFocus=canSend,assets=()=>null,tables=()=>null,onNotice=()=>{}}){
  Object.assign(this,{world,resolve,send,canSend,canFocus,assets,tables,onNotice});this.generation=0;this.rows=[];this.pending=false;
  this.host=el('section');this.host.className='network-speech';this.host.hidden=true;this.host.setAttribute('aria-label','Server messages');
  this.panes=new Map();const panes=el('div');panes.className='network-speech-panes';
  for(const [id,label]of [['messages','Messages'],['system','System']]){
   const pane=el('section');pane.className='network-speech-pane';pane.setAttribute('aria-label',label);
   const handle=el('div');handle.className='network-speech-resize';handle.setAttribute('role','separator');handle.setAttribute('aria-label','Resize '+label);handle.setAttribute('aria-orientation','horizontal');handle.tabIndex=0;
   const list=el('div');list.className='network-speech-lines';list.setAttribute('role','log');list.setAttribute('aria-label',label);list.tabIndex=0;pane.append(handle,list);panes.append(pane);this.panes.set(id,{pane,handle,list});
   const resize=height=>{const next=Math.round(Math.max(48,Math.min(viewport.clientHeight*.65,height)));list.style.height=next+'px';handle.setAttribute('aria-valuenow',String(next));};
   handle.addEventListener('pointerdown',event=>{if(event.button!==0)return;event.preventDefault();handle.setPointerCapture(event.pointerId);handle.drag={y:event.clientY,height:list.clientHeight};});
   handle.addEventListener('pointermove',event=>{if(handle.drag)resize(handle.drag.height+handle.drag.y-event.clientY);});
   for(const type of ['pointerup','pointercancel','lostpointercapture'])handle.addEventListener(type,()=>{handle.drag=null;});
   handle.addEventListener('keydown',event=>{if(!['ArrowUp','ArrowDown'].includes(event.key))return;event.preventDefault();resize(list.clientHeight+(event.key==='ArrowUp'?16:-16));});
  }
  this.list=this.panes.get('messages').list;this.systemList=this.panes.get('system').list;this.host.append(panes);
  this.form=el('form');this.form.className='network-chat-entry';this.form.hidden=!send;
  this.channel=el('select');this.channel.setAttribute('aria-label','Chat channel');for(const [id,label]of [[1,'Talk'],[2,'Shout'],[3,'Whisper'],[6,'Party'],[14,'DM'],[4,'Tell']]){const option=el('option',label);option.value=String(id);this.channel.append(option);}
  this.recipient=el('input');this.recipient.type='text';this.recipient.placeholder='Recipient first name';this.recipient.setAttribute('aria-label','Tell recipient');this.recipient.hidden=true;
  this.input=el('input');this.input.type='text';this.input.setAttribute('aria-label','Chat message');this.input.autocomplete='off';this.input.placeholder='Talk';
  this.submitButton=el('button','Send');this.submitButton.type='submit';this.submitButton.className='tool-button';this.status=el('output');this.status.setAttribute('aria-live','polite');
  this.form.append(this.channel,this.recipient,this.input,this.submitButton,this.status);this.host.append(this.form);viewport.append(this.host);
  this.channel.addEventListener('change',()=>{this.recipient.hidden=this.channel.value!=='4';this.input.placeholder=this.channel.selectedOptions[0]?.textContent??'Chat';});
  this.form.addEventListener('submit',event=>{event.preventDefault();void this.submit();});
  this.input.addEventListener('keydown',event=>{if(event.key==='Escape'){event.preventDefault();this.input.blur();}});
  for(const type of ['pointerdown','pointerup','click','dblclick','contextmenu','wheel','keydown','keyup'])this.host.addEventListener(type,e=>e.stopPropagation());
  this.focusEntry=event=>{if(event.key!=='Enter'||event.defaultPrevented||event.altKey||event.ctrlKey||event.metaKey||!this.send||!this.canFocus()||!this.world()||event.target?.closest?.('input,textarea,select,button,[contenteditable="true"]'))return;event.preventDefault();this.host.hidden=false;this.input.focus();};
  window.addEventListener('keydown',this.focusEntry);this.sync();void this.skin();
 }
 async skin(){const assets=this.assets();if(!assets||this.skinOwner===assets)return;this.skinOwner=assets;try{const skin=await assets.skin('but_chat_bar360');if(assets!==this.assets()||!skin?.url)return;for(const {handle}of this.panes.values()){handle.style.backgroundImage=`url("${skin.url}")`;handle.dataset.nativeModel='but_chat_bar360';}}catch(error){runtimeDiagnostics.error(error,'network.chat-skin-unavailable');}}
 sync(){void this.skin();const disabled=!this.send||!this.world()||!this.canSend()||this.pending;for(const node of [this.input,this.recipient,this.channel,this.submitButton])node.disabled=disabled;if(this.send&&this.world())this.host.hidden=false;}
 reset(){this.generation++;this.rows=[];this.pending=false;this.input.value='';this.recipient.value='';this.channel.value='1';this.recipient.hidden=true;this.input.placeholder='Talk';this.status.textContent='';this.host.hidden=true;this.render();this.sync();}
 async submit(){
  if(!this.send||this.pending||!this.canSend()||!this.world()||!this.input.value.length)return;
  const generation=this.generation,world=this.world(),text=this.input.value,channel=Number(this.channel.value),request={channel,text};if(channel===4)request.recipient=this.recipient.value;
  this.pending=true;this.status.textContent='';this.sync();
  try{await this.send(request);if(generation===this.generation&&world===this.world())this.input.value='';}
  catch(error){if(generation===this.generation&&world===this.world()){this.status.textContent=error.message;runtimeDiagnostics.error(error,'network.chat-request-failed');}}
  finally{if(generation===this.generation&&world===this.world()){this.pending=false;this.sync();this.input.focus();}}
 }
 async notice(message){
  const generation=this.generation,world=this.world();if(!world)return;
  const prefix=await this.resolve({strRef:message.strRef},0x7f000000,{playerId:message.playerId,playerName:message.playerName,nativeB8:0});
  const text=message.category==='journal'?prefix+' '+await this.resolve(message.title,0x7f000000):prefix+(message.suffix??'');
  if(generation!==this.generation||world!==this.world())return;
  this.append({system:true,category:message.category,text,color:message.color,playerId:message.playerId});this.onNotice(message);
 }
 append(row){if(!row.richText){row.richText=nativeRichText((row.prefix??'')+row.text).spans;row.raw??=row.text;row.text=nativeRichText(row.text).text;}this.rows.push(row);const system=r=>r.system||networkSpeechIsSystem(r.channel),target=Boolean(system(row));if(this.rows.filter(r=>Boolean(system(r))===target).length>200)this.rows.splice(this.rows.findIndex(r=>Boolean(system(r))===target),1);this.host.hidden=false;this.render();}
 async receive(message){
  if(message.channel===7||message.kind==='script-sound')return;
  const generation=this.generation,world=this.world();if(!world)return;
  const current=()=>generation===this.generation&&world===this.world()&&(!message.current||message.current()),context=message.contextId??world.localObjectId,text=await this.resolve(message.text,context,{nativeB8:0});if(!current())return;
  if(message.sound||message.soundFlag)runtimeDiagnostics.record('network.speech-audio-unhandled','Native server speech audio is not connected',{objectId:message.objectId,soundObjectId:message.soundObjectId,sound:message.sound,flag:message.soundFlag});if(!text)return;
  const object=world.registry.get(message.objectId);if(!object&&!networkSpeechIsSystem(message.channel)&&![11,12].includes(message.channel)&&!networkSpeechHasRemoteName(message.channel))return;
  let name='',value=message.speakerName??object?.replicated?.name??object?.appearance?.name??object?.item?.name??object?.staticState?.name;
  if(!networkSpeechIsSystem(message.channel)){
   if(value?.firstName)name=(await Promise.all([this.resolve(value.firstName,message.objectId),this.resolve(value.lastName,message.objectId)])).filter(Boolean).join(' ');else if(value)name=await this.resolve(value,message.objectId);
   if(!name)name=await this.resolve({strRef:5189},message.objectId);
  }
  const ref=prefixRef(message.channel),label=ref===undefined?'':await this.resolve({strRef:ref},context),prefix=[14,30].includes(message.channel)&&label?'['+label+'] ':label;if(!current())return;
  const player=[...world.players.values()].find(p=>p.objectId===message.objectId||p.character?.id===message.objectId),portrait=object?.replicated??player?.character;
  const row={channel:message.channel,objectId:message.objectId,contextId:message.contextId,position:message.position,name,prefix,text};this.append(row);
  // Portrait IO is presentation-only and must never hold up received packets.
  const assets=this.assets();if(name&&portrait)void networkPortrait(assets,this.tables(),{id:message.objectId,portrait:portrait.portrait,portraitRef:portrait.portraitRef},1).then(image=>{if(!current()||assets!==this.assets()||!this.rows.includes(row)||!image)return;row.image=image;this.render();}).catch(error=>runtimeDiagnostics.error(error,'network.chat-portrait-failed'));
 }
 render(){
  for(const [id,{list}]of this.panes){
   const bottom=list.scrollHeight-list.scrollTop-list.clientHeight<4,top=list.scrollTop;list.replaceChildren();
   for(const row of this.rows){if(Boolean(row.system||networkSpeechIsSystem(row.channel))!==(id==='system'))continue;
    const line=el('p');if(row.channel!==undefined)line.dataset.channel=String(row.channel);if(row.category)line.dataset.category=row.category;if(row.color)line.style.color=row.color;
    if(row.name){if(row.image){const portrait=el('img');portrait.className='network-chat-portrait';portrait.src=row.image;portrait.alt='';line.append(portrait);}const name=el('span');setNativeRichText(name,row.name+': ');name.className='network-chat-speaker';line.append(name);}
    if(row.richText)for(const part of row.richText){const span=el('span',part.text);if(part.color)span.style.color=part.color;line.append(span);}else line.append(el('span',(row.prefix??'')+row.text));list.append(line);
   }
   list.scrollTop=bottom?list.scrollHeight:top;
  }
  this.host.dataset.state=JSON.stringify({layout:'split',rows:this.rows.map(({image,...row})=>({...row,portraitLoaded:Boolean(image)}))});
 }
}
