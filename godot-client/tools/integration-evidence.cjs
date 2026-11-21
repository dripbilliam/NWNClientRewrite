// A user closing the test window or a clean engine exit is not evidence that
// a multi-stage integration check completed.
function frontendExitComplete(report){return Boolean(report.frontendExitOnly===true&&report.explicitMenuQuit===true&&report.settingsNoNetwork===true&&report.nativeLoaded?.length===0&&!report.rendererErrors?.length&&(report.nativeExit===undefined||report.nativeExit===0)&&!/SCRIPT ERROR|(?:^|\n)ERROR:|leaked|Message queue out of memory/.test(report.nativeErrors??''));}
function integrationComplete(mode,report){
 if(mode==='creation')return require('./creation-evidence.cjs').creationIntegrationComplete(report);
 if(mode==='settings'){
  const t=report.settingsTest,p=report.settingsPersistence;
  return Boolean(t?.completed&&t.nativeWindow===true&&t.checks?.length>=20&&t.checks.every(v=>v.passed)&&p?.windowsProtected&&p.userProfileUnchanged&&p.globalHakEnabled&&p.disabledHakUnavailable&&p.saves?.length>=3&&p.saves.every(v=>v.persistent&&v.containsNoPlaintext)&&p.saves.some(v=>v.keyReplaced&&v.protected&&v.roundTrip)&&p.saves.some(v=>v.keyRemoved&&!v.protected)&&report.settingsNoNetwork&&report.nativeLoaded?.length===0&&!report.rendererErrors?.length&&(report.nativeExit===undefined||report.nativeExit===0)&&!/SCRIPT ERROR|(?:^|\n)ERROR:|leaked|Message queue out of memory/.test(report.nativeErrors??''));
 }
 if(!report.nativeLoaded?.length||report.rendererErrors?.length||report.nativeExit!==undefined&&report.nativeExit!==0||/SCRIPT ERROR|(?:^|\n)ERROR:|Message queue out of memory|RIDs?.*leaked|ObjectDB instances were leaked/.test(report.nativeErrors??''))return false;
 if(mode==='normal')return true;
 const presented=report.nativeLoaded.every(load=>report.presentations?.some(p=>p.connection===load.connection&&p.areaId===load.areaId&&p.generation===load.generation&&p.screenshot&&p.distance>0.25&&p.cameraFollow&&require('./presentation-evidence.cjs').presentationAnimationComplete(p,load)));
 if(!presented)return false;
 if(mode==='text'||mode==='radial'||mode==='book'||mode==='combat'||mode==='particles'){
  const text=Boolean(report.gameplayTest?.completed&&report.gameplayTest.checks?.length>=12&&report.gameplayTest.checks.every(row=>row.passed)&&report.gameplayText?.examine>=1&&report.gameplayText?.['dialog-entry']>=3&&report.gameplayText?.['dialog-close']>=2&&report.gameplayText?.floating>=1&&report.commands?.filter(row=>row.kind==='reply').length>=3);
  if(mode==='text')return text&&Boolean(report.commands?.some(row=>row.kind==='examine'));
  if(mode==='particles')return text&&report.gameplayTest.particleProbe?.changedPixels>=8&&report.gameplayTest.nativeParticles?.frames>=20&&report.gameplayTest.nativeParticles?.failures===0&&report.particles?.epochs?.some(row=>row.frames>=20&&row.workers>=1)&&Object.keys(report.gameplayTest.particleSamples?.before??{}).length>0&&JSON.stringify(report.gameplayTest.particleSamples.before)!==JSON.stringify(report.gameplayTest.particleSamples.after);
  const radial=text&&report.gameplayTest.radial===true&&report.gameplayTest.checks.length>=20&&report.commands?.filter(row=>row.kind==='radial-open').length>=4&&report.commands?.filter(row=>row.kind==='radial-select').length>=6&&report.spellConsumption?.before>report.spellConsumption?.after;
  if(mode==='radial')return radial;
  const book=radial&&report.gameplayTest.book===true&&report.gameplayTest.checks.length>=48&&report.commands?.some(row=>row.kind==='quickbar-assign')&&report.commands?.some(row=>row.kind==='quickbar-activate')&&report.spellConsumptions?.filter(row=>row.spellId===100&&row.before>row.after).length>=2&&report.spellConsumptions?.some(row=>report.authoredFamilySpell?.children?.includes(row.spellId)&&row.before>row.after)&&report.preparationObservations?.some(row=>row.clear&&row.after===null)&&report.preparationObservations?.some(row=>!row.clear&&row.after?.spell===row.spellId);
  if(mode==='book')return book;
  const samples=report.gameplayTest.combatSamples??[],deforms=row=>row.comparison?.advanced_model_clocks>0&&row.comparison?.maximum_local_skin_vertex_delta>0.0001;
  return book&&report.gameplayTest.combat===true&&report.gameplayTest.checks.length>=56&&report.combatInput?.some(row=>row.action==='attack-animation'&&row.records>0)&&report.combatInput?.some(row=>row.action==='cast-animation')&&report.gameplayTest.nativeCombat?.stats?.casts>=3&&report.gameplayTest.nativeCombat?.stats?.attacks>=2&&report.gameplayTest.nativeCombat?.stats?.hits>=1&&samples.some(row=>[17,18,19,20,61].includes(row.animation)&&deforms(row))&&samples.some(row=>row.animation>=200&&row.animation<=205&&deforms(row));
 }
 if(mode==='movement')return Boolean(report.movementTest?.completed&&report.movementTest.menuMovement&&report.movementTest.textFocusStopped&&report.movementDistance>0.5&&report.driveCommands?.some(c=>c.operation==='drive'&&c.transmit)&&report.driveCommands?.some(c=>c.operation==='stop')&&report.drivePreviews?.some(p=>p.blocked||p.factor<1||p.resendFraction<1));
 if(mode==='lifecycle'){
  const saves=report.characterSaves??[];
  return report.nativeLoaded.length===2&&saves.length>=3&&new Set(saves.map(s=>s.id)).size===1&&Boolean(report.characterReads?.some(row=>row.connection===3&&row.source==='vault'&&row.sha256===saves[1]?.sha256));
 }
 if(mode==='content'||mode==='transition'){
  if(report.contentSmokeComplete!==true)return false;
  if(mode==='transition')return report.areas.length===3&&report.areas.map(a=>a.area).join(',')==='dense_a,dense_b,dense_a'&&report.pendingContentRace?.discarded===true&&report.presentations.every(p=>p.cleanup?.alive===0);
 }
 return true;
}
function nuiIntegrationComplete(report){
 const test=report.nuiTest;
 const core=Boolean(integrationComplete('text',report)&&test?.completed&&test.checks?.length>=20&&test.checks.every(row=>row.passed)&&report.nuiCanonicalMatch===true&&test.statistics?.failed===0&&report.nuiMessages?.some(row=>row.kind==='nui-create'&&row.format===0)&&report.nuiMessages?.some(row=>row.kind==='nui-layout'));
 if(!core)return false;
 if(report.nuiSkinRequired&&!(test.skin?.passed&&test.skin.checks>=9))return false;
 if(report.nuiPopupRequired&&!(test.popup?.passed&&test.popup.checks>=8))return false;
 if(report.nuiActionRequired&&!(report.nuiTargetAcknowledged===true&&report.actionRequests?.filter(row=>row.operation==='selectScriptTarget').length>=2&&report.nuiSpellConsumption?.spellId===100&&report.nuiSpellConsumption.before>0&&report.nuiSpellConsumption.after<report.nuiSpellConsumption.before))return false;
 if(!report.nuiReconnectRequired)return true;
 return report.nuiReconnectVerified===true&&report.nuiPhases?.length===2&&new Set(report.nuiPhases.map(row=>row.connection)).size===2&&report.nuiPhases.every(row=>row.accepted&&row.canonical)&&report.nuiRetiredServices?.length>=1&&report.nuiRetiredServices.every(row=>row.closed&&row.pendingResources===0)&&report.nativeLoaded.length===6;
}
function buffIntegrationComplete(report){
 const t=report.buffTest;
 if(!(integrationComplete('text',report)&&t?.completed&&t.checks?.length>=16&&t.checks.every(v=>v.passed)&&report.buffCanonicalMatch===true))return false;
 const records=(report.buffServerIcons??[]).filter(v=>v.connection===report.buffTestConnection);
 if(![1,2].every(id=>records.some(v=>v.added?.some(icon=>icon.icon===id)))||!records.some(v=>v.removed?.includes(1)))return false;
 if(!report.buffReconnectRequired)return true;
 return report.buffReconnectVerified===true&&report.buffPhases?.length===2&&new Set(report.buffPhases.map(p=>p.connection)).size===2&&report.buffPhases.every(p=>p.accepted&&p.canonical)&&report.buffRetiredServices?.length>=1&&report.buffRetiredServices.every(p=>p.closed&&p.pendingDescriptions===0)&&report.nativeLoaded.length===6;
}
function partyIntegrationComplete(report,reconnect=true){
 const t=report.partyTest,c=report.partyTestConnection,id=t?.companionId;
 if(!(integrationComplete('text',report)&&t?.completed&&t.checks?.length>=24&&t.checks.every(v=>v.passed)&&report.partyCanonicalMatch===true))return false;
 if(!['add','remove'].every(operation=>report.partyMembership?.some(v=>v.connection===c&&v.operation===operation&&v.ids.includes(id)))||!report.actionRequests?.some(v=>v.connection===c&&v.operation==='castSpell'&&v.targetId===id)||!report.spellConsumptions?.some(v=>v.connection===c&&v.spellId===100&&v.before>v.after)||!report.partyRequests?.some(v=>v.connection===c&&v.operation==='rest'))return false;
 if(!reconnect)return true;
 return report.partyReconnectVerified===true&&report.partyPhases?.length===2&&new Set(report.partyPhases.map(v=>v.connection)).size===2&&report.partyPhases.every(v=>v.accepted&&v.canonical)&&report.partyRetiredServices?.length>=1&&report.partyRetiredServices.every(v=>v.closed&&v.pendingPresentation===0)&&report.nativeLoaded.length===6;
}
function feedbackIntegrationComplete(report){
 const t=report.feedbackTest,modes=[[true,false],[true,true],[false,true]],damage=report.feedbackServerDamage??[],delivered=report.feedbackDeliveries??[];
 if(!integrationComplete('text',report)||!t?.completed||!t.userConfigUnchanged||t.checks?.length<20||!t.checks.every(v=>v.passed)||t.phases?.length!==3||damage.length!==3||report.rejectedCommands?.length)return false;
 return modes.every(([enabled,total],i)=>{
  const p=t.phases[i],d=damage[i],numeric=p.floating.filter(v=>/^\d+$/.test(v));
  return p.values.floatingFeedback===enabled&&p.values.damageTotalsOnly===total&&p.damageChat>=1&&p.floating.includes('GODOT_FEEDBACK_PROMPT')&&JSON.stringify(numeric)===JSON.stringify(enabled?['3']:[])&&d.options.enabled===enabled&&d.options.total===total&&d.damage.filter(v=>v!==-1).reduce((a,b)=>a+b,0)===3&&delivered.some(v=>v.kind==='chat'&&v.category==='damage-feedback'&&v.options.enabled===enabled&&v.options.total===total)&&delivered.some(v=>v.kind==='floating'&&v.rich.text==='GODOT_FEEDBACK_PROMPT'&&v.options.enabled===enabled&&v.options.total===total)&&delivered.filter(v=>v.kind==='floating'&&v.rich.text==='3'&&v.options.enabled===enabled&&v.options.total===total).length===(enabled?1:0);
 });
}
function cameraIntegrationComplete(report){
 const t=report.cameraTest,angle=v=>Math.abs(((v+180)%360+360)%360-180);
 if(!integrationComplete('text',report)||!t?.completed||!t.userConfigUnchanged||t.checks?.length<23||!t.checks.every(v=>v.passed)||t.modes?.length!==3||t.transitions?.length!==2||report.nativeLoaded?.length!==3||report.areas?.map(v=>v.area).join(',')!=='dense_a,dense_b,dense_a'||report.rejectedCommands?.length||!report.presentations.every(v=>v.cleanup?.alive===0)||report.retiredParticleInputs?.filter(v=>v.sequence===987654).length!==2)return false;
 return [1,0,2].every((mode,index)=>{const m=t.modes[index];return m.requested===mode&&m.selected===mode&&m.after.mode===mode&&m.before.mode===mode&&(mode===1?m.before.yaw===m.after.yaw:angle(m.facing-m.after.yaw)<=angle(m.facing-m.before.yaw)+0.0001);})&&t.transitions.every(v=>v.pose.mode===1&&['mode','yaw','pitch','distance'].every(k=>v.pose[k]===v.expected[k]));
}
function cameraCommandIntegrationComplete(report){
 const t=report.cameraCommandTest,near=(a,b)=>Number.isFinite(a)&&Math.abs(a-b)<0.001,names=['setup','store','snap','restore','lock','unlock','flags','clear','transition','attach','self','height','store','restore','reset'];
 if(!integrationComplete('text',report)||report.rejectedCommands?.length||!t?.completed||!t.userConfigUnchanged||t.checks?.length<39||!t.checks.every(v=>v.passed)||t.phases?.map(v=>v.name).join(',')!==names.join(',')||!t.phases.every(v=>v.received)||t.transitions?.length!==2||report.nativeLoaded.length!==3||report.areas?.map(v=>v.area).join(',')!=='dense_a,dense_b,dense_a'||!report.presentations.every(v=>v.cleanup?.alive===0))return false;
 const p=t.phases,s=p[0].state,restore=p[3].state,last=p[13].state,saved=p[12].state.savedCamera;
 if(!near(s.yaw,45)||!near(s.distance,12)||!near(s.pitch,55)||s.height!==3||!near(p[2].state.yaw,160)||!near(restore.yaw,45)||restore.savedCamera!==null||p[6].state.flags!==112||p[7].state.flags!==0||p[9].state.target<0||p[10].state.target!==-1||!saved||last.savedCamera!==null||!near(last.yaw,saved.yaw)||!t.transitions.every(v=>JSON.stringify(v.saved)===JSON.stringify(saved)&&JSON.stringify(v.limits)===JSON.stringify(p[12].state.limits)))return false;
 return ['camera-mode','camera-location','camera-store','camera-restore','camera-height','camera-limits','camera-lock','camera-flags','camera-attach'].every(kind=>report.cameraServerCommands?.some(v=>v.kind===kind));
}
function nwsyncIntegrationComplete(report){
	if(report.nwsyncCancelRequired){const t=report.nwsyncCancelTest;return Boolean(t?.completed&&t.userConfigUnchanged&&t.checks?.length===8&&t.checks.every(v=>v.passed)&&t.progress?.some(v=>v.completed>0&&v.completed<v.total)&&t.downloadScreenshot&&report.nativeLoaded?.length===0&&report.characterReads?.length===0&&!report.commands?.some(v=>v.kind==='lobby-play')&&report.commands?.some(v=>v.kind==='lobby-cancel-join')&&!report.rejectedCommands?.length&&!report.rendererErrors?.length&&(report.nativeExit===undefined||report.nativeExit===0)&&!/SCRIPT ERROR|(?:^|\n)ERROR:|leaked/.test(report.nativeErrors??''));}
 const t=report.nwsyncTest,resources=report.nwsyncResources??[],progress=report.nwsyncProgress??[];
 return Boolean(integrationComplete('text',report)&&!report.rejectedCommands?.length&&report.nativeLoaded.length===1&&t?.completed&&t.userConfigUnchanged&&t.checks?.length===10&&t.checks.every(v=>v.passed)&&t.progress?.length&&t.progress.every(v=>!v.canPlay&&v.canCancel)&&(!t.cold||t.downloadScreenshot)&&report.nwsyncFixture?.reuseInstalledNWSync===false&&report.nwsyncAdvertisement?.hash===report.nwsyncFixture?.hash&&resources.length===13&&resources.every(v=>v.match&&v.hash===v.expected&&v.size>0)&&[0,1,2].every(a=>resources.some(v=>v.algorithm===a))&&progress.some(v=>v.phase==='server-content'&&v.completed===13&&v.total===13));
}
module.exports={integrationComplete,nuiIntegrationComplete,buffIntegrationComplete,partyIntegrationComplete,frontendExitComplete,feedbackIntegrationComplete,cameraIntegrationComplete,cameraCommandIntegrationComplete,nwsyncIntegrationComplete};
