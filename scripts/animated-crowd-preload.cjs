const {contextBridge,ipcRenderer}=require('electron');
contextBridge.exposeInMainWorld('snapshotFixture',{metadata:()=>ipcRenderer.invoke('snapshot-fixture:metadata'),resource:(name,type)=>ipcRenderer.invoke('snapshot-fixture:resource',name,type),texture:name=>ipcRenderer.invoke('snapshot-fixture:texture',name),progress:value=>ipcRenderer.invoke('snapshot-fixture:progress',value)});
