const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('runtimeLog', {
  location: () => ipcRenderer.invoke('runtime-log:location'),
  append: records => ipcRenderer.invoke('runtime-log:append', records)
});
