const {contextBridge,ipcRenderer}=require('electron');
contextBridge.exposeInMainWorld('inventoryFixture',{resource:(name,type)=>ipcRenderer.invoke('inventory-fixture:resource',name,type),texture:name=>ipcRenderer.invoke('inventory-fixture:texture',name),fixture:()=>ipcRenderer.invoke('inventory-fixture:metadata')});
