import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { DDSLoader } from 'three/addons/loaders/DDSLoader.js';
import { TGALoader } from 'three/addons/loaders/TGALoader.js';
import { parseModel } from './model_parser.js';
import { deformSkinnedVertices } from './model_skinning.js';
import { createModelHierarchy } from './model_hierarchy.js';
import { inheritAnimations } from './mdl_animation.js';
import { ModelAnimator } from './model_animation.js';
import {CreatureAnimationPresentation} from './creature_animation_presentation.js';
import {totalAttackDamage} from './combat_attack_data.js';
import {attackResultDoesDamage} from './combat_strike.js';
import { modelMaterialOptions } from './model_material.js';
import { parseGff } from './gff.js';
import { groupFacesByMaterial } from './mdl_mesh.js';
import { parseBioWareDds } from './bioware_dds.js';
import { decodeBioWarePlt, PLT_PALETTE_NAMES } from './bioware_plt.js';
import { sampleEmitterParticle } from './particle_preview.js';
import { loadAreaWalkmesh, parseAreaModule } from './area.js';
import { ResourceResolver, RESOURCE_TYPE } from './resource_archive.js';
import { findWalkableHeight, moveOnWalkmesh } from './walkmesh.js';
import { activeObjectCollisions, doorCollision, loadAreaCollisions, nearestDoor } from './door.js';
import { animateDoorState } from './door_animation.js';
import { createDoorUseHandler, doorUsePoints } from './door_use.js';
import { WorldObjects } from './world_objects.js';
import { ModuleSession } from './module_session.js';
import { horizontalInRange, placeableUsePoint, placeableUseRange } from './interaction_range.js';
import { resolveJumpSpawn } from './transition_spawn.js';
import { ActionQueue } from './action_queue.js';
import { WalkmeshNavigator } from './navigation.js';
import { pickedWorldObject, pointerRay } from './world_picking.js';
import { buildRadialActions, buildGroundRadialActions, radialActionRequest } from './radial_actions.js';
import { RadialMenu } from './radial_menu.js';
import { GameUi } from './game_ui.js';
import { CharacterFrontend } from './character_frontend.js';
import { parseCharacter,resolvePlayerModels } from './character.js';
import { GameAudio } from './game_audio.js';
import { runtimeDiagnostics } from './runtime_diagnostics.js';
import { installDiagnosticReporting } from './diagnostic_reporting.js';
import './style.css';

let diagnosticContext = {};
let moduleLoadBusy = false;
runtimeDiagnostics.context = () => diagnosticContext;
installDiagnosticReporting();
runtimeDiagnostics.record('session.started', 'Runtime diagnostic recording started', {}, 'info');

const canvas = document.querySelector('#model-canvas');
const viewport = document.querySelector('#viewport-frame');
const fileInput = document.querySelector('#model-file');
const openButton = document.querySelector('#open-button');
const areaButton = document.querySelector('#open-area-button');
const areaInput = document.querySelector('#area-file');
const gameDataButton = document.querySelector('#game-data-button');
const gameDataInput = document.querySelector('#game-data-folder');
const hakDataButton = document.querySelector('#hak-data-button');
const hakDataInput = document.querySelector('#hak-data-folder');
const areaSelect = document.querySelector('#area-select');
const wireButton = document.querySelector('#wireframe-button');
const previewEffectsEnabled = document.querySelector('#preview-effects-enabled');
const previewSunEnabled = document.querySelector('#preview-sun-enabled');
const previewSunIntensity = document.querySelector('#preview-sun-intensity');
const previewSunValue = document.querySelector('#preview-sun-value');
const previewSunDirection = document.querySelector('#preview-sun-direction');
const statusText = document.querySelector('#status-text');
const statusLight = document.querySelector('#connection-light');
const emptyState = document.querySelector('#empty-state');
const animationObjectSelect = document.querySelector('#animation-object');
const animationClipSelect = document.querySelector('#animation-clip');
const animationPlay = document.querySelector('#animation-play');
const animationPanel = document.querySelector('#animation-panel');
const animationSummary = document.querySelector('#animation-summary');
const animationTime = document.querySelector('#animation-time');
const animationFocus = document.querySelector('#animation-focus');
const animationIsolate = document.querySelector('#animation-isolate');
const isolatedVisibility = new Map();
const animationToolsEnabled = document.querySelector('#animation-tools-enabled');
let worldObjects = null;
let actionQueue = null;
let hoveredObject = null;
let selectedWorldObject = null;
let pendingSpellTarget = null;
let activeAnimations = [];
const movementHud = document.querySelector('#movement-hud');
const doorAction = document.querySelector('#door-action');
const doorFeedback = document.querySelector('#door-feedback');
let moduleSession = null;
let gameAudio = null;
let creatureAnimations=null;
let dynamicCreatureSync=null;
const unlockAudio = () => { void gameAudio?.unlock(); };
window.addEventListener('pointerdown', unlockAudio, { capture: true });
window.addEventListener('keydown', unlockAudio, { capture: true });
let selectedCharacter = null;
const characterInput = document.querySelector('#character-file');
document.querySelector('#release-test-cutscene').addEventListener('click', () => {
  if (!moduleSession?.player.cutscene?.enabled) return;
  moduleSession.setCutscene(moduleSession.player.id, 0, false);
  gameUi.message('Testing: cutscene mode released manually.', 'system');
  if (playerController) focusPlayer(playerController.object);
});

const scene = new THREE.Scene();
const NWN_POINT_LIGHT_ATTENUATION = 9;
scene.background = new THREE.Color('#19211e');
const camera = new THREE.PerspectiveCamera(42, 1, 0.01, 1000);
camera.position.set(3, 2.5, 3);
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: false });
renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.NoToneMapping;
renderer.toneMappingExposure = 1;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;

const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.dampingFactor = 0.08;
controls.target.set(0, 0.5, 0);

const sceneLighting = new THREE.Group();
scene.add(sceneLighting);
const previewLighting = new THREE.Group();
scene.add(previewLighting);
const previewSun = new THREE.DirectionalLight(0xffffff, 1);
previewSun.name = 'Manual preview sun';
previewSun.visible = false;
previewSun.castShadow = false;
previewLighting.add(previewSun, previewSun.target);

const grid = new THREE.GridHelper(10, 20, 0x638279, 0x344840);
grid.material.transparent = true;
grid.material.opacity = 0.5;
scene.add(grid);
const axes = new THREE.AxesHelper(0.7);
scene.add(axes);

let loadedRoot = null;
let loadedTextures = [];
let gameDataFiles = [];
let gameDataResolver = null;
let moduleHakFiles = [];
let activeAreaResolver = null;
let wireframe = false;

previewSunEnabled.addEventListener('change', updatePreviewSun);
previewSunIntensity.addEventListener('input', updatePreviewSun);
previewSunDirection.addEventListener('change', updatePreviewSun);
previewEffectsEnabled.addEventListener('change', () => updateEmitterPreviewVisibility(loadedRoot));
updatePreviewSun();

function resizeRenderer() {
  const bounds = viewport.getBoundingClientRect();
  if (!bounds.width || !bounds.height) return;
  renderer.setSize(bounds.width, bounds.height, false);
  camera.aspect = bounds.width / bounds.height;
  camera.updateProjectionMatrix();
}

new ResizeObserver(resizeRenderer).observe(viewport);
window.addEventListener('resize', resizeRenderer);
resizeRenderer();

const effectClock = new THREE.Clock();
renderer.setAnimationLoop(() => {
  const delta = effectClock.getDelta();
  const simulationReady = !moduleSession?.scheduler.pumping;
  if (simulationReady) {
    dynamicCreatureSync?.();
    if (playerController?.actor) playerController.position = playerController.actor.position;
    try { worldObjects?.syncCreaturePositions((actor, shift) => {
    if (actor !== playerController?.actor) return;
    playerController.position = actor.position;
    if (cameraFollowsPlayer) { const deltaPosition = new THREE.Vector3(...shift); controls.target.add(deltaPosition); camera.position.add(deltaPosition); }
    }); } catch (error) { if (moduleSession) moduleSession.report(error, { operation: 'creature-render-position' }); else runtimeDiagnostics.error(error); }
  }
  controls.update();
  updateScriptCamera(delta);
  if (simulationReady && !moduleLoadBusy && !gameUi.externalCapture && !moduleSession?.transitioning && !moduleSession?.player.cutscene?.enabled && !moduleSession?.conversation.state) updatePlayerMovement(delta);
  if (simulationReady && !moduleLoadBusy && !gameUi.externalCapture && !document.hidden && !moduleSession?.transitioning && (!moduleSession?.player.cutscene?.enabled || moduleSession.player.cutscene.leftClicks) && !moduleSession?.conversation.state) actionQueue?.update(Math.min(delta, 0.05));
  if (!document.hidden && worldObjects && moduleSession && !moduleSession.transitioning && !gameUi.externalCapture && !moduleLoadBusy) {
    if (simulationReady) moduleSession.scheduler.advance(Math.min(delta, 0.1) * 1000);
    gameAudio?.update();
    void moduleSession.scheduler.pump().catch(error => moduleSession.report(error));
  }
  if (!document.hidden&&simulationReady){creatureAnimations?.update();if(creatureAnimations)canvas.dataset.creatureAnimations=JSON.stringify(creatureAnimations.snapshot());}
  if (!document.hidden) for (const animator of activeAnimations) if(!animator.presentationOwned||animator.presentationPreview)animator.update(Math.min(delta, 0.1));
  updateAnimationPlaybackStatus();
  updateDoorTarget();
  updateGameplayDiagnostics();
  if (simulationReady) gameUi.refresh();
  if (loadedRoot && previewEffectsEnabled.checked) updateEmitterPreviews(loadedRoot, effectClock.elapsedTime);
  renderer.render(scene, camera);
});

const movementKeys = new Set();
let playerController = null;
let cameraFollowsPlayer = false;
const radialIconCache = new Map();
const radialMenu = new RadialMenu(viewport,{
  onVisibility: visible => { controls.enabled = !visible && !gameUi?.captured && !moduleSession?.player.cutscene?.enabled; movementKeys.clear(); pointerPress = null; },
  loadIcon: name => {
    const resolver = activeAreaResolver ?? gameDataResolver;
    if (!resolver) return Promise.resolve(null);
    if (!radialIconCache.has(name)) radialIconCache.set(name,(async () => {
      try {
        const image = new TGALoader().parse(await resolver.getResource(name.toLowerCase(),RESOURCE_TYPE.TGA));
        const icon = document.createElement('canvas'); icon.width = image.width; icon.height = image.height;
        icon.getContext('2d').putImageData(new ImageData(new Uint8ClampedArray(image.data),image.width,image.height),0,0);
        return icon.toDataURL();
      } catch (error) { runtimeDiagnostics.error(error, 'ui.radial-icon-unavailable', { resRef: name }); return null; }
    })());
    return radialIconCache.get(name);
  },
  onAction: (entry,context) => {
    if(entry.action==='quickbar.assign'){gameUi.assignQuickbar(context.quickbarIndex,entry.binding);return;}
    if (moduleSession?.player.cutscene?.enabled || moduleSession?.conversation.state) return;
    const target = worldObjects?.get(context.targetId), actor = playerController?.actor;
    if (!target || !actor || target.areaId !== actor.areaId) { doorFeedback.textContent = 'Radial target is no longer in this area'; return; }
    const request = radialActionRequest(entry,target,actor,context.groundPoint);
    canvas.dataset.lastRadialAction = JSON.stringify(request);
    if (entry.action === 'door.toggle' && target.kind === 'door') {
      actionQueue?.request(target.id,target.animationState === 0 ? 'open' : 'close');
      return;
    }
    if (entry.action === 'object.examine') { gameUi.examineId = target.id; gameUi.open('examine'); return; }
    if (entry.action === 'conversation.start') { actionQueue?.request(target.id, 'talk'); return; }
    if (entry.action === 'placeable.use') { actionQueue?.request(target.id, 'use'); return; }
    if (entry.action === 'combat.attack' && target.id !== actor.id) {
      actionQueue?.cancel(); movementKeys.clear();
      const session = moduleSession;
      void session.queuePlayerAttack(target.id).then(accepted => {
        if (moduleSession !== session) return;
        doorFeedback.textContent = accepted ? `Attack requested: ${target.name || target.tag || target.id}` : 'Attack input was rejected';
      }).catch(error => { session.report(error, { ...session.diagnosticContext(actor.id), targetId: target.id, operation: 'radial-attack' }); });
      return;
    }
    runtimeDiagnostics.record('ui.radial-action-unimplemented', `${entry.label}: ${entry.system ?? 'this system'} is not implemented`, request);
    console.info('[Radial placeholder]',request);
    doorFeedback.textContent = `${entry.label}: ${entry.system ?? 'this system'} is not implemented`;
  }
});
const gameUi = new GameUi(viewport, {
  getSession: () => moduleSession,
  getWorld: () => ({ triangles: playerController?.triangles ?? [], objects: worldObjects }),
  getSelected: () => selectedWorldObject,
  radialActive: () => radialMenu.active,
  hasPendingAction: () => Boolean(actionQueue?.current||moduleSession?.player.objectActionState?.list.count),
  onCancelAction: () => {actionQueue?.cancel();void moduleSession?.queuePlayerClearActions().catch(error=>moduleSession?.report(error));},
  onInputCapture: captured => { if (captured) radialMenu.close(); controls.enabled = !captured && !radialMenu.active && !moduleSession?.player.cutscene?.enabled; movementKeys.clear(); pointerPress = null; },
  onOpenModule: () => areaInput.click(),
  onSettings: settings => { if (settings.wireframe !== wireframe) wireButton.click(); },
  onQuickbarMenu:(menu,index,event)=>radialMenu.open(menu,event.clientX,event.clientY,{targetId:moduleSession.player.id,quickbarIndex:index}),
  onRequest: request => {
    if(request.action==='spell.cast'){beginSpellCast(request);return;}
    if (request.action === 'character.load' || request.action === 'character.create') { void openCharacters(request.action === 'character.create'); return; }
    if(request.action==='action.queue.cancel'){
      const session=moduleSession;if(!session)return;
      void session.queuePlayerCancelAction(request.actionId,request.groupId).catch(error=>session.report(error,{operation:'ui-queue-cancel'}));return;
    }
    if (request.action === 'door.use') {
      if (worldObjects?.get(request.targetId)?.areaId !== moduleSession?.player.areaId) { gameUi.notify('That object is in another area'); return; }
      actionQueue?.use(request.targetId); return;
    }
    if (request.action === 'conversation.start') { actionQueue?.request(request.targetId, 'talk'); return; }
    if (request.action === 'conversation.reply' || request.action === 'conversation.close') {
      moduleSession.scheduler.enqueue(moduleSession.player.id, request.action === 'conversation.reply'
        ? { type: 'dialogReply', ordinal: request.ordinal, version: request.version }
        : { type: 'dialogClose', aborted: request.aborted, version: request.version }); return;
    }
    runtimeDiagnostics.record('ui.action-unimplemented', `${request.action}: not implemented`, request);
    console.info('[UI placeholder]', request);
    gameUi.message(`${request.action}: not implemented`, 'system');
  }
});

