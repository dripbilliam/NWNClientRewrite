// Real Electron window transitions on the owned QA client; no global input.
module.exports=async(window,read)=>{
 const {screen}=require('electron'),sleep=ms=>new Promise(r=>setTimeout(r,ms)),bounds=window.getBounds(),display=screen.getDisplayMatching(bounds),stages=[];
 const wait=async(predicate,label)=>{const end=Date.now()+10000;while(!predicate()){if(Date.now()>end)throw Error(label+' timed out');await sleep(100);}};
 try{
  for(const[mode,durationMs]of[['windowed',20000],['maximized',20000],['fullscreen',60000],['restored',20000]]){
   if(mode==='fullscreen'){
    // Windows can report the flag while retaining the pre-maximize bounds.
    // Establish display-sized bounds first and verify the settled native size.
    window.unmaximize();await wait(()=>!window.isMaximized(),'Prepare fullscreen');window.setBounds(display.bounds);window.setFullScreen(true);
    await wait(()=>{const b=window.getBounds();return window.isFullScreen()&&Math.abs(b.width-display.bounds.width)<=2&&Math.abs(b.height-display.bounds.height)<=2;},'Enter display-sized fullscreen');
   }
   else{if(window.isFullScreen()){window.setFullScreen(false);await wait(()=>!window.isFullScreen(),'Leave fullscreen');}if(mode==='maximized'){window.maximize();await wait(()=>window.isMaximized(),'Maximize');}else{window.unmaximize();await wait(()=>!window.isMaximized(),'Restore');window.setBounds(bounds);}}
   window.show();window.focus();const start=Date.now(),stage={mode,durationMs,startedAt:start,window:window.getBounds(),fullScreen:window.isFullScreen(),maximized:window.isMaximized(),samples:[]};stages.push(stage);let rotating=false;
   try{while(Date.now()-start<durationMs){const elapsedMs=Date.now()-start;if(elapsedMs>=3000&&elapsedMs<durationMs-3000&&!rotating){window.webContents.sendInputEvent({type:'keyDown',keyCode:'Home'});rotating=true;}else if(elapsedMs>=durationMs-3000&&rotating){window.webContents.sendInputEvent({type:'keyUp',keyCode:'Home'});rotating=false;}
    stage.samples.push({elapsedMs,rotating,fullScreen:window.isFullScreen(),maximized:window.isMaximized(),...await read()});await sleep(500);
   }}finally{window.webContents.sendInputEvent({type:'keyUp',keyCode:'Home'});}stage.finishedAt=Date.now();
  }
  return{scope:'Electron native windowed/maximized/fullscreen/restored states, not exclusive GPU display mode; local current academy scene',display:{bounds:display.bounds,scaleFactor:display.scaleFactor},stages};
 }finally{window.webContents.sendInputEvent({type:'keyUp',keyCode:'Home'});if(window.isFullScreen()){window.setFullScreen(false);await wait(()=>!window.isFullScreen(),'Restore fullscreen');}window.unmaximize();window.setBounds(bounds);}
};
