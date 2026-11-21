import {performanceCandidateDefinitions as definitions,performanceCandidateFlags,validatePerformanceCandidateFlags,summarizeCandidateFrames} from './live-performance-profile.mjs';

export function installLivePerformanceDiagnostics({root,apply,readContext,readTelemetry,report}) {
  let flags=performanceCandidateFlags(),profile='baseline',changedAt=performance.now(),context={},contextKey='',rows=[],first=0,last=null,lastLog=0,sequence=0;
  const element=(tag,text)=>{const node=document.createElement(tag);if(text)node.textContent=text;return node;};
  const launcher=element('button','Performance test'),panel=element('section');launcher.type='button';panel.dataset.performanceCandidates='true';
  launcher.style.cssText='position:absolute;right:12px;bottom:12px;z-index:100000;padding:6px 10px;color:#f2e6be;background:#101914;border:1px solid #b29a54;';
  panel.style.cssText='position:absolute;right:12px;bottom:48px;z-index:100001;width:350px;max-width:85vw;max-height:75vh;overflow:auto;padding:12px;color:#f2e6be;background:rgba(8,15,12,.97);border:1px solid #b29a54;font:13px/1.5 sans-serif;box-shadow:0 3px 14px #000;';
  const title=element('strong','Performance comparison'),description=element('p','Experimental build. Compare profiles in the same area. Settings marked “next area” apply when an area loads.'),status=element('p'),buttons=element('div'),checklist=element('div'),metrics=element('pre');
  metrics.style.cssText='white-space:pre-wrap;font:12px/1.5 monospace;color:#fff;';panel.append(title,description,status,buttons,checklist,metrics);
  const controls=new Map();
  for(const [key,label,nextArea]of definitions){const line=element('label'),input=element('input');input.type='checkbox';input.dataset.candidate=key;line.style.display='block';line.append(input,document.createTextNode(' '+label+(nextArea?' · next area':'')));checklist.append(line);controls.set(key,input);input.addEventListener('change',()=>{try{setFlags({...flags,[key]:input.checked},'custom');}finally{input.blur();}});}
  const addButton=(label,action)=>{const button=element('button',label);button.type='button';button.style.cssText='margin:0 5px 6px 0;padding:4px 7px;';button.addEventListener('click',()=>{action();button.blur();});buttons.append(button);};
  addButton('Baseline',()=>setProfile('baseline'));addButton('All candidates',()=>setProfile('candidates'));addButton('Copy diagnostics',()=>{void navigator.clipboard.writeText(JSON.stringify(snapshot(),null,2)).then(()=>status.textContent='Diagnostics copied.',()=>status.textContent='Copy unavailable; diagnostics are recorded in runtime logs.');});addButton('Hide',()=>panel.hidden=true);
  for(const node of [launcher,panel])for(const type of ['pointerdown','pointerup','click','dblclick','contextmenu','wheel'])node.addEventListener(type,event=>event.stopPropagation());
  launcher.addEventListener('click',()=>{panel.hidden=!panel.hidden;launcher.blur();});root.append(launcher,panel);
  function snapshot(){return {version:1,profile,flags:{...flags},activationMs:performance.now()-changedAt,warmup:performance.now()-changedAt<10000,context,recent:summarizeCandidateFrames(rows.slice(first)),telemetry:readTelemetry()};}
  function setFlags(value,name='custom') {
    const validated=validatePerformanceCandidateFlags(value);apply(validated);flags=validated;profile=name;changedAt=performance.now();rows=[];first=0;last=null;sequence++;
    for(const [key,input]of controls)input.checked=flags[key];
    report('performance.candidate-profile','Performance comparison settings changed',{sequence,profile,flags:{...flags},nextArea:definitions.filter(([, ,next])=>next).map(([key])=>key)});update();
  }
  function setProfile(name){setFlags(performanceCandidateFlags(name),name);}
  function update(){
    const next=readContext(),key=JSON.stringify([next.phase,next.areaId]);
    if(contextKey&&key!==contextKey){report('performance.candidate-phase','Performance comparison phase ended',snapshot());rows=[];first=0;last=null;changedAt=performance.now();}
    context=next;contextKey=key;const state=snapshot(),recent=state.recent;
    const pending=next.areaSettings&&definitions.filter(([, ,perArea])=>perArea).some(([key])=>next.areaSettings[key]!==flags[key]);
    status.textContent=profile.toUpperCase()+' · '+(next.phase??'menu')+(pending?' · area settings pending':'')+(state.warmup?' · warming up':'');
    metrics.textContent=recent?`${recent.fps.toFixed(1)} FPS · p95 ${recent.p95Ms.toFixed(1)} ms\nWorst ${recent.maxMs.toFixed(1)} ms · ${recent.hitchesOver50Ms} hitches >50 ms\nWork ${recent.workMs.toFixed(1)} · render ${recent.renderMs.toFixed(1)} ms\nCamera ${recent.cameraMs.toFixed(1)} · particles ${recent.particlesMs.toFixed(1)} ms\n${recent.renderedFrames}/${recent.frames} frames rendered\n${next.area??'No area'}`:'Waiting for frames';
    root.dataset.performanceCandidates=JSON.stringify(state);
    if(performance.now()-lastLog>=5000){lastLog=performance.now();report('performance.candidate-sample','Performance comparison sample',state);}
  }
  const timer=setInterval(update,1000);
  function record(at,timing,rendered){const gapMs=last===null?timing.intervalMs:at-last;last=at;if(!(gapMs>0&&Number.isFinite(gapMs)))return;rows.push({at,gapMs,rendered,workMs:timing.totalMs,renderMs:timing.renderMs,cameraMs:timing.cameraAndShadowsMs,particlesMs:timing.particlesMs,networkMs:timing.networkMs});while(first<rows.length-1&&rows[first].at<at-15000)first++;if(first>4096){rows=rows.slice(first);first=0;}}
  const api={record,snapshot,setProfile,setFlags,hide:()=>panel.hidden=true,dispose(){clearInterval(timer);panel.remove();launcher.remove();delete root.dataset.performanceCandidates;}};
  window.performanceCandidatesForTest=api;setProfile('candidates');return api;
}
