const path=require('node:path');
const {pathToFileURL}=require('node:url');
const tabs=new Set(['performance','gameplay','diagnostics','inspector','resources']);
// The inspector has its own restricted preload, never the network bridge.
function registerDebugWindows({ipcMain,BrowserWindow,root,applicationUrl=pathToFileURL(path.join(root,'dist/index.html')).href}){
 const owners=new Map(),mainUrl=applicationUrl,debugUrl=pathToFileURL(path.join(root,'electron/debug.html')).href;
 const trusted=(event,child=false)=>{
  if(event.senderFrame!==event.sender.mainFrame)throw Error('Untrusted debug frame');
  const owner=child?[...owners.values()].find(o=>o.child?.webContents===event.sender):owners.get(event.sender.id);
  if(!owner||event.sender.getURL()!==(child?debugUrl:mainUrl))throw Error('Untrusted debug window');return owner;
 };
 const state=owner=>({open:Boolean(owner.child&&!owner.child.isDestroyed()),visible:Boolean(owner.child&&!owner.child.isDestroyed()&&owner.child.isVisible()&&!owner.child.isMinimized()),tab:owner.tab});
 const sendState=owner=>{const value=state(owner);if(!owner.window.isDestroyed())owner.window.webContents.send('client-debug:event',{kind:'state',...value});return value;};
 ipcMain.handle('client-debug:status',event=>sendState(trusted(event)));
 ipcMain.handle('client-debug:open',(event,open)=>{
  const owner=trusted(event);if(typeof open!=='boolean')throw Error('Invalid debug window setting');
  if(!open){owner.child?.close();return sendState(owner);}
  if(owner.child&&!owner.child.isDestroyed()){owner.child.show();owner.child.focus();return sendState(owner);}
  const child=owner.child=new BrowserWindow({title:'NWN Debug',width:720,height:820,minWidth:440,minHeight:360,show:false,parent:owner.window,backgroundColor:'#111916',webPreferences:{preload:path.join(root,'electron/debug_preload.cjs'),contextIsolation:true,nodeIntegration:false,sandbox:true}});
  child.setMenuBarVisibility(false);child.webContents.setWindowOpenHandler(()=>({action:'deny'}));child.webContents.on('will-navigate',event=>event.preventDefault());
  child.once('ready-to-show',()=>{if(!child.isDestroyed())child.show();});
  for(const name of ['show','hide','minimize','restore'])child.on(name,()=>sendState(owner));
  child.once('closed',()=>{if(owner.child===child)owner.child=null;sendState(owner);});
  void child.loadFile(path.join(root,'electron/debug.html')).catch(()=>{if(!child.isDestroyed())child.close();});return sendState(owner);
 });
 ipcMain.handle('client-debug:ready',event=>sendState(trusted(event,true)));
 ipcMain.handle('client-debug:tab',(event,tab)=>{const owner=trusted(event,true);if(!tabs.has(tab))throw Error('Invalid debug tab');owner.tab=tab;return sendState(owner);});
 ipcMain.on('client-debug:snapshot',(event,snapshot)=>{try{const owner=trusted(event);if(state(owner).visible&&snapshot?.tab===owner.tab&&Array.isArray(snapshot.roots))owner.child.webContents.send('client-debug:snapshot',snapshot);}catch{/* Ignore closed/untrusted senders. */}});
 ipcMain.on('client-debug:command',(event,command)=>{try{const owner=trusted(event,true);if(!command||typeof command.key!=='string'||command.key.length>40||!['click','input','change'].includes(command.type)||typeof command.value!=='string'&&command.value!==undefined||command.value?.length>4096)return;owner.window.webContents.send('client-debug:event',{kind:'command',command});}catch{/* Ignore closed/untrusted senders. */}});
 return{attach(window){const id=window.webContents.id,owner={window,child:null,tab:'performance'};owners.set(id,owner);window.once('closed',()=>{owners.delete(id);owner.child?.destroy();owner.child=null;});}};
}
module.exports={registerDebugWindows};
