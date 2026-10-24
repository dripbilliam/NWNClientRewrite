import {GameAudio} from '../src/game_audio.js';
import {parse2da} from '../src/area.js';
import {decodeResourceText} from '../src/resource_archive.js';
import {nativeWaveTiming} from '../src/native_wave_timing.js';
import {nativeStringEntry} from '../src/spell_metadata.js';
import {effectSoundProviders} from '../src/native_effect_sound.js';
import {createVisualPhaseState} from '../src/visual_phase_runtime.js';
import {startVisualPhases,stopVisualPhases} from '../src/visual_phase_control.js';
import {updateVisualPhases} from '../src/visual_phase_update.js';
const wait=()=>new Promise(r=>setTimeout(r,20)),check=(v,m)=>{if(!v)throw Error(m);};
window.startEffectSoundFixture=()=>{document.querySelector('#play').onclick=async()=>{try{
 const table=parse2da(decodeResourceText(await window.visualFixture.resource('visualeffects',2017)));let selected;
 for(let id=0;id<table.orderedRows.length;id++){const entry=nativeStringEntry(table,id,'SoundDuration');if(!entry.found||!entry.value)continue;try{const bytes=await window.visualFixture.resource(entry.value,4);if(nativeWaveTiming(bytes)?.channels===1){selected={id,resRef:entry.value};break;}}catch{}}
 check(selected,'No installed mono visual duration sound found');
 const context=new AudioContext(),meter=context.createAnalyser();meter.fftSize=2048;meter.connect(context.destination);let position=[1,0,0];
 const adapter=new Proxy(context,{get:(target,key)=>{if(key==='destination')return meter;const v=Reflect.get(target,key,target);return typeof v==='function'?v.bind(target):v;}}),audio=new GameAudio({getResource:(...args)=>window.visualFixture.resource(...args)},{getObject:()=>null,getPlayer:()=>null,getListener:()=>({position:[0,0,0],forward:[0,1,0],up:[0,0,1]}),createContext:()=>adapter});await audio.unlock();
 const e=createVisualPhaseState();e.visualF8=selected.id;e.target54=0xffffffff;e.closedEc=1;e.durationFc=1;e.programsD0=[65535,65535,65535];
 const p={...effectSoundProviders(resRef=>audio.effectSound({resRef,objectId:e.target54,channel:'visual'}),()=>check(false,'Missing factory')),clientObject:()=>({}),renderObject:()=>({position38:position}),visualString:(id,key)=>nativeStringEntry(table,id,key),visualInt:()=>({found:false,value:0}),visualFloat:()=>({found:false,value:0}),controlledClient:()=>null,positionalSound(){},detach(){}};
 startVisualPhases(e,p);const source=e.sound118,samples=new Float32Array(meter.fftSize);let peak=0;const deadline=performance.now()+12000;
 while(performance.now()<deadline){updateVisualPhases(e,20,p);audio.update();meter.getFloatTimeDomainData(samples);peak=Math.max(peak,...samples.map(Math.abs));if(peak>0&&source.source.hardwarePlaying())break;await wait();}
 check(peak>0,'Effect loop produced no PCM');const initial=source.snapshot();check(initial.priority===11&&initial.loop&&initial.positional,'Native effect settings differ');check(source.source.record.gain.gain.value===Math.fround(127/255),'Native effect gain differs');
 position=[2,3,4];updateVisualPhases(e,20,p);check(source.source.record.panner.positionZ.value===-4,'Moving effect Z differs');position=[100,0,0];updateVisualPhases(e,20,p);audio.update();check(source.source.status==='parked','Far effect loop failed to park');position=[1,0,0];updateVisualPhases(e,20,p);audio.update();check(source.source.hardwarePlaying(),'Effect loop failed to resume');const resumed=source.snapshot();
 stopVisualPhases(e,1,p);check(e.sound118===null&&source.destroyed&&audio.streams.size===0,'Cessation retained duration sound');audio.dispose();
 const result={scope:'Installed active visualeffects table/WAV, original-derived object phase owners and production GameAudio output. Geometry, camera shake, impact one-shot and target provider are isolated; no live server spell or original hardware parity claim.',selected,pcmPeak:peak,initial,resumed,moved:true,parked:true,stopped:true,unloaded:true};window.fixtureResult=result;document.querySelector('#status').textContent=JSON.stringify({selected,pcmPeak:peak,nativeSettings:{priority:initial.priority,loop:initial.loop,positional:initial.positional,volume:initial.volume,rawSampleRate:initial.sampleRate,durationMs:initial.duration},initialStarts:initial.played,resumedStarts:resumed.played,moved:true,parked:true,stopped:true,unloaded:true},null,2);
 }catch(error){window.fixtureFailure=error.stack;document.querySelector('#status').textContent=error.stack;}};};
window.startEffectSoundFixture();
