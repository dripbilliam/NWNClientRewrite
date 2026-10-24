export function installSceneCaptureControls({root,bridge,view,report}){
 if(!bridge?.sceneCaptureStatus||!bridge?.captureSceneView)return{dispose(){}};
 const panel=document.createElement('div'),label=document.createElement('span'),finish=document.createElement('button');finish.type='button';finish.textContent='Finish recording';panel.hidden=true;panel.style.cssText='position:absolute;left:12px;top:12px;z-index:100000;background:#101914;color:#f2e6be;border:1px solid #b29a54;padding:8px;font:13px sans-serif;';finish.style.marginLeft='10px';panel.append(label,finish);root.append(panel);
 let stopped=false,pending=false,lastStatus=0,status=null,reported=false;
 for(const kind of ['pointerdown','pointerup','click','dblclick','wheel'])panel.addEventListener(kind,event=>event.stopPropagation());
 finish.onclick=async()=>{finish.disabled=true;try{const result=await bridge.finishSceneCapture();label.textContent=result.complete?'Scene capture saved':'Capture incomplete';report('performance.scene-capture-finished','Scene recording finished',result);status={recording:false};}catch(error){label.textContent='Capture failed';report('performance.scene-capture-failed',error.message,{});}finally{finish.blur();}};
 const timer=setInterval(async()=>{
  if(stopped||pending)return;pending=true;
  try{
   if(performance.now()-lastStatus>1000){lastStatus=performance.now();status=await bridge.sceneCaptureStatus();panel.hidden=!status.recording&&!status.failure;if(status.failure){label.textContent='Capture incomplete: '+status.failure;finish.disabled=true;}else if(status.recording){label.textContent='Recording scene';if(!reported){reported=true;report('performance.scene-capture-started','Scene recording is armed',{directory:status.directory});}}}
   if(status?.recording){const sample=view();if(sample)await bridge.captureSceneView(sample.sessionId,sample.view);}
  }catch(error){if(!reported){reported=true;report('performance.scene-capture-failed',error.message,{});}}
  finally{pending=false;}
 },200);
 return{dispose(){stopped=true;clearInterval(timer);panel.remove();}};
}