function cancelSpellTarget(){pendingSpellTarget=null;delete canvas.dataset.spellTarget;canvas.style.cursor='';}
function submitSpellCast(request,targetId,position,location){
  const session=moduleSession;if(!session)return;
  cancelSpellTarget();movementKeys.clear();actionQueue?.cancel();
  void session.queuePlayerCastSpell({...request,targetId,position,location}).then(accepted=>{
    if(moduleSession!==session)return;
    gameUi.message(accepted?'Spell queued':'Spell request rejected','system');
  }).catch(error=>session.report(error,{...session.diagnosticContext(request.actorId),spellId:request.spellId,operation:'ui-spell-cast'}));
}
function beginSpellCast(request){
  const session=moduleSession;if(!session)return;
  const spell=session.spellBook.castingSpell(request.spellId);if(!spell){gameUi.notify('Spell unavailable');return;}
  if(request.actorId!==session.player.id||request.areaId!==session.player.areaId)return;
  gameUi.closeAll();radialMenu.close();
  const cast={...request,classIndex:request.classIndex,metamagic:request.metamagic??0,domainLevel:request.domainLevel??0};
  if(spell.targetType===1){submitSpellCast(cast,session.player.id,[0,0,0],0);return;}
  pendingSpellTarget={session,request:cast};canvas.dataset.spellTarget=String(spell.id);canvas.style.cursor='crosshair';
  gameUi.notify('Choose a spell target · Escape or right-click to cancel');
}

const characterFrontend = new CharacterFrontend(viewport, {
  text: () => gameUi.text,
  onCapture: captured => { gameUi.externalCapture = captured; controls.enabled = !captured && !gameUi.captured; movementKeys.clear(); pointerPress = null; radialMenu.close(); },
  onSelected: entry => { selectedCharacter = entry; },
  onPreview: (draft,rules) => renderCharacterCreationPreview(draft,rules)
});
async function openCharacters(create = false) {
  if (characterFrontend.active) return;
  const resolver = activeAreaResolver ?? gameDataResolver;
  if (!resolver) { setStatus('SELECT GAME DATA FOLDER FIRST', false); gameDataInput.click(); return; }
  const previousMode = document.body.classList.contains('game-mode');
  gameUi.closeAll(); gameUi.mode(true);
  const entry = await characterFrontend.choose(resolver, { files: gameDataFiles.filter(f=>/\.bic$/i.test(f.name)), selected: selectedCharacter, create });
  if (entry) setStatus('CHARACTER READY · OPEN A NEW MODULE',true);
  if (!moduleSession && entry) await gameUi.attachFrontend(gameDataResolver); else gameUi.mode(previousMode);
}
document.querySelector('#character-data-button').addEventListener('click', () => { void openCharacters(); });
characterInput.addEventListener('change', async event => {
  const file = event.target.files?.[0]; if (!file) return;
  try {
    const bytes = await file.arrayBuffer();
    // Validate before retaining the selection or changing the current session.
    parseCharacter(bytes);
    selectedCharacter = await characterFrontend.vault.add(bytes,file.name,{persist:true});
    if (characterFrontend.active) { characterFrontend.selected = selectedCharacter; characterFrontend.render(); }
    setStatus('CHARACTER READY · OPEN A MODULE', true);
  } catch (error) { console.warn('[Character load]', error); gameUi.notify(error.message); setStatus('CHARACTER LOAD FAILED', false); }
  finally { characterInput.value = ''; }
});
document.querySelector('#game-mode-button').addEventListener('click', () => {
  if (!moduleSession && gameDataResolver) { void gameUi.attachFrontend(gameDataResolver); return; }
  if (!gameDataResolver) { gameDataInput.click(); return; }
  gameUi.mode(!document.body.classList.contains('game-mode'));
});
document.querySelector('#language-data-button').addEventListener('click', () => document.querySelector('#language-data-folder').click());
document.querySelector('#language-data-folder').addEventListener('change', async event => {
  try { await gameUi.loadLanguage(event.target.files); setStatus('LANGUAGE DATA READY', true); }
  catch (error) { showLoadError('Language data could not be loaded', error); }
});
window.addEventListener('keydown', (event) => {
  if(event.key==='Escape'&&pendingSpellTarget){event.preventDefault();cancelSpellTarget();return;}
  if (event.target instanceof HTMLElement && ['INPUT', 'SELECT', 'TEXTAREA'].includes(event.target.tagName)) return;
  const key = event.key.toLowerCase();
  if (gameUi.captured || moduleSession?.player.cutscene?.enabled || moduleSession?.conversation.state) return;
  if (key === 'escape') { actionQueue?.cancel();void moduleSession?.queuePlayerClearActions().catch(error=>moduleSession?.report(error));return; }
  if (key === 'f' && playerController) { event.preventDefault(); focusPlayer(playerController.object); return; }
  if (key === 'e' && playerController) {
    event.preventDefault();
    if (!event.repeat) interactWithDoor();
    return;
  }
  if (!['w', 'a', 's', 'd', 'arrowup', 'arrowleft', 'arrowdown', 'arrowright'].includes(key)) return;
  event.preventDefault();
  actionQueue?.cancel('Movement cancelled the queued action');
  if(movementKeys.size===0&&!event.repeat)void moduleSession?.queuePlayerClearActions().catch(error=>moduleSession?.report(error));
  movementKeys.add(key);
});
window.addEventListener('keyup', (event) => movementKeys.delete(event.key.toLowerCase()));
window.addEventListener('blur', () => movementKeys.clear());
document.addEventListener('visibilitychange', () => movementKeys.clear());
document.addEventListener('focusin', (event) => {
  if (['INPUT', 'SELECT', 'TEXTAREA', 'BUTTON'].includes(event.target.tagName)) movementKeys.clear();
});
doorAction.addEventListener('click', () => interactWithDoor());
const playerActions = document.querySelector('#player-actions');
const openPlayerActions = (x,y) => {
  if (moduleSession?.player.cutscene?.enabled || moduleSession?.conversation.state || gameUi.captured) return;
  const actor = playerController?.actor;
  if (!actor) return;
  radialMenu.open(buildRadialActions(actor,actor),x,y,{targetId:actor.id,groundPoint:null});
};
playerActions.addEventListener('click',() => {
  const bounds = playerActions.getBoundingClientRect();
  openPlayerActions(bounds.left+bounds.width/2,bounds.top+bounds.height/2);
  radialMenu.clickMode = true;
});
playerActions.addEventListener('pointerdown',event => {
  if (event.button !== 2) return;
  event.preventDefault(); openPlayerActions(event.clientX,event.clientY);
});
playerActions.addEventListener('contextmenu',event => event.preventDefault());
let pointerPress = null;
canvas.addEventListener('pointerdown', event => {
  if (gameUi.captured) return;
  if (event.button === 0 && playerController) pointerPress = { id: event.pointerId, x: event.clientX, y: event.clientY };
});
canvas.addEventListener('contextmenu',event => { if (worldObjects) event.preventDefault(); });
canvas.addEventListener('pointerdown',event => {
  if(event.button===2&&pendingSpellTarget){event.preventDefault();event.stopImmediatePropagation();cancelSpellTarget();return;}
  if (gameUi.captured || moduleSession?.conversation.state || moduleSession?.player.cutscene?.enabled) return;
  if (event.button !== 2 || !worldObjects || !playerController?.actor) return;
  event.preventDefault(); event.stopImmediatePropagation();
  const hit = pickedWorldObject(pointerRay(event.clientX,event.clientY,canvas.getBoundingClientRect(),camera),loadedRoot,worldObjects,{includePlayer:true});
  const target = hit?.object ?? playerController.actor;
  selectedWorldObject = hit?.object ?? null;
  const menu = hit?.object ? buildRadialActions(target,playerController.actor) : buildGroundRadialActions(playerController.actor);
  radialMenu.open(menu,event.clientX,event.clientY,
    { targetId:target.id,groundPoint:hit?.point.toArray() ?? null });
},true);
canvas.addEventListener('pointermove', event => {
  if (!worldObjects || !playerController || radialMenu.active || gameUi.captured) return;
  const hit = pickedWorldObject(pointerRay(event.clientX, event.clientY, canvas.getBoundingClientRect(), camera), loadedRoot, worldObjects);
  hoveredObject = hit?.object ?? null;
  canvas.style.cursor = pendingSpellTarget?'crosshair':hoveredObject?.kind === 'door' ? 'pointer' : 'grab';
  canvas.title = hoveredObject ? `${hoveredObject.tag || hoveredObject.kind}${hoveredObject.kind === 'door' ? ' · click to use' : ''}` : '';
});
canvas.addEventListener('pointerleave', () => { hoveredObject = null; canvas.style.cursor = ''; });
canvas.addEventListener('pointercancel', () => { pointerPress = null; });
canvas.addEventListener('pointerup', event => {
  if (gameUi.captured || moduleSession?.conversation.state || moduleSession?.player.cutscene?.enabled && !moduleSession.player.cutscene.leftClicks) { pointerPress = null; return; }
  const press = pointerPress; pointerPress = null;
  if (!press || event.button !== 0 || press.id !== event.pointerId || Math.hypot(event.clientX - press.x, event.clientY - press.y) > 5 || !worldObjects) return;
  if(pendingSpellTarget){
    const pending=pendingSpellTarget;
    if(pending.session!==moduleSession||pending.request.areaId!==moduleSession.player.areaId){cancelSpellTarget();return;}
    const hit=pickedWorldObject(pointerRay(event.clientX,event.clientY,canvas.getBoundingClientRect(),camera),loadedRoot,worldObjects,{includePlayer:true});
    if(!hit)return;
    const spell=moduleSession.spellBook.castingSpell(pending.request.spellId),target=hit.object;
    const mask=target?.id===moduleSession.player.id?1:({5:2,6:8,10:16,9:32})[target?.objectType];
    if(target&&mask&&(spell.targetType&mask)){submitSpellCast(pending.request,target.id,[0,0,0],0);return;}
    if(!target&&(spell.targetType&4)){const point=hit.point.toArray();submitSpellCast(pending.request,0x7f000000,[point[0],-point[2],point[1]],1);return;}
    gameUi.notify('That is not a valid target for this spell');return;
  }
  const hit = pickedWorldObject(pointerRay(event.clientX, event.clientY, canvas.getBoundingClientRect(), camera), loadedRoot, worldObjects);
  if (!hit?.object) return;
  selectedWorldObject = hit.object;
  movementKeys.clear();
  animationIsolate.checked = false; updateAnimationIsolation();
  actionQueue?.use(hit.object.id);
});

openButton.addEventListener('click', () => fileInput.click());
fileInput.addEventListener('change', async (event) => {
  const files = [...(event.target.files || [])];
  const file = files.find((item) => item.name.toLowerCase().endsWith('.mdl'));
  if (!file) {
    setStatus('SELECT AN MDL FILE', false);
    return;
  }
  gameUi.detach(); gameUi.mode(false); moduleSession?.cancelPendingPlayerInputs(); moduleSession = null;
  diagnosticContext = { modelFile: file.name };
  gameAudio?.dispose(); gameAudio = null;
  try {
    setStatus('PARSING MODEL', false);
    const [parsed, textures] = await Promise.all([
      file.arrayBuffer().then(parseModel),
      loadTextures(files.filter((item) => item.name.toLowerCase().endsWith('.tga')))
    ]);
    const sources = new Map([[parsed.modelName.toLowerCase(), parsed]]);
    const modelFiles = new Map(files.filter(item => /\.mdl$/i.test(item.name)).map(item => [item.name.replace(/\.mdl$/i, '').toLowerCase(), item]));
    try {
      await inheritAnimations(parsed, async name => {
        if (!sources.has(name)) {
          const source = modelFiles.get(name);
          const resolver = activeAreaResolver ?? gameDataResolver;
          if (!source && !resolver) throw new Error(`Supermodel ${name} unavailable; select its MDL with this model or choose Game Data.`);
          sources.set(name, parseModel(source ? await source.arrayBuffer() : await resolver.getResource(name, RESOURCE_TYPE.MDL)));
        }
        return sources.get(name);
      });
    } catch (error) { runtimeDiagnostics.error(error, 'animation.supermodel-unavailable', { model: parsed.modelName }); parsed.unsupportedAnimations.push(error.message); }
    const object = buildObject(parsed, textures);
    setLoadedScene(object, textures);
    const animator = createModelAnimator(parsed, object, parsed.modelName, activeAnimations);
    animationToolsEnabled.checked = true;
    configureAnimationPanel();
    setStandaloneLighting(object);
    frameObject(object);
    updateInspector(parsed, file.name, textures);
    emptyState.classList.add('hidden');
    setStatus(animator?.playing ? 'ANIMATED MODEL' : parsed.hasSkinnedMeshes
      ? (hasStaticSkinMapping(parsed) ? 'STATIC SKINNED POSE' : 'STATIC SKIN PREVIEW')
      : 'MODEL RENDERED', true);
  } catch (error) {
    console.error(error);
    emptyState.querySelector('strong').textContent = 'Model could not be loaded';
    emptyState.querySelector('span').textContent = error.message || 'Check the selected file.';
    emptyState.classList.remove('hidden');
    setStatus('MODEL LOAD FAILED', false);
  } finally {
    fileInput.value = '';
  }
});

gameDataButton.addEventListener('click', () => gameDataInput.click());
gameDataInput.addEventListener('change', async (event) => {
  const files = [...(event.target.files || [])];
  const hasKey = files.some((file) => localFilePath(file).endsWith('/nwn_base.key') || file.name.toLowerCase() === 'nwn_base.key');
  if (!hasKey) {
    runtimeDiagnostics.record('load.game-data-failed', 'Selected game data folder does not contain nwn_base.key');
    setStatus('GAME DATA FOLDER MUST INCLUDE NWN_BASE.KEY', false);
    gameDataFiles = [];
    gameDataResolver = null;
  } else {
    try {
      setStatus('INDEXING GAME DATA', false);
      gameDataResolver = await ResourceResolver.createGameData(files);
      gameDataFiles = files;
      setStatus(`GAME DATA READY · ${files.length} FILES`, true);
    } catch (error) { gameDataFiles = []; gameDataResolver = null; setStatus(error.message, false); }
  }
  gameDataInput.value = '';
});

hakDataButton.addEventListener('click', () => hakDataInput.click());
hakDataInput.addEventListener('change', (event) => {
  moduleHakFiles = [...(event.target.files || [])].filter((file) => file.name.toLowerCase().endsWith('.hak'));
  setStatus(`HAK DATA READY · ${moduleHakFiles.length} ARCHIVES`, true);
  hakDataInput.value = '';
});

