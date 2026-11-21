const{contextBridge,ipcRenderer}=require('electron');
contextBridge.exposeInMainWorld('targetFixture',{input:r=>ipcRenderer.invoke('target-fixture:nui',r),select:r=>ipcRenderer.invoke('target-fixture:select',r),onMessage:callback=>ipcRenderer.on('target-fixture:message',(_e,message)=>callback(message))});
