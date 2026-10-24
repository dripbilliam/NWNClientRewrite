const {contextBridge,ipcRenderer}=require('electron');
contextBridge.exposeInMainWorld('lobbyFixture',{resource:(name,type)=>ipcRenderer.invoke('lobby-fixture:resource',name,type),servers:()=>ipcRenderer.invoke('lobby-fixture:servers'),talk:ref=>ipcRenderer.invoke('lobby-fixture:talk',ref),data:()=>ipcRenderer.invoke('lobby-fixture:data')});