areaButton.addEventListener('click', () => {
  if (gameDataFiles.length === 0) {
    setStatus('SELECT GAME DATA FOLDER FIRST', false);
    return;
  }
  areaInput.click();
});

areaInput.addEventListener('change', async (event) => {
  const moduleFile = event.target.files?.[0];
  if (!moduleFile) return;
  if (moduleLoadBusy || characterFrontend.active) { areaInput.value = ''; return; }
  moduleLoadBusy = true; areaButton.disabled = true;
  diagnosticContext = { module: moduleFile.name };
  try {
    setStatus('INDEXING MODULE', false);
    const resolver = await ResourceResolver.create(moduleFile, gameDataFiles, moduleHakFiles);
    let areaResRefs = [...new Set([
      ...resolver.module.entries.keys(),
      ...resolver.haks.flatMap((hak) => [...hak.entries.keys()])
    ].filter((key) => key.endsWith(`:${RESOURCE_TYPE.ARE}`))
      .map((key) => key.slice(0, key.lastIndexOf(':'))))];
    if (areaResRefs.length === 0) throw new Error('The module contains no ARE resources.');
    const ifoBytes = resolver.module.entries.get(`module:${RESOURCE_TYPE.IFO}`);
    const entryArea = ifoBytes ? String(parseGff(ifoBytes, 'IFO ').root.Mod_Entry_Area ?? '').toLowerCase() : '';
    const previousMode = document.body.classList.contains('game-mode');
    gameUi.closeAll(); gameUi.mode(true);
    setStatus('SELECT A CHARACTER', false);
    const chosen = await characterFrontend.choose(resolver, { files: gameDataFiles.filter(f=>/\.bic$/i.test(f.name)), selected: selectedCharacter, moduleName: moduleFile.name });
    if (!chosen) { gameUi.mode(previousMode); setStatus('MODULE LOAD CANCELLED',Boolean(moduleSession)); return; }
    selectedCharacter = chosen;
    setStatus('LOADING MODULE', false);
    activeAreaResolver = resolver;
    gameAudio?.dispose();
    gameAudio = new GameAudio(resolver, {
      getObject: id => moduleSession?.registry.get(id), getPlayer: () => moduleSession?.player,
      onState: state => { canvas.dataset.audio = JSON.stringify(state); },
      onDiagnostic: message => { console.warn('[Audio]', message); canvas.dataset.audioError = message; gameUi.message(message, 'system'); }
    });
    const previousSession = moduleSession;
    creatureAnimations?.clear();creatureAnimations=null;
    moduleSession = await new ModuleSession(resolver, {
      runStartupScripts: document.querySelector('#run-module-startup').checked,
      // Skipping opening scripts must still leave perception and combat active.
      runNativeAI: true,
      serverPvpSetting: Number(document.querySelector('#session-pvp-setting').value),
      onSound: event => gameAudio.play(event),
      onCameraMode: (actor, mode) => {
        if (actor !== moduleSession?.player) return;
        cameraFollowsPlayer = true;
        updateScriptCamera(0, true);
        if (mode !== 1) runtimeDiagnostics.record('camera.presentation-approximate', 'Chase-camera steering uses a local renderer adapter; native camera smoothing is not reconstructed', { actorId: actor.id, mode }, 'info');
      },
      onCombatMessage: event=>{
        if(moduleSession&&event.recipientId!==moduleSession.player?.id)return;
        const handled=creatureAnimations?.receive(event);
        if([5,6].includes(event.type)&&event.attack){
          const [actorId,targetId]=event.data.objects,actor=moduleSession.registry.get(actorId),target=moduleSession.registry.get(targetId),attack=event.attack;
          gameUi.message(`${actor?.name||actor?.tag||'Creature'} attacks ${target?.name||target?.tag||'target'}: ${attack.roll} + ${attack.modifier} = ${attack.roll+attack.modifier}; ${attackResultDoesDamage(attack.result)?`hit (${totalAttackDamage(attack)} damage)`:'miss or defended'}`,'combat');
          if(!handled)runtimeDiagnostics.record('combat.animation-unavailable','Combat attack has no available creature animation binding',{actorId,targetId});
        }else runtimeDiagnostics.record('combat.presentation-unimplemented','Native combat message presentation is not implemented',{messageType:event.type,recipientId:event.recipientId});
      },
      onConversation: () => { movementKeys.clear(); radialMenu.close(); gameUi.conversationChanged(); },
      onClearActions: id => { if (id === moduleSession?.player.id) actionQueue?.cancel('Actions cleared'); },
      onCutscene: (actor, enabled) => {
        if (actor !== moduleSession?.player) return;
        movementKeys.clear(); pointerPress = null; radialMenu.close();
        if (enabled) {
          actor.savedCutsceneCamera = { position: camera.position.toArray(), target: controls.target.toArray(), follows: cameraFollowsPlayer };
          actionQueue?.cancel('Cutscene mode');
        } else if (actor.savedCutsceneCamera) {
          camera.position.fromArray(actor.savedCutsceneCamera.position); controls.target.fromArray(actor.savedCutsceneCamera.target);
          cameraFollowsPlayer = actor.savedCutsceneCamera.follows; controls.update();
        }
        controls.enabled = !enabled && !gameUi.captured;
      },
      onDiagnostic: message => { console.warn('[NWScript]', message); canvas.dataset.scriptError = message; doorFeedback.textContent = message; gameUi.message(message, 'system'); },
      onMessage: message => { console.log('[NWScript message]', message); doorFeedback.textContent = message.type === 'oneLiner' ? gameUi.dialogueText(message.text, moduleSession?.registry.get(message.tokenTargetId) ?? null, message.gender) : message.text; gameUi.message(message, 'message'); },
      onDoorState: (door, previous) => {
        if (playerController?.collisions.doors.includes(door)) {
          updateDoorVisual(door, loadedRoot, previous);
          playerController.obstacles = activeObjectCollisions(playerController.collisions);
        }
      },
      onTransition: async ({ destination, actor }) => {
        const targetArea = moduleSession.registry.get(destination.areaId);
        if (!targetArea?.resRef) throw new Error('Transition target has no area');
        actionQueue?.cancel('Scripted area transition');
        radialMenu.close(); movementKeys.clear();
        areaSelect.disabled = true;
        try {
          await loadAreaScene(targetArea.resRef, resolver, { destination, actor });
          areaSelect.value = targetArea.resRef;
        } finally { areaSelect.disabled = false; }
      }
    }).initialize(areaResRefs, { character: selectedCharacter?.bytes });
    previousSession?.cancelPendingPlayerInputs();
    if (selectedCharacter) moduleSession.player.characterFile = selectedCharacter.name;
    moduleSession.quickbarProfileKey=selectedCharacter?.id??null;
    await gameUi.attach(moduleSession, resolver);
    gameUi.mode(true);
    areaResRefs = [...moduleSession.areas.keys()];
    delete canvas.dataset.scriptError;
    areaSelect.replaceChildren();
    for (const resRef of areaResRefs) {
      const option = document.createElement('option');
      option.value = resRef;
      option.textContent = resRef;
      areaSelect.append(option);
    }
    areaSelect.hidden = false;
    areaSelect.value = areaResRefs.includes(entryArea) ? entryArea : areaResRefs[0];
    await loadAreaScene(areaSelect.value, resolver);
  } catch (error) {
    console.error(error);
    showLoadError('Area could not be loaded', error);
  } finally {
    moduleLoadBusy = false; areaButton.disabled = false;
    areaInput.value = '';
  }
});

areaSelect.addEventListener('change', async () => {
  if (!activeAreaResolver || !areaSelect.value) return;
  try {
    await loadAreaScene(areaSelect.value, activeAreaResolver);
  } catch (error) {
    console.error(error);
    showLoadError('Area could not be loaded', error);
  }
});

wireButton.addEventListener('click', () => {
  wireframe = !wireframe;
  wireButton.setAttribute('aria-pressed', String(wireframe));
  wireButton.textContent = wireframe ? 'Solid' : 'Wireframe';
  loadedRoot?.traverse((object) => {
    if (object.isMesh) object.material.wireframe = wireframe;
  });
});

function setStatus(message, success) {
  statusText.textContent = message.toUpperCase();
  statusLight.style.background = success ? '#45a79a' : '#ce613b';
}

function hasStaticSkinMapping(parsed) {
  return parsed.nodes.some((node) => node.skinned &&
    node.skinData.boneConstantSlots.some((nodeIndex) => nodeIndex >= 0 && nodeIndex < parsed.nodes.length));
}

function findObjectByName(root, name) {
  const wanted = name.toLowerCase();
  let match = null;
  root.traverse((object) => {
    if (!match && object.name.toLowerCase() === wanted) match = object;
  });
  return match;
}

async function loadTextures(files, resolver = null, pltColorRows = new Map()) {
  const tgaLoader = new TGALoader();
  const ddsLoader = new DDSLoader();
  const textures = new Map();
  const paletteImages = new Map();
  const hasPltFiles = files.some((file) => file.name.toLowerCase().endsWith('.plt'));
  if (hasPltFiles && resolver) {
    for (const paletteName of PLT_PALETTE_NAMES) {
      if (paletteImages.has(paletteName)) continue;
      try {
        const image = tgaLoader.parse(await resolver.getResource(paletteName, RESOURCE_TYPE.TGA));
        paletteImages.set(paletteName, { width: image.width, height: image.height, data: image.data });
      } catch (error) {
        runtimeDiagnostics.error(error, 'texture.palette-unavailable', { resRef: paletteName });
      }
    }
  }
  for (const file of files) {
    try {
    const buffer = await file.arrayBuffer();
    let texture;
    const lowerName = file.name.toLowerCase();
    if (lowerName.endsWith('.plt')) {
      const decoded = decodeBioWarePlt(buffer, paletteImages, pltColorRows.get(file.name.replace(/\.plt$/i, '').toLowerCase()));
      texture = new THREE.DataTexture(decoded.data, decoded.width, decoded.height, THREE.RGBAFormat);
      texture.flipY = decoded.flipY;
      texture.generateMipmaps = true;
      texture.minFilter = THREE.LinearMipmapLinearFilter;
    } else if (lowerName.endsWith('.dds')) {
      const magic = buffer.byteLength >= 4 ? new DataView(buffer).getUint32(0, false) : 0;
      if (magic === 0x44445320) {
        const image = ddsLoader.parse(buffer, true);
        texture = new THREE.CompressedTexture(image.mipmaps, image.width, image.height, image.format);
        texture.minFilter = image.mipmapCount > 1 ? THREE.LinearMipmapLinearFilter : THREE.LinearFilter;
      } else {
        texture = parseBioWareDds(buffer);
      }
    } else {
      const image = tgaLoader.parse(buffer);
      texture = new THREE.DataTexture(image.data, image.width, image.height, THREE.RGBAFormat);
      texture.flipY = image.flipY;
      texture.generateMipmaps = image.generateMipmaps;
      texture.minFilter = image.minFilter;
    }
    texture.magFilter = THREE.LinearFilter;
    texture.colorSpace = THREE.SRGBColorSpace;
    texture.anisotropy = renderer.capabilities.getMaxAnisotropy();
    texture.wrapS = THREE.RepeatWrapping;
    texture.wrapT = THREE.RepeatWrapping;
    texture.updateMatrix();
    texture.needsUpdate = true;
    textures.set(file.name.replace(/\.(tga|dds|plt)$/i, '').toLowerCase(), texture);
    } catch (error) { runtimeDiagnostics.error(error, 'texture.decode-failed', { resourceFile: file.name }); throw error; }
  }
  return textures;
}

// A separate scene uses the same model hierarchy, skinning, palette decoding
// and body-part attachment as the world renderer. It allocates no game objects.
async function renderCharacterCreationPreview(draft, rules) {
  const data={Race:draft.raceId,Gender:draft.gender,Appearance_Type:Number(rules.racialtypes.orderedRows[draft.raceId].Appearance),Phenotype:draft.phenotype,Appearance_Head:draft.head,
    Color_Skin:draft.skin,Color_Hair:draft.hair,Color_Tattoo1:draft.tattoo1,Color_Tattoo2:draft.tattoo2,ArmorPart_RFoot:1};
  for(const part of ['Neck','Torso','Pelvis','LBicep','LFArm','LHand','LThigh','LShin','LFoot','RBicep','RFArm','RHand','RThigh','RShin'])data[`BodyPart_${part}`]=1;
  const clothes=rules.chargenclothes.orderedRows[draft.clothes];
  if(clothes){const armor=parseGff(await rules.creationResolver.getResource(clothes.ItemResRef,RESOURCE_TYPE.UTI),'UTI ').root;for(const[key,value]of Object.entries(armor))if(key.startsWith('ArmorPart_'))data[key.replace('ArmorPart_','BodyPart_')]=value;data.ArmorPart_RFoot=armor.ArmorPart_RFoot??1;for(const material of ['Metal1','Metal2','Cloth1','Cloth2','Leather1','Leather2'])data[`Color_${material}`]=armor[`${material}Color`]??0;}
  const appearance=resolvePlayerModels(data,rules),resolver=rules.creationResolver,parsed=new Map(),files=[],paletteRows=new Map(),partKeys=new Map();
  if(!appearance)throw new Error('Character appearance is unavailable');
  const load=async(primary,fallback)=>{if(parsed.has(primary))return primary;try{parsed.set(primary,parseModel(await resolver.getResource(primary,RESOURCE_TYPE.MDL)));return primary;}catch(error){if(error.code!=='RESOURCE_NOT_FOUND'||!fallback||primary===fallback)throw error;parsed.set(fallback,parseModel(await resolver.getResource(fallback,RESOURCE_TYPE.MDL)));return fallback;}};
  const bodyName=await load(appearance.model,appearance.fallbackModel);
  const partNames=new Map();for(const part of appearance.parts){partNames.set(part,await load(part.model,part.fallbackModel));for(const candidate of part.pltCandidates??[]){try{const bytes=await resolver.getResource(candidate,RESOURCE_TYPE.PLT),key=`${candidate}__creation_${partNames.size}`;files.push({name:`${key}.plt`,arrayBuffer:async()=>bytes});paletteRows.set(key,appearance.paletteColors);partKeys.set(part,key);break;}catch(error){if(error.code!=='RESOURCE_NOT_FOUND')throw error;}}}
  const animationSources=new Map(parsed);for(const model of parsed.values())await inheritAnimations(model,async name=>{if(!animationSources.has(name))animationSources.set(name,parseModel(await resolver.getResource(name,RESOURCE_TYPE.MDL)));return animationSources.get(name);});
  for(const name of new Set([...parsed.values()].flatMap(p=>p.materialNames))){if(!name||name.toLowerCase()==='null')continue;paletteRows.set(name,appearance.paletteColors);let found=false;for(const[ext,type]of [['tga',RESOURCE_TYPE.TGA],['dds',RESOURCE_TYPE.DDS],['plt',RESOURCE_TYPE.PLT]]){try{const bytes=await resolver.getResource(name,type);files.push({name:`${name}.${ext}`,arrayBuffer:async()=>bytes});found=true;break;}catch(error){if(error.code!=='RESOURCE_NOT_FOUND')throw error;}}if(!found)runtimeDiagnostics.record('character.preview-texture-unavailable',`Character preview texture ${name} is unavailable`,{resource:name});}
  const textures=await loadTextures(files,resolver,paletteRows),previewScene=new THREE.Scene(),previewRenderer=new THREE.WebGLRenderer({antialias:true,preserveDrawingBuffer:true}),model=buildObject(parsed.get(bodyName),textures);
  const previewAnimations=[],originalGeometries=new Set();
  try{
    for(const part of appearance.parts){const anchor=findObjectByName(model,part.node);if(!anchor)throw new Error(`Character preview anchor ${part.node} is unavailable`);const instance=buildObject(parsed.get(partNames.get(part)),textures,textures.get(partKeys.get(part)));instance.traverse(o=>{if(o.geometry)originalGeometries.add(o.geometry);});anchor.add(instance);createModelAnimator(parsed.get(partNames.get(part)),instance,'Creation part',previewAnimations);}
    model.traverse(o=>{if(o.geometry)originalGeometries.add(o.geometry);});createModelAnimator(parsed.get(bodyName),model,'Creation body',previewAnimations);
    previewScene.add(model,new THREE.HemisphereLight(0xfff1d5,0x343c4a,2));const light=new THREE.DirectionalLight(0xffffff,2);light.position.set(-2,4,-4);previewScene.add(light);
    model.updateWorldMatrix(true,true);const bounds=new THREE.Box3().setFromObject(model),center=bounds.getCenter(new THREE.Vector3()),size=bounds.getSize(new THREE.Vector3());
    const c=new THREE.PerspectiveCamera(35,300/400,.01,100);c.position.set(center.x,center.y,center.z-Math.max(size.y*1.8,size.x*2));c.lookAt(center);
    previewRenderer.setSize(300,400);previewRenderer.outputColorSpace=THREE.SRGBColorSpace;previewRenderer.setClearColor(0x080d12);previewRenderer.render(previewScene,c);return previewRenderer.domElement.toDataURL();
  }finally{originalGeometries.forEach(g=>g.dispose());model.traverse(o=>{o.geometry?.dispose();for(const material of Array.isArray(o.material)?o.material:o.material?[o.material]:[])material.dispose();});textures.forEach(t=>t.dispose());previewRenderer.dispose();previewRenderer.forceContextLoss();}
}

