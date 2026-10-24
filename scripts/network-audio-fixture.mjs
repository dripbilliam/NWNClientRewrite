import {GameAudio} from '../src/game_audio.js';
import {nativeAudioListener,NetworkAudioPresentation} from '../src/native_audio.js';
import {NetworkWorld} from '../src/network_world.js';
import {NetworkFrontend} from '../src/network_frontend.js';
import {NetworkSpeechView} from '../src/network_speech_view.js';
import {decodeServerGameMessage} from '../src/network_game_messages.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const check=(value,message)=>{if(!value)throw Error(message);},tick=()=>new Promise(resolve=>setTimeout(resolve,20));
window.startAudioFixture=packet=>{
 document.querySelector('#play').onclick=async()=>{try{
  const decoded=decodeServerGameMessage(Uint8Array.from(packet.match(/../g).map(h=>parseInt(h,16)))),world=new NetworkWorld();world.areaId=0x80000004;world.localObjectId=decoded.objectId;
  const point=[12.25,-3.5,0];world.registry.addObjectAtPos(decoded.objectId,{objectType:5,areaId:world.areaId,replicated:{position:point,name:{text:'Audio source'}}});const before=JSON.stringify([...world.registry.objects]);
  let camera=[14.25,-6.5,5],quaternion=[1,0,0,0];const reports=[],context=new AudioContext(),meter=context.createAnalyser();meter.fftSize=2048;meter.connect(context.destination);
  // Observe actual Chromium PCM before the window's muted output. This is an
  // adapter boundary check, not native OpenAL or hardware audibility parity.
  const adapter=new Proxy(context,{get:(target,key)=>{if(key==='destination')return meter;const value=Reflect.get(target,key,target);return typeof value==='function'?value.bind(target):value;}});
  const audio=new GameAudio({getResource:(...args)=>window.visualFixture.resource(...args)},{getObject:id=>world.registry.get(id),getPlayer:()=>({id:world.localObjectId}),getListener:()=>nativeAudioListener(point,camera,quaternion),createContext:()=>adapter});
  await audio.unlock();const speech=new NetworkSpeechView(document.querySelector('#fixture'),{world:()=>world,resolve:async value=>value?.text??'',send:null});
  const sound=new NetworkAudioPresentation({world:()=>world,output:audio,report:code=>reports.push(code)}),front={id:1,world,queue:Promise.resolve(),onAudio:message=>sound.receive(message),onHud:message=>speech.receive(message),showError:error=>{throw error;}};
  NetworkFrontend.prototype.receive.call(front,{sessionId:1,kind:'message',message:decoded});await front.queue;
  const deadline=performance.now()+10000;let peak=0;const samples=new Float32Array(meter.fftSize);
  while(performance.now()<deadline){meter.getFloatTimeDomainData(samples);peak=Math.max(peak,...samples.map(Math.abs));if(audio.state.played===1&&peak>0)break;await tick();}
  check(audio.state.played===1,'Installed mono sound was not played');check(audio.state.pending===0&&context.state==='running','Audio output stayed suspended');check(peak>0,'Actual Chromium graph produced no PCM samples');check(speech.rows.length===0,'Resource name leaked into chat');check(JSON.stringify([...world.registry.objects])===before,'Canonical world changed during playback');
  const active=[...audio.active][0],sourcePosition=active?['X','Y','Z'].map(a=>active.panner['position'+a].value):null,initialListener=audio.listenerState;check(sourcePosition&&sourcePosition.every((v,i)=>v===point[i]),'Own-player script sound was incorrectly centered');
  camera=[17,-2,7];quaternion=[.5,.5,.5,.5];audio.update();check(audio.listenerState.position[0]!==initialListener.position[0]&&context.listener.forwardX.value!==initialListener.forward[0],'Listener did not follow camera');
  const result={packetKind:decoded.kind,objectId:decoded.objectId,resource:audio.state.last,audio:{...audio.state},sourcePosition,initialListener,updatedListener:audio.listenerState,pcmPeak:peak,chatRows:speech.rows.length,canonicalUnchanged:true,reports,diagnostics:runtimeDiagnostics.records.filter(r=>r.severity==='error').map(r=>({code:r.code,message:r.message})),limits:'Original-code9/7 packet and installed WAV, actual production decode/frontend/source/listener adapters, isolated canonical proxy. Chromium output is muted; no fresh server emission, native mixer or hardware audibility claim.'};
  sound.dispose();audio.dispose();check(audio.active.size===0&&audio.pending.length===0,'Audio sources survived disconnect');window.fixtureResult=result;document.querySelector('#audio-status').textContent=JSON.stringify(result,null,2);
 }catch(error){window.fixtureFailure=error.stack;document.querySelector('#audio-status').textContent=error.stack;}};
};
