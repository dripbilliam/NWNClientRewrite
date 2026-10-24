// Opt-in ordinary renderer input, restricted to the existing owned character.
// Returns server poses and message headers only; never records packet bodies.
module.exports=async function checkKeyboard(window,session){
 const sleep=ms=>new Promise(r=>setTimeout(r,ms)),messages=[],samples=[];
 const original=session.peer.sendGameMessage.bind(session.peer);
 session.peer.sendGameMessage=async bytes=>{if(bytes[1]===6&&[28,29,33].includes(bytes[2]))messages.push({major:6,minor:bytes[2],at:Date.now()});return original(bytes);};
 const pose=()=>{const a=session.world.registry.get(session.world.localObjectId),o=a?.replicated?.orientation;return{position:a?.replicated?.position?.slice(),orientation:structuredClone(o),animation:a?.replicated?.animation};};
 // Dispatch from an actual game element so capture precedes legacy bubble
 // listeners, just as it does for a physical key. Window-targeted synthetic
 // events run at-target listeners in a different order and are not valid QA.
 const key=(type,code,shift=false)=>window.webContents.executeJavaScript(`document.querySelector('#model-canvas').dispatchEvent(new KeyboardEvent(${JSON.stringify(type)},{key:${JSON.stringify(code.slice(3).toLowerCase())},code:${JSON.stringify(code)},shiftKey:${Boolean(shift)},bubbles:true,cancelable:true}))`);
 try{
  for(const [code,shift]of [['KeyW',false],['KeyW',true],['KeyS',false],['KeyQ',false],['KeyE',false],['KeyA',false],['KeyD',false]]){
   const row={code,walk:shift,before:pose(),start:messages.length};
   await key('keydown',code,shift);await sleep(650);row.held=pose();await key('keyup',code,shift);await sleep(1100);row.stopped=pose();await sleep(350);row.later=pose();row.messages=messages.slice(row.start);delete row.start;samples.push(row);
  }
 }finally{for(const code of ['KeyW','KeyS','KeyA','KeyD','KeyQ','KeyE'])await key('keyup',code);session.peer.sendGameMessage=original;}
 const distance=(a,b)=>Math.hypot(...a.map((v,i)=>v-b[i]));
 return{samples,driveMessages:messages.filter(m=>m.minor===29).length,stopMessages:messages.filter(m=>m.minor===33).length,turnMessages:messages.filter(m=>m.minor===28).length,translations:samples.filter(s=>!['KeyA','KeyD'].includes(s.code)).map(s=>({code:s.code,walk:s.walk,moved:distance(s.before.position,s.stopped.position),afterStop:distance(s.stopped.position,s.later.position)}))};
};
