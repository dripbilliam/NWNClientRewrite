import {runtimeDiagnostics} from './runtime_diagnostics.js';
const roots={performance:['#performance-debug','.bottom-strip','.topbar-meta'],gameplay:['.game-debug-controls'],diagnostics:['.runtime-diagnostics'],inspector:['.inspector'],resources:['.viewer-toolbar']};
const excluded=new Set(['SCRIPT','STYLE','LINK','CANVAS','IMG','IFRAME','OBJECT']);
let controller;
export function debugWindowOption(){const row=document.createElement('label'),box=document.createElement('input');box.type='checkbox';box.dataset.debugWindowToggle='true';box.setAttribute('aria-label','Show debug window');box.checked=controller?.open??false;box.disabled=!controller?.bridge;box.addEventListener('change',()=>{void controller.setOpen(box.checked).catch(error=>runtimeDiagnostics.error(error,'debug.window-failed'));});row.append(box,document.createTextNode(' Show debug window'));return row;}
export class DebugShell{
 constructor({bridge=window.debugTools}={}){controller=this;this.bridge=bridge;this.open=false;this.tab='performance';this.ids=new WeakMap();this.next=0;this.controls=new Map();this.timer=null;if(!bridge)return;
  let reopen=false;try{reopen=localStorage.getItem('nwn.debug.window')==='true';}catch{}
  bridge.subscribe(event=>{if(event.kind==='state')this.state(event);else if(event.kind==='command')this.command(event.command);});
  void (reopen?this.setOpen(true):bridge.status().then(state=>this.state(state))).catch(error=>runtimeDiagnostics.error(error,'debug.window-failed'));
 }
 state(state){this.open=state.open;this.tab=state.tab;try{localStorage.setItem('nwn.debug.window',String(this.open));}catch{}for(const box of document.querySelectorAll('[data-debug-window-toggle]'))box.checked=this.open;clearInterval(this.timer);this.timer=null;if(state.open&&state.visible){this.publish();this.timer=setInterval(()=>this.publish(),500);}}
 async setOpen(open){if(this.bridge)this.state(await this.bridge.setOpen(open));}
 gameOnly(active){document.body.classList.toggle('game-only',Boolean(active));}
 key(n){let key=this.ids.get(n);if(!key){key=String(++this.next);this.ids.set(n,key);}return key;}
 sourceRoots(){return(roots[this.tab]??[]).flatMap(selector=>[...document.querySelectorAll(selector)]);}
 publish(){
  const controls=new Map();let budget=2500;const project=n=>{
   if(--budget<0)return null;if(n.nodeType===3)return{tag:'#text',key:this.key(n),text:n.nodeValue.slice(0,48000)};
   if(n.nodeType!==1||excluded.has(n.tagName)||n.hidden||this.tab==='inspector'&&n.matches('#performance-debug,.game-debug-controls,.runtime-diagnostics')||n.matches('input[type=password],input[type=file],input[type=hidden]'))return null;
   const item={key:this.key(n),tag:n.localName,className:n.className,children:[...n.childNodes].map(project).filter(Boolean)};
   for(const a of ['title','aria-label','aria-pressed','data-performance','min','max','step'])if(n.hasAttribute(a))item[a]=n.getAttribute(a);
   if(['BUTTON','INPUT','SELECT','OPTION','OUTPUT'].includes(n.tagName)){Object.assign(item,{value:n.value,checked:n.checked,disabled:n.disabled,readOnly:n.readOnly,type:n.type});if(['BUTTON','INPUT','SELECT'].includes(n.tagName))controls.set(item.key,n);}return item;
  };
  const snapshot={tab:this.tab,roots:this.sourceRoots().map(project).filter(Boolean)};this.controls=controls;this.bridge.publish(snapshot);
 }
 command(command){const n=this.controls.get(command?.key);if(!n?.isConnected||n.disabled||!this.sourceRoots().some(root=>root===n||root.contains(n)))return;
  if(command.type==='click'){if(n.tagName==='BUTTON')n.click();}
  else if(['input','change'].includes(command.type)&&['INPUT','SELECT'].includes(n.tagName)&&!n.readOnly){if(['checkbox','radio'].includes(n.type))n.checked=Boolean(command.checked);else n.value=command.value;n.dispatchEvent(new Event(command.type,{bubbles:true}));}this.publish();
 }
}