async function loadAreaScene(areaResRef, resolver, jump = null) {
  diagnosticContext = { module: resolver.moduleName, area: areaResRef };
  runtimeDiagnostics.record('load.area-started', `Loading area ${areaResRef}`, {}, 'info');
  setStatus('READING AREA', false);
  const area = await parseAreaModule(areaResRef, resolver);
  const sceneCreatures = [...area.creatures];
  const staticCreatureKeys=new Set(area.creatures.map((c,index)=>`${area.resRef}:creature:${c.sourceIndex??index}`));
  for(const id of moduleSession.areas.get(area.resRef)?.objects??[]){const actor=moduleSession.registry.get(id);
    if(actor?.objectType!==5||actor===moduleSession.player||staticCreatureKeys.has(actor.sourceKey))continue;
    const appearance=resolvePlayerModels(actor.creatureData,moduleSession.characterRules);
    if(appearance)sceneCreatures.push({...appearance,sourceKey:actor.sourceKey,x:actor.position[0],y:-actor.position[2],z:actor.position[1],bearing:-Math.atan2(actor.orientation[0],-actor.orientation[2])});
    else runtimeDiagnostics.record('scene.creature-appearance-unavailable','Runtime creature appearance could not be resolved',{objectId:actor.id});
  }
  if (moduleSession.player.appearance) sceneCreatures.push({ ...moduleSession.player.appearance, player: true });
  const { triangles: walkableTriangles, missing: missingWalkmeshes } = await loadAreaWalkmesh(area, resolver);
  const collisions = await loadAreaCollisions(area, resolver);
  const sessionArea = moduleSession?.areas.get(area.resRef);
  for (let index = 0; index < collisions.doors.length; index++) {
    const parsedDoor = collisions.doors[index];
    const persistent = moduleSession?.source(parsedDoor.sourceKey);
    if (!persistent) throw new Error(`Door is missing from object registry: ${parsedDoor.sourceKey}`);
    Object.assign(persistent, { model: parsedDoor.model, states: parsedDoor.states, actionPoints: parsedDoor.actionPoints, object: null, animating: false });
    collisions.doors[index] = persistent;
  }
  // Native jumping to a closed door queues a destination open action. Its
  // actor/event context still needs mapping; do not fabricate an OnOpen event.
  // Normal paired-door use mirrors the open state before its script jumps.
  if (jump?.destination.kind === 'door' && jump.destination.animationState === 0) {
    throw new Error('Scripted jump to a closed door requires the destination open action (not implemented)');
  }
  const objectWalkmeshes = activeObjectCollisions(collisions);
  const arrival = jump ? resolveJumpSpawn(jump.destination, jump.actor, walkableTriangles, collisions) : null;
  const spawn = arrival?.position ?? (sessionArea === moduleSession?.currentArea ? [...moduleSession.player.position] : findPlayerSpawn(area, resolver, walkableTriangles, objectWalkmeshes));
  if (!spawn) throw new Error('Area has no safe player spawn');
  const modelNames = [...new Set([
    ...area.tiles.map((tile) => tile.model.toLowerCase()),
    ...area.placeables.map((placeable) => placeable.model.toLowerCase()),
    ...area.doors.map((door) => door.model.toLowerCase()),
    ...sceneCreatures.flatMap((creature) => [
      creature.model,
      creature.fallbackModel,
      ...creature.parts.flatMap((part) => [part.model, part.fallbackModel])
    ].filter(Boolean).map((name) => name.toLowerCase()))
  ])];
  const parsedModels = new Map();
  const skippedModels = [];

  for (const name of modelNames) {
    try {
      parsedModels.set(name, parseModel(await resolver.getResource(name, RESOURCE_TYPE.MDL)));
    } catch (error) {
      runtimeDiagnostics.error(error, 'model.load-failed', { model: name });
      skippedModels.push({ name, reason: error.message });
    }
  }
  const animationSources = new Map(parsedModels);
  for (const parsed of parsedModels.values()) {
    try {
      await inheritAnimations(parsed, async name => {
        if (!animationSources.has(name)) animationSources.set(name, parseModel(await resolver.getResource(name, RESOURCE_TYPE.MDL)));
        return animationSources.get(name);
      });
    } catch (error) { runtimeDiagnostics.error(error, 'animation.supermodel-unavailable', { model: parsed.modelName }); parsed.unsupportedAnimations.push(error.message); }
  }
  if (parsedModels.size === 0) throw new Error('No area tile or placeable models could be parsed.');

  const bitmapNames = [...new Set([...parsedModels.values()].flatMap((parsed) => parsed.materialNames)
    .map((name) => name.toLowerCase()).filter((name) => name && name !== 'null'))];
  const textureFiles = [];
  const missingTextures = [];
  const pltColorRows = new Map();
  const partPltTextures = new Map();
  for (const [creatureIndex, creature] of sceneCreatures.entries()) {
    for (const [partIndex, part] of creature.parts.entries()) {
      for (const candidate of part.pltCandidates ?? []) {
        try {
          const buffer = await resolver.getResource(candidate, RESOURCE_TYPE.PLT);
          const textureKey = `${candidate}__creature_${creatureIndex}_${partIndex}`;
          textureFiles.push({ name: `${textureKey}.plt`, arrayBuffer: async () => buffer });
          pltColorRows.set(textureKey, creature.paletteColors);
          partPltTextures.set(part, textureKey);
          break;
        } catch {
        }
      }
      for (const modelName of [part.model, part.fallbackModel].filter(Boolean)) {
        const parsed = parsedModels.get(modelName);
        for (const bitmapName of parsed?.materialNames ?? []) {
          const key = bitmapName.toLowerCase();
          if (!pltColorRows.has(key)) pltColorRows.set(key, creature.paletteColors);
        }
      }
    }
  }
  for (const name of bitmapNames) {
    try {
      const buffer = await resolver.getResource(name, RESOURCE_TYPE.TGA);
      textureFiles.push({ name: `${name}.tga`, arrayBuffer: async () => buffer });
    } catch {
      try {
        const buffer = await resolver.getResource(name, RESOURCE_TYPE.DDS);
        textureFiles.push({ name: `${name}.dds`, arrayBuffer: async () => buffer });
      } catch {
        try {
          const buffer = await resolver.getResource(name, RESOURCE_TYPE.PLT);
          textureFiles.push({ name: `${name}.plt`, arrayBuffer: async () => buffer });
        } catch {
          missingTextures.push(name);
        }
      }
    }
  }
  const textures = await loadTextures(textureFiles, resolver, pltColorRows);
  const templates = new Map([...parsedModels].map(([name, parsed]) => [name, buildObject(parsed, textures)]));
  const creaturePartTemplates = new Map();
  const root = new THREE.Group();
  const areaObjects = new WorldObjects(sessionArea.id, moduleSession.registry);
  const areaAnimations = [];
  root.name = area.name || area.resRef;
  const addInstance = (modelName, position, rotation, label = modelName) => {
    const template = templates.get(modelName.toLowerCase());
    if (!template) return null;
    const wrapper = new THREE.Group();
    wrapper.position.set(position[0], position[1], position[2]);
    wrapper.rotation.y = rotation;
    const instance = template.clone(true);
    wrapper.add(instance);
    root.add(wrapper);
    wrapper.animator = createModelAnimator(parsedModels.get(modelName.toLowerCase()), instance, label, areaAnimations);
    return wrapper;
  };

  let renderedTiles = 0;
  for (let index = 0; index < area.tiles.length; index += 1) {
    const tile = area.tiles[index];
    const x = index % area.width;
    const y = Math.floor(index / area.width);
    if (addInstance(tile.model, [x * 10 + 5, tile.height * area.tileHeight, -(y * 10 + 5)], tile.orientation * Math.PI / 2, `Tile ${index} · ${tile.model}`)) {
      renderedTiles += 1;
    } else runtimeDiagnostics.record('scene.tile-omitted', `Tile model ${tile.model} is unavailable`, { tileIndex: index, model: tile.model });
  }

  const skippedObjects = [];
  let renderedDoors = 0;
  for (const door of collisions.doors) {
    door.object = addInstance(door.model, door.position, door.bearing, `Door · ${door.tag || door.model}`);
    door.animator = door.object?.animator;
    if (door.object) {
      const points = (door.states?.[0] ?? []).flatMap(triangle=>triangle.vertices);
      if (points.length) door.pickBounds = {
        min:[0,1,2].map(axis=>Math.min(...points.map(point=>point[axis]))-0.04),
        max:[0,1,2].map(axis=>Math.max(...points.map(point=>point[axis]))+0.04)
      };
      areaObjects.add('door', door.sourceKey, door, door.object);
      updateDoorVisual(door, root);
      renderedDoors += 1;
    } else {
      runtimeDiagnostics.record('scene.object-omitted', `Door model ${door.model} is unavailable`, { objectId: door.id, sourceKey: door.sourceKey, model: door.model, objectKind: 'door', tag: door.tag });
      skippedObjects.push(door.model);
    }
  }
  let renderedPlaceables = 0;
  for (const [index, placeable] of area.placeables.entries()) {
    const object = addInstance(placeable.model, [placeable.x, placeable.z, -placeable.y], placeable.bearing, `Placeable · ${placeable.tag || placeable.model}`);
    if (object) {
      const sourceKey = `${area.resRef}:placeable:${index}`;
      const record = moduleSession.source(sourceKey);
      record.actionPoints = collisions.placeableActionPoints.get(sourceKey);
      areaObjects.add('placeable', sourceKey, record, object);
      renderedPlaceables += 1;
    } else {
      const sourceKey = `${area.resRef}:placeable:${index}`;
      runtimeDiagnostics.record('scene.object-omitted', `Placeable model ${placeable.model} is unavailable`, { objectId: moduleSession.source(sourceKey)?.id, sourceKey, model: placeable.model, objectKind: 'placeable', tag: placeable.tag });
      skippedObjects.push(placeable.model);
    }
  }
  const skippedCreatures = [];
  let renderedCreatures = 0;
  let palettePartsApplied = 0;
  const skippedCreatureParts = [];
  let playerAssembly = null;
  creatureAnimations?.clear();
  creatureAnimations=new CreatureAnimationPresentation({object:id=>moduleSession.registry.get(id),rules:()=>moduleSession.characterRules,now:()=>moduleSession.scheduler.time,
    project:render=>{const p=render.getWorldPosition(new THREE.Vector3());p.y+=.5;p.project(camera);const r=canvas.getBoundingClientRect();return{x:r.left+(p.x+1)*r.width/2,y:r.top+(1-p.y)*r.height/2,z:p.z};},
    report:(message,context)=>runtimeDiagnostics.record('animation.native-presentation-unavailable',message,context)});
  let playerAnimator=null;
  for (const [index, creature] of sceneCreatures.entries()) {
    const template = templates.get(creature.model) ?? templates.get(creature.fallbackModel);
    if (!template) {
      const sourceKey = creature.player ? 'player' : creature.sourceKey??`${area.resRef}:creature:${creature.sourceIndex ?? index}`;
      runtimeDiagnostics.record('scene.creature-omitted', `Creature ${creature.tag || creature.model} has no available model`, { sourceKey, objectId: moduleSession.source(sourceKey)?.id, model: creature.model, fallbackModel: creature.fallbackModel });
      skippedCreatures.push(creature.tag || creature.model);
      continue;
    }
    const assembly = template.clone(true);
    if (creature.parts.length) {
      for (const part of creature.parts) {
        const partModelName = parsedModels.has(part.model) ? part.model : part.fallbackModel;
        const textureKey = partPltTextures.get(part);
        const hasPaletteTexture = Boolean(textureKey && textures.has(textureKey) && parsedModels.has(partModelName));
        let partTemplate = templates.get(partModelName);
        if (hasPaletteTexture) {
          const cacheKey = `${partModelName}:${textureKey}`;
          if (!creaturePartTemplates.has(cacheKey)) {
            creaturePartTemplates.set(cacheKey, buildObject(parsedModels.get(partModelName), textures, textures.get(textureKey)));
          }
          partTemplate = creaturePartTemplates.get(cacheKey);
        }
        const anchor = findObjectByName(assembly, part.node);
        if (!partTemplate || !anchor) {
          runtimeDiagnostics.record('scene.creature-part-omitted', !partTemplate ? 'Creature part model unavailable' : 'Creature part skeleton anchor unavailable', { creature: creature.tag || creature.model, model: part.model, anchor: part.node });
          skippedCreatureParts.push({
            creature: creature.tag || creature.model,
            model: part.model,
            anchor: part.node,
            reason: !partTemplate ? 'model unavailable' : 'skeleton anchor unavailable'
          });
          continue;
        }
        const partInstance = partTemplate.clone(true);
        anchor.add(partInstance);
        createModelAnimator(parsedModels.get(partModelName), partInstance, `Part · ${creature.tag || creature.model}/${part.node}`, areaAnimations);
        if (hasPaletteTexture) palettePartsApplied += 1;
      }
    }
    if (creature.player) {
      playerAssembly = assembly;
      playerAnimator=createModelAnimator(parsedModels.get(creature.model) ?? parsedModels.get(creature.fallbackModel), assembly, `Player · ${moduleSession.player.name}`, areaAnimations);
      continue;
    }
    const wrapper = new THREE.Group();
    wrapper.position.set(creature.x, creature.z, -creature.y);
    wrapper.rotation.y = creature.bearing;
    wrapper.add(assembly);
    root.add(wrapper);
    const sourceKey = creature.sourceKey??`${area.resRef}:creature:${creature.sourceIndex ?? index}`;
    areaObjects.add('creature', sourceKey, moduleSession.source(sourceKey), wrapper);
    const animator=createModelAnimator(parsedModels.get(creature.model) ?? parsedModels.get(creature.fallbackModel), assembly,
      `Creature · ${creature.tag || creature.model}`, areaAnimations);
    creatureAnimations.bind(moduleSession.source(sourceKey),animator,wrapper);
    renderedCreatures += 1;
  }
  if (renderedTiles === 0) throw new Error('No area tiles could be rendered.');
  root.userData.assetTemplates = [...templates.values(), ...creaturePartTemplates.values()];

  // Disposed render bindings must not live in the persistent simulation registry.
  for (const object of worldObjects?.objects.values() ?? []) {
    if (object.areaId !== sessionArea.id) {
      for (const field of ['object', 'animator', 'proxy', 'pickBounds', 'transitionCollision']) delete object[field];
      object.animating = false;
    }
  }
  setLoadedScene(root, textures);
  worldObjects = areaObjects;
  activeAnimations = areaAnimations;
  const pendingCreatures=new Set(),failedCreatures=new Set(),presentation=creatureAnimations;
  const addRuntimeCreature=async actor=>{
    const appearance=resolvePlayerModels(actor.creatureData,moduleSession.characterRules);if(!appearance)throw new Error('Runtime creature appearance is unavailable');
    const models=[appearance.model,appearance.fallbackModel,...appearance.parts.flatMap(p=>[p.model,p.fallbackModel])].filter(Boolean);
    for(const name of new Set(models))if(!parsedModels.has(name)){
      try{const model=parseModel(await resolver.getResource(name,RESOURCE_TYPE.MDL));parsedModels.set(name,model);animationSources.set(name,model);
        await inheritAnimations(model,async ref=>{if(!animationSources.has(ref))animationSources.set(ref,parseModel(await resolver.getResource(ref,RESOURCE_TYPE.MDL)));return animationSources.get(ref);});
      }catch(error){runtimeDiagnostics.error(error,'model.runtime-creature-load-failed',{objectId:actor.id,model:name});}
    }
    const files=[],paletteRows=new Map(),partTextures=new Map();
    for(const [index,part] of appearance.parts.entries())for(const candidate of part.pltCandidates??[]){
      try{const bytes=await resolver.getResource(candidate,RESOURCE_TYPE.PLT),key=`${candidate}__creature_${actor.id}_${index}`;
        files.push({name:`${key}.plt`,arrayBuffer:async()=>bytes});paletteRows.set(key,appearance.paletteColors);partTextures.set(part,key);break;
      }catch(error){if(error.code!=='RESOURCE_NOT_FOUND')throw error;}
    }
    const bitmaps=new Set(models.flatMap(name=>parsedModels.get(name)?.materialNames??[]).map(name=>name.toLowerCase()).filter(name=>name&&name!=='null'));
    for(const name of bitmaps){paletteRows.set(name,appearance.paletteColors);if(textures.has(name))continue;let loaded=false;
      for(const [extension,type] of [['tga',RESOURCE_TYPE.TGA],['dds',RESOURCE_TYPE.DDS],['plt',RESOURCE_TYPE.PLT]]){
        try{const bytes=await resolver.getResource(name,type);files.push({name:`${name}.${extension}`,arrayBuffer:async()=>bytes});loaded=true;break;}
        catch(error){if(error.code!=='RESOURCE_NOT_FOUND')throw error;}
      }
      if(!loaded)runtimeDiagnostics.record('texture.runtime-creature-unavailable',`Runtime creature bitmap ${name} is unavailable`,{objectId:actor.id,resource:name});
    }
    if(loadedRoot!==root||worldObjects!==areaObjects)return;
    const extra=await loadTextures(files,resolver,paletteRows);
    if(loadedRoot!==root||worldObjects!==areaObjects||moduleSession.registry.get(actor.id)!==actor||actor.areaId!==sessionArea.id){extra.forEach(texture=>texture.dispose());return;}
    extra.forEach((texture,key)=>{textures.set(key,texture);loadedTextures.push(texture);});
    for(const name of new Set(models))if(!templates.has(name)&&parsedModels.has(name)){const template=buildObject(parsedModels.get(name),textures);templates.set(name,template);root.userData.assetTemplates.push(template);}
    const modelName=parsedModels.has(appearance.model)?appearance.model:appearance.fallbackModel,template=templates.get(modelName);
    if(!template)throw new Error('Runtime creature body model is unavailable');
    const assembly=template.clone(true);
    for(const part of appearance.parts){const name=parsedModels.has(part.model)?part.model:part.fallbackModel,parsed=parsedModels.get(name),anchor=findObjectByName(assembly,part.node);
      if(!parsed||!anchor){runtimeDiagnostics.record('scene.runtime-creature-part-unavailable','Runtime creature part or anchor is unavailable',{objectId:actor.id,model:name,anchor:part.node});continue;}
      const textureKey=partTextures.get(part),partTemplate=textureKey&&textures.has(textureKey)?buildObject(parsed,textures,textures.get(textureKey)):templates.get(name);
      if(!partTemplate)continue;if(textureKey)root.userData.assetTemplates.push(partTemplate);
      const instance=partTemplate.clone(true);anchor.add(instance);createModelAnimator(parsed,instance,`Part · ${actor.tag}/${part.node}`,areaAnimations);
    }
    // Model/texture reads can span several simulation frames. Bind only the
    // same live canonical record in this area after all asynchronous work.
    if(moduleSession.registry.get(actor.id)!==actor||actor.areaId!==sessionArea.id)return;
    const wrapper=new THREE.Group();wrapper.position.set(...actor.position);wrapper.rotation.y=-Math.atan2(actor.orientation[0],-actor.orientation[2]);wrapper.add(assembly);root.add(wrapper);
    areaObjects.add('creature',actor.sourceKey,actor,wrapper);
    const animator=createModelAnimator(parsedModels.get(modelName),assembly,`Creature · ${actor.tag||modelName}`,areaAnimations);presentation.bind(actor,animator,wrapper);
    runtimeDiagnostics.record('scene.runtime-creature-added','Runtime creature model and animations bound',{objectId:actor.id,sourceKey:actor.sourceKey,model:modelName},'info');
    configureAnimationPanel();
  };
  dynamicCreatureSync=()=>{
    if(loadedRoot!==root||worldObjects!==areaObjects)return;
    for(const id of sessionArea.objects){const actor=moduleSession.registry.get(id);
      if(actor?.objectType!==5||actor===moduleSession.player||actor.areaId!==sessionArea.id||areaObjects.get(id)||pendingCreatures.has(id)||failedCreatures.has(id))continue;
      pendingCreatures.add(id);void addRuntimeCreature(actor).catch(error=>{failedCreatures.add(id);runtimeDiagnostics.error(error,'scene.runtime-creature-failed',{objectId:id,sourceKey:actor.sourceKey});}).finally(()=>pendingCreatures.delete(id));
    }
  };
  animationToolsEnabled.checked = false;
  configureAnimationPanel();
  const lightingMode = setAreaLighting(area.lighting, root);
  frameObject(root);
  if (spawn) {
    const player = playerAssembly ? new THREE.Group() : createPlayerPreview();
    if (playerAssembly) { playerAssembly.rotation.y = Math.PI; player.add(playerAssembly); player.name = moduleSession.player.name; }
    player.userData.characterModel = Boolean(playerAssembly);
    player.userData.worldPickingPlayer = true;
    player.position.set(...spawn);
    root.add(player);
    playerController = { object: player, position: [...spawn], triangles: walkableTriangles, obstacles: objectWalkmeshes, collisions };
    const actor = moduleSession.player;
    if (!moduleSession.started && moduleSession.ifo.Mod_Entry_Area === area.resRef) actor.bearing = -Math.atan2(moduleSession.ifo.Mod_Entry_Dir_X, moduleSession.ifo.Mod_Entry_Dir_Y);
    await moduleSession.enterArea(area.resRef, playerController.position);
    if (arrival) actor.bearing = arrival.bearing;
    player.rotation.y = Math.PI + (actor.bearing ?? 0);
    areaObjects.add('player', 'player', actor, player);
    creatureAnimations.bind(actor,playerAnimator,player);
    playerController.actor = actor;
    const navigator = new WalkmeshNavigator(walkableTriangles);
    actionQueue = new ActionQueue({
      registry: areaObjects, actor, handlers: { door: createDoorUseHandler({ radius: actor.radius }), creature: {
        actions: ['talk'], intent: () => 'talk',
        prepare: target => ({ ok: !moduleSession.isDead(target) && !moduleSession.isDying(target), message: 'That creature cannot converse', points: [target.position], range: moduleSession.talkRange(actor, target) }),
        execute: target => ({ ok: moduleSession.requestTalk(target.id), message: `Talking to ${target.name || target.tag}` }),
        settled: () => true
      }, placeable: {
        actions: ['use'], intent: () => 'use',
        prepare: target => ({ ok: Boolean(target.usable && target.scripts?.used), message: 'That object does not have an implemented use action', points: [placeableUsePoint(actor, target)], range: placeableUseRange(actor, moduleSession.appearances) }),
        execute: target => { moduleSession.scheduler.enqueue(target.id, { type: 'use', playerId: actor.id }); return { ok: true, message: `Using ${target.name || target.tag}` }; },
        settled: () => true
      } },
      navigate: points => navigator.approach(actor.position, points, playerController.obstacles),
      move: (point, delta) => movePlayerTowards(point, delta),
      face: point => {
        player.rotation.y = Math.atan2(point[0] - actor.position[0], point[2] - actor.position[2]);
        actor.bearing = player.rotation.y - Math.PI;
      },
      inRange: (target, points, range) => points.some(point => {
        if (['creature', 'placeable'].includes(target.kind) ? !horizontalInRange(actor.position, point, range) : Math.abs(point[1] - actor.position[1]) > 1.5 || Math.hypot(point[0] - actor.position[0], point[2] - actor.position[2]) > range) return false;
        const obstacles = [...collisions.placeables.filter(face => face.ownerSourceKey !== target.sourceKey), ...collisions.doors.filter(door => door !== target).flatMap(door => doorCollision(door))];
        return Boolean(moveOnWalkmesh(walkableTriangles, actor.position, point[0] - actor.position[0], point[2] - actor.position[2], 0, 0.9, obstacles));
      }),
      onStatus: message => { doorFeedback.textContent = message; gameUi.message(message, 'system'); },
      onEvent: event => {
        const door = areaObjects.get(event.targetId);
        if (event.type === 'door.stateChanged') {
          updateDoorVisual(door, loadedRoot, event.previousState);
          playerController.obstacles = activeObjectCollisions(collisions);
        }
        moduleSession.doorEvent(door, actor, event);
      }
    });
    movementHud.hidden = false;
    doorFeedback.textContent = '';
    focusPlayer(player);
  }
  updateAreaInspector(area, parsedModels, textures, {
    skippedModels,
    skippedObjects,
    missingTextures,
    renderedTiles,
    renderedDoors,
    renderedPlaceables,
    renderedCreatures,
    skippedCreatures,
    skippedCreatureParts,
    paletteParts: palettePartsApplied,
    walkableTriangles: walkableTriangles.length,
    objectCollisionTriangles: objectWalkmeshes.length,
    missingWalkmeshes,
    missingObjectWalkmeshes: collisions.missing,
    playerSpawned: Boolean(spawn),
    missingHaks: resolver.missingHaks,
    lightingMode
  });
  for (const resRef of missingTextures) runtimeDiagnostics.record('scene.texture-unavailable', `No TGA, DDS or PLT texture for ${resRef}`, { resRef });
  for (const [kind, count] of Object.entries(area.unsupported)) if (count) runtimeDiagnostics.record('scene.system-unimplemented', `${count} ${kind} unavailable or unsupported`, { kind, count });
  for (const parsed of parsedModels.values()) recordModelLimitations(parsed);
  runtimeDiagnostics.record('load.area-completed', `Area ${areaResRef} rendered`, { renderedTiles, renderedDoors, renderedPlaceables, renderedCreatures,
    missingTextures: missingTextures.length, missingWalkmeshes: missingWalkmeshes.length, missingObjectWalkmeshes: collisions.missing.length,
    skippedModels: skippedModels.length, skippedObjects: skippedObjects.length, skippedCreatures: skippedCreatures.length, skippedCreatureParts: skippedCreatureParts.length }, 'info');
  emptyState.classList.add('hidden');
  const hasOmissions = skippedModels.length || skippedObjects.length || missingTextures.length ||
    missingWalkmeshes.length || collisions.missing.length || skippedCreatures.length || skippedCreatureParts.length || resolver.missingHaks.length ||
    [...parsedModels.values()].some(model => model.unsupportedAnimations.length) ||
    Object.values(area.unsupported).some((count) => count > 0);
  setStatus(hasOmissions ? 'AREA RENDERED WITH OMISSIONS' : 'AREA RENDERED', true);
}

