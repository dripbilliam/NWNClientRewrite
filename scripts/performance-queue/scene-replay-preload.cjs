const {contextBridge,ipcRenderer}=require('electron');
if(process.argv.includes('--scene-replay-babylon-profile'))contextBridge.exposeInMainWorld('sceneReplayProfiler',{start:label=>ipcRenderer.invoke('scene-replay:profile-start',label),stop:()=>ipcRenderer.invoke('scene-replay:profile-stop')});
const invoke=async(name,...args)=>{const result=await ipcRenderer.invoke('scene-replay:request',name,args);if(!result.ok){const error=Error(result.message);if(result.code)error.code=result.code;throw error;}return result.value;};
const bridge={
 offlineWorkerStream:process.argv.includes('--scene-replay-worker-stream'),
 getResource:(id,ref,type)=>invoke('resource',id,ref,type),
 getResourceResult:(id,ref,type)=>ipcRenderer.invoke('scene-replay:request','resource',[id,ref,type]),
 getTextureResourceResult:(id,ref)=>ipcRenderer.invoke('scene-replay:request','texture',[id,ref]),
 getModelSource:(id,ref,knownKey)=>invoke('model',id,ref,knownKey),
 getAudioResource:(id,ref,type)=>invoke('audio',id,ref,type),
 talkString:(id,ref,gender)=>invoke('talk',id,ref,gender),talkTable:(id,custom)=>invoke('talk-table',id,custom),
 areaReady:(id,generation)=>invoke('area-ready',id,generation),
 savedCharacters:async()=>[],
 sceneCaptureStatus:async()=>({recording:false}),
 subscribe:callback=>{const listener=(_event,value)=>callback(value);ipcRenderer.on('network:event',listener);return()=>ipcRenderer.removeListener('network:event',listener);}
};
// Every outbound action is rejected locally; there is no live bridge or socket.
for(const name of ['connect','disconnect','chooseInstall','exportCharacter','walkTo','keyboardMove','interact','chat','containerInput','storeInput','examine','replyDialog','inventoryWindow','inventoryPanel','itemAction','assignQuickbar','activateQuickbar','castSpell','prepareSpell','rest','levelUp','nuiInput','selectScriptTarget','cancelAction','hudPanel','playerAttitude','useItem','castSpellLike','useFeat','changeMode','possessFamiliar','associateCommand','quickChat'])bridge[name]=(...args)=>invoke('action',name,...args);
contextBridge.exposeInMainWorld('nativeNetwork',bridge);
