const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld('runtimeLog', {
  location: () => ipcRenderer.invoke('runtime-log:location'),
  append: records => ipcRenderer.invoke('runtime-log:append', records)
});
const networkInvoke=async(channel,...args)=>{const result=await ipcRenderer.invoke(channel,...args);if(!result.ok)throw new Error(result.message);return result.value;};
contextBridge.exposeInMainWorld('nativeNetwork',{
 connect:request=>networkInvoke('network:connect',request),
 disconnect:()=>networkInvoke('network:disconnect'),
 chooseInstall:()=>networkInvoke('network:install'),
 selectCharacter:(id,bytes)=>networkInvoke('network:character',id,bytes),
 areaReady:(id,generation)=>networkInvoke('network:area-ready',id,generation),
 walkTo:(id,request)=>networkInvoke('network:walk',id,request),
 interact:(id,request)=>networkInvoke('network:interact',id,request),
 examine:(id,request)=>networkInvoke('network:examine',id,request),
 replyDialog:(id,request)=>networkInvoke('network:dialog-reply',id,request),
 inventoryWindow:(id,request)=>networkInvoke('network:inventory-window',id,request),
 inventoryPanel:(id,request)=>networkInvoke('network:inventory-panel',id,request),
 itemAction:(id,request)=>networkInvoke('network:item-action',id,request),
 assignQuickbar:(id,request)=>networkInvoke('network:quickbar-assign',id,request),
 activateQuickbar:(id,request)=>networkInvoke('network:quickbar-use',id,request),
 castSpell:(id,request)=>networkInvoke('network:spell-cast',id,request),
 prepareSpell:(id,request)=>networkInvoke('network:spell-prepare',id,request),
 rest:(id,request)=>networkInvoke('network:rest',id,request),
 hudPanel:(id,request)=>networkInvoke('network:hud-panel',id,request),
 playerAttitude:(id,request)=>networkInvoke('network:player-attitude',id,request),
 useItem:(id,request)=>networkInvoke('network:item-use',id,request),
 castSpellLike:(id,request)=>networkInvoke('network:spell-like-cast',id,request),
 useFeat:(id,request)=>networkInvoke('network:feat-use',id,request),
 changeMode:(id,request)=>networkInvoke('network:mode-change',id,request),
 possessFamiliar:(id,request)=>networkInvoke('network:familiar-possess',id,request),
 associateCommand:(id,request)=>networkInvoke('network:associate-command',id,request),
 quickChat:(id,request)=>networkInvoke('network:quick-chat',id,request),
 talkString:(id,ref,gender)=>networkInvoke('network:talk-string',id,ref,gender),
 getResource:(id,resref,type)=>networkInvoke('network:resource',id,resref,type),
 subscribe:callback=>{const listener=(_event,value)=>callback(value);ipcRenderer.on('network:event',listener);return()=>ipcRenderer.removeListener('network:event',listener);}
});
