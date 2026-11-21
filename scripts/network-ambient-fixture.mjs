import {GameAudio} from '../src/game_audio.js';
import {NetworkAmbientPresentation} from '../src/network_ambient_presentation.js';
import {runtimeDiagnostics} from '../src/runtime_diagnostics.js';
const tick=()=>new Promise(resolve=>setTimeout(resolve,25)),check=(condition,text)=>{if(!condition)throw Error(text);};
window.startAmbientFixture=area=>{
 document.querySelector('#play').onclick=async()=>{try{
  const context=new AudioContext(),meter=context.createAnalyser();meter.fftSize=2048;meter.connect(context.destination);
  const adapter=new Proxy(context,{get:(target,key)=>{if(key==='destination')return meter;const value=Reflect.get(target,key,target);return typeof value==='function'?value.bind(target):value;}});
  const output=new GameAudio({getResource:()=>{throw Error('Unexpected one-shot in ambient fixture');}},{getObject:()=>null,getPlayer:()=>null,createContext:()=>adapter}),reports=[],presentation=new NetworkAmbientPresentation({output,getResource:(...args)=>window.ambientFixture.audio(...args),report:(...r)=>reports.push(r)});
  await output.unlock();await presentation.attach(area,{getResource:(...args)=>window.ambientFixture.resource(...args)});
  const deadline=performance.now()+25000,samples=new Float32Array(meter.fftSize),peakByStream={music:0,ambient:0};let peak=0;
  while(performance.now()<deadline){output.update();presentation.update(area.time.timeOfDay);meter.getFloatTimeDomainData(samples);peak=Math.max(peak,...samples.map(Math.abs));if(Object.values(presentation.owner.streams).every(s=>s.status==='playing')&&peak>0)break;await tick();}
  const initial=presentation.snapshot();check(initial.streams.music.started===1&&initial.streams.ambient.started===1,'Both native streams did not start');check(initial.streams.music.loop===false&&initial.streams.ambient.loop===true,'Native stream looping policy differs');check(peak>0,'Actual streaming audio graph produced no PCM');
  for(const [kind,other]of [['music','ambient'],['ambient','music']]){
   const muted=presentation.owner.streams[other].gain.gain;const value=muted.value;muted.value=0;
   const until=performance.now()+1500;await new Promise(resolve=>setTimeout(resolve,100));while(performance.now()<until){meter.getFloatTimeDomainData(samples);peakByStream[kind]=Math.max(peakByStream[kind],...samples.map(Math.abs));if(peakByStream[kind]>0)break;await tick();}muted.value=value;check(peakByStream[kind]>0,kind+' stream produced no PCM');
  }
  presentation.receive({kind:'ambient-command',operation:8,day:initial.owner.day,value:32});check(presentation.snapshot().streams.ambient.volume===32,'Native volume command did not reach active stream');presentation.receive({kind:'ambient-command',operation:2,value:12345});check(presentation.owner.delay===12345,'Native music delay did not update');
  const active=Object.values(presentation.owner.streams),nodes=active.map(s=>s.media);presentation.detach();check(output.streams.size===0&&nodes.every(m=>m.paused&&!m.getAttribute('src')),'Area audio survived unload');output.dispose();
  const result={area,initial,peak,peakByStream,unloaded:true,reports,errors:runtimeDiagnostics.records.filter(r=>r.severity==='error').map(r=>({code:r.code,message:r.message})),limits:'Captured original-server area settings, installed active2DAs and BMU/WAV, production streaming adapter in actual Chromium. Output muted. Isolated replay is not a fresh server emission or native OpenAL/hardware parity check.'};window.fixtureResult=result;document.querySelector('#status').textContent=JSON.stringify(result,null,2);
 }catch(error){window.fixtureFailure=error.stack;document.querySelector('#status').textContent=error.stack;}};
};
