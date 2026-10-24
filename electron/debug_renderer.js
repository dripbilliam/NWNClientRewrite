const bridge=window.debugInspector,content=document.querySelector('#debug-content'),status=document.querySelector('#debug-status'),nav=document.querySelector('#debug-tabs');
const tabs=[['performance','Performance'],['gameplay','Gameplay'],['diagnostics','Diagnostics'],['inspector','Inspector'],['resources','Resources']],nodes=new Map(),scrolls=new Map();let selected='performance';
function select(tab){scrolls.set(selected,content.scrollTop);selected=tab;nodes.clear();content.replaceChildren();content.scrollTop=scrolls.get(tab)??0;for(const b of nav.children){const active=b.dataset.tab===tab;b.setAttribute('aria-selected',String(active));b.tabIndex=active?0:-1;}content.setAttribute('aria-labelledby','debug-tab-'+tab);status.textContent='Updating…';}
for(const [id,label]of tabs){const b=document.createElement('button');b.id='debug-tab-'+id;b.dataset.tab=id;b.type='button';b.setAttribute('role','tab');b.textContent=label;b.addEventListener('click',()=>{select(id);void bridge.selectTab(id).catch(error=>status.textContent=error.message);});b.addEventListener('keydown',event=>{if(!['ArrowLeft','ArrowRight','Home','End'].includes(event.key))return;event.preventDefault();const index=tabs.findIndex(t=>t[0]===id),next=event.key==='Home'?0:event.key==='End'?tabs.length-1:(index+(event.key==='ArrowRight'?1:-1)+tabs.length)%tabs.length;nav.children[next].click();nav.children[next].focus();});nav.append(b);}
const tags=new Set('section div span p pre label button input select option output h1 h2 h3 h4 dl dt dd details summary ul ol li strong b em small br a'.split(' '));
function render(parent,items,live){
 let cursor=parent.firstChild;for(const item of items){if(!item||typeof item.key!=='string')continue;let n=nodes.get(item.key);const text=item.tag==='#text',tag=tags.has(item.tag)?item.tag:'span';if(!n||(text?n.nodeType!==3:n.localName!==tag)){n=text?document.createTextNode(''):document.createElement(tag);nodes.set(item.key,n);if(tag==='details')n.open=true;}
  live.add(item.key);if(n!==cursor)parent.insertBefore(n,cursor);cursor=n.nextSibling;
  if(text){if(n.nodeValue!==item.text)n.nodeValue=String(item.text??'');continue;}
  n.className=typeof item.className==='string'?item.className:'';
  for(const a of ['title','aria-label','aria-pressed','data-performance','min','max','step']){if(item[a]!==undefined)n.setAttribute(a,String(item[a]));else n.removeAttribute(a);}
  if(tag==='input')n.type=['checkbox','radio','range','number','color','text'].includes(item.type)?item.type:'text';
  if(['button','input','select','option'].includes(tag)){n.disabled=Boolean(item.disabled);n.dataset.debugKey=item.key;}
  if(tag==='button')n.type='button';if(tag==='input'){n.checked=Boolean(item.checked);n.readOnly=Boolean(item.readOnly);}
  render(n,item.children??[],live);
  if(['input','select','option','output'].includes(tag)&&document.activeElement!==n&&n.value!==item.value)n.value=item.value??'';
 }
 while(cursor){const next=cursor.nextSibling;cursor.remove();cursor=next;}
}
bridge.subscribe(snapshot=>{if(snapshot.tab!==selected)return;const live=new Set();render(content,snapshot.roots,live);for(const key of nodes.keys())if(!live.has(key))nodes.delete(key);status.textContent='Live · '+new Date().toLocaleTimeString();});
for(const type of ['click','input','change'])content.addEventListener(type,event=>{const n=event.target.closest('[data-debug-key]');if(!n||n.disabled||type==='click'&&n.localName!=='button'||type!=='click'&&!['input','select'].includes(n.localName))return;bridge.command({type,key:n.dataset.debugKey,value:n.value??'',checked:Boolean(n.checked)});});
select('performance');void bridge.ready().then(state=>{if(state.tab!==selected){select(state.tab);return bridge.selectTab(state.tab);}}).catch(error=>status.textContent=error.message);