function clearLoadedScene() {
  dynamicCreatureSync=null;
  radialMenu.close(); radialIconCache.clear();
  actionQueue?.cancel('Area changed');
  actionQueue = null; worldObjects = null; hoveredObject = null; selectedWorldObject = null; pointerPress = null;cancelSpellTarget();
  canvas.style.cursor = ''; canvas.title = '';
  for (const key of ['worldObjects', 'actionPhase', 'selectedObject', 'hoveredObject', 'doorStates', 'actorPosition', 'lastRadialAction', 'cameraMode']) delete canvas.dataset[key];
  restoreAnimationVisibility();
  animationIsolate.checked = false;
  activeAnimations = [];
  animationPanel.hidden = true;
  playerController = null;
  cameraFollowsPlayer = false;
  movementHud.hidden = true;
  movementKeys.clear();
  if (loadedRoot) {
    scene.remove(loadedRoot);
    const geometries = new Set();
    const materials = new Set();
    const roots = [loadedRoot, ...(loadedRoot.userData.assetTemplates ?? [])];
    for (const root of roots) {
      root.traverse((child) => {
        if (child.geometry) geometries.add(child.geometry);
        if (Array.isArray(child.material)) child.material.forEach((material) => materials.add(material));
        else if (child.material) materials.add(child.material);
      });
    }
    geometries.forEach((geometry) => geometry.dispose());
    materials.forEach((material) => material.dispose());
  }
  loadedTextures.forEach((texture) => texture.dispose());
  loadedRoot = null;
  loadedTextures = [];
}

