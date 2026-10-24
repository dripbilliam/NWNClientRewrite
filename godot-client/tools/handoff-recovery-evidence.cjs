const {integrationComplete}=require('./integration-evidence.cjs');
function recoveryIntegrationComplete(r,{beforeShutdown=false}={}){
 const mode=r.portalRecoveryMode,cancel=mode==='cancel',retry=cancel?4:3,native=r.portalRecoveryNative,click=r.portalRecoveryRetry;
 if(!['cancel','failure'].includes(mode)||!integrationComplete('text',r)||r.failure||r.rejectedCommands?.length||!native?.completed||native.mode!==mode||native.startedConnection!==2||native.recoveredConnection!==(cancel?3:2)||native.checks?.length!==12||native.checks.some(v=>!v.passed))return false;
 if(!click?.completed||!click.pointerClick||!click.buttonEnabled||click.from!==native.recoveredConnection||click.to!==retry)return false;
 if(!r.portalRecoveryDestinationClosed||!r.portalRecoveryCharacterWiped||r.portalRecoveryJoinWhileClosing!==false||r.portalRecoveryConnects!==(cancel?0:1)||!cancel&&!r.portalRecoveryStopped)return false;
 if(cancel?native.error!=='':!String(native.error).includes('destination'))return false;
 if(r.nativeLoaded?.map(v=>v.connection).join(',')!==`1,${retry}`||r.areas?.map(v=>v.area).join(',')!=='dense_a,dense_a'||r.handoffGameplay?.length!==2||r.characterSaves?.map(v=>v.connection).join(',')!==`1,${retry}`||r.characterReads?.some(v=>![1,retry].includes(v.connection)))return false;
 if(!r.characterSaves.every(v=>v.bytes>1000&&/^[a-f0-9]{64}$/.test(v.sha256)))return false;
 if(!r.nativeLoaded.every((load,i)=>load.generation===1&&r.handoffGameplay[i].connection===load.connection&&r.handoffGameplay[i].result?.completed&&r.handoffGameplay[i].result.checks?.length===16&&r.handoffGameplay[i].result.checks.every(v=>v.passed)&&r.presentations.some(v=>v.connection===load.connection&&v.cleanup?.alive===0)))return false;
 if(r.portalCharacters?.length!==1||!r.portalCharacters[0].originReleased||r.portalCharacters[0].kind!=='bic'||r.portalCharacters[0].bytes<1000)return false;
 const stages=r.portalAdoptions?.map(v=>v.stage).join(',');if(stages!==(cancel?'prepared,adopting':'prepared,adopting,installed,failed')||r.portalAdoptions.some(v=>v.from!==1||v.to!==2||v.endpoint?.host!=='127.0.0.1'||v.endpoint.port!==5122||v.cleanupFailed))return false;
 if(!r.commands.some(v=>v.kind==='lobby-join'&&v.connection===native.recoveredConnection)||cancel&&!r.commands.some(v=>v.kind==='lobby-cancel-join'&&v.connection===2))return false;
 if(r.diagnostics?.some(v=>v.code==='godot.particle-frame-failed'))return false;
 if(!beforeShutdown&&(r.nativeExit!==0||r.disconnected!==true))return false;
 return r.particles?.epochs?.length===2&&r.particles.epochs.every((v,i)=>beforeShutdown&&i===1||v.closed&&v.pendingJobs===0&&v.remainingThreads===0);
}
module.exports={recoveryIntegrationComplete};
