const {nativeShutdownComplete}=require('./shutdown-evidence.cjs');
function worldAudioIntegrationComplete(r){
 const audio=r.visualTest?.audio,backend=r.worldAudio?.at(-1),loop=audio?.duration?.voices?.find(v=>v.name==='sdr_eleshieldlp'&&v.profile.loop),final=audio?.final;
 if(r.nativeShutdown?.observed?.audioSurvivors!==0)return false;
 if(!r.success||!nativeShutdownComplete(r)||r.endpoint!=='127.0.0.1:5121'||!r.visualTest?.completed||r.visualTest.checks.length<39||r.visualTest.checks.some(v=>v.passed!==true)||!loop?.playing||!(loop.playback>0)||loop.profile.priority!==11||!loop.profile.positional||loop.profile.volume!==127||audio.durationSoundId!==loop.id||final?.driver!=='WASAPI'||final.stats.failed!==0||final.voices.some(v=>v.id===loop.id)||!backend?.closed||backend.pending!==0||!backend.scopes?.length||backend.scopes.some(v=>!v.closed||v.pending!==0||v.cachedBytes!==0))return false;
 if(!backend.scriptMessages?.some(v=>v.kind==='server-script-sound'&&v.sound==='sim_heal01'&&v.objectId!==0x7f000000)||!r.visuals.input.some(v=>v.kind==='loop'&&v.visualId===147&&v.action==='A')||!r.visuals.input.some(v=>v.kind==='loop'&&v.visualId===147&&v.action==='D'))return false;
 for(const stage of ['playing','stopped','retired'])if(!backend.observed.some(v=>v.soundId===loop.id&&v.stage===stage&&v.driver==='WASAPI'))return false;
 if(!final.history.some(v=>v.effectId===0&&v.name==='sim_heal01'&&v.profile.priority===8&&v.profile.positional)||!final.history.some(v=>v.effectId>0&&v.name==='sim_heal01'&&v.profile.priority===11))return false;
 for(const row of final.history){const resource=backend.resources.find(v=>v.resourceId===row.resourceId);if(!resource||resource.sha256!==row.metadata.sha256||resource.bytes!==row.metadata.bytes||resource.codec!==row.metadata.codec||resource.channels!==row.metadata.channels||!(row.duration>0))return false;}
 return Boolean(r.visuals.closed&&r.visuals.pendingJobs===0&&r.particles?.epochs?.length&&r.particles.epochs.every(v=>v.closed&&v.remainingThreads===0)&&!r.rendererErrors?.length&&!/SCRIPT ERROR|^ERROR:|ObjectDB instances were leaked/m.test(r.nativeErrors??''));
}
module.exports={worldAudioIntegrationComplete};