function setLoadedScene(root, textures) {
  clearLoadedScene();
  loadedRoot = root;
  loadedTextures = [...textures.values()];
  scene.add(root);
}

function setAreaLighting(lighting, object) {
  sceneLighting.clear();
  const useSun = hasLightEnergy(lighting.sunAmbientColor) || hasLightEnergy(lighting.sunDiffuseColor);
  const useMoon = hasLightEnergy(lighting.moonAmbientColor) || hasLightEnergy(lighting.moonDiffuseColor);
  const period = useSun ? 'sun' : useMoon ? 'moon' : 'unlit';
  const ambientColor = useSun ? lighting.sunAmbientColor : lighting.moonAmbientColor;
  const diffuseColor = useSun ? lighting.sunDiffuseColor : lighting.moonDiffuseColor;
  const diffuseDirection = useSun ? lighting.sunDiffuseDirection : lighting.moonDiffuseDirection;

  if (hasLightEnergy(ambientColor)) {
    sceneLighting.add(new THREE.AmbientLight(new THREE.Color().setRGB(...ambientColor, THREE.SRGBColorSpace), 1));
  }
  const hasDiffuseDirection = Array.isArray(diffuseDirection) &&
    diffuseDirection.length >= 3 && diffuseDirection.some((channel) => Math.abs(channel) > 1e-6);
  if (hasLightEnergy(diffuseColor)) {
    const bounds = new THREE.Box3().setFromObject(object);
    const center = bounds.getCenter(new THREE.Vector3());
    const size = bounds.getSize(new THREE.Vector3());
    const distance = Math.max(size.x, size.y, size.z, 1) * 2;
    const direction = hasDiffuseDirection
      ? new THREE.Vector3(diffuseDirection[0], diffuseDirection[2], -diffuseDirection[1]).normalize()
      : new THREE.Vector3(-0.35, 1, 0.45).normalize();
    const sunlight = new THREE.DirectionalLight(
      new THREE.Color().setRGB(...diffuseColor, THREE.SRGBColorSpace), 1);
    sunlight.castShadow = Number(useSun ? lighting.sunShadows : lighting.moonShadows) > 0;
    sunlight.position.copy(center).addScaledVector(direction, distance);
    sunlight.target.position.copy(center);
    configureLightShadow(sunlight, lighting.shadowOpacity);
    sunlight.shadow.camera.left = -size.x / 2;
    sunlight.shadow.camera.right = size.x / 2;
    sunlight.shadow.camera.top = size.z / 2;
    sunlight.shadow.camera.bottom = -size.z / 2;
    sunlight.shadow.camera.far = distance * 2;
    sunlight.shadow.camera.updateProjectionMatrix();
    sceneLighting.add(sunlight, sunlight.target);
  }
  object.traverse((child) => {
    if (child.isLight && child.castShadow) configureLightShadow(child, lighting.shadowOpacity);
  });
  return hasLightEnergy(diffuseColor) && !hasDiffuseDirection
    ? `${period} · default preview direction (runtime direction unavailable)`
    : period;
}

function setStandaloneLighting(object) {
  sceneLighting.clear();
  const bounds = new THREE.Box3().setFromObject(object);
  const center = bounds.getCenter(new THREE.Vector3());
  const size = bounds.getSize(new THREE.Vector3());
  const distance = Math.max(size.x, size.y, size.z, 1) * 2;
  sceneLighting.add(new THREE.HemisphereLight(0xffffff, 0x34302c, 0.55));
  const keyLight = new THREE.DirectionalLight(0xffffff, 0.75);
  keyLight.position.copy(center).add(new THREE.Vector3(-0.35, 1, 0.45).normalize().multiplyScalar(distance));
  keyLight.target.position.copy(center);
  sceneLighting.add(keyLight, keyLight.target);
}

function hasLightEnergy(color) {
  return Array.isArray(color) && color.some((channel) => channel > 0);
}

function configureLightShadow(light, opacity = 255) {
  if (!light.shadow) return;
  light.shadow.mapSize.set(512, 512);
  light.shadow.bias = -0.0002;
  light.shadow.normalBias = 0.025;
  light.shadow.intensity = Math.max(0, Math.min(1, Number(opacity) / 255));
  if (light.isPointLight) {
    light.shadow.camera.near = 0.1;
    light.shadow.camera.far = light.distance > 0 ? Math.max(light.distance, 2) : 100;
    light.shadow.camera.updateProjectionMatrix();
  }
}

function localFilePath(file) {
  return String(file.webkitRelativePath || file.name || '').replaceAll('\\', '/').toLowerCase();
}

function showLoadError(title, error) {
  emptyState.querySelector('strong').textContent = title;
  emptyState.querySelector('span').textContent = error.message || 'Check the selected files.';
  emptyState.classList.remove('hidden');
  setStatus('AREA LOAD FAILED', false);
}

function updateAreaInspector(area, parsedModels, textures, report) {
  const instances = [
    ...area.tiles.map((tile) => tile.model.toLowerCase()),
    ...area.placeables.map((placeable) => placeable.model.toLowerCase()),
    ...area.doors.map((door) => door.model.toLowerCase())
  ];
  let nodes = 0;
  let meshes = 0;
  let vertices = 0;
  let faces = 0;
  let lights = 0;
  let emitters = 0;
  const materialNames = new Set();
  for (const name of instances) {
    const parsed = parsedModels.get(name);
    if (!parsed) continue;
    nodes += parsed.nodes.length;
    const meshNodes = parsed.nodes.filter((node) => node.type === 'trimesh' && node.faces.length > 0);
    meshes += meshNodes.length;
    vertices += meshNodes.reduce((total, node) => total + node.verts.length, 0);
    faces += meshNodes.reduce((total, node) => total + node.faces.length, 0);
    lights += parsed.nodes.filter((node) => node.type === 'light').length;
    emitters += parsed.nodes.filter((node) => node.type === 'emitter').length;
    parsed.materialNames.forEach((material) => materialNames.add(material));
  }

  document.querySelector('#model-title').textContent = area.name || area.resRef;
  document.querySelector('#node-count').textContent = nodes.toLocaleString();
  document.querySelector('#mesh-count').textContent = meshes.toLocaleString();
  document.querySelector('#vertex-count').textContent = vertices.toLocaleString();
  document.querySelector('#face-count').textContent = faces.toLocaleString();
  document.querySelector('#format-value').textContent = 'MOD / ARE / GIT';
  document.querySelector('#geometry-value').textContent = `${area.width} x ${area.height} tiles`;
  document.querySelector('#hierarchy-value').textContent = `${area.tileset} · ${report.renderedTiles} tiles`;
  document.querySelector('#view-caption').textContent = `${area.resRef.toUpperCase()} · ${report.playerSpawned ? 'WALKABLE AREA' : 'STATIC AREA'}`;
  const omissions = [];
  if (report.skippedModels.length) omissions.push(`Models skipped: ${report.skippedModels.map((item) => `${item.name} (${item.reason})`).join(', ')}`);
  if (report.skippedObjects.length) omissions.push(`Objects skipped: ${[...new Set(report.skippedObjects)].join(', ')}`);
  if (report.missingTextures.length) omissions.push(`Bitmaps not found: ${report.missingTextures.join(', ')}`);
  if (report.missingHaks.length) omissions.push(`HAKs not loaded: ${report.missingHaks.join(', ')}`);
  if (report.missingWalkmeshes.length) omissions.push(`${report.missingWalkmeshes.length} tile walkmeshes unavailable`);
  if (report.missingObjectWalkmeshes.length) omissions.push(`${report.missingObjectWalkmeshes.length} object walkmeshes unavailable`);
  if (report.skippedCreatures.length) omissions.push(`Creatures skipped: ${[...new Set(report.skippedCreatures)].join(', ')}`);
  if (report.skippedCreatureParts.length) {
    omissions.push(`Creature parts unavailable: ${report.skippedCreatureParts.map((part) =>
      `${part.creature}/${part.model} (${part.reason})`).join(', ')}`);
  }
  const animationWarnings = [...parsedModels.values()].filter(model => model.unsupportedAnimations.length);
  if (animationWarnings.length) omissions.push(`${animationWarnings.length} models have unsupported animation controllers or unavailable supermodels`);
  for (const [kind, count] of Object.entries(area.unsupported)) {
    if (count) omissions.push(`${count} ${kind} not rendered`);
  }
  const effectSummary = previewEffectsEnabled.checked ? `${emitters} emitter previews on` : `${emitters} emitters available; previews off`;
  const lightingSummary = `${report.lightingMode} area lighting · ${lights} lights · ${effectSummary}; PCF shadows approximate the game passes, particle physics are not simulated.`;
  const paletteSummary = report.paletteParts ? ` · ${report.paletteParts} creature parts palette-colored` : '';
  const movementSummary = report.playerSpawned
    ? `walkable area · ${report.walkableTriangles} faces · player active · ${report.objectCollisionTriangles} object collision faces`
    : 'player unavailable · no valid spawn surface';
  const sceneSummary = `${report.renderedPlaceables} placeables · ${report.renderedDoors} doors (click / E to use) · ${report.renderedCreatures} creatures${paletteSummary} · ${activeAnimations.length} animation-capable instances · ${movementSummary} · ${lightingSummary}`;
  document.querySelector('#inspector-note').textContent = omissions.length
    ? `${omissions.join(' · ')} · ${sceneSummary}`
    : sceneSummary;
  updateMaterialList([...materialNames], textures);
}

function buildObject(parsed, textures, textureOverride = null) {
  const { root, groups,nodeGroups } = createModelHierarchy(parsed);
  for (const node of parsed.nodes) {
    if (node.type !== 'trimesh' || node.render === false || node.properties?.render === 0 || node.properties?.render === '0') continue;
    const transformedVertices = node.skinned
      ? deformSkinnedVertices(node, parsed.nodes, groups, nodeGroups.get(node),nodeGroups)
      : null;
    const mesh = buildMesh(node, textures, transformedVertices, textureOverride);
    if (mesh) nodeGroups.get(node).add(mesh);
  }
  for (const node of parsed.nodes) {
    const group = nodeGroups.get(node);
    if (node.type === 'light') addModelLight(node, group);
    else if (node.type === 'emitter') buildEmitterPreview(node, group, textures, parsed.modelName);
  }
  return root;
}

function addModelLight(node, parent) {
  const properties = node.properties ?? {};
  const colorValues = vectorProperty(properties.color, [1, 1, 1]);
  const color = new THREE.Color().setRGB(...colorValues, THREE.SRGBColorSpace);
  const intensity = Math.max(0, numericProperty(properties, 'multiplier', 1));
  const radius = Math.max(0, numericProperty(properties, 'radius', 0));
  const attenuation = radius > 0
    ? NWN_POINT_LIGHT_ATTENUATION / (2 * radius * radius)
    : 1;
  const pointIntensity = intensity / attenuation;
  const light = Number(properties.ambientonly) > 0
    ? new THREE.AmbientLight(color, intensity)
    : new THREE.PointLight(color, pointIntensity, radius, 0);
  light.name = `${node.name} light`;
  light.castShadow = !light.isAmbientLight && Number(properties.shadow) > 0;
  if (light.castShadow) configureLightShadow(light);
  parent.add(light);
}

function buildEmitterPreview(node, parent, textures, modelName) {
  const properties = node.properties ?? {};
  const textureName = typeof properties.texture === 'string' ? properties.texture.toLowerCase() : '';
  const sourceTexture = textures.get(textureName);
  if (!sourceTexture) return;
  const columns = Math.max(1, Math.min(32, Math.floor(numericProperty(properties, 'xgrid', 1))));
  const rows = Math.max(1, Math.min(32, Math.floor(numericProperty(properties, 'ygrid', 1))));
  let atlasTexture = null;
  if (sourceTexture) {
    atlasTexture = sourceTexture.clone();
    atlasTexture.repeat.set(1 / columns, 1 / rows);
    textures.set(`__emitter_${modelName}_${node.name}`, atlasTexture);
  }
  const particleRoot = new THREE.Group();
  particleRoot.name = `${node.name} particle preview`;
  particleRoot.userData.emitterPreview = true;
  particleRoot.visible = previewEffectsEnabled.checked;
  parent.add(particleRoot);

  const birthRate = Math.max(0, Math.min(32, numericProperty(properties, 'birthrate', 1)));
  const life = Math.max(0.1, Math.min(20, numericProperty(properties, 'lifeexp', 1)));
  const particleCount = Math.min(32, Math.ceil(birthRate * life));
  if (!particleCount) return;

  const startColor = vectorProperty(properties.colorstart, [1, 1, 1]);
  const endColor = vectorProperty(properties.colorend, startColor);
  const startAlpha = Math.max(0, Math.min(1, numericProperty(properties, 'alphastart', 1)));
  const endAlpha = Math.max(0, Math.min(1, numericProperty(properties, 'alphaend', 0)));
  const startSize = Math.max(0.01, numericProperty(properties, 'sizestart', 0.25));
  const endSize = Math.max(0.01, numericProperty(properties, 'sizeend', startSize));
  const startSizeY = Math.max(0.01, numericProperty(properties, 'sizestart_y', startSize) || startSize);
  const endSizeY = Math.max(0.01, numericProperty(properties, 'sizeend_y', endSize) || endSize);
  const frameStart = Math.max(0, Math.floor(numericProperty(properties, 'framestart', 0)));
  const frameEnd = Math.min(columns * rows - 1, Math.max(frameStart, Math.floor(numericProperty(properties, 'frameend', frameStart))));
  const frameCount = Math.max(1, frameEnd - frameStart + 1);
  const framesPerSecond = Math.max(0, numericProperty(properties, 'fps', 0));
  const gravity = numericProperty(properties, 'grav', 0);
  const additive = String(properties.blend ?? '').toLowerCase() === 'lighten';

  for (let index = 0; index < particleCount; index += 1) {
    const motion = sampleEmitterParticle(properties, index, particleCount);
    const particleMaterial = new THREE.SpriteMaterial({
      map: atlasTexture,
      color: new THREE.Color().setRGB(...startColor, THREE.SRGBColorSpace),
      opacity: startAlpha,
      transparent: true,
      depthWrite: false,
      blending: additive ? THREE.AdditiveBlending : THREE.NormalBlending,
      sizeAttenuation: true
    });
    const particle = new THREE.Sprite(particleMaterial);
    particle.name = `${node.name} preview particle ${index + 1}`;
    particle.userData.emitterParticle = {
      phase: index * life / particleCount,
      life,
      origin: motion.origin,
      velocity: motion.velocity,
      gravity,
      startColor,
      endColor,
      startAlpha,
      endAlpha,
      startSize,
      endSize,
      startSizeY,
      endSizeY,
      frameStart,
      columns,
      rows,
      frameCount,
      framesPerSecond
    };
    particleRoot.add(particle);
  }
}

