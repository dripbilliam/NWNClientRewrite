const {contextBridge,ipcRenderer}=require('electron');
contextBridge.exposeInMainWorld('debugInspector',{
 ready:()=>ipcRenderer.invoke('client-debug:ready'),
 selectTab:tab=>ipcRenderer.invoke('client-debug:tab',tab),
 command:command=>ipcRenderer.send('client-debug:command',command),
 subscribe:callback=>{const listener=(_event,snapshot)=>callback(snapshot);ipcRenderer.on('client-debug:snapshot',listener);return()=>ipcRenderer.removeListener('client-debug:snapshot',listener);}
});
