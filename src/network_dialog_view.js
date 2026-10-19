import {runtimeDiagnostics} from './runtime_diagnostics.js';

// Server-authored dialog presentation. No DLG graph, conditions or scripts.
export class NetworkDialogView{
 constructor(viewport,{resolve,reply,onVisibility}){
  Object.assign(this,{resolve,reply,onVisibility});this.generation=0;
  this.host=document.createElement('section');this.host.className='network-dialog';this.host.hidden=true;this.host.setAttribute('aria-label','Conversation');this.host.innerHTML='<p class="game-dialogue-text"></p><div class="game-dialogue-replies"></div><p class="game-dialogue-error" role="status"></p><button type="button" class="tool-button">End conversation</button>';viewport.append(this.host);
  this.text=this.host.querySelector('.game-dialogue-text');this.replies=this.host.querySelector('.game-dialogue-replies');this.error=this.host.querySelector('.game-dialogue-error');this.host.lastChild.addEventListener('click',()=>this.choose(0xffffffff,true));
  window.addEventListener('keydown',event=>{if(!this.active)return;if(event.key==='Escape'){event.preventDefault();event.stopPropagation();void this.choose(0xffffffff,true);}else if(/^[1-9]$/.test(event.key)){event.preventDefault();this.replies.children[Number(event.key)-1]?.click();}},true);
 }
 get active(){return!this.host.hidden;}
 close(){this.generation++;this.host.hidden=true;this.entry=null;this.choices=null;this.pending=false;this.replies.replaceChildren();this.host.dataset.state='null';this.onVisibility(false);}
 snapshot(){return this.entry?{ownerId:this.entry.ownerId,entryId:this.choices?.entryId??null,text:this.text.textContent,replies:[...this.replies.children].map(b=>({id:Number(b.dataset.replyId),text:b.textContent})),pending:this.pending}:null;}
 publish(){this.host.dataset.state=JSON.stringify(this.snapshot());}
 async receive(message){
  if(message.kind==='dialog-close'){this.close();return;}
  if(message.kind==='dialog-entry'){
   const generation=++this.generation;this.entry=message;this.choices=null;this.pending=false;this.error.textContent='';this.replies.replaceChildren();this.host.hidden=false;this.text.textContent='…';this.onVisibility(true);
   const value=await this.resolve(message.text,message.tokenObjectId);if(generation!==this.generation)return;this.text.textContent=value;this.publish();
  }else if(message.kind==='dialog-replies'&&this.entry){
   const generation=this.generation;this.choices=message;this.pending=false;this.replies.replaceChildren();
   const values=message.replies.length?message.replies:[{id:0xffffffff,text:{text:''}}];
   for(const [index,choice]of values.entries()){
    let label=await this.resolve(choice.text,message.tokenObjectId);if(!label)label=await this.resolve({strRef:message.end||!message.replies.length?0x6ce:0x6cd,gender:0});if(generation!==this.generation)return;
    const button=document.createElement('button');button.className='tool-button game-dialogue-reply';button.type='button';button.dataset.replyId=String(choice.id);button.textContent=`${index+1}. ${label}`;button.addEventListener('click',()=>this.choose(choice.id));this.replies.append(button);
   }this.publish();
  }else if(message.kind==='dialog-selected')runtimeDiagnostics.record('network.dialog-selected-unhandled','Selected multiplayer reply transcript presentation is not connected');
 }
 async choose(replyId,abort=false){
  if(!this.choices||this.pending)return;const generation=this.generation;this.pending=true;for(const button of this.replies.children)button.disabled=true;this.publish();
  try{await this.reply({entryId:this.choices.entryId,replyId,abort});}
  catch(error){if(generation!==this.generation)return;this.pending=false;this.error.textContent=error.message;for(const button of this.replies.children)button.disabled=false;this.publish();runtimeDiagnostics.error(error,'network.dialog-reply-failed');}
 }
}