function updateEmitterPreviewVisibility(root) {
  root?.traverse((object) => {
    if (object.userData.emitterPreview) object.visible = previewEffectsEnabled.checked;
  });
}

function updateEmitterPreviews(root, elapsed) {
  const updatedAtlases = new Set();
  root.traverse((object) => {
    const preview = object.userData.emitterParticle;
    if (!preview) return;
    const age = (elapsed + preview.phase) % preview.life;
    const progress = age / preview.life;
    object.position.set(
      preview.origin[0] + preview.velocity[0] * age,
      preview.origin[1] + preview.velocity[1] * age - preview.gravity * age * age * 0.5,
      preview.origin[2] + preview.velocity[2] * age
    );
    object.scale.set(
      preview.startSize + (preview.endSize - preview.startSize) * progress,
      preview.startSizeY + (preview.endSizeY - preview.startSizeY) * progress,
      1
    );
    object.material.color.setRGB(
      preview.startColor[0] + (preview.endColor[0] - preview.startColor[0]) * progress,
      preview.startColor[1] + (preview.endColor[1] - preview.startColor[1]) * progress,
      preview.startColor[2] + (preview.endColor[2] - preview.startColor[2]) * progress,
      THREE.SRGBColorSpace
    );
    object.material.opacity = preview.startAlpha + (preview.endAlpha - preview.startAlpha) * progress;

    const map = object.material.map;
    if (!map || updatedAtlases.has(map)) return;
    updatedAtlases.add(map);
    const frame = preview.frameStart + Math.floor(elapsed * preview.framesPerSecond) % preview.frameCount;
    const column = frame % preview.columns;
    const row = Math.floor(frame / preview.columns);
    map.offset.set(column / preview.columns, 1 - (row + 1) / preview.rows);
  });
}

function numericProperty(properties, name, fallback) {
  const value = properties[name];
  return Number.isFinite(value) ? value : fallback;
}

function vectorProperty(value, fallback) {
  return Array.isArray(value) && value.length >= 3 && value.slice(0, 3).every(Number.isFinite)
    ? value.slice(0, 3)
    : fallback;
}

function buildMesh(node, textures, transformedVertices = null, textureOverride = null) {
  if (node.verts.length === 0 || node.faces.length === 0) return null;
  const positions = [];
  const sourceVertexIndices = [];
  const uvs = [];
  const geometry = new THREE.BufferGeometry();
  const bitmapNames = node.bitmaps?.length ? node.bitmaps : [node.bitmap || ''];
  for (const faceGroup of groupFacesByMaterial(node.faces, bitmapNames.length)) {
    const groupStart = positions.length / 3;
    for (const face of faceGroup.faces) {
      const vertexIndices = face.slice(0, 3);
      const uvIndices = face.slice(4, 7);
      for (let corner = 0; corner < 3; corner += 1) {
        const vertex = node.verts[vertexIndices[corner]];
        sourceVertexIndices.push(vertexIndices[corner]);
        if (!vertex || vertex.length < 3) throw new Error(`Face index outside vertex array in ${node.name}.`);
        const transformedVertex = transformedVertices?.[vertexIndices[corner]];
        if (transformedVertex) positions.push(...transformedVertex);
        else positions.push(vertex[0], vertex[2], -vertex[1]);
        const uv = node.tverts[uvIndices[corner]];
        uvs.push(uv?.[0] ?? 0, uv?.[1] ?? 0);
      }
    }
    geometry.addGroup(groupStart, positions.length / 3 - groupStart, faceGroup.materialIndex);
  }

  if (positions.length === 0) return null;
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
  geometry.computeVertexNormals();
  geometry.computeBoundingSphere();

  const diffuseColor = vectorProperty(node.diffuse ?? node.properties?.diffuse, [1, 1, 1]);
  const materials = bitmapNames.map((bitmapName, index) => {
    const map = index === 0 && textureOverride ? textureOverride : textures.get(bitmapName.toLowerCase());
    const materialOptions = {
      color: new THREE.Color().setRGB(...diffuseColor, THREE.SRGBColorSpace),
      side: THREE.DoubleSide,
      ...modelMaterialOptions(node)
    };
    if (map) {
      materialOptions.map = map;
      materialOptions.alphaTest = 0.035;
      materialOptions.polygonOffset = true;
      materialOptions.polygonOffsetFactor = -1;
      materialOptions.polygonOffsetUnits = -1;
    }
    const material = new THREE.MeshLambertMaterial(materialOptions);
    material.name = bitmapName || 'untextured';
    return material;
  });
  const mesh = new THREE.Mesh(geometry, materials.length === 1 ? materials[0] : materials);
  mesh.userData.sourceVertexIndices = sourceVertexIndices;
  mesh.castShadow = Number(node.shadow ?? node.properties?.shadow ?? 1) !== 0;
  mesh.receiveShadow = true;
  return mesh;
}

function colorForName(name) {
  let hash = 2166136261;
  for (const char of name.toLowerCase()) hash = Math.imul(hash ^ char.charCodeAt(0), 16777619);
  const hue = ((hash >>> 0) % 360) / 360;
  return new THREE.Color().setHSL(hue, 0.38, 0.57);
}

function frameObject(object) {
  cameraFollowsPlayer = false;
  object.updateWorldMatrix(true, true);
  const bounds = new THREE.Box3().setFromObject(object);
  if (bounds.isEmpty()) throw new Error('The model contains no renderable triangle meshes.');
  const center = bounds.getCenter(new THREE.Vector3());
  const size = bounds.getSize(new THREE.Vector3());
  const longest = Math.max(size.x, size.y, size.z, 0.1);
  const distance = longest * 2.2;
  controls.target.copy(center);
  camera.position.set(center.x + distance, center.y + distance * 0.72, center.z + distance);
  camera.near = Math.max(longest / 200, 0.01);
  camera.far = Math.max(longest * 20, 10);
  controls.minDistance = Math.max(longest * 0.01, camera.near * 2);
  controls.maxDistance = camera.far;
  camera.updateProjectionMatrix();
  controls.update();
  updatePreviewSun();
  grid.position.y = bounds.min.y;
  axes.position.copy(bounds.min);
}

function createModelAnimator(parsed, instance, label, list) {
  if (!parsed?.animations?.length) return null;
  const groups = new Map(),nodeGroups=new Map();
  instance.traverse(object => {
    if (object.userData.mdlModel === parsed.modelName && object.userData.mdlNode){groups.set(object.userData.mdlNode, object);const node=parsed.nodes[object.userData.mdlNodeIndex];if(node)nodeGroups.set(node,object);}
  });
  const skins = parsed.nodes.filter(node => node.skinned).flatMap(node => {
    const group = nodeGroups.get(node)??groups.get(node.name);
    const mesh = group?.children.find(child => child.isMesh && child.userData.sourceVertexIndices);
    if (!mesh) return [];
    mesh.geometry = mesh.geometry.clone();
    return [{ node, group, mesh }];
  });
  const updateSkin = skins.length ? () => {
    for (const { node, group, mesh } of skins) {
      const vertices = deformSkinnedVertices(node, parsed.nodes, groups, group,nodeGroups);
      const attribute = mesh.geometry.getAttribute('position');
      mesh.userData.sourceVertexIndices.forEach((source, index) => attribute.setXYZ(index, ...vertices[source]));
      attribute.needsUpdate = true;
      mesh.geometry.computeVertexNormals();
      mesh.geometry.computeBoundingSphere();
    }
  } : null;
  const animator = new ModelAnimator(parsed, instance, updateSkin);
  animator.label = label;
  list.push(animator);
  const idle = ['pause1', 'idle', 'pause', 'default'].find(name => parsed.animations.some(clip => clip.name === name))
    ?? parsed.animations.find(clip => clip.name.endsWith('pause1'))?.name;
  if (idle) animator.play(idle);
  return animator;
}

function configureAnimationPanel() {
  animationPanel.hidden = !activeAnimations.length || !animationToolsEnabled.checked;
  const actorIds=new Map([...creatureAnimations?.bindings.values()??[]].map(binding=>[binding.animator,binding.actor.id]));
  animationObjectSelect.replaceChildren(...activeAnimations.map((animator, index) => {
    const option = new Option(animator.label, String(index));
    option.dataset.clips = String(animator.model.animations.length);
    if(actorIds.has(animator))option.dataset.objectId=String(actorIds.get(animator));
    return option;
  }));
  updateAnimationClips();
}
animationToolsEnabled.addEventListener('change', () => {
  if(!animationToolsEnabled.checked)for(const animator of activeAnimations)animator.presentationPreview=false;
  if (!animationToolsEnabled.checked) { animationIsolate.checked = false; restoreAnimationVisibility(); }
  configureAnimationPanel();
});

function selectedAnimator() { return activeAnimations[Number(animationObjectSelect.value)]; }

function updateAnimationClips() {
  const animator = selectedAnimator();
  animationClipSelect.replaceChildren(new Option('Bind pose', ''));
  if (!animator) return;
  updateAnimationIsolation();
  for (const clip of animator.model.animations) animationClipSelect.add(new Option(`${clip.name}${clip.inheritedFrom ? ' (inherited)' : ''}`, clip.name));
  animationClipSelect.value = animator.clip?.name ?? '';
  animationSummary.textContent = `${activeAnimations.length} animation-capable instances · ${animator.model.animations.length} clips${animator.model.unsupportedAnimations.length ? ` · ${animator.model.unsupportedAnimations.length} unsupported controllers/resources` : ''}. Preview affects appearance; door collision follows E interaction.`;
  animationSummary.title = animator.model.unsupportedAnimations.join('\n');
  updateAnimationPlaybackStatus();
}

function updateAnimationPlaybackStatus() {
  const animator = selectedAnimator();
  if (!animator) return;
  animationPlay.textContent = animator.playing ? 'Pause' : 'Play';
  animationClipSelect.value = animator.clip?.name ?? '';
  // Gameplay transitions finish before diagnostic previews can replace their clip.
  animationClipSelect.disabled = Boolean(animator.gameplayTransition);
  animationPlay.disabled = Boolean(animator.gameplayTransition) || !animator.clip || !animator.clip.length;
  animationTime.value = animator.clip ? `${animator.clip.name} · ${animator.time.toFixed(2)} / ${animator.clip.length.toFixed(2)} s${animator.missingNodes.length ? ` · ${animator.missingNodes.length} unbound nodes` : ''}` : 'Bind pose';
  animationTime.dataset.time = String(animator.time);
  animationTime.dataset.playing = String(animator.playing);
}

animationObjectSelect.addEventListener('change', updateAnimationClips);
animationClipSelect.addEventListener('change', () => {
  const animator = selectedAnimator();
  if (!animator || animator.gameplayTransition) return;
  animator.presentationPreview=true;
  if (animationClipSelect.value) animator.play(animationClipSelect.value);
  else { animator.playing = false; animator.clip = null; animator.apply(null, 0); }
  updateAnimationClips();
});
animationPlay.addEventListener('click', () => {
  const animator = selectedAnimator();
  if (!animator?.clip || animator.gameplayTransition) return;
  animator.loop = true;
  animator.playing = !animator.playing;
  updateAnimationClips();
});
animationFocus.addEventListener('click', () => {
  const animator = selectedAnimator();
  if (animator) frameObject(animator.root);
});
animationIsolate.addEventListener('change', updateAnimationIsolation);

function restoreAnimationVisibility() {
  for (const [object, visible] of isolatedVisibility) object.visible = visible;
  isolatedVisibility.clear();
}

function updateAnimationIsolation() {
  restoreAnimationVisibility();
  const animator = selectedAnimator();
  if (!animationIsolate.checked || !animator || animator.root === loadedRoot) return;
  let owner = animator.root;
  while (owner.parent && owner.parent !== loadedRoot) owner = owner.parent;
  if (owner.parent !== loadedRoot) return;
  for (const object of loadedRoot.children) {
    if (object === owner) continue;
    isolatedVisibility.set(object, object.visible);
    object.visible = false;
  }
}

function updateDoorVisual(door, root, previousState = null) {
  if (animateDoorState(door, previousState, () => {
    if (playerController?.collisions.doors.includes(door)) playerController.obstacles = activeObjectCollisions(playerController.collisions);
  })) {
    door.object.visible = true;
    return;
  }
  // Keep a diagnostic proxy for models whose authored state clip is unavailable.
  runtimeDiagnostics.record('animation.door-state-unavailable', `Door ${door.tag || door.model} has no usable state animation`, { objectId: door.id, sourceKey: door.sourceKey, model: door.model, state: door.animationState });
  if (door.object) door.object.visible = door.animationState === 0;
  if (door.proxy) {
    root.remove(door.proxy);
    door.proxy.geometry.dispose();
    door.proxy.material.dispose();
    door.proxy = null;
  }
  if (door.animationState === 0 || door.animationState === 3) return;
  const triangles = doorCollision(door);
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(
    triangles.flatMap(triangle => triangle.vertices.flat()), 3));
  geometry.computeVertexNormals();
  const proxy = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial({
    color: 0x6fb7a5, transparent: true, opacity: 0.35, side: THREE.DoubleSide
  }));
  proxy.userData.worldObjectId = door.id;
  proxy.name = `${door.tag || door.model} · open collision preview`;
  root.add(proxy);
  door.proxy = proxy;
}

function updateDoorTarget() {
  if (!playerController) return;
  const door = selectedWorldObject?.kind === 'door' ? selectedWorldObject : nearestDoor(playerController.collisions.doors, playerController.position);
  playerController.targetDoor = door;
  doorAction.disabled = !door || Boolean(moduleSession?.player.cutscene?.enabled || moduleSession?.conversation.state || gameUi.captured);
  const verb = door?.animationState === 0 ? 'Open' : door?.linkedTo || door?.linkedToModule ? 'Use transition' : 'Close';
  const label = door ? `${verb} ${door.tag || door.model}${door.locked ? ' (locked)' : ''} · E` : 'Approach a door · E to interact';
  if (doorAction.textContent !== label) doorAction.textContent = label;
}

function interactWithDoor(intent = null) {
  if (!playerController || moduleSession?.player.cutscene?.enabled || moduleSession?.conversation.state || gameUi.captured) return;
  updateDoorTarget();
  const door = selectedWorldObject?.kind === 'door' ? selectedWorldObject : playerController.targetDoor;
  if (!door) return;
  actionQueue?.request(door.id, intent);
}

function updateGameplayDiagnostics() {
  if (!worldObjects) return;
  canvas.dataset.worldObjects = String(worldObjects.objects.size);
  canvas.dataset.actionPhase = actionQueue?.current?.phase ?? 'idle';
  canvas.dataset.selectedObject = selectedWorldObject?.id ?? '';
  canvas.dataset.hoveredObject = hoveredObject?.id ?? '';
  canvas.dataset.actorPosition = JSON.stringify(playerController?.position ?? null);
  canvas.dataset.actorId = String(playerController?.actor.id ?? '');
  canvas.dataset.areaResRef = moduleSession?.currentArea?.resRef ?? '';
  canvas.dataset.registryObjects = String(moduleSession?.registry.objects.size ?? 0);
  canvas.dataset.objectRecords = JSON.stringify([...worldObjects.objects.values()].map(o => ({ id: o.id, kind: o.kind, tag: o.tag, sourceKey: o.sourceKey })));
  canvas.dataset.scriptEvents = String(moduleSession?.scheduler.events.length ?? 0);
  canvas.dataset.scriptBusy = String(Boolean(moduleSession?.scheduler.pumping || moduleSession?.transitioning));
  canvas.dataset.scriptJumps = String(moduleSession?.scheduler.events.filter(e => e.event.type === 'jump').length ?? 0);
  canvas.dataset.journalEntries = String(moduleSession?.player.journal.size ?? 0);
  canvas.dataset.characterLoaded = String(Boolean(moduleSession?.player.characterLoaded));
  canvas.dataset.characterStats = JSON.stringify(moduleSession?.player.stats ?? null);
  const characterData = moduleSession?.player.creatureData ?? moduleSession?.player.authored;
  canvas.dataset.characterSpellCounts = JSON.stringify((characterData?.ClassList ?? []).map(c => ({
    classId: c.Class, known: Array.from({ length: 10 }, (_, l) => c[`KnownList${l}`]?.length ?? 0).reduce((a, b) => a + b, 0),
    memorized: Array.from({ length: 10 }, (_, l) => (c[`MemorizedList${l}`] ?? []).filter(Boolean).length).reduce((a, b) => a + b, 0)
  })));
  canvas.dataset.characterModel = String(Boolean(playerController?.object.userData.characterModel));
  canvas.dataset.doorStates = JSON.stringify(playerController?.collisions.doors.map(door => ({ id: door.id, state: door.animationState, moving: Boolean(door.animating) })) ?? []);
}

function findPlayerSpawn(area, resolver, triangles, obstacles) {
  if (!triangles.length) return null;
  const ifoBytes = resolver.module.entries.get(`module:${RESOURCE_TYPE.IFO}`);
  if (ifoBytes) {
    const entry = parseGff(ifoBytes, 'IFO ').root;
    if (String(entry.Mod_Entry_Area ?? '').toLowerCase() === area.resRef.toLowerCase()) {
      const x = Number(entry.Mod_Entry_X);
      const z = -Number(entry.Mod_Entry_Y);
      const floor = findWalkableHeight(triangles, x, z, Number(entry.Mod_Entry_Z), 1.25);
      if (floor !== null) {
        const valid = moveOnWalkmesh(triangles, [x, floor, z], 0, 0, 0.22, 0.9, obstacles);
        if (valid) return valid;
        // Search near the authored entry; never silently spawn far away.
        for (let radius = 0.25; radius <= 2; radius += 0.25) {
          for (let index = 0; index < 16; index += 1) {
            const dx = Math.cos(index * Math.PI / 8) * radius;
            const dz = Math.sin(index * Math.PI / 8) * radius;
            const height = findWalkableHeight(triangles, x + dx, z + dz, floor, 0.9);
            if (height === null) continue;
            const candidate = moveOnWalkmesh(triangles, [x + dx, height, z + dz], 0, 0, 0.22, 0.9, obstacles);
            if (candidate) return candidate;
          }
        }
      }
      return null;
    }
  }

  // Development-only area selection should start beside an authored entrance,
  // rather than in an unrelated disconnected room. Actual script jumps always
  // use resolveJumpSpawn and never this fallback.
  const sessionArea = moduleSession?.areas.get(area.resRef);
  for (const id of sessionArea?.objects ?? []) {
    const door = moduleSession.registry.get(id);
    if (door?.kind !== 'door' || !door.linkedToFlags || door.locked || !door.usable) continue;
    const center = [area.width * 5, 0, -area.height * 5];
    const points = doorUsePoints(door).slice().sort((a, b) => Math.hypot(a[0]-center[0],a[2]-center[2]) - Math.hypot(b[0]-center[0],b[2]-center[2]));
    for (const point of points) {
      const valid = moveOnWalkmesh(triangles, point, 0, 0, 0.22, 0.9, obstacles);
      if (valid) return valid;
    }
  }
  for (const { vertices } of triangles) {
    const center = [0, 1, 2].map(axis => vertices.reduce((sum, vertex) => sum + vertex[axis], 0) / 3);
    const valid = moveOnWalkmesh(triangles, center, 0, 0, 0.22, 0.9, obstacles);
    if (valid) return valid;
  }
  return null;
}

function createPlayerPreview() {
  const player = new THREE.Group();
  player.name = 'Player movement preview';
  const body = new THREE.Mesh(
    new THREE.CapsuleGeometry(0.22, 0.82, 4, 8),
    new THREE.MeshLambertMaterial({ color: 0x6fb7a5 })
  );
  body.position.y = 0.74;
  body.castShadow = true;
  player.add(body);
  return player;
}

function focusPlayer(player) {
  cameraFollowsPlayer = true;
  const target = player.position.clone().add(new THREE.Vector3(0, 0.8, 0));
  controls.target.copy(target);
  camera.position.copy(target).add(new THREE.Vector3(7, 5, 7));
  camera.near = 0.05;
  camera.far = 500;
  camera.updateProjectionMatrix();
  controls.minDistance = 2;
  controls.maxDistance = 80;
  controls.update();
}

function updateScriptCamera(delta, immediate = false) {
  const actor = playerController?.actor, mode = actor?.scriptCameraMode;
  if (mode === undefined) return;
  canvas.dataset.cameraMode = String(mode);
  if (mode === 1 || !cameraFollowsPlayer || actor.cutscene?.enabled) return;
  const offset = camera.position.clone().sub(controls.target), radius = Math.hypot(offset.x, offset.z);
  const desired = new THREE.Vector3(Math.sin(actor.bearing ?? 0) * radius, offset.y, Math.cos(actor.bearing ?? 0) * radius).add(controls.target);
  camera.position.lerp(desired, immediate || mode === 2 ? 1 : 1 - Math.exp(-Math.max(0, delta) * 5));
  controls.update();
}

function updatePlayerMovement(delta) {
  if (!playerController || movementKeys.size === 0 || document.hidden) return;
  const forward = camera.getWorldDirection(new THREE.Vector3());
  forward.y = 0;
  if (forward.lengthSq() < 1e-8) return;
  forward.normalize();
  const right = new THREE.Vector3().crossVectors(forward, new THREE.Vector3(0, 1, 0)).normalize();
  const input = new THREE.Vector3();
  if (movementKeys.has('w') || movementKeys.has('arrowup')) input.add(forward);
  if (movementKeys.has('s') || movementKeys.has('arrowdown')) input.sub(forward);
  if (movementKeys.has('d') || movementKeys.has('arrowright')) input.add(right);
  if (movementKeys.has('a') || movementKeys.has('arrowleft')) input.sub(right);
  if (input.lengthSq() < 1e-8) return;
  input.normalize().multiplyScalar(Math.min(delta, 0.05) * 3.2);

  const { object, position, triangles } = playerController;
  let next = moveOnWalkmesh(triangles, position, input.x, input.z, 0.22, 0.9, playerController.obstacles);
  if (!next) next = moveOnWalkmesh(triangles, position, input.x, 0, 0.22, 0.9, playerController.obstacles);
  if (!next) next = moveOnWalkmesh(triangles, position, 0, input.z, 0.22, 0.9, playerController.obstacles);
  if (!next) return;

  applyPlayerPosition(next, input.x, input.z);
}

function movePlayerTowards(point, delta) {
  const { position, triangles, obstacles } = playerController;
  const dx = point[0] - position[0], dz = point[2] - position[2];
  const distance = Math.hypot(dx, dz);
  if (distance < 0.025) return 'arrived';
  const scale = Math.min(distance, delta * 3.2) / distance;
  const next = moveOnWalkmesh(triangles, position, dx * scale, dz * scale, 0.22, 0.9, obstacles);
  if (!next) return 'blocked';
  applyPlayerPosition(next, dx, dz);
  return scale >= 1 ? 'arrived' : 'moving';
}

function applyPlayerPosition(next, dx, dz) {
  const { position, object } = playerController;
  const shift = new THREE.Vector3(next[0] - position[0], next[1] - position[1], next[2] - position[2]);
  position.splice(0, position.length, ...next);
  moduleSession.updatePositionArray(playerController.actor);
  object.position.set(...next);
  object.rotation.y = Math.atan2(dx, dz);
  playerController.actor.bearing = object.rotation.y - Math.PI;
  moduleSession.updateTriggers(playerController.actor);
  if (cameraFollowsPlayer) {
    controls.target.add(shift);
    camera.position.add(shift);
  }
}

function updatePreviewSun() {
  const bounds = loadedRoot
    ? new THREE.Box3().setFromObject(loadedRoot)
    : new THREE.Box3(new THREE.Vector3(-5, -1, -5), new THREE.Vector3(5, 5, 5));
  const center = bounds.getCenter(new THREE.Vector3());
  const size = bounds.getSize(new THREE.Vector3());
  const distance = Math.max(size.x, size.y, size.z, 1) * 2;
  const directions = {
    overhead: new THREE.Vector3(-0.15, 1, 0.12),
    'front-left': new THREE.Vector3(-0.75, 0.65, 0.6),
    'front-right': new THREE.Vector3(0.75, 0.65, 0.6),
    'rear-left': new THREE.Vector3(-0.75, 0.65, -0.6),
    'rear-right': new THREE.Vector3(0.75, 0.65, -0.6)
  };
  const direction = directions[previewSunDirection.value] ?? directions.overhead;
  previewSun.position.copy(center).addScaledVector(direction.normalize(), distance);
  previewSun.target.position.copy(center);
  previewSun.intensity = Number(previewSunIntensity.value);
  previewSun.visible = previewSunEnabled.checked;
  previewSunValue.value = `${previewSunIntensity.value}x`;
}

function updateMaterialList(materialNames, textures) {
  const list = document.querySelector('#material-list');
  list.replaceChildren();
  if (materialNames.length === 0) {
    list.innerHTML = '<span class="muted">No bitmap references</span>';
    return;
  }
  for (const name of materialNames) {
    const row = document.createElement('div');
    row.className = 'material-row';
    const swatch = document.createElement('span');
    swatch.className = 'material-swatch';
    swatch.style.background = `#${colorForName(name).getHexString()}`;
    const label = document.createElement('span');
    const texture = textures.get(name.toLowerCase());
    const format = texture?.isCompressedTexture ? 'DDS' : texture ? 'TGA' : '';
    label.textContent = `${name}${format ? ` · ${format}` : ''}`;
    row.append(swatch, label);
    list.append(row);
  }
}

function updateInspector(parsed, filename, textures) {
  recordModelLimitations(parsed);
  for (const resRef of parsed.materialNames) if (resRef && resRef.toLowerCase() !== 'null' && !textures.has(resRef.toLowerCase())) runtimeDiagnostics.record('scene.texture-unavailable', `Model texture ${resRef} is unavailable`, { model: parsed.modelName, resRef });
  const meshes = parsed.nodes.filter((node) => node.type === 'trimesh' && node.faces.length > 0);
  const vertices = meshes.reduce((total, node) => total + node.verts.length, 0);
  const faces = meshes.reduce((total, node) => total + node.faces.length, 0);
  document.querySelector('#model-title').textContent = parsed.modelName || filename.replace(/\.mdl$/i, '');
  document.querySelector('#node-count').textContent = parsed.nodes.length.toLocaleString();
  document.querySelector('#mesh-count').textContent = meshes.length.toLocaleString();
  document.querySelector('#vertex-count').textContent = vertices.toLocaleString();
  document.querySelector('#face-count').textContent = faces.toLocaleString();
  document.querySelector('#format-value').textContent = parsed.format;
  document.querySelector('#geometry-value').textContent = `${meshes.length} meshes`;
  document.querySelector('#hierarchy-value').textContent = `${parsed.nodes.length} nodes`;
  document.querySelector('#inspector-note').textContent = parsed.hasSkinnedMeshes
    ? (hasStaticSkinMapping(parsed)
      ? 'Bone weights follow the animated hierarchy. Unmapped bones remain in base pose.'
      : 'Skin weight data is present but no bone slots map to model nodes, so base vertices are shown.')
    : 'Available transform and opacity clips can be previewed above. Dangly-mesh simulation and some controller types remain unsupported.';
  if (parsed.unsupportedAnimations.length) document.querySelector('#inspector-note').textContent += ` Animation diagnostics: ${parsed.unsupportedAnimations.join('; ')}`;
  updateMaterialList(parsed.materialNames, textures);
  document.querySelector('#view-caption').textContent = `${parsed.modelName.toUpperCase()} · ${parsed.format.toUpperCase()}`;
}

function recordModelLimitations(parsed) {
  for (const message of parsed.unsupportedAnimations) runtimeDiagnostics.record('animation.unsupported', message, { model: parsed.modelName });
  if (parsed.hasSkinnedMeshes && !hasStaticSkinMapping(parsed)) runtimeDiagnostics.record('model.skin-mapping-unavailable', 'No skin bone slots map to model nodes; base vertices are displayed', { model: parsed.modelName });
  for (const node of parsed.nodes) {
    for (const feature of node.unsupportedFeatures ?? []) runtimeDiagnostics.record('model.feature-unimplemented', `${feature} is not implemented`, { model: parsed.modelName, node: node.name, feature });
    if (!['trimesh', 'dummy', 'light', 'emitter'].includes(node.type)) runtimeDiagnostics.record('model.node-unimplemented', `Node type ${node.type} is not rendered`, { model: parsed.modelName, node: node.name, nodeType: node.type });
    if (node.type === 'emitter') runtimeDiagnostics.record('model.feature-unimplemented', 'Emitter runtime activation and particle physics are not implemented; optional preview is approximate', { model: parsed.modelName, node: node.name });
  }
}
