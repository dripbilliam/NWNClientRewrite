import {ModelSourceCache} from './model_source_cache.js';
import {PersistentModelSources} from './persistent_model_sources.js';
import {ResourceWorkerPool} from './resource_worker_pool.js';
import {FrameWorkBudget} from './frame_work_budget.js';
import {RendererTexturePreparation} from './renderer_texture_preparation.js';
import {prepareResourceBatch} from './resource_preparation.js';
import {s3tcTexture} from './s3tc_decode.js';
import {portraitImage} from './portrait_image.js';
import {rendererNetworkBridge} from './network_resource_bridge.js';
import {loadCharacterCreationAssets} from './character_creation_assets.js';
import * as THREE from 'three';
import {updateNetworkFrame} from './network_frame.js';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { DDSLoader } from 'three/addons/loaders/DDSLoader.js';
import { KTXLoader } from 'three/addons/loaders/KTXLoader.js';
import {resolveTextureResource,textureResourceFile} from './texture_resource.js';
import {parseNativeTga} from './native_tga.js';
import { parseModel } from './model_parser.js';
import { deformSkinnedVertices,updateSkinnedMesh } from './model_skinning.js';
import { createModelHierarchy } from './model_hierarchy.js';
import { inheritAnimations } from './mdl_animation.js';
import { ModelAnimator } from './model_animation.js';
import {setScalarPoseTransfer} from './model_native_pose.js';
import { createModelLight, setModelLightShadows, installModelLightShaders } from './model_light.js';
import {RendererShadowBudget} from './renderer_shadow_budget.js';
import {RendererShadowTraversal} from './renderer_shadow_traversal.js';
import {RendererPerformanceView} from './renderer_performance_view.js';
import {RendererResourceRetirement} from './renderer_resource_retirement.js';
import {RendererModelGeometry} from './renderer_model_geometry.js';
import {manageLocalMatrix,setManagedMatrixReuse,managedMatrixReuseSnapshot} from './managed_local_matrix.js';
import {setMatrixSubtreeReuse,matrixSubtreeSnapshot} from './renderer_matrix_subtree.js';
import {RendererMainBatches} from './renderer_main_batches.js';
import { LoopingVisualPresentation } from './looping_visual_presentation.js';
import {createVisualSceneRuntime} from './visual_scene_runtime.js';
import {ObjectVisualInbox} from './object_visual_inbox.js';
import {ClientProjectileInbox,ClientProjectilePresentation} from './client_projectile_presentation.js';
import {serverObjectIdForClient} from './client_projectile_message.js';
import {ClientSpellPresentation} from './client_spell_presentation.js';
import {ClientPausePresentation} from './client_pause_presentation.js';
import {localClientCastFields} from './client_cast_fields.js';
import {clientCastVoiceFields} from './client_cast_voice_fields.js';
import {clientProjectileModelQuaternion} from './client_projectile_orientation.js';
import {randomSceneModelPart} from './model_random_part.js';
import {NativeRandom} from './native_random.js';
import {visualLocalPoseServices} from './visual_scene_pose.js';
import {ModelReferenceScene} from './model_reference_scene.js';
import {loadModelReferenceAssets,releaseModelReferenceAssets} from './model_reference_assets.js';
import {CreatureAnimationPresentation} from './creature_animation_presentation.js';
import {totalAttackDamage} from './combat_attack_data.js';
import {attackResultDoesDamage} from './combat_strike.js';
import { modelMaterialOptions } from './model_material.js';
import { parseGff } from './gff.js';
import {buildModelGeometry} from './prepared_model_geometry.js';
import { parseBioWareDds } from './bioware_dds.js';
import { decodeBioWarePlt, PLT_PALETTE_NAMES } from './bioware_plt.js';
import { sampleEmitterParticle } from './particle_preview.js';
import {createModelEmitter,ModelParticlePresentation} from './model_particles.js';
import { loadAreaWalkmesh, parseAreaModule } from './area.js';
import { ResourceResolver, RESOURCE_TYPE } from './resource_archive.js';
import { findWalkableHeight, moveOnWalkmesh } from './walkmesh.js';
import { activeObjectCollisions, doorCollision, loadAreaCollisions, nearestDoor } from './door.js';
import { animateDoorState } from './door_animation.js';
import { createDoorUseHandler, doorUsePoints } from './door_use.js';
import { WorldObjects } from './world_objects.js';
import { ModuleSession } from './module_session.js';
import {NetworkScene} from './network_scene.js';
import {startNetworkAreaGraphics} from './network_area_graphics.js';
import {NetworkPlayerCamera} from './network_camera.js';
import {GameCamera} from './game_camera.js';
import {cameraSceneQuery} from './camera_scene_query.js';
import {GameCameraInput} from './game_camera_input.js';
import {WorldPointerView} from './world_pointer_view.js';
import {spellTargetPreview} from './target_preview.js';
import {CameraKeyholePresentation} from './camera_keyhole_shader.js';
import {NetworkFrontend} from './network_frontend.js';
import { horizontalInRange } from './interaction_range.js';
import { resolveJumpSpawn } from './transition_spawn.js';
import { ActionQueue } from './action_queue.js';
import { WalkmeshNavigator } from './navigation.js';
import { pickedWorldObject, pointerRay,withWorldPickFrame } from './world_picking.js';
import {WorldHighlightView} from './world_highlight_view.js';
import {highlightCreatureDetails} from './world_highlight_assets.js';
import { buildRadialActions, buildGroundRadialActions, radialActionRequest } from './radial_actions.js';
import {visualMainModel} from './visual_scene_pose.js';
import { RadialMenu } from './radial_menu.js';
import {isTextEntry,isControlArrow} from './game_input.js';
import {NetworkKeyboardInput,keyboardActorContext} from './network_keyboard_input.js';
import {radialSpellCastRequest,radialSpellTargetAllowed} from './spell_radial.js';
import {prepareSpellTarget,spellTargetDefinition} from './spell_targeting.js';
import {isSpellFamily,spellFamilyContains,spellShortcutChoice} from './spell_family.js';
import {quickbarChoiceMenu} from './quickbar_menu.js';
import {talentSpell} from './spell_metadata.js';
import {prepareFeatTarget,featTargetAllowed} from './feat_targeting.js';
import {prepareItemTarget,itemCreatureTargetVeto,confirmItemTarget,sendItemUse} from './item_targeting.js';
import {selectLearnScroll} from './scroll_learning.js';
import {featActivationInfo,featActivationSpell} from './use_feat.js';
import {selectRadialFeat} from './feat_radial.js';
import {OBJECT_INVALID} from './game_object_array.js';
import { GameUi } from './game_ui.js';
import { CharacterFrontend } from './character_frontend.js';
import { parseCharacter,resolvePlayerModels } from './character.js';
import { GameAudio } from './game_audio.js';
import {nativeAudioListener,NetworkAudioPresentation} from './native_audio.js';
import {NetworkAmbientPresentation} from './network_ambient_presentation.js';
import {NetworkPlacedSounds} from './network_placed_sounds.js';
import {VoicePresentation} from './voice_presentation.js';
import {networkRadialActions,networkDefaultInteraction} from './network_action_menu.js';
import {NetworkDialogView} from './network_dialog_view.js';
import {NetworkQuickbarView} from './network_quickbar_view.js';
import {NetworkActionQueueView} from './network_action_queue_view.js';
import {NetworkSpellTargeting} from './network_spell_targeting.js';
import {prepareNetworkSpellMenus} from './network_spell_menu.js';
import {prepareNetworkItemMenu} from './network_item_menu.js';
import {configureNetworkItemShortcut} from './network_quickbar_items.js';
import {emptyQuickbarButton} from './quickbar.js';
import {networkFamiliar} from './network_associates.js';
import {NetworkInventoryView} from './network_inventory_view.js';
import {NetworkPartyView} from './network_party_view.js';
import {NetworkPanels} from './network_panels.js';
import {NetworkNuiView} from './network_nui_view.js';
import {nuiImage} from './nui_image.js';
import {recordImage} from './character_record_view.js';
import './network_nui.css';
import {NetworkTimingView} from './network_timing_view.js';
import {NetworkFeedbackView,nativeDamageFeedbackOptions} from './network_feedback_view.js';
import {NetworkFloatingTextView} from './network_floating_text_view.js';
import {NetworkSpeechView} from './network_speech_view.js';
import {NetworkExamineView} from './network_examine_view.js';
import {RendererLightSlots,prepareRendererLights,renderPreparedScene} from './renderer_light_slots.js';
import {RendererLightUniforms} from './renderer_light_uniforms.js';
import {RendererMaterialReuse} from './renderer_material_reuse.js';
import {RendererLightSelection} from './renderer_light_selection.js';
import {RendererModelPreparation} from './renderer_model_preparation.js';
import {intEntry} from './combat_stats.js';
import { runtimeDiagnostics } from './runtime_diagnostics.js';
import { installDiagnosticReporting } from './diagnostic_reporting.js';
import './style.css';
import {DebugShell} from './debug_shell.js';
import {MovableWindows} from './movable_windows.js';
import {NetworkBuffBarView} from './network_buff_bar.js';
const debugShell=new DebugShell();
import './network_lobby.css';
import {GameText,parseTalkTable} from './talk_table.js';

const nativeNetwork=rendererNetworkBridge(window.nativeNetwork);

let diagnosticContext = {};
let moduleLoadBusy = false;
runtimeDiagnostics.context = () => diagnosticContext;
installDiagnosticReporting();
runtimeDiagnostics.record('session.started', 'Runtime diagnostic recording started', {}, 'info');

const canvas = document.querySelector('#model-canvas');
const viewport = document.querySelector('#viewport-frame');
new MovableWindows(viewport);
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
let networkPresentation=null,networkFloating=null,networkCombatSnapshotAt=0;
const networkRendererRetirement=new RendererResourceRetirement({report:(code,message)=>runtimeDiagnostics.record(code,message)});
const rendererModelGeometry=new RendererModelGeometry();
const persistentModelSources=new PersistentModelSources();
let usePersistentModelPreparation=import.meta.env.VITE_PERSISTENT_MODEL_PREP==='1';
canvas.dataset.persistentModelPreparation=String(usePersistentModelPreparation);
if(import.meta.env.VITE_MODEL_PREP_COMPARE==='1')window.setPersistentModelPrepForTest=value=>{usePersistentModelPreparation=Boolean(value);canvas.dataset.persistentModelPreparation=String(usePersistentModelPreparation);if(!value)persistentModelSources.clear();};
let finishNetworkRendererTransition=null;
function retireNetworkTransition(){finishNetworkRendererTransition?.();finishNetworkRendererTransition=null;}
const networkCamera=new NetworkPlayerCamera({report:(code,message,data)=>runtimeDiagnostics.record(code,message,data)});
let networkFrontend=null;
let gameAudio = null;
let networkGuiAudio = null;
let networkScriptAudio = null;
let networkAmbientAudio = null;
let networkPlacedSounds = null;
let voicePresentation=null;
let creatureAnimations=null;
let clientPause=null;
let dynamicCreatureSync=null;
let loopingVisuals=null;
let visualDelivery=null;
let projectileDelivery=null,projectiles=null;
const clientAnimationRandom=new NativeRandom(1);
const unlockAudio = () => { void gameAudio?.unlock();void networkGuiAudio?.unlock(); };
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
setManagedMatrixReuse(import.meta.env.VITE_MANAGED_MATRIX_REUSE==='1');
setScalarPoseTransfer(import.meta.env.VITE_SCALAR_POSE_TRANSFER==='1');
if(import.meta.env.VITE_POSE_TRANSFER_COMPARE==='1')window.setScalarPoseTransferForTest=setScalarPoseTransfer;
let reuseWorldPicking=import.meta.env.VITE_REUSE_WORLD_PICKING!=='0';
if(import.meta.env.VITE_PICKING_COMPARE==='1')window.setWorldPickingForTest=value=>{reuseWorldPicking=Boolean(value);};
const prepareMatrixSubtrees=import.meta.env.VITE_MATRIX_SUBTREES==='1'||import.meta.env.VITE_MATRIX_SUBTREE_COMPARE==='1';
setMatrixSubtreeReuse(import.meta.env.VITE_MATRIX_SUBTREES==='1');
if(import.meta.env.VITE_MATRIX_SUBTREE_COMPARE==='1')window.setMatrixSubtreeReuseForTest=setMatrixSubtreeReuse;
// The presentation scene itself has a fixed identity transform.
manageLocalMatrix(scene);
installModelLightShaders();
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
const rendererShadowTraversal=new RendererShadowTraversal(renderer,{instances:renderer.capabilities.maxAttributes>=12});
// The ordered palette-batch candidate is correct in GPU comparisons but still
// slower in the dense local fixture. Keep ordinary submission until profitable.
const wideStaticBatches=import.meta.env.VITE_WIDE_STATIC_BATCHES==='1'||import.meta.env.VITE_BATCH_POOL_COMPARE==='1';
const rendererMainBatches=new RendererMainBatches(renderer,{enabled:import.meta.env.VITE_ORDERED_MAIN_BATCHES==='1'||import.meta.env.VITE_WIDE_STATIC_BATCHES==='1',...(wideStaticBatches?{staticOnly:true,minRepeatSize:1024,maxBytes:256*1024*1024,compressed:true}:{})});
let batchPoolSamples=null;
if(import.meta.env.VITE_BATCH_POOL_COMPARE==='1'){window.setBatchPoolForTest=value=>{rendererMainBatches.enabled=Boolean(value);batchPoolSamples=[];};window.setRenderScaleForTest=value=>{renderer.setPixelRatio(value ? .5 : 1);batchPoolSamples=[];};window.batchPoolFrameSamplesForTest=()=>batchPoolSamples;window.batchPoolAuditForTest=()=>rendererMainBatches.audit(renderer.renderLists.get(scene,0));}
const rendererLightUniforms=new RendererLightUniforms(renderer,{enabled:false});
const rendererMaterialReuse=new RendererMaterialReuse(renderer,{enabled:false});
const modelParticles=new ModelParticlePresentation({camera,vertexPool:()=>networkPresentation?.vertexWorkers??null,report:(code,message,data)=>runtimeDiagnostics.record(code,message,data)});
let shadowCastingLights=3;
try{const saved=localStorage.getItem('nwn.graphics.shadowCastingLights');if(saved!==null&&[1,2,3].includes(Number(saved)))shadowCastingLights=Number(saved);}catch{}
const rendererShadowBudget=new RendererShadowBudget({renderer,nativeSelection:true,maximum:shadowCastingLights,report:(code,message,data)=>runtimeDiagnostics.record(code,message,data)});

const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.dampingFactor = 0.08;
controls.target.set(0, 0.5, 0);
const singlePlayerCamera=new GameCamera();
let cameraKeyhole=null;
let worldPointer=null;
let orbitConnected=true;
const gameplayCameraActive=()=>Boolean(networkPresentation||playerController&&cameraFollowsPlayer);
const gameplayCamera=()=>networkPresentation?networkCamera.controller:singlePlayerCamera;
// Floating windows disable the viewer's orbit controls, not gameplay camera
// input over the canvas. Keep creation/loading/cutscene capture independent.
const gameplayCameraInputEnabled=()=>!characterFrontend.active&&!gameUi.blocksWorldInput&&!moduleSession?.player?.cutscene?.enabled&&!moduleSession?.transitioning&&!moduleLoadBusy&&!rendererWarmupCount&&(!networkPresentation||networkFrontend.phase==='playing'&&!networkPresentation.closed&&!networkPresentation.graphicsPending);
const gameplayCameraInput=new GameCameraInput(canvas,{active:gameplayCameraActive,enabled:gameplayCameraInputEnabled,controller:gameplayCamera});
for(const select of document.querySelectorAll('[data-camera-mode]'))select.addEventListener('change',()=>{const mode=Number(select.value);gameplayCamera().setMode(mode);for(const other of document.querySelectorAll('[data-camera-mode]'))other.value=String(mode);});

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
const rendererLightSlots=new RendererLightSlots(renderer,(...args)=>runtimeDiagnostics.record(...args));
const rendererLightSelection=new RendererLightSelection({report:(...args)=>runtimeDiagnostics.record(...args)});
const rendererModelPreparation=new RendererModelPreparation({renderer,scene,camera,shadowInstances:Boolean(rendererShadowTraversal.instances),cachePrograms:true,
 createRoot:asset=>buildObject(asset.model,asset.textures,asset.override,{previews:false,shareGeometry:true,managedMatrices:true}),destroyRoot:disposeVisualRoot,
 profile:()=>{
  const lighting=prepareRendererLights(scene,camera,{shadowBudget:rendererShadowBudget,lightSlots:rendererLightSlots,lightSelection:rendererLightSelection,focus:controls.target.toArray()}),shadows=[0,0,0];
  scene.traverseVisible(o=>{if(o.castShadow&&o.layers.test(camera.layers)){if(o.isPointLight)shadows[0]++;else if(o.isSpotLight)shadows[1]++;else if(o.isDirectionalLight)shadows[2]++;}});
  return JSON.stringify([Object.values(lighting.slots).map(s=>s.capacity),shadows,renderer.shadowMap.type,renderer.outputColorSpace,renderer.toneMapping,scene.fog?.type??null,scene.environment?.uuid??null,renderer.clippingPlanes.length]);
 },report:(...args)=>runtimeDiagnostics.record(...args)});
let frameTimingPublished=0;
const performanceView=new RendererPerformanceView(document.querySelector('#performance-debug'));
const rendererLightClock=()=>performance.now();
let rendererWarmupCount=0;
renderer.setAnimationLoop(() => {
  const frameStarted=performance.now();
  const delta = effectClock.getDelta();
  // Native animation scheduling uses elapsed world time even on a slow frame.
  // Clamping it made queued server rounds race through shortened catch-up clips.
  updateNetworkFrame(networkKeyboard,networkPresentation,delta);
  if(networkPresentation&&canvas.dataset.captureKeyboard==='true'){
    const id=networkFrontend?.world?.localObjectId,m=networkPresentation.motion.objects.get(id);
    if(m){const binding=networkPresentation.objects.get(id);canvas.dispatchEvent(new CustomEvent('nwn-keyboard-frame',{detail:{at:performance.now(),position:m.render.slice(),orientation:m.orientation.slice(),animation:m.animation,visualAnimation:binding?.combat?.visual??binding?.animation,clip:binding?.models[0].animator?.clip?.name,factor:m.factor,active:m.active,script:m.script,preview:m.previewBase,held:m.driveHeld,correction:m.correction}}));}
  }
  const networkUpdated=performance.now();
  if(networkPresentation&&performance.now()-networkCombatSnapshotAt>=200){networkCombatSnapshotAt=performance.now();canvas.dataset.networkCombat=JSON.stringify(networkPresentation.combat?.snapshot()??null);canvas.dataset.networkProjectiles=JSON.stringify(networkPresentation.projectiles?.snapshot()??null);canvas.dataset.networkScene=JSON.stringify(networkSceneSnapshot());}
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
  const gameCameraActive=gameplayCameraActive();
  if(gameCameraActive&&orbitConnected){controls.disconnect();orbitConnected=false;}
  else if(!gameCameraActive&&!orbitConnected){controls.connect(canvas);orbitConnected=true;}
  if(!gameCameraActive)controls.update();
  if(playerController?.keyboardMoving&&movementKeys.size===0)stopKeyboardMovement();
  if (simulationReady && !moduleLoadBusy && !gameUi.externalCapture && !moduleSession?.transitioning && !moduleSession?.player.cutscene?.enabled) updatePlayerMovement(delta);
  if (simulationReady && !moduleLoadBusy && !gameUi.externalCapture && !document.hidden && !moduleSession?.transitioning && (!moduleSession?.player.cutscene?.enabled || moduleSession.player.cutscene.leftClicks)) actionQueue?.update(Math.min(delta, 0.05));
  if (!document.hidden && worldObjects && moduleSession && !moduleSession.transitioning && !gameUi.externalCapture && !moduleLoadBusy) {
    if (simulationReady) moduleSession.scheduler.advance(Math.min(delta, 0.1) * 1000);
    gameAudio?.update();
    void moduleSession.scheduler.pump().catch(error => moduleSession.report(error));
  }
  if (!document.hidden&&simulationReady){
    try{clientPause?.flush();if(clientPause)canvas.dataset.clientPause=JSON.stringify(clientPause.snapshot());}catch(error){moduleSession?.report(error,{operation:'client-pause-presentation'});}
    creatureAnimations?.update();if(creatureAnimations)canvas.dataset.creatureAnimations=JSON.stringify(creatureAnimations.snapshot());
  }
  if (!document.hidden) for (const animator of activeAnimations) if(!animator.presentationOwned||animator.presentationPreview)animator.update(Math.min(delta, 0.1));
  if (!document.hidden && simulationReady) {
    if(!moduleLoadBusy&&!moduleSession?.transitioning&&visualDelivery&&moduleSession&&worldObjects)visualDelivery.flush({session:moduleSession,objects:worldObjects,presentation:loopingVisuals});
    loopingVisuals?.update(Math.min(delta, 0.1));
    if(!moduleLoadBusy&&!moduleSession?.transitioning&&projectileDelivery&&moduleSession&&worldObjects)projectileDelivery.flush({session:moduleSession,objects:worldObjects,presentation:projectiles});
    projectiles?.update(Math.min(delta,.1));
    for(const runtime of modelReferenceRuntimes.values())if(!runtime.owner.referenceParent&&!runtime.failed){
      try{runtime.update(Math.min(delta,.1));}catch(error){runtime.failed=true;runtimeDiagnostics.error(error,'model.reference-update-failed',{model:runtime.owner.resourceName});}
    }
    canvas.dataset.modelReferences=JSON.stringify([...modelReferenceRuntimes.values()].map(runtime=>({resource:runtime.owner.resourceName,failed:!!runtime.failed,children:runtime.models.map(model=>({resource:model.resourceName,position:model.root.position.toArray(),quaternion:model.root.quaternion.toArray()}))})));
    if(projectiles)canvas.dataset.projectiles=JSON.stringify(projectiles.snapshot());
    if (loopingVisuals) canvas.dataset.loopingVisuals = JSON.stringify(loopingVisuals.snapshot());
  }
  updateAnimationPlaybackStatus();
  updateDoorTarget();
  updateGameplayDiagnostics();
  if (simulationReady) gameUi.refresh();
  if (loadedRoot && previewEffectsEnabled.checked) updateEmitterPreviews(loadedRoot, effectClock.elapsedTime);
  const particlesStarted=performance.now();
  if(!document.hidden&&simulationReady){modelParticles.update(loadedRoot,delta);canvas.dataset.modelParticles=JSON.stringify(modelParticles.snapshot());canvas.dataset.pointWinds=JSON.stringify(modelParticles.pointWinds);}
  const particlesEnded=performance.now();
  gameplayCameraInput.update();
  if(networkPresentation){networkCamera.update(networkFrontend?.world,networkPresentation,camera,controls,delta,{keyholeActive:Boolean(cameraKeyhole?.shader&&networkPresentation.objects.has(networkFrontend.world.localObjectId))});canvas.dataset.networkCamera=JSON.stringify({...networkCamera.controller.snapshot(),controlledId:networkCamera.controlledId,targetId:networkCamera.targetId,attachmentId:networkCamera.attachmentId,waitingForTarget:networkCamera.waitingForTarget,anchor:networkCamera.anchor,position:camera.position.toArray(),target:controls.target.toArray()});networkGuiAudio?.update();networkAmbientAudio?.update(networkFrontend.world.time.timeOfDay);networkPlacedSounds?.update();canvas.dataset.networkAudio=JSON.stringify({listener:networkGuiAudio?.listenerState??null,...networkScriptAudio?.snapshot(),ambient:networkAmbientAudio?.snapshot(),placed:networkPlacedSounds?.snapshot()});}
  else updateScriptCamera(delta);
  const cameraAndAudioUpdated=performance.now();
  if(cameraKeyhole&&loadedRoot){const player=networkPresentation?networkPresentation.objects.get(networkFrontend.world.localObjectId)?.wrapper:playerController?.object;cameraKeyhole.update(loadedRoot,player?.position,gameplayCamera(),gameplayCameraActive());canvas.dataset.cameraKeyhole=JSON.stringify(cameraKeyhole.snapshot());}
  const keyholeUpdated=performance.now();
  networkFloating?.update(delta);
  const updatePointers=()=>{worldHighlights.update();worldPointer?.update();};
  if(reuseWorldPicking)withWorldPickFrame(networkPresentation,updatePointers);else updatePointers();
  const overlayUpdated=performance.now();
  const rendererLighting=prepareRendererLights(scene,camera,{shadowBudget:rendererShadowBudget,lightSlots:rendererLightSlots,lightSelection:rendererLightSelection,focus:controls.target.toArray(),delta:simulationReady?Math.min(delta,.1):0,clock:rendererLightClock});
  const lightingPrepared=performance.now();
  canvas.dataset.rendererLightSelection=JSON.stringify(rendererLighting.selection);
  canvas.dataset.rendererShadowBudget=JSON.stringify(rendererLighting.shadows);
  canvas.dataset.rendererLightSlots=JSON.stringify(rendererLighting.slots);
  canvas.dataset.rendererModelPreparation=JSON.stringify(rendererModelPreparation.snapshot());
  canvas.dataset.rendererModelGeometry=JSON.stringify(rendererModelGeometry.snapshot());
  canvas.dataset.rendererMainBatches=JSON.stringify(rendererMainBatches.snapshot());
  canvas.dataset.rendererLightUniforms=JSON.stringify(rendererLightUniforms.snapshot());
  canvas.dataset.rendererMaterialReuse=JSON.stringify(rendererMaterialReuse.snapshot());
  if(networkPresentation?.resourceWorkers)canvas.dataset.resourceWorkers=JSON.stringify(networkPresentation.resourceWorkers.snapshot());else delete canvas.dataset.resourceWorkers;
  const renderStarted=performance.now(),programsBefore=renderer.info.programs?.length??0;
  if(!rendererWarmupCount)renderPreparedScene(renderer,scene,camera,rendererLighting,rendererMainBatches,rendererLightUniforms,rendererMaterialReuse);
  const frameEnded=performance.now(),timing={intervalMs:delta*1000,totalMs:frameEnded-frameStarted,networkMs:networkUpdated-frameStarted,presentationMs:particlesStarted-networkUpdated,particlesMs:particlesEnded-particlesStarted,cameraAndShadowsMs:renderStarted-particlesEnded,renderMs:frameEnded-renderStarted,cameraStages:{cameraAndAudioMs:cameraAndAudioUpdated-particlesEnded,keyholeMs:keyholeUpdated-cameraAndAudioUpdated,overlayMs:overlayUpdated-keyholeUpdated,metadataMs:renderStarted-lightingPrepared,...rendererLighting.timings},programsBefore,programsAfter:renderer.info.programs?.length??0};
  performanceView.record({at:frameEnded,timing,rendered:!rendererWarmupCount,visible:!document.hidden,details:()=>({draw:renderer.info.render,shadow:rendererShadowTraversal.snapshot()??{},viewport:{width:canvas.clientWidth,height:canvas.clientHeight,bufferWidth:canvas.width,bufferHeight:canvas.height,pixelRatio:renderer.getPixelRatio()},lighting:rendererLighting,models:rendererModelPreparation.stats,particleWorkers:modelParticles.vertexSnapshot(),pendingAssets:networkPresentation?.assetPending??0,memory:renderer.info.memory,heapBytes:performance.memory?.usedJSHeapSize})});
  if(!document.hidden&&(timing.totalMs>250||timing.intervalMs>750))runtimeDiagnostics.record('renderer.frame-stall','Slow frame observed; durations separate frame work from time waiting between callbacks',timing);
  if(import.meta.env.VITE_BATCH_POOL_COMPARE==='1'&&batchPoolSamples&&batchPoolSamples.length<10000)batchPoolSamples.push({at:frameEnded,totalMs:timing.totalMs,renderMs:timing.renderMs,networkMs:timing.networkMs,particlesMs:timing.particlesMs,cameraMs:timing.cameraAndShadowsMs,draws:renderer.info.render.calls,batches:rendererMainBatches.enabled?(rendererMainBatches.stats.batches??0):0});
  if(frameEnded-frameTimingPublished>=200){frameTimingPublished=frameEnded;canvas.dataset.matrixSubtrees=JSON.stringify(matrixSubtreeSnapshot());canvas.dataset.managedMatrixReuse=JSON.stringify(managedMatrixReuseSnapshot());canvas.dataset.particleVertexWorkers=JSON.stringify(modelParticles.vertexSnapshot());canvas.dataset.shadowInstances=JSON.stringify(rendererShadowTraversal.instances?.snapshot()??null);canvas.dataset.preparedModelSources=JSON.stringify(persistentModelSources.snapshot());canvas.dataset.resourcePrefetch=JSON.stringify(networkPresentation?.sourcePrefetch.snapshot()??null);canvas.dataset.frameTimings=JSON.stringify({...timing,viewport:{width:canvas.clientWidth,height:canvas.clientHeight,bufferWidth:canvas.width,bufferHeight:canvas.height,pixelRatio:renderer.getPixelRatio(),devicePixelRatio:window.devicePixelRatio},draw:{...renderer.info.render},shadowTraversal:rendererShadowTraversal.snapshot()});}
});

const movementKeys = new Set();
let playerController = null;
let cameraFollowsPlayer = false;
const modelReferenceRuntimes=new Map();
const radialIconCache = new Map();
const radialMenu = new RadialMenu(viewport,{
  onVisibility: () => { controls.enabled = !gameUi?.blocksWorldInput && !moduleSession?.player.cutscene?.enabled; if(gameUi?.blocksWorldInput)movementKeys.clear(); pointerPress = null; },
  loadIcon: name => {
    const resolver = networkPresentation?.resolver ?? activeAreaResolver ?? gameDataResolver;
    if (!resolver) return Promise.resolve(null);
    if (!radialIconCache.has(name)) radialIconCache.set(name,(async () => {
      try {
        const image = await portraitImage(resolver,name.toLowerCase());
        const icon = document.createElement('canvas'); icon.width = image.width; icon.height = image.height;
        icon.getContext('2d').putImageData(new ImageData(new Uint8ClampedArray(image.data),image.width,image.height),0,0);
        return icon.toDataURL();
      } catch (error) { runtimeDiagnostics.error(error, 'ui.radial-icon-unavailable', { resRef: name }); return null; }
    })());
    return radialIconCache.get(name);
  },
  onAction: (entry,context) => {
    if(context.localSpellFamily){if(moduleSession===context.session&&moduleSession?.player.areaId===context.request.areaId&&entry.action==='spell.variant'&&spellFamilyContains(moduleSession.characterRules,context.request.spellId,entry.binding.intParam))beginSpellCast({...context.request,spellId:entry.binding.intParam});return;}
    if(context.networkQuickbar){if(context.sessionId===networkFrontend.id&&context.areaGeneration===networkFrontend.areaGeneration&&context.actorId===networkFrontend.world?.localObjectId&&entry.action==='quickbar.assign')void networkQuickbar.assign(context.quickbarIndex,entry.binding);return;}
    if(context.network){void submitNetworkRadialAction(entry,context);return;}
    if(entry.action==='quickbar.assign'){gameUi.assignQuickbar(context.quickbarIndex,entry.binding);return;}
    if (moduleSession?.player.cutscene?.enabled || moduleSession?.conversation.state) return;
    const actor = playerController?.actor,target=context.inventory?moduleSession?.registry.get(context.targetId):worldObjects?.get(context.targetId);
    if (!target || !actor || (context.inventory?!isPlayerInventoryItem(target):target.areaId !== actor.areaId)) { doorFeedback.textContent = 'Radial target is no longer available'; return; }
    const request = radialActionRequest(entry,target,actor,context.groundPoint);
    canvas.dataset.lastRadialAction = JSON.stringify(request);
    if(entry.action==='item.use'&&entry.binding){beginItemUse(entry.binding);return;}
    if(entry.action==='item.learn'){submitLearnScroll({...request,areaId:actor.areaId,itemId:target.id});return;}
    if(entry.action==='feat.use'){
      const session=moduleSession,selection=selectRadialFeat((entry.binding.featId&65535)|((entry.binding.auxiliary&65535)<<16),{
        controlled:true,assignment:false,self:!context.ground&&target.id===actor.id,
        feat:id=>featActivationInfo(session.characterRules,id),warning:message=>runtimeDiagnostics.record('ui.native-feat-selection-warning',message,request)
      });
      if(selection.mode==='mode'){
        void session.queuePlayerMode(selection.modeId).catch(error=>session.report(error,{operation:'radial-feat-mode'}));return;
      }
      const binding={action:'feat.use',actorId:actor.id,areaId:actor.areaId,featId:selection.featId,auxiliary:selection.auxiliary};
      if(selection.mode==='target'){beginFeatUse(binding);return;}
      if(selection.mode==='use'){
        const point=context.ground?context.groundPoint:target.id===actor.id?[0,0,0]:target.position;
        if(!point){gameUi.notify('No ground position was selected');return;}
        submitFeatUse(binding,context.ground?OBJECT_INVALID:target.id,[point[0],-point[2],point[1]]);
      }
      return;
    }
    if(entry.action==='character.cancelPolymorph'){
      const session=moduleSession;void session.queuePlayerCancelPolymorph().catch(error=>session.report(error,{...session.diagnosticContext(actor.id),operation:'radial-cancel-polymorph'}));return;
    }
    if(entry.action==='associate.command'){
      const session=moduleSession;
      void session.queuePlayerAssociateCommand(target.id,entry.command).catch(error=>session.report(error,{...session.diagnosticContext(actor.id),targetId:target.id,operation:'radial-associate-command'}));return;
    }
    if(entry.action==='spell.counterspell'){
      const session=moduleSession;
      void session.queuePlayerMode(5,target.id).then(()=>{
        if(moduleSession===session)gameUi.message(`Counterspell requested: ${target.name||target.tag||target.id}`,'system');
      }).catch(error=>session.report(error,{...session.diagnosticContext(actor.id),targetId:target.id,operation:'radial-counterspell'}));return;
    }
    if(entry.action==='spell.defensiveCasting'){
      const session=moduleSession;
      void session.queuePlayerMode(10).then(()=>{
        if(moduleSession===session)gameUi.message(session.player.pendingCombatMode===9?'Defensive casting pending':session.player.combatMode===9?'Defensive casting enabled':'Defensive casting disabled','system');
      }).catch(error=>session.report(error,{...session.diagnosticContext(actor.id),operation:'radial-defensive-casting'}));return;
    }
    if(entry.action==='spell.cast'||entry.action==='spellLike.use'){
      const castTarget=context.ground?null:target,session=moduleSession;
      const spell=session.spellBook.castingSpell(entry.binding.spellId);
      if(!radialSpellTargetAllowed(spell,actor,castTarget)){gameUi.notify('That is not a valid target for this spell');return;}
      const point=context.ground?context.groundPoint:target.id===actor.id?[0,0,0]:target.position;
      if(!point){gameUi.notify('No ground position was selected');return;}
      const nativePoint=[point[0],-point[2],point[1]];
      const cast={...radialSpellCastRequest(entry.binding,actor,castTarget,nativePoint),action:entry.action};
      submitSpellCast(cast,cast.targetId,cast.position,cast.location);return;
    }
    if (entry.action === 'door.toggle' && target.kind === 'door') {
      actionQueue?.request(target.id,target.animationState === 0 ? 'open' : 'close');
      return;
    }
    if (entry.action === 'object.examine') { gameUi.examineId = target.id; gameUi.open('examine'); return; }
    if (entry.action === 'conversation.start') { actionQueue?.request(target.id, 'talk'); return; }
    if (entry.action === 'placeable.use') { submitWorldUse(target); return; }
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
  hasPendingAction: () => Boolean(pendingSpellTarget||actionQueue?.current||moduleSession?.player.objectActionState?.list.count),
  onCancelAction: () => {if(pendingSpellTarget){cancelSpellTarget(true);return;}actionQueue?.cancel();void moduleSession?.queuePlayerClearActions().catch(error=>moduleSession?.report(error));},
  onInputCapture: captured => { if (captured){radialMenu.close();if(gameUi.state.panel!=='inventory')cancelSpellTarget();} controls.enabled = !gameUi.blocksWorldInput && !moduleSession?.player.cutscene?.enabled; if(gameUi.blocksWorldInput)movementKeys.clear(); pointerPress = null; },
  onOpenModule: () => areaInput.click(),
  onSettings: settings => { if (settings.wireframe !== wireframe) wireButton.click(); },
  onQuickbarMenu:(menu,index,event)=>radialMenu.open(menu,event.clientX,event.clientY,{targetId:moduleSession.player.id,quickbarIndex:index}),
  onItemTarget:id=>{
    if(!pendingSpellTarget)return false;
    const pending=pendingSpellTarget,item=moduleSession?.registry.get(id);
    if(pending.session!==moduleSession||pending.request.areaId!==moduleSession.player.areaId){cancelSpellTarget();return true;}
    if(!isPlayerInventoryItem(item)||!pendingTargetAllowed(pending,item)){
      gameUi.notify('That is not a valid target for this spell');return true;
    }
    submitPendingTarget(pending,item.id,[0,0,0],0);return true;
  },
  onItemMenu:(id,event)=>{
    if(pendingSpellTarget){cancelSpellTarget(true);return;}
    const item=moduleSession?.registry.get(id),actor=moduleSession?.player;
    if(!isPlayerInventoryItem(item)||(item.nativeItemPending240??0)!==0||actor.cutscene?.enabled||moduleSession.conversation.state)return;
    radialMenu.open(buildRadialActions(item,actor,{title:gameUi.objectName(item),castMenu:()=>gameUi.worldSpellMenu(item,{filter:8}),itemUseEntries:()=>gameUi.itemUseEntries(item)}),event.clientX,event.clientY,{targetId:item.id,inventory:true});
  },
  onRequest: request => {
    if(request.action==='character.sheet'){
      const session=moduleSession;if(!session||request.actorId!==session.player.id)return;
      void session.queuePlayerCharacterSheet(request).catch(error=>session.report(error,{...session.diagnosticContext(request.actorId),operation:'ui-character-sheet'}));return;
    }
    if(['inventory.status','inventory.page','container.close','container.page','inventory.move','item.container.open'].includes(request.action)){
      const session=moduleSession;if(!session||request.actorId!==session.player.id)return;let input;
      if(request.action==='inventory.status')input=session.queuePlayerInventoryStatus(request.value,request.ownerId);
      else if(request.action==='inventory.page')input=session.queuePlayerInventoryPanel(request.panel,request.primary);
      else if(request.action==='container.close')input=session.queuePlayerContainerInput(1);
      else if(request.action==='container.page')input=session.queuePlayerContainerInput(request.subtype);
      else if(request.action==='item.container.open')input=session.queuePlayerUseObject(request.itemId,{popup:1});
      else input=session.queuePlayerRepositoryMove(request.itemId,request.destination,request.x,request.y);
      void input.catch(error=>session.report(error,{...session.diagnosticContext(request.actorId),operation:`ui-${request.action}`}));return;
    }
    if(request.action==='item.use'){beginItemUse(request);return;}
    if(request.action==='item.learn'){submitLearnScroll(request);return;}
    if(request.action==='spell.prepare'){
      const session=moduleSession;if(!session)return;void session.queuePlayerSpellPreparation(request).catch(error=>session.report(error,{...session.diagnosticContext(request.actorId),operation:'ui-spell-preparation'}));return;
    }
    if(request.action==='rest'){
      const session=moduleSession;if(!session)return;cancelSpellTarget();void session.queuePlayerRest(request).catch(error=>session.report(error,{...session.diagnosticContext(request.actorId),operation:'ui-rest'}));return;
    }
    if(request.action==='spell.cast'||request.action==='spellLike.use'){beginSpellCast(request);return;}
    if(request.action==='feat.use'){beginFeatUse(request);return;}
    if (request.action === 'character.load' || request.action === 'character.create') { void openCharacters(request.action === 'character.create'); return; }
    if(request.action==='action.queue.cancel'){
      const session=moduleSession;if(!session)return;
      void session.queuePlayerCancelAction(request.actionId,request.groupId).catch(error=>session.report(error,{operation:'ui-queue-cancel'}));return;
    }
    if (request.action === 'door.use') {
      if (worldObjects?.get(request.targetId)?.areaId !== moduleSession?.player.areaId) { gameUi.notify('That object is in another area'); return; }
      const target=worldObjects.get(request.targetId);if(target.objectType===9)submitWorldUse(target);else actionQueue?.use(request.targetId);return;
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

function isPlayerInventoryItem(item){const actor=moduleSession?.player;return Boolean(actor&&item?.objectType===6&&item.possessorId===actor.id&&actor.inventory?.includes(item.id));}
function cancelSpellTarget(notify=false){const active=Boolean(pendingSpellTarget);pendingSpellTarget=null;delete canvas.dataset.spellTarget;canvas.style.cursor='';if(active&&notify)gameUi.notify('Spell targeting canceled');}
function submitSpellCast(request,targetId,position,location){
  const session=moduleSession;if(!session)return;
  cancelSpellTarget();movementKeys.clear();actionQueue?.cancel();
  canvas.dataset.lastSpellRequest=JSON.stringify({...request,targetId,position,location});delete canvas.dataset.lastSpellAccepted;
  const ability=request.action==='spellLike.use';
  void (ability?session.queuePlayerSpellLike({...request,targetId,position,location}):session.queuePlayerCastSpell({...request,targetId,position,location})).then(accepted=>{
    if(moduleSession!==session)return;
    canvas.dataset.lastSpellAccepted=String(accepted);
    gameUi.message(ability?'Ability requested':accepted?'Spell queued':'Spell request rejected','system');
  }).catch(error=>session.report(error,{...session.diagnosticContext(request.actorId),spellId:request.spellId,operation:'ui-spell-cast'}));
}
function beginSpellCast(request){
  const session=moduleSession;if(!session)return;
  if(request.actorId!==session.player.id||request.areaId!==session.player.areaId)return;
  if(isSpellFamily(session.characterRules,request.spellId)){
    cancelSpellTarget();void spellShortcutChoice(session.characterRules,{type:request.action==='spellLike.use'?44:2,intParam:request.spellId,classIndex:request.classIndex,domainLevel:request.domainLevel,metamagic:request.metamagic},async id=>({label:gameUi.ruleName('spells',id)})).then(choice=>{if(moduleSession!==session||session.player.areaId!==request.areaId)return;if(!choice?.children?.length){gameUi.notify('No valid variants are available for this spell');return;}const bounds=canvas.getBoundingClientRect();radialMenu.open(quickbarChoiceMenu(choice.label,choice.children,'spell.variant'),bounds.left+bounds.width/2,bounds.top+bounds.height/2,{localSpellFamily:true,session,request});radialMenu.clickMode=true;}).catch(error=>session.report(error));return;
  }
  // Read panel state before closeAll. Native mask9 suppresses automatic self
  // targeting while the inventory/container targeter is active.
  const plan=prepareSpellTarget(session.player,request,spellTargetProviders(session),{inventoryMode:gameUi.state.panel==='inventory'?1:null});
  if(plan.mode==='unavailable'){gameUi.notify('Spell unavailable');return;}
  const spell=plan.definition;
  gameUi.closeAll();radialMenu.close();
  const cast={...plan.request,classIndex:request.classIndex,metamagic:request.metamagic??0,domainLevel:request.domainLevel??0};
  if(plan.mode==='self'){
    const point=session.player.position,nativePoint=[point[0],-point[2],point[1]],selected=radialSpellCastRequest(cast,session.player,session.player,nativePoint);
    submitSpellCast({...cast,...selected,action:cast.action},selected.targetId,selected.position,selected.location);return;
  }
  pendingSpellTarget={session,request:cast,definition:spell};canvas.dataset.spellTarget=String(cast.spellId);canvas.style.cursor='crosshair';
  gameUi.notify(spell.targetType&8?'Choose a target in the world or inventory · Escape or right-click to cancel':'Choose a spell target · Escape or right-click to cancel');
}
function spellTargetProviders(session){return {spell:id=>{const spell=session.spellBook.castingSpell(id);return spell?{...spell,children:talentSpell(session.characterRules,id).children}:null;}};}
function featTargetProviders(session){return {feat:id=>featActivationInfo(session.characterRules,id),spell:id=>featActivationSpell(session.characterRules,id)};}
function itemTargetProviders(session){return{
 item:id=>{const o=session.registry.get(id);return o?.objectType===6?o:null;},property:(o,index)=>o.activeProperties[index]??null,
 propertySpell:(o,index)=>{const prop=o.activeProperties[index];return prop?session.items.castProviders().spellIndex(prop.subtype):-1;},
 spell:id=>{const spell=session.spellBook.castingSpell(id);return spell?{...spell,children:talentSpell(session.characterRules,id).children}:null;},
 subRadialSpell:(spell,index)=>{if(index<spell.children.length)return spell.children[index];runtimeDiagnostics.record('ui.native-item-variant-warning','Requested item spell variant is outside the valid range',{spellId:spell.id,index});return -1;},
 baseInfo:o=>session.items.baseInfo(o),controlledId:()=>session.player.id,creature:id=>{const o=session.registry.get(id);return o?.objectType===5?o:null;},
 preview:spell=>runtimeDiagnostics.record('ui.item-target-preview-unimplemented','Native item spell targeting preview presentation is unavailable',{spellId:spell.id}),
 warning:message=>runtimeDiagnostics.record('ui.native-item-target-warning',message)
};}
function submitLearnScroll(request){
 const session=moduleSession,actor=session?.player,item=session?.registry.get(request.itemId);
 if(!session||!isPlayerInventoryItem(item)||actor.id!==request.actorId||actor.areaId!==request.areaId)return;
 canvas.dataset.lastScrollLearnRequest=JSON.stringify(request);
 void selectLearnScroll(item.id,{item:id=>{const o=session.registry.get(id);return o?.objectType===6?o:null;},transport:()=>session,
  send:async(_transport,id)=>{const ack=await session.queuePlayerLearnScroll({...request,itemId:id});if(moduleSession!==session)return;canvas.dataset.lastScrollLearnResult=JSON.stringify({ack,...session.items.lastLearnScroll});gameUi.refresh(true);}})
 .catch(error=>session.report(error,{...session.diagnosticContext(actor.id),itemId:item.id,operation:'ui-scroll-learning'}));
}
function submitWorldUse(target,{notify=0}={}){
 const session=moduleSession;if(!session||session.registry.get(target.id)!==target||target.areaId!==session.player.areaId)return;
 actionQueue?.cancel();movementKeys.clear();
 void session.queuePlayerUseObject(target.id,{popup:1,notify}).then(accepted=>{
  if(moduleSession===session)doorFeedback.textContent=accepted?`Use requested: ${target.name||target.tag||target.id}`:'Use input was rejected';
 }).catch(error=>session.report(error,{...session.diagnosticContext(session.player.id),targetId:target.id,operation:'ui-use-object'}));
}
function beginItemUse(request){
 const session=moduleSession;if(!session||request.actorId!==session.player.id||request.areaId!==session.player.areaId)return;
 const item=session.registry.get(request.itemId);if(!isPlayerInventoryItem(item)){gameUi.notify('Item unavailable');return;}
 if((request.propertyIndex&65535)===255){runtimeDiagnostics.record('ui.item-equipment-activation-unimplemented','Native non-property item shortcut activation owner is not connected',{itemId:item.id,secondaryItemId:request.secondaryItemId});gameUi.notify('This item shortcut requires its equipment or container action');return;}
 const packed=request.packed??((request.propertyIndex&65535)|((request.variant??request.subPropertyIndex??255)<<16)),
  plan=prepareItemTarget(item.id,packed,itemTargetProviders(session),{inventoryMode:gameUi.state.panel==='inventory'?1:0});
 if(plan.mode==='unavailable'){gameUi.notify('Item action unavailable');return;}
 const binding={...request,action:'item.use',packed};
 gameUi.closeAll();radialMenu.close();
 if(plan.mode==='self'){submitItemUse(binding,plan.targetId,plan.point);return;}
 if(!plan.targetTypes.length){gameUi.notify('No targets are available for this item action');return;}
 pendingSpellTarget={session,request:binding,itemPlan:plan};canvas.dataset.spellTarget=`item:${item.id}:${packed>>>0}`;canvas.style.cursor='crosshair';
 gameUi.notify(plan.targetTypes.some(([type])=>type===6)?'Choose an item target in the world or inventory · Escape to cancel':'Choose an item action target · Escape to cancel');
}
function submitItemUse(request,targetId,point){
 const session=moduleSession;if(!session||request.actorId!==session.player.id||request.areaId!==session.player.areaId)return;
 cancelSpellTarget();movementKeys.clear();actionQueue?.cancel();
 const state={itemId:request.itemId,packed:request.packed,targetId,point:[...point]};canvas.dataset.lastItemRequest=JSON.stringify(state);delete canvas.dataset.lastItemInputResult;
 void confirmItemTarget(state,{...itemTargetProviders(session),player:()=>session.player,
  position:o=>[o.position[0],-o.position[2],o.position[1]].map(Math.fround),
  use:(_actor,id,packed,target,position)=>sendItemUse(id,packed,target,position,{transport:()=>session.player,
   send:async(_transport,itemId,propertyIndex,variant,targetId,position)=>{
    canvas.dataset.lastItemRequest=JSON.stringify({itemId,packed,targetId,point:position});
    // Native writer7c0610 omits variant255, which input9 decodes as0;
    // it transmits XYZ exactly when the FLOAT vector is nonzero (scale1).
    const result=await session.queuePlayerUseItem({actorId:request.actorId,areaId:request.areaId,itemId,propertyIndex,variant:(variant&255)===255?0:variant&255,targetId,position,location:Number(position.some(v=>v!==0))});
    if(moduleSession===session){canvas.dataset.lastItemInputResult=String(result);gameUi.message('Item use requested','system');}
   }}),clearPreview:()=>{},clearRange:()=>{},dispose:()=>{}})
  .catch(error=>session.report(error,{...session.diagnosticContext(request.actorId),itemId:request.itemId,operation:'ui-item-use'}));
}
function beginFeatUse(request){
 const session=moduleSession;if(!session||request.actorId!==session.player.id||request.areaId!==session.player.areaId)return;
 const plan=prepareFeatTarget(request,featTargetProviders(session));if(plan.mode==='unavailable'){gameUi.notify('Feat unavailable');return;}
 gameUi.closeAll();radialMenu.close();
 if(plan.mode==='mode'){
  cancelSpellTarget();void session.queuePlayerMode(plan.modeId).catch(error=>session.report(error,{...session.diagnosticContext(session.player.id),operation:'ui-feat-mode'}));return;
 }
 if(plan.mode==='self'){submitFeatUse(plan.request,session.player.id,[0,0,0]);return;}
 pendingSpellTarget={session,request:plan.request,definition:plan.definition};canvas.dataset.spellTarget=`feat:${plan.request.featId}`;canvas.style.cursor='crosshair';
 gameUi.notify('Choose an ability target · Escape or right-click to cancel');
}
function submitFeatUse(request,targetId,position){
 const session=moduleSession;if(!session)return;
 cancelSpellTarget();movementKeys.clear();actionQueue?.cancel();canvas.dataset.lastFeatRequest=JSON.stringify({...request,targetId,position});delete canvas.dataset.lastFeatAccepted;
 void session.queuePlayerFeat({...request,targetId,position}).then(accepted=>{if(moduleSession!==session)return;canvas.dataset.lastFeatAccepted=String(accepted);gameUi.message(accepted?'Feat requested':'Feat request rejected','system');})
  .catch(error=>session.report(error,{...session.diagnosticContext(session.player.id),featId:request.featId,operation:'ui-feat-use'}));
}
function pendingTargetAllowed(pending,target){
 if(pending.request.action==='item.use'){
  if(!pending.itemPlan.targetTypes.some(([type])=>type===(target?.objectType??2)))return false;
  return !pending.itemPlan.creatureVeto||itemCreatureTargetVeto(pending.request.itemId,pending.request.packed,target?.id??OBJECT_INVALID,itemTargetProviders(pending.session))===0;
 }
 if(pending.request.action==='feat.use')return featTargetAllowed(prepareFeatTarget(pending.request,featTargetProviders(pending.session),{autoSelf:0}).definition,target);
 return radialSpellTargetAllowed(spellTargetDefinition(pending.request.spellId,spellTargetProviders(pending.session)),pending.session.player,target);
}
function submitPendingTarget(pending,targetId,position,location){if(pending.request.action==='item.use')submitItemUse(pending.request,targetId,position);else if(pending.request.action==='feat.use')submitFeatUse(pending.request,targetId,position);else submitSpellCast(pending.request,targetId,position,location);}

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
  if(event.key==='Escape'&&pendingSpellTarget){event.preventDefault();cancelSpellTarget(true);return;}
  if (event.defaultPrevented||isTextEntry(event.target)||isControlArrow(event)) return;
  const key = event.key.toLowerCase();
  if (gameUi.blocksWorldInput || moduleSession?.player.cutscene?.enabled) return;
  if(key==='f'&&networkFrontend?.id&&networkPresentation){const binding=networkPresentation.objects.get(networkFrontend.world.localObjectId);if(binding){event.preventDefault();focusPlayer(binding.wrapper);}return;}
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
  if (isTextEntry(event.target)) movementKeys.clear();
});
doorAction.addEventListener('click', () => interactWithDoor());
const playerActions = document.querySelector('#player-actions');
const openPlayerActions = (x,y) => {
  if(networkFrontend?.id&&networkPresentation){openNetworkRadial(null,x,y,true);return;}
  if (moduleSession?.player.cutscene?.enabled || moduleSession?.conversation.state || gameUi.captured) return;
  const actor = playerController?.actor;
  if (!actor) return;
  radialMenu.open(buildRadialActions(actor,actor,{castMenu:()=>gameUi.worldSpellMenu(actor),abilityMenu:()=>gameUi.worldAbilityMenu(actor)}),x,y,{targetId:actor.id,groundPoint:null});
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
canvas.tabIndex=-1;
canvas.addEventListener('pointerdown',()=>canvas.focus({preventScroll:true}));
canvas.addEventListener('pointerdown', event => {
  if (gameUi.blocksWorldInput) return;
  if (event.button === 0 && playerController) pointerPress = { id: event.pointerId, x: event.clientX, y: event.clientY };
});
canvas.addEventListener('contextmenu',event => { if (worldObjects) event.preventDefault(); });
canvas.addEventListener('pointerdown',event => {
  if(event.button===2&&pendingSpellTarget){event.preventDefault();event.stopImmediatePropagation();cancelSpellTarget(true);return;}
  if (gameUi.blocksWorldInput || moduleSession?.player.cutscene?.enabled) return;
  if (event.button !== 2 || !worldObjects || !playerController?.actor) return;
  event.preventDefault(); event.stopImmediatePropagation();
  const hit = pickedWorldObject(pointerRay(event.clientX,event.clientY,canvas.getBoundingClientRect(),camera),loadedRoot,worldObjects,{includePlayer:true});
  const target = hit?.object ?? playerController.actor;
  selectedWorldObject = hit?.object ?? null;
  const options={castMenu:()=>gameUi.worldSpellMenu(hit?.object??null),abilityMenu:()=>gameUi.worldAbilityMenu(hit?.object??null)};
  const menu = hit?.object ? buildRadialActions(target,playerController.actor,options) : buildGroundRadialActions(playerController.actor,options);
  radialMenu.open(menu,event.clientX,event.clientY,
    { targetId:target.id,groundPoint:hit?.point.toArray() ?? null,ground:!hit?.object });
},true);
canvas.addEventListener('pointercancel', () => { pointerPress = null; });
canvas.addEventListener('pointerup', event => {
  if (gameUi.blocksWorldInput || moduleSession?.player.cutscene?.enabled && !moduleSession.player.cutscene.leftClicks) { pointerPress = null; return; }
  const press = pointerPress; pointerPress = null;
  if (!press || event.button !== 0 || press.id !== event.pointerId || Math.hypot(event.clientX - press.x, event.clientY - press.y) > 5 || !worldObjects) return;
  if(pendingSpellTarget){
    const pending=pendingSpellTarget;
    if(pending.session!==moduleSession||pending.request.areaId!==moduleSession.player.areaId){cancelSpellTarget();return;}
    const hit=pickedWorldObject(pointerRay(event.clientX,event.clientY,canvas.getBoundingClientRect(),camera),loadedRoot,worldObjects,{includePlayer:true});
    if(!hit)return;
    const target=hit.object;
    if(target&&pendingTargetAllowed(pending,target)){submitPendingTarget(pending,target.id,[0,0,0],0);return;}
    if(!target&&pendingTargetAllowed(pending,null)){const point=hit.point.toArray();submitPendingTarget(pending,0x7f000000,[point[0],-point[2],point[1]],1);return;}
    gameUi.notify('That is not a valid target for this spell');return;
  }
  const hit = pickedWorldObject(pointerRay(event.clientX, event.clientY, canvas.getBoundingClientRect(), camera), loadedRoot, worldObjects);
  if(!hit)return;
  if(!hit.object){
    const point=hit.point.toArray(),height=findWalkableHeight(playerController.triangles,point[0],point[2],point[1],.9);
    if(height===null){gameUi.notify('That point is not on walkable ground');return;}
    movementKeys.clear();playerController.keyboardMoving=false;selectedWorldObject=null;actionQueue?.cancel('Moving to ground destination');
    animationIsolate.checked=false;updateAnimationIsolation();
    submitPlayerMovement([point[0],height,point[2]],event.shiftKey?0:1,'ground');return;
  }
  selectedWorldObject = hit.object;
  movementKeys.clear();
  playerController.keyboardMoving=false;
  animationIsolate.checked = false; updateAnimationIsolation();
  if(hit.object.objectType===9)submitWorldUse(hit.object,{notify:1});else actionQueue?.use(hit.object.id);
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
  gameAudio?.dispose(); gameAudio = null;voicePresentation?.dispose();voicePresentation=null;
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
    gameAudio?.dispose();voicePresentation?.dispose();
    gameAudio = new GameAudio(resolver, {
      getObject: id => moduleSession?.registry.get(id), getPlayer: () => moduleSession?.player,
      onState: state => { canvas.dataset.audio = JSON.stringify(state); },
      onDiagnostic: message => { console.warn('[Audio]', message); canvas.dataset.audioError = message; gameUi.message(message, 'system'); }
    });
    const voiceAudio=gameAudio;voicePresentation=new VoicePresentation(resolver,{
      getObject:id=>moduleSession?.registry.get(id),getPlayer:()=>moduleSession?.player,getText:()=>gameUi.text,
      onCaption:event=>{const actor=moduleSession?.registry.get(event.actorId);gameUi.message(`[${actor?gameUi.objectName(actor):'Creature'}]: ${event.text}`,'message');
        canvas.dataset.voiceCaption=JSON.stringify(event);},onSound:event=>voiceAudio.play(event)
    });
    const previousSession = moduleSession;
    creatureAnimations?.clear();creatureAnimations=null;
    let nextSession;
    const nextVisualDelivery=new ObjectVisualInbox({session:()=>nextSession,report:(code,message,data)=>runtimeDiagnostics.record(code,message,data)});
    const nextProjectileDelivery=new ClientProjectileInbox({session:()=>nextSession,report:(code,message,data)=>runtimeDiagnostics.record(code,message,data)});
    const nextSpellPresentation=new ClientSpellPresentation({session:()=>nextSession,text:()=>gameUi.text,display:text=>gameUi.message(text,'combat',{allowRepeat:true}),report:(code,message,data)=>runtimeDiagnostics.record(code,message,data)});
    const nextClientPause=new ClientPausePresentation({session:()=>nextSession,scene:id=>creatureAnimations?.bindings.get(id)??null,report:(code,message,data)=>runtimeDiagnostics.record(code,message,data)});
    nextSession = new ModuleSession(resolver, {
      talkFiles:gameUi.languageFiles??[],
      runStartupScripts: document.querySelector('#run-module-startup').checked,
      // Skipping opening scripts must still leave perception and combat active.
      runNativeAI: true,
      serverPvpSetting: Number(document.querySelector('#session-pvp-setting').value),
      onSound: event => gameAudio.play(event),
      onCameraMode: (actor, mode) => {
        if (actor !== moduleSession?.player) return;
        canvas.dataset.cameraScriptMode=String(mode);
        cameraFollowsPlayer = true;
        updateScriptCamera(0, true);
        for(const select of document.querySelectorAll('[data-camera-mode]'))select.value=String(mode);
      },
      onCombatMessage: event=>{
        if(nextClientPause.receive(event))return;
        if(nextProjectileDelivery.receive(event))return;
        if(nextVisualDelivery.receive(event))return;
        if(nextSpellPresentation.receive(event)){if(gameUi.session===nextSession){nextSpellPresentation.flush();canvas.dataset.spellMessages=JSON.stringify(nextSpellPresentation.snapshot());}return;}
        if(moduleSession&&event.recipientId!==moduleSession.player?.id)return;
        if(event.type==='quick-chat'||event.type==='voice-chat'){void voicePresentation?.receive(event);return;}
        if(event.type==='chat-strref'){gameUi.message({...event,type:'speech-reference'},'talk');return;}
        if(event.type==='debug-info-string'){gameUi.message(event.text,'system');return;}
        if(event.type==='polymorph')return; // Live appearance sync below owns model replacement after canonical mutation.
        if(gameUi.receiveInventoryMessage(event))return;
        const handled=creatureAnimations?.receive(event);
        if([5,6].includes(event.type)&&event.attack){
          const [actorId,targetId]=event.data.objects,actor=moduleSession.registry.get(actorId),target=moduleSession.registry.get(targetId),attack=event.attack;
          gameUi.message(`${actor?.name||actor?.tag||'Creature'} attacks ${target?.name||target?.tag||'target'}: ${attack.roll} + ${attack.modifier} = ${attack.roll+attack.modifier}; ${attackResultDoesDamage(attack.result)?`hit (${totalAttackDamage(attack)} damage)`:'miss or defended'}`,'combat');
          if(!handled)runtimeDiagnostics.record('combat.animation-unavailable','Combat attack has no available creature animation binding',{actorId,targetId});
        }else if(event.type===11&&[93,94].includes(event.data?.integers?.[9])){
          const ref=event.data.integers[9]===93,text=ref?gameUi.text.strRef(event.data.integers[0]>>>0):event.data.strings?.[0];
          if(text)gameUi.message(text,'message');
          if(event.data.integers[ref?1:0]!==0)runtimeDiagnostics.record('combat.floating-text-sound-unimplemented','Native floating-text sound playback is unavailable',{
            recipientId:event.recipientId,objectId:event.data.objectIds?.[0],feedbackCode:event.data.integers[9]});
        }else if(event.type===12){
          const [casterId,counterId]=event.data.objects,caster=moduleSession.registry.get(casterId),counter=moduleSession.registry.get(counterId);
          const [incoming,selected,identified]=event.data.integers,spellName=ref=>gameUi.text.resolve({strRef:ref>>>0,entries:[]})||'spell';
          gameUi.message(`${counter?.name||counter?.tag||'Creature'} counters ${caster?.name||caster?.tag||'creature'}'s ${identified?spellName(incoming):'spell'}${identified?` using ${spellName(selected)}`:''}`,'combat');
        }else runtimeDiagnostics.record('combat.presentation-unimplemented','Native combat message presentation is not implemented',{messageType:event.type,recipientId:event.recipientId});
      },
      onConversation: () => { radialMenu.close(); gameUi.conversationChanged(); },
      onClearActions: id => { if (id === moduleSession?.player.id) actionQueue?.cancel('Actions cleared'); },
      onCutscene: (actor, enabled) => {
        if (actor !== moduleSession?.player) return;
        movementKeys.clear(); pointerPress = null; radialMenu.close();
        if (enabled) {
          actor.savedCutsceneCamera = { position: camera.position.toArray(), target: controls.target.toArray(), follows: cameraFollowsPlayer, native:structuredClone(singlePlayerCamera) };
          actionQueue?.cancel('Cutscene mode');
        } else if (actor.savedCutsceneCamera) {
          camera.position.fromArray(actor.savedCutsceneCamera.position); controls.target.fromArray(actor.savedCutsceneCamera.target);
          cameraFollowsPlayer = actor.savedCutsceneCamera.follows; controls.update();
          if(actor.savedCutsceneCamera.native)Object.assign(singlePlayerCamera,actor.savedCutsceneCamera.native);
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
    });
    moduleSession=await nextSession.initialize(areaResRefs, { character: selectedCharacter?.bytes });
    clientPause=nextClientPause;
    visualDelivery=nextVisualDelivery;
    projectileDelivery=nextProjectileDelivery;
    previousSession?.cancelPendingPlayerInputs();
    if (selectedCharacter) moduleSession.player.characterFile = selectedCharacter.name;
    moduleSession.quickbarProfileKey=selectedCharacter?.id??null;
    await gameUi.attach(moduleSession, resolver);
    nextSpellPresentation.flush();canvas.dataset.spellMessages=JSON.stringify(nextSpellPresentation.snapshot());
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

async function loadTextures(files, resolver = null, pltColorRows = new Map(), sources = null) {
  const tgaLoader = {parse:parseNativeTga};
  const ddsLoader = new DDSLoader();
  const textures = new Map();
  let paletteImages = new Map();
  const hasPltFiles = files.some((file) => file.name.toLowerCase().endsWith('.plt'));
  if (hasPltFiles && resolver) {
    const readPalettes=async()=>new Map((await Promise.all([...new Set(PLT_PALETTE_NAMES)].map(async paletteName=>{
      try {
        const bytes=await resolver.getResource(paletteName, RESOURCE_TYPE.TGA);
        const image = sources?.workers?await sources.workers.decode('tga',bytes):tgaLoader.parse(bytes);
        return [paletteName, { width: image.width, height: image.height, data: image.data }];
      } catch (error) {
        runtimeDiagnostics.error(error, 'texture.palette-unavailable', { resRef: paletteName });
      }
    }))).filter(Boolean));
    paletteImages=sources?await sources.paletteImages(readPalettes):await readPalettes();
  }
  const decodedFiles=await prepareResourceBatch(files,async file=>{
    try {
    const buffer = await file.arrayBuffer();
    let texture;
    const lowerName = file.name.toLowerCase();
    if (lowerName.endsWith('.plt')) {
      const rows=pltColorRows.get(file.name.replace(/\.plt$/i, '').toLowerCase());
      const decoded = sources?.workers?await (import.meta.env.VITE_RESIDENT_PLT_PALETTES!=='0'?sources.workers.decodePlt(buffer,paletteImages,rows):sources.workers.decode('plt',buffer,{palettes:paletteImages,rows})):decodeBioWarePlt(buffer,paletteImages,rows);
      texture = new THREE.DataTexture(decoded.data, decoded.width, decoded.height, THREE.RGBAFormat);
      texture.flipY = decoded.flipY;
      texture.generateMipmaps = true;
      texture.minFilter = THREE.LinearMipmapLinearFilter;
    } else if (lowerName.endsWith('.ktx')) {
      const image=new KTXLoader().parse(buffer,true);
      if(image.isCubemap)throw new Error('Cubemap cannot be used as a model diffuse bitmap');
      texture=s3tcTexture(image.mipmaps,image.width,image.height,image.format);
      texture.minFilter=image.mipmapCount>1?THREE.LinearMipmapLinearFilter:THREE.LinearFilter;
    } else if (lowerName.endsWith('.dds')) {
      const magic = buffer.byteLength >= 4 ? new DataView(buffer).getUint32(0, false) : 0;
      if (magic === 0x44445320) {
        const image = ddsLoader.parse(buffer, true);
        texture = s3tcTexture(image.mipmaps, image.width, image.height, image.format);
        texture.minFilter = image.mipmapCount > 1 ? THREE.LinearMipmapLinearFilter : THREE.LinearFilter;
      } else {
        texture = parseBioWareDds(buffer);
      }
    } else {
      const image = sources?.workers?await sources.workers.decode('tga',buffer):tgaLoader.parse(buffer);
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
    return [file.name.replace(/\.(tga|dds|plt|ktx)$/i, '').toLowerCase(), texture];
    } catch (error) { runtimeDiagnostics.error(error, 'texture.decode-failed', { resourceFile: file.name }); throw error; }
  });
  const failure=decodedFiles.find(result=>result.status==='rejected');
  if(failure){for(const result of decodedFiles)if(result.status==='fulfilled')result.value[1].dispose();throw failure.reason;}
  for(const result of decodedFiles){const [name,texture]=result.value;const previous=textures.get(name);if(previous&&previous!==texture)previous.dispose();textures.set(name,texture);}
  return textures;
}

// A separate scene uses the same model hierarchy, skinning, palette decoding
// and body-part attachment as the world renderer. It allocates no game objects.
async function renderCharacterCreationPreview(draft, rules) {
  const {appearance,resolver,parsed,files,paletteRows,partKeys,bodyName,partNames}=await loadCharacterCreationAssets(draft,rules);
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
  // Parsed placements describe the original module, while the registry owns
  // current lifetime and area membership. Preserve placement keys before
  // filtering so removal cannot renumber the surviving creature bindings.
  const sceneCreatures = area.creatures.map((creature,index)=>({...creature,sourceKey:`${area.resRef}:creature:${creature.sourceIndex??index}`}))
    .filter(creature=>{const actor=moduleSession.source(creature.sourceKey);return actor&&actor.areaId===moduleSession.areas.get(area.resRef)?.id;});
  const staticCreatureKeys=new Set(area.creatures.map((c,index)=>`${area.resRef}:creature:${c.sourceIndex??index}`));
  for(const id of moduleSession.areas.get(area.resRef)?.objects??[]){const actor=moduleSession.registry.get(id);
    if(actor?.objectType!==5||actor===moduleSession.player||staticCreatureKeys.has(actor.sourceKey))continue;
    const appearance=resolvePlayerModels(actor.creatureData,moduleSession.characterRules);
    if(appearance)sceneCreatures.push({...appearance,sourceKey:actor.sourceKey,x:actor.position[0],y:-actor.position[2],z:actor.position[1],bearing:-Math.atan2(actor.orientation[0],-actor.orientation[2])});
    else runtimeDiagnostics.record('scene.creature-appearance-unavailable','Runtime creature appearance could not be resolved',{objectId:actor.id});
  }
  if (moduleSession.player.appearance) sceneCreatures.push({ ...moduleSession.player.appearance, player: true });
  const { triangles: walkableTriangles, cameraTriangles:cameraWalkmeshTriangles, missing: missingWalkmeshes } = await loadAreaWalkmesh(area, resolver);
  const collisions = await loadAreaCollisions(area, resolver);
  const sessionArea = moduleSession?.areas.get(area.resRef);
  await sessionArea.nativeGeometry.objects.load(); // Canonical PWK interaction points precede input binding.
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
      textureFiles.push(textureResourceFile(name,await resolveTextureResource(resolver,name)));
    } catch(error) {if(error.code!=='RESOURCE_NOT_FOUND')throw error;missingTextures.push(name);}
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
    wrapper.userData.nativeLoadedModelName=modelName;
    return wrapper;
  };

  let renderedTiles = 0;
  for (let index = 0; index < area.tiles.length; index += 1) {
    const tile = area.tiles[index];
    const x = index % area.width;
    const y = Math.floor(index / area.width);
    const tileObject=addInstance(tile.model, [x * 10 + 5, tile.height * area.tileHeight, -(y * 10 + 5)], tile.orientation * Math.PI / 2, `Tile ${index} · ${tile.model}`);
    if (tileObject) {
      tileObject.userData.nativeStaticTile=true;
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
    const sourceKey = `${area.resRef}:placeable:${index}`,record = moduleSession.source(sourceKey);
    if(!record||record.areaId!==sessionArea.id)continue;
    const object = addInstance(placeable.model, [placeable.x, placeable.z, -placeable.y], placeable.bearing, `Placeable · ${placeable.tag || placeable.model}`);
    if (object) {
      areaObjects.add('placeable', sourceKey, record, object);
      renderedPlaceables += 1;
    } else {
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
  creatureAnimations=new CreatureAnimationPresentation({random:clientAnimationRandom,object:id=>moduleSession.registry.get(id),rules:()=>moduleSession.characterRules,now:id=>clientPause.now(id),
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
  await installCameraKeyhole(root,resolver);
  worldObjects = areaObjects;
  activeAnimations = areaAnimations;
  const visualSession=moduleSession;
  const projectilePoses=visualLocalPoseServices({sceneRoot:root}),basis=new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1,0,0),-Math.PI/2),inverseBasis=basis.clone().invert();
  projectiles=new ClientProjectilePresentation({objects:()=>areaObjects.objects.values(),renderFor:id=>areaObjects.renderBindings.get(id),rules:()=>visualSession.characterRules,
    rangedRules:async()=>({...visualSession.characterRules,ammunitiontypes:await visualSession.items.table('ammunitiontypes')}),hitPartsEnabled:()=>1,randomImpactPart:model=>randomSceneModelPart(model,creatureAnimations.random),
    playerId:()=>serverObjectIdForClient(visualSession.player.id),
    voiceFields:clientCastVoiceFields,
    castFields:actor=>localClientCastFields(actor,visualSession.characterRules,{spell:id=>visualSession.spellBook.castingSpell(id),classType:(o,index)=>(o.creatureData??o.authored).ClassList[index]?.Class??255,level:(spell,type)=>visualSession.spellBook.level(spell.id,type),hasFeat:(o,id)=>visualSession.combat.hasFeat(o,id)}),
    now:()=>visualSession.worldTimer.time(),dayLength:()=>visualSession.worldTimer.dayLength,random:creatureAnimations.random,
    loadModel:async name=>{const asset=await loadSceneVisualAsset(name,resolver);try{return{...createStandaloneSceneModel(asset,name,'Projectile · '+name,root),asset};}catch(error){releaseSceneVisualAsset(asset);throw error;}},
    prepareAuxiliaryModel:async resource=>{
      let asset;try{asset=await loadSceneVisualAsset(resource,resolver);}catch(error){runtimeDiagnostics.error(error,'visual.projectile-auxiliary-prefetch-failed',{resource,outcome:'Optional endpoint prefetch failed; a native NewCAurObject request will return null. The initializer may not request this asset.'});return null;}
      const owned=new Set();let released=false;
      const destroy=model=>{if(!owned.delete(model))return;disposeVisualRoot(model.root);};
      return{create:alias=>{if(released)throw new Error('Projectile auxiliary assets were already released');const model=createStandaloneSceneModel(asset,resource,'Projectile endpoint · '+alias,root);model.alias=alias;owned.add(model);return model;},destroy,
        release:()=>{if(released)return;released=true;for(const model of [...owned])destroy(model);releaseSceneVisualAsset(asset);}};
    },
    destroyModel:model=>{disposeVisualRoot(model.root);releaseSceneVisualAsset(model.asset);},modelFor:render=>projectilePoses.modelHandle(render),nodePose:(model,name,position,quaternion)=>projectilePoses.nodePoseInto(model,name,position,quaternion),
    orient:(model,vector)=>{const q=clientProjectileModelQuaternion(vector);if(q)model.root.quaternion.copy(basis).multiply(new THREE.Quaternion(q[1],q[2],q[3],q[0])).multiply(inverseBasis);},
    castAttachment:{attach:(...args)=>projectilePoses.setParent(...args),forget:model=>projectilePoses.forgetAttachment(model),updateAttachments:()=>projectilePoses.updateAttachments()},
    impactAttachment:{attach:(...args)=>projectilePoses.setParent(...args),setNodePose:(...args)=>projectilePoses.setNodePose(...args),forget:model=>projectilePoses.forgetAttachment(model),updateAttachments:()=>projectilePoses.updateAttachments()},
    scene:root,report:(code,message,data)=>runtimeDiagnostics.record(code,message,data),oneShot:event=>void gameAudio?.play(event)});
  let visualTables;
  const loadVisualTables=()=>visualTables??=Promise.all([visualSession.items.table('visualeffects'),visualSession.items.table('progfx'),visualSession.items.table('appearance')]).then(([visuals,programs,appearance])=>{
    if(!visuals||!programs||!appearance)throw new Error('Looping visual rules are unavailable');return{visuals,programs,appearance};
  });
  const areaProjectiles=projectiles;
  loopingVisuals = new LoopingVisualPresentation({areaId:sessionArea.id,objects:()=>areaObjects.objects.values(),object:id=>areaObjects.registry.get(id),
    render:id=>areaObjects.renderBindings.get(id),tables:loadVisualTables,
    createNative:(actor,target,record,tables)=>createSceneVisual(actor,target,record,tables,{resolver,session:visualSession,bindings:areaObjects.renderBindings,sceneRoot:root,projectileOwner:areaProjectiles}),selectedObjectId1406ac1c0:()=>visualSession.player.id,
    report:(code,message,data)=>runtimeDiagnostics.record(code,message,data)});
  const pendingCreatures=new Set(),failedCreatures=new Map(),appearanceKeys=new Map(),presentation=creatureAnimations;
  const pendingPlaceables=new Set(),failedPlaceables=new Map(),reportedGroundItems=new Set();
  const addRuntimePlaceable=async(object,appearance)=>{
    const table=await visualSession.items.table('placeables'),column=table?.columns.find(name=>name.toLowerCase()==='modelname'),value=table?.orderedRows[appearance]?.[column];
    if(!Number.isInteger(appearance)||!value||value==='****')throw new Error('Runtime placeable active ModelName is unavailable');
    const name=value.toLowerCase().slice(0,16);
    if(!parsedModels.has(name)){
      const model=parseModel(await resolver.getResource(name,RESOURCE_TYPE.MDL));
      await inheritAnimations(model,async ref=>{if(!animationSources.has(ref))animationSources.set(ref,parseModel(await resolver.getResource(ref,RESOURCE_TYPE.MDL)));return animationSources.get(ref);});
      parsedModels.set(name,model);animationSources.set(name,model);
    }
    const files=[],model=parsedModels.get(name);
    for(const bitmap of new Set((model.materialNames??[]).map(name=>name.toLowerCase()).filter(name=>name&&name!=='null'))){
      if(textures.has(bitmap))continue;let found=false;
      try{files.push(textureResourceFile(bitmap,await resolveTextureResource(resolver,bitmap)));found=true;}
      catch(error){if(error.code!=='RESOURCE_NOT_FOUND')throw error;}
      if(!found)runtimeDiagnostics.record('texture.runtime-placeable-unavailable',`Runtime placeable bitmap ${bitmap} is unavailable`,{objectId:object.id,resource:bitmap});
    }
    const extra=await loadTextures(files,resolver),current=()=>loadedRoot===root&&worldObjects===areaObjects&&visualSession.registry.get(object.id)===object&&object.areaId===sessionArea.id&&(object.nativeMessageFields?.[0x32c]??object.authored.Appearance)===appearance;
    if(!current()){extra.forEach(texture=>texture.dispose());return;}
    extra.forEach((texture,key)=>{textures.set(key,texture);loadedTextures.push(texture);});
    if(!templates.has(name)){const template=buildObject(model,textures);templates.set(name,template);root.userData.assetTemplates.push(template);}
    const rotation=object.bearing??-Math.atan2(object.orientation[0],-object.orientation[2]),wrapper=addInstance(name,object.position,rotation,`Placeable · ${object.tag||name}`);
    if(!wrapper)throw new Error('Runtime placeable model instance is unavailable');
    areaObjects.add('placeable',object.sourceKey,object,wrapper);object.model=name;loopingVisuals?.rebindModel(object);
    runtimeDiagnostics.record('scene.runtime-placeable-added','Runtime placeable model and animations bound',{objectId:object.id,sourceKey:object.sourceKey,model:name,appearanceId:appearance},'info');configureAnimationPanel();
  };
  const liveAppearance=actor=>resolvePlayerModels(actor.creatureData??actor.authored,moduleSession.characterRules,{items:moduleSession.equippedItems(actor)});
  const appearanceKey=actor=>JSON.stringify(liveAppearance(actor));
  for(const actor of areaObjects.objects.values())if(actor.objectType===5)appearanceKeys.set(actor.id,appearanceKey(actor));
  const addRuntimeCreature=async(actor,key)=>{
    const appearance=liveAppearance(actor);if(!appearance)throw new Error('Runtime creature appearance is unavailable');
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
      try{files.push(textureResourceFile(name,await resolveTextureResource(resolver,name)));loaded=true;}
      catch(error){if(error.code!=='RESOURCE_NOT_FOUND')throw error;}
      if(!loaded)runtimeDiagnostics.record('texture.runtime-creature-unavailable',`Runtime creature bitmap ${name} is unavailable`,{objectId:actor.id,resource:name});
    }
    if(loadedRoot!==root||worldObjects!==areaObjects)return;
    const extra=await loadTextures(files,resolver,paletteRows);
    if(loadedRoot!==root||worldObjects!==areaObjects||moduleSession.registry.get(actor.id)!==actor||actor.areaId!==sessionArea.id||appearanceKey(actor)!==key){extra.forEach(texture=>texture.dispose());return;}
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
    if(moduleSession.registry.get(actor.id)!==actor||actor.areaId!==sessionArea.id||appearanceKey(actor)!==key)return;
    let wrapper=areaObjects.renderBindings.get(actor.id);
    if(wrapper){
      const previous=visualMainModel(wrapper)?.root??null,owned=new Set();previous?.traverse(node=>owned.add(node));presentation.unbind(actor.id);
      for(let i=areaAnimations.length-1;i>=0;i--)if(owned.has(areaAnimations[i].root))areaAnimations.splice(i,1);
      previous?.traverse(node=>{if(node.userData.animationOwnedGeometry)node.geometry?.dispose();});
      previous?.removeFromParent();
    }else{
      wrapper=new THREE.Group();wrapper.position.set(...actor.position);wrapper.rotation.y=-Math.atan2(actor.orientation[0],-actor.orientation[2]);root.add(wrapper);
      areaObjects.add('creature',actor.sourceKey,actor,wrapper);
    }
    if(actor===moduleSession.player){assembly.rotation.y=Math.PI;wrapper.userData.characterModel=true;}
    wrapper.add(assembly);appearanceKeys.set(actor.id,key);
    loopingVisuals?.rebindModel(actor);
    const animator=createModelAnimator(parsedModels.get(modelName),assembly,`Creature · ${actor.tag||modelName}`,areaAnimations);presentation.bind(actor,animator,wrapper);
    runtimeDiagnostics.record('scene.runtime-creature-added','Runtime creature model and animations bound',{objectId:actor.id,sourceKey:actor.sourceKey,model:modelName,appearanceId:(actor.creatureData??actor.authored).Appearance_Type},'info');
    configureAnimationPanel();
  };
  dynamicCreatureSync=()=>{
    if(loadedRoot!==root||worldObjects!==areaObjects)return;
    let removed=false;
    for(const [id,actor]of areaObjects.objects){
      if(![5,9].includes(actor.objectType)||actor===moduleSession.player||moduleSession.registry.get(id)===actor&&actor.areaId===sessionArea.id)continue;
      const detached=areaObjects.remove(id),wrapper=detached?.render;if(actor.objectType===5)presentation.unbind(id);
      if(wrapper){const owned=new Set();wrapper.traverse(node=>owned.add(node));
        for(let i=areaAnimations.length-1;i>=0;i--)if(owned.has(areaAnimations[i].root))areaAnimations.splice(i,1);
        wrapper.traverse(node=>{if(node.userData.animationOwnedGeometry)node.geometry?.dispose();});
        wrapper.removeFromParent();}
      if(hoveredObject?.id===id)hoveredObject=null;if(selectedWorldObject?.id===id)selectedWorldObject=null;
      removed=true;
    }
    if(removed)configureAnimationPanel();
    for(const id of sessionArea.objects){const object=visualSession.registry.get(id);
      if(object?.objectType===6&&object.areaId===sessionArea.id&&object.possessorId===OBJECT_INVALID&&!areaObjects.get(id)&&!reportedGroundItems.has(id)){
        reportedGroundItems.add(id);runtimeDiagnostics.record('scene.runtime-ground-item-unimplemented','Canonical ground item has no native ground-model presentation',{objectId:id,sourceKey:object.sourceKey,resource:object.templateResRef,baseItem:object.baseItem});
      }
    }
    for(const id of sessionArea.objects){const object=visualSession.registry.get(id);
      if(object?.objectType!==9||object.areaId!==sessionArea.id||areaObjects.get(id)||pendingPlaceables.has(id))continue;
      const appearance=object.nativeMessageFields?.[0x32c]??object.authored.Appearance;if(failedPlaceables.get(id)===appearance)continue;
      pendingPlaceables.add(id);void addRuntimePlaceable(object,appearance).catch(error=>{failedPlaceables.set(id,appearance);runtimeDiagnostics.error(error,'scene.runtime-placeable-failed',{objectId:id,sourceKey:object.sourceKey});}).finally(()=>pendingPlaceables.delete(id));
    }
    for(const id of sessionArea.objects){const actor=moduleSession.registry.get(id);
      if(actor?.objectType!==5||actor.areaId!==sessionArea.id||actor.nativeField9f4!==0||pendingCreatures.has(id))continue;
      const key=appearanceKey(actor);if(areaObjects.get(id)&&appearanceKeys.get(id)===key||failedCreatures.get(id)===key)continue;
      pendingCreatures.add(id);void addRuntimeCreature(actor,key).catch(error=>{failedCreatures.set(id,key);runtimeDiagnostics.error(error,'scene.runtime-creature-failed',{objectId:id,sourceKey:actor.sourceKey});}).finally(()=>pendingCreatures.delete(id));
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
    playerController = { object: player, position: [...spawn], triangles: walkableTriangles, cameraTriangles:cameraWalkmeshTriangles,sceneRoot:root,cameraQuery:null,obstacles: objectWalkmeshes, collisions };
    const actor = moduleSession.player;
    if (!moduleSession.started && moduleSession.ifo.Mod_Entry_Area === area.resRef) actor.bearing = -Math.atan2(moduleSession.ifo.Mod_Entry_Dir_X, moduleSession.ifo.Mod_Entry_Dir_Y);
    await moduleSession.enterArea(area.resRef, playerController.position);
    if (arrival) actor.bearing = arrival.bearing;
    player.rotation.y = Math.PI + (actor.bearing ?? 0);
    areaObjects.add('player', 'player', actor, player);
    appearanceKeys.set(actor.id,appearanceKey(actor));
    creatureAnimations.bind(actor,playerAnimator,player);
    playerController.actor = actor;
    const navigator = new WalkmeshNavigator(walkableTriangles);
    actionQueue = new ActionQueue({
      registry: areaObjects, actor, handlers: { door: createDoorUseHandler({ radius: actor.radius }), creature: {
        actions: ['talk'], intent: () => 'talk',
        prepare: target => ({ ok: !moduleSession.isDead(target) && !moduleSession.isDying(target), message: 'That creature cannot converse', points: [target.position], range: moduleSession.talkRange(actor, target) }),
        execute: target => ({ ok: moduleSession.requestTalk(target.id), message: `Talking to ${target.name || target.tag}` }),
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
  rendererShadowBudget.reset();
  rendererShadowTraversal.reset();
  rendererMainBatches.reset();
  rendererLightUniforms.reset();
  rendererMaterialReuse.reset();
  worldHighlights.reset();
  worldPointer?.detach();
  cameraKeyhole?.dispose({retire:dispose=>networkRendererRetirement.retire(dispose)});cameraKeyhole=null;delete canvas.dataset.cameraKeyhole;
  projectiles?.dispose();projectiles=null;delete canvas.dataset.projectiles;
  modelParticles.dispose();delete canvas.dataset.modelParticles;delete canvas.dataset.pointWinds;
  loopingVisuals?.dispose(); loopingVisuals=null; delete canvas.dataset.loopingVisuals;
  dynamicCreatureSync=null;
  radialMenu.close(); radialIconCache.clear();
  actionQueue?.cancel('Area changed');
  actionQueue = null; worldObjects = null; hoveredObject = null; selectedWorldObject = null; pointerPress = null;cancelSpellTarget();
  canvas.style.cursor = ''; canvas.title = '';
  for (const key of ['worldObjects', 'actionPhase', 'selectedObject', 'hoveredObject', 'doorStates', 'actorPosition', 'lastRadialAction', 'cameraMode','cameraScriptMode']) delete canvas.dataset[key];
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
        if(child.isLight){child.shadow?.map?.dispose();child.shadow?.mapPass?.dispose();}
        if (child.geometry&&!rendererModelGeometry.release(child)) geometries.add(child.geometry);
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

async function installCameraKeyhole(root,resolver){
  const presentation=new CameraKeyholePresentation({renderer,camera,report:(code,message,data)=>runtimeDiagnostics.record(code,message,data)});
  try{await presentation.load(resolver);if(loadedRoot!==root){presentation.dispose();return;}presentation.bind(root);cameraKeyhole?.dispose();cameraKeyhole=presentation;}
  catch(error){presentation.dispose();runtimeDiagnostics.error(error,'camera.keyhole-load-failed');}
  if(loadedRoot===root)await worldPointer?.attach(root,resolver);
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
  const lightingSummary = `${report.lightingMode} area lighting · ${lights} lights · ${effectSummary}; native particle CPU paths active, remaining scene/material features recorded; PCF shadows approximate the game passes.`;
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

function buildObject(parsed, textures, textureOverride = null,{previews=true,shareGeometry=false,managedMatrices=false}={}) {
  const { root, groups,nodeGroups } = createModelHierarchy(parsed,{managedMatrices});
  root.userData.mdlRoot=parsed.modelName;
  for (const node of parsed.nodes) {
    if (node.type !== 'trimesh' || node.render === false || node.properties?.render === 0 || node.properties?.render === '0') continue;
    const transformedVertices = node.skinned
      ? deformSkinnedVertices(node, parsed.nodes, groups, nodeGroups.get(node),nodeGroups)
      : null;
    const mesh = buildMesh(node, textures, transformedVertices, textureOverride,shareGeometry);
    if (mesh){if(managedMatrices)manageLocalMatrix(mesh);nodeGroups.get(node).add(mesh);}
  }
  for (const node of parsed.nodes) {
    const group = nodeGroups.get(node);
    if (node.type === 'light') {const light=addModelLight(node, group);if(managedMatrices&&prepareMatrixSubtrees)manageLocalMatrix(light);}
    else if (node.type === 'emitter') {const emitter=createModelEmitter(node,textures,parsed.modelName);if(managedMatrices&&prepareMatrixSubtrees)manageLocalMatrix(emitter);group.add(emitter);if(previews)buildEmitterPreview(node, group, textures, parsed.modelName);}
  }
  return root;
}

function addModelLight(node, parent) {
  const light=createModelLight(node, configureLightShadow);parent.add(light);return light;
}

async function createSceneVisual(actor, target, record, tables,{resolver,session,bindings,sceneRoot,projectileOwner}) {
  return createVisualSceneRuntime({actor,record,tables,objects:session.registry,renderFor:id=>bindings.get(id),player:()=>session.player,sceneRoot,projectiles:projectileOwner,
    loadAsset:name=>loadSceneVisualAsset(name,resolver),
    createModel:(asset,resourceName)=>createStandaloneSceneModel(asset,resourceName,'Visual · '+record.visualId,sceneRoot),
    destroyModel:model=>disposeVisualRoot(model.root),releaseAsset:releaseSceneVisualAsset,
    shadowing:(model,enabled)=>setModelLightShadows(model.root,enabled,configureLightShadow),
    report:(code,message,data)=>runtimeDiagnostics.record(code,message,data)
  });
}

async function loadSceneVisualAsset(name,resolver){
  return loadModelReferenceAssets(name,{load:key=>loadSingleSceneVisualAsset(key,resolver),release:asset=>{asset.textures.forEach(texture=>texture.dispose());asset.textures.clear();}});
}

function releaseSceneVisualAsset(asset){
  releaseModelReferenceAssets(asset,entry=>{entry.textures.forEach(texture=>texture.dispose());entry.textures.clear();});
}

async function loadSingleSceneVisualAsset(name,resolver){
      const files=[],textures=new Map();
      try{
        const model=parseModel(await resolver.getResource(name,RESOURCE_TYPE.MDL));
        await inheritAnimations(model,async resRef=>parseModel(await resolver.getResource(resRef,RESOURCE_TYPE.MDL)));
        recordModelLimitations(model,{references:true});
        for(const bitmap of model.materialNames){
          let found=false;
          try{files.push(textureResourceFile(bitmap,await resolveTextureResource(resolver,bitmap)));found=true;}
          catch(error){if(error.code!=='RESOURCE_NOT_FOUND')throw error;}
          if(!found)throw new Error('Visual bitmap '+bitmap+' is unavailable');
        }
        (await loadTextures(files,resolver)).forEach((texture,key)=>textures.set(key,texture));
        return{model,textures};
      }catch(error){textures.forEach(texture=>texture.dispose());throw error;}
}

function createStandaloneSceneModel(asset,resourceName,label,sceneRoot){
      const root=buildObject(asset.model,asset.textures);
      try{
        const model={root,model:asset.model,resourceName,animator:createModelAnimator(asset.model,root,label,[],{autoIdle:false})??new ModelAnimator(asset.model,root)};
        if(asset.model.nodes.some(node=>node.type==='reference')){
          if(!sceneRoot)throw new Error('Reference model requires an owned scene root');
          model.references=new ModelReferenceScene({owner:model,asset,sceneRoot,createModel:(child,name)=>createStandaloneSceneModel(child,name,label+' / '+name,sceneRoot),destroyModel:child=>disposeVisualRoot(child.root)});
          modelReferenceRuntimes.set(root,model.references);
        }
        return model;
      }
      catch(error){disposeVisualRoot(root);throw error;}
}

function disposeVisualRoot(root){
  const references=modelReferenceRuntimes.get(root);if(references){modelReferenceRuntimes.delete(root);references.dispose();}
  root.removeFromParent();root.traverse(o=>{if(o.geometry&&!rendererModelGeometry.release(o))o.geometry.dispose();for(const material of Array.isArray(o.material)?o.material:o.material?[o.material]:[])material.dispose();if(o.isLight){o.shadow?.map?.dispose();o.shadow?.mapPass?.dispose();}});
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

function buildMesh(node, textures, transformedVertices = null, textureOverride = null,shareGeometry=false) {
  if(node.verts.length===0||node.faces.length===0)return null;
  const instantiate=geometry=>{
  const bitmapNames=node.bitmaps?.length?node.bitmaps:[node.bitmap||''];
  const diffuseColor = vectorProperty(node.diffuse ?? node.properties?.diffuse, [1, 1, 1]);
  const materials = bitmapNames.map((bitmapName, index) => {
    const map = index === 0 && textureOverride ? textureOverride : textures.get(bitmapName.toLowerCase());
    const materialOptions = {
      color: new THREE.Color().setRGB(...diffuseColor, THREE.SRGBColorSpace),
      emissive: new THREE.Color().setRGB(...vectorProperty(node.selfillumcolor ?? node.properties?.selfillumcolor, [0, 0, 0]), THREE.SRGBColorSpace),
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
  mesh.userData.sourceVertexIndices = geometry.userData.sourceVertexIndices;
  mesh.userData.nativeModelMesh = true;
  mesh.castShadow = Number(node.shadow ?? node.properties?.shadow ?? 1) !== 0;
  mesh.receiveShadow = true;
  return mesh;
  };
  if(shareGeometry&&!node.skinned&&!transformedVertices)return rendererModelGeometry.create(node,()=>buildModelGeometry(node,transformedVertices),instantiate);
  const geometry=buildModelGeometry(node,transformedVertices);if(!geometry)return null;
  try{return instantiate(geometry);}catch(error){geometry.dispose();throw error;}
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

function createModelAnimator(parsed, instance, label, list, {autoIdle=true}={}) {
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
    mesh.userData.animationOwnedGeometry=true;
    return [{ node, group, mesh }];
  });
  const updateSkin = skins.length ? () => {
    for (const { node, group, mesh } of skins) {
      const vertices = deformSkinnedVertices(node, parsed.nodes, groups, group,nodeGroups);
      updateSkinnedMesh(mesh,vertices);
    }
  } : null;
  const animator = new ModelAnimator(parsed, instance, updateSkin);
  animator.label = label;
  list.push(animator);
  const idle = ['pause1', 'idle', 'pause', 'default'].find(name => parsed.animations.some(clip => clip.name === name))
    ?? parsed.animations.find(clip => clip.name.endsWith('pause1'))?.name;
  if (autoIdle&&idle) animator.play(idle);
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
  canvas.dataset.objectRecords = JSON.stringify([...worldObjects.objects.values()].map(o => {
    const record={id:o.id,kind:o.kind,tag:o.tag,sourceKey:o.sourceKey};
    if(o.objectType===9){const render=worldObjects.renderBindings.get(o.id);if(render){const center=new THREE.Box3().setFromObject(render).getCenter(new THREE.Vector3()).project(camera);record.screen={x:(center.x+1)*canvas.clientWidth/2,y:(1-center.y)*canvas.clientHeight/2,z:center.z};}record.position=o.position;}
    return record;
  }));
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
  canvas.dataset.characterAppearance = JSON.stringify({id:characterData?.Appearance_Type,polymorphed:moduleSession?.player.nativeField97c,locked:moduleSession?.player.nativeField9f8,model:playerController?.object.children[0]?.name??null});
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
  if(networkFrontend?.id){networkCamera.recenter(player.position.toArray());}
  else{const actor=playerController?.actor,height=actor?.nativePathInfo?.fieldC??1;singlePlayerCamera.reset({mode:singlePlayerCamera.mode,position:[player.position.x,-player.position.z,player.position.y],height});}
  camera.fov=45;
  camera.near = 0.1;
  camera.far = 500;
  camera.updateProjectionMatrix();
  controls.minDistance = 1;
  controls.maxDistance = 25;
  gameplayCamera().update({position:[player.position.x,-player.position.z,player.position.y]},1,camera,controls);
}

function updateScriptCamera(delta, immediate = false) {
  const actor=playerController?.actor;if(!actor||!cameraFollowsPlayer||actor.cutscene?.enabled)return;
  if(actor.scriptCameraMode!==undefined&&actor.scriptCameraMode!==singlePlayerCamera.lastScriptMode){singlePlayerCamera.setMode(actor.scriptCameraMode,actor.nativePathInfo?.fieldC??1);singlePlayerCamera.lastScriptMode=actor.scriptCameraMode;}
  const p=playerController.object.position;
  const position=[p.x,-p.z,p.y],keyholeActive=Boolean(cameraKeyhole?.shader),needsQuery=!keyholeActive||(singlePlayerCamera.flags&1),query=needsQuery&&!moduleLoadBusy&&!moduleSession?.transitioning?(playerController.cameraQuery??=cameraSceneQuery(playerController.sceneRoot,playerController.cameraTriangles)):null;query?.update();
  const collision=query?{position,cameraPosition:[camera.position.x,-camera.position.z,camera.position.y],keyholeActive,query:query.nearest,eligible:Boolean(playerController.object.userData.characterModel)}:null;
  singlePlayerCamera.update({position,facing:(actor.bearing??0)*180/Math.PI,animation:actor.animationState??0,collision},immediate?1:delta,camera,controls);
  canvas.dataset.cameraMode=String(singlePlayerCamera.mode);canvas.dataset.gameCamera=JSON.stringify(singlePlayerCamera.snapshot());
}

function updatePlayerMovement(delta) {
  if (!playerController || movementKeys.size === 0 || document.hidden) return;
  const forward = camera.getWorldDirection(new THREE.Vector3());
  forward.y = 0;
  if(forward.lengthSq()<1e-8){
    // An overhead orbit still has a horizontal heading in its right axis.
    const cameraRight=new THREE.Vector3(1,0,0).applyQuaternion(camera.quaternion);cameraRight.y=0;
    forward.crossVectors(new THREE.Vector3(0,1,0),cameraRight);
  }
  if (forward.lengthSq() < 1e-12) return;
  forward.normalize();
  const right = new THREE.Vector3().crossVectors(forward, new THREE.Vector3(0, 1, 0)).normalize();
  const input = new THREE.Vector3();
  if (movementKeys.has('w') || movementKeys.has('arrowup')) input.add(forward);
  if (movementKeys.has('s') || movementKeys.has('arrowdown')) input.sub(forward);
  if (movementKeys.has('d') || movementKeys.has('arrowright')) input.add(right);
  if (movementKeys.has('a') || movementKeys.has('arrowleft')) input.sub(right);
  if (input.lengthSq() < 1e-8) {if(playerController.keyboardMoving)stopKeyboardMovement();return;}
  input.normalize();
  const controller=playerController,now=performance.now();
  if(controller.keyboardMoving&&now-(controller.keyboardSubmittedAt??0)<120)return;
  if(controller.movementPending)return;
  const {position,triangles}=controller,x=position[0]+input.x,z=position[2]+input.z;
  const height=findWalkableHeight(triangles,x,z,position[1],.9);
  if(height===null)return;
  controller.keyboardMoving=true;controller.keyboardSubmittedAt=now;
  submitPlayerMovement([x,height,z],1,'keyboard');
}

function movePlayerTowards(point, delta) {
  const { position } = playerController;
  const dx = point[0] - position[0], dz = point[2] - position[2];
  const distance = Math.hypot(dx, dz);
  if (distance < 0.1) return 'arrived';
  const issued=playerController.movementIssued;
  if(!issued||issued.owner!=='interaction'||issued.point.some((v,i)=>v!==point[i]))submitPlayerMovement(point,0,'interaction');
  else if(!playerController.movementPending&&!playerController.actor.objectActionState.list.head)return 'blocked';
  return 'moving';
}

function submitPlayerMovement(point,run,owner){
  const session=moduleSession,controller=playerController;if(!session||!controller)return;
  const sequence=controller.movementSequence=((controller.movementSequence??0)+1)&255;
  controller.movementIssued={point:point.slice(),owner};controller.movementPending=true;
  void session.queuePlayerMovement({actorId:controller.actor.id,areaId:controller.actor.areaId,position:[point[0],-point[2],point[1]],run,sequence})
    .catch(error=>session.report(error,{operation:'player-movement-input',owner}))
    .finally(()=>{if(controller.movementSequence===sequence)controller.movementPending=false;});
}

function stopKeyboardMovement(){
  const controller=playerController,session=moduleSession;if(!controller||!session)return;
  controller.keyboardMoving=false;
  void session.queuePlayerMovementStop(controller.movementSequence).catch(error=>session.report(error,{operation:'keyboard-movement-stop'}));
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

function recordModelLimitations(parsed,{references=false}={}) {
  if(parsed.nodes.some(node=>node.type==='light'))runtimeDiagnostics.record('model.lighting-approximate','Model lights use the native legacy quadratic falloff; gamma-corrected settings, native per-object light selection, vertical/shadow offsets and shadow/flare passes are not yet reconstructed',{model:parsed.modelName});
  for (const message of parsed.unsupportedAnimations) runtimeDiagnostics.record('animation.unsupported', message, { model: parsed.modelName });
  if (parsed.hasSkinnedMeshes && !hasStaticSkinMapping(parsed)) runtimeDiagnostics.record('model.skin-mapping-unavailable', 'No skin bone slots map to model nodes; base vertices are displayed', { model: parsed.modelName });
  for (const node of parsed.nodes) {
    for (const feature of node.unsupportedFeatures ?? []) if(feature!=='Emitter runtime simulation'&&!(references&&feature==='Referenced model attachment'))runtimeDiagnostics.record('model.feature-unimplemented', `${feature} is not implemented`, { model: parsed.modelName, node: node.name, feature });
    if (!['trimesh', 'dummy', 'light', 'emitter',...(references?['reference']:[])].includes(node.type)) runtimeDiagnostics.record('model.node-unimplemented', `Node type ${node.type} is not rendered`, { model: parsed.modelName, node: node.name, nodeType: node.type });
  }
}

async function loadNetworkSceneAsset(name,resolver,palette,candidates,sources){
  const model=await sources.load(name);
  recordModelLimitations(model);
  const files=[],rows=new Map();let override=null;
  for(const candidate of candidates){try{const bytes=await resolver.getResource(candidate,RESOURCE_TYPE.PLT);override=candidate+'__network';files.push({name:override+'.plt',arrayBuffer:async()=>bytes});rows.set(override,palette);break;}catch{}}
  if(!override){const bitmaps=[...new Set(model.materialNames.map(n=>n.toLowerCase()).filter(n=>n&&n!=='null'))];const fetched=await prepareResourceBatch(bitmaps,async bitmap=>{
    let found=false;
    try{const file=textureResourceFile(bitmap,await resolveTextureResource(resolver,bitmap));if(palette)rows.set(bitmap,palette);found=true;return file;}
    catch(error){if(error.code!=='RESOURCE_NOT_FOUND')throw error;}
    if(!found)runtimeDiagnostics.record('network.scene-bitmap-unavailable','Network model bitmap is unavailable',{model:name,bitmap});
  });for(const result of fetched){if(result.status==='rejected')throw result.reason;if(result.value)files.push(result.value);}}
  const textures=await loadTextures(files,resolver,rows,sources);return{model,textures,override:override?textures.get(override):null};
}

function setNetworkControls(active){
  for(const id of ['open-button','open-area-button','game-data-button','hak-data-button','character-data-button','game-mode-button','area-select','model-file','area-file','character-file'])document.getElementById(id).disabled=active;
}
let networkUiRefreshRequested=false,networkUiRefreshWork=null,networkUiRefreshGeneration=0;
function requestNetworkUiRefresh(){networkUiRefreshRequested=true;if(networkUiRefreshWork)return;const generation=networkUiRefreshGeneration;networkUiRefreshWork=Promise.resolve().then(async()=>{while(networkUiRefreshRequested&&generation===networkUiRefreshGeneration){networkUiRefreshRequested=false;for(const view of [networkBuffBar,networkInventory,networkQuickbar,networkParty,networkPanels,networkActionQueue]){if(generation!==networkUiRefreshGeneration)return;await view.sync();}}}).catch(e=>runtimeDiagnostics.error(e,'network.ui-refresh-failed')).finally(()=>{networkUiRefreshWork=null;if(networkUiRefreshRequested)requestNetworkUiRefresh();});}
function networkSceneSnapshot(){const snapshot=networkPresentation?.snapshot({camera,bounds:canvas.getBoundingClientRect()}),world=networkFrontend?.world,local=world?.registry.get(world.localObjectId);return snapshot?{...snapshot,controlled:{id:world.localObjectId,present:Boolean(local),areaId:local?.areaId,removed:Boolean(local?.replicationRemoved),position:local?.replicated?.position,appearance:local?.appearance?.appearance,head:local?.appearance?.head,bodyParts:local?.appearance?.bodyParts?.length,equipment:local?.appearance?.equipment?.length,rendered:networkPresentation.objects.has(world.localObjectId)},combat:networkPresentation.combat?.snapshot()??null,projectiles:networkPresentation.projectiles?.snapshot()??null,visuals:networkPresentation.visuals?.snapshot()??null,areaVisuals:networkPresentation.areaVisuals?.snapshot()??null}:null;}
const networkKeyboard=new NetworkKeyboardInput({
 context:()=>{const context=keyboardActorContext(networkFrontend);if(!context)return null;const pose=networkPresentation?.keyboardPose(context.actorId);return pose?{...context,...pose}:context;},
 enabled:()=>networkFrontend.phase==='playing'&&Boolean(networkPresentation)&&!networkPresentation.closed&&!networkPresentation.graphicsPending&&!rendererWarmupCount&&!document.hidden&&!characterFrontend.active&&!gameUi.blocksWorldInput&&!isTextEntry(document.activeElement),
 send:(context,request)=>nativeNetwork.keyboardMove(context.sessionId,{areaId:context.areaId,areaGeneration:context.areaGeneration,actorId:context.actorId,...request}),
 preview:(context,flags)=>{const capture=canvas.dataset.captureKeyboard==='true';let trace;const publish=path=>{if(capture)canvas.dispatchEvent(new CustomEvent('nwn-keyboard-preview',{detail:{at:performance.now(),flags,path,trace}}));return path;},path=networkPresentation?.previewKeyboard(context.actorId,flags,capture?{capture:value=>trace=value}:undefined);return path&&typeof path.then==='function'?path.then(publish):publish(path);},
 stopPreview:context=>networkPresentation?.endKeyboard(context.actorId,context.motionLifetime),
 onDriveHeading:(context,heading)=>networkPresentation?.motion.applyDriveHeading(context.actorId,heading,context.motionLifetime),
 onSent:(context,request,result)=>{if(request.operation==='drive')networkPresentation?.motion.driveSequence(context.actorId,result.sequence);},
 report:error=>runtimeDiagnostics.error(error,'network.keyboard-input-failed'),
});
const networkDialog=new NetworkDialogView(viewport,{resolve:(value,context,options)=>networkFrontend.resolveText(value,context,options),reply:value=>networkFrontend.replyDialog(value),onVisibility:visible=>{if(visible)radialMenu.close();controls.enabled=!visible&&!networkInventory.active&&!networkPanels.active&&!radialMenu.active;}});
const networkInventoryPreferences={showCreatureSlots:false};
try{networkInventoryPreferences.showCreatureSlots=localStorage.getItem('nwn.inventory.showCreatureSlots')==='true';}catch{}
const networkInventory=new NetworkInventoryView(viewport,{world:()=>networkFrontend?.id?networkFrontend.world:null,request:open=>networkFrontend.inventoryWindow(open),resolve:value=>networkFrontend.resolveText(value),action:value=>networkFrontend.itemAction(value),baseItems:()=>networkFrontend.inventoryBaseItems(),inventoryTables:()=>networkQuickbar.tables,itemIcon:item=>networkQuickbar.itemIcon(item),emptyIcon:name=>networkQuickbar.icon(name),skin:name=>networkQuickbar.assets.skin(name),settings:()=>networkInventoryPreferences,panel:page=>networkFrontend.inventoryPanel(page),containerInput:operation=>networkFrontend.containerInput(operation),storeInput:request=>networkFrontend.storeInput(request),examine:id=>networkFrontend.examine(id),itemMenu:openNetworkInventoryRadial,activate:activateNetworkItem,onVisibility:visible=>{if(visible)radialMenu.close();controls.enabled=!visible&&!networkDialog.active&&!networkPanels.active&&!radialMenu.active;}});
const worldHighlights=new WorldHighlightView({viewport,canvas,camera,scene,
 context:()=>{
  if(networkFrontend?.id&&networkPresentation&&!networkPresentation.closed&&!networkPresentation.graphicsPending)return{identity:networkPresentation,root:networkPresentation.root,areaId:networkFrontend.world.areaId,playerId:networkFrontend.world.localObjectId,objects:networkFrontend.world.registry.objects,render:id=>networkPresentation.objects.get(id)?.wrapper,pick:ray=>networkPresentation.pick(ray,{includePlayer:true,objectsOnly:true}),textVersion:networkFrontend.world.tlkOverrideVersion,network:true};
  if(!networkFrontend?.id&&worldObjects&&playerController&&loadedRoot)return{identity:worldObjects,root:loadedRoot,areaId:worldObjects.areaId,playerId:playerController.actor.id,objects:worldObjects.objects,render:id=>worldObjects.renderBindings.get(id),pick:ray=>pickedWorldObject(ray,loadedRoot,worldObjects,{includePlayer:true})};
  return null;
 },enabled:()=>!rendererWarmupCount&&!characterFrontend.active&&!gameUi.blocksWorldInput&&!radialMenu.active&&!moduleSession?.transitioning&&!moduleLoadBusy,
 resolve:(value,context,object)=>context.network?networkFrontend.resolveText(value,object?.id):gameUi.text.resolve(value),
 details:(object,context)=>{
  if(context.network){const state=object.replicated??{},player=[...networkFrontend.world.players.values()].find(p=>p.objectId===object.id||p.character?.id===object.id);return highlightCreatureDetails(object,{assets:networkQuickbar.assets,tables:networkQuickbar.tables,resolve:value=>networkFrontend.resolveText(value,object.id),portraitRow:{portrait:state.portrait??player?.character?.portrait,portraitRef:state.portraitRef??player?.character?.portraitRef}});}
  const data=object.creatureData??object.authored??{},maximum=moduleSession?.stats(object.id)?.maxHP,current=moduleSession?.hitPoints(object.id,false);return highlightCreatureDetails({...object,replicated:{hitPoints:{current,maximum}}},{assets:gameUi.assets,resolve:value=>gameUi.text.resolve(value),portraitRow:{portrait:object.nativePortraitId??data.PortraitId,portraitRef:object.nativePortraitResRef||data.Portrait}});
 },
 onHover:object=>{hoveredObject=object;canvas.style.cursor=pendingSpellTarget||networkSpellTarget?.active?'crosshair':object?'pointer':'';canvas.title='';},
 report:error=>runtimeDiagnostics.error(error,'world.highlight-label-failed')});
worldPointer=new WorldPointerView({viewport,canvas,camera,enabled:()=>!rendererWarmupCount&&!characterFrontend.active&&!gameUi.blocksWorldInput&&!radialMenu.active&&!moduleSession?.transitioning&&!moduleLoadBusy,report:(code,message,data)=>runtimeDiagnostics.record(code,message,data),context:()=>{
 if(networkFrontend?.id&&networkPresentation&&!networkPresentation.closed&&!networkPresentation.graphicsPending){const world=networkFrontend.world,actor=world.registry.get(world.localObjectId),position=networkPresentation.objects.get(actor?.id)?.wrapper.position;return{root:networkPresentation.root,playerId:world.localObjectId,player:position?[position.x,-position.z,position.y]:actor?.replicated?.position,assets:networkQuickbar.assets,targetingActive:networkSpellTarget.active,targeting:target=>networkSpellTarget.presentation(target),pick:ray=>networkPresentation.pick(ray,{includePlayer:networkSpellTarget.active})};}
 if(!networkFrontend?.id&&worldObjects&&loadedRoot&&moduleSession){const actor=moduleSession.player,pending=pendingSpellTarget,position=playerController?.object.position;return{root:loadedRoot,playerId:actor.id,player:position?[position.x,-position.z,position.y]:null,assets:gameUi.assets,targetingActive:Boolean(pending),targeting:target=>{if(!pending||pending.session!==moduleSession)return null;const valid=pendingTargetAllowed(pending,target),definition=pending.itemPlan?.definition??pending.definition;return{valid,cursor:valid?pending.itemPlan?.targetTypes.find(([kind])=>kind===(target?.objectType??2))?.[1]??29:pending.itemPlan?.flags??31,preview:spellTargetPreview(definition,moduleSession.characterRules.ranges)};},pick:ray=>pickedWorldObject(ray,loadedRoot,worldObjects,{includePlayer:Boolean(pending)})};}return null;
}});
const networkQuickbar=new NetworkQuickbarView(viewport,{world:()=>networkFrontend?.id?networkFrontend.world:null,assign:(index,button)=>networkFrontend.assignQuickbar(index,button),resolve:value=>networkFrontend.resolveText(value),inventoryToken:()=>networkInventory.dragToken,canUse:()=>Boolean(networkFrontend?.id)&&!networkPresentation?.graphicsPending&&!rendererWarmupCount&&!networkDialog.active&&!networkInventory.active&&!networkPanels.active&&!radialMenu.active,
  menu:(menu,index,event)=>radialMenu.open(menu,event.clientX,event.clientY,{networkQuickbar:true,sessionId:networkFrontend.id,areaGeneration:networkFrontend.areaGeneration,actorId:networkFrontend.world.localObjectId,quickbarIndex:index}),
  use:(button,index)=>{void ([2,4,44].includes(button.type)||button.type===1&&(button.intParam&65535)!==255?networkSpellTarget.begin(button):networkFrontend.activateQuickbar(index)).catch(e=>networkQuickbar.failure(e));}});
const networkSpellTarget=new NetworkSpellTargeting({world:()=>networkFrontend?.id?networkFrontend.world:null,tables:()=>networkQuickbar.tables,context:()=>({sessionId:networkFrontend.id,areaGeneration:networkFrontend.areaGeneration}),inventoryOpen:()=>networkInventory.active,
  chooseFamily:async binding=>{const id=networkFrontend.id,generation=networkFrontend.areaGeneration,actorId=networkFrontend.world.localObjectId,token=networkQuickbar.token,choice=await networkQuickbar.spellChoice(binding);if(id!==networkFrontend.id||generation!==networkFrontend.areaGeneration||actorId!==networkFrontend.world.localObjectId||token!==networkQuickbar.token)throw new Error('Spell family belongs to an old connection');if(!choice?.children?.length)throw new Error('No valid variants are available for this spell');const bounds=canvas.getBoundingClientRect();radialMenu.open(quickbarChoiceMenu(choice.label,choice.children,'spell.variant'),bounds.left+bounds.width/2,bounds.top+bounds.height/2,{network:true,sessionId:id,areaGeneration:generation,actorId,familyToken:token,familyParent:binding.intParam});radialMenu.clickMode=true;return{choosingVariant:true};},
  report:(...args)=>runtimeDiagnostics.record(...args),
  submit:async request=>{const result=await(request.kind==='script-target'?networkFrontend.selectScriptTarget(request):request.kind==='item'?networkFrontend.useItem(request):request.kind==='feat'?networkFrontend.useFeat(request):request.kind==='mode'?networkFrontend.changeMode(request):request.kind==='innate'?networkFrontend.castSpellLike(request):networkFrontend.castSpell(request));document.querySelector('#network-feedback').textContent=request.kind==='script-target'?'Target selected':request.kind==='item'?'Item use requested':request.kind==='mode'?'Mode requested':request.kind==='feat'?'Ability requested':'Spell cast requested';return result;},
  onChange:state=>{canvas.dataset.networkSpellTarget=JSON.stringify(state);canvas.classList.toggle('network-spell-targeting',Boolean(state));if(state)document.querySelector('#network-feedback').textContent=state.scriptTarget?'Select a target · Esc to cancel':'Select a spell target · Esc to cancel';}});
const networkTiming=new NetworkTimingView(viewport,value=>networkFrontend.resolveText(value));
const networkActionQueue=new NetworkActionQueueView(viewport,{world:()=>networkFrontend?.id?networkFrontend.world:null,quickbar:networkQuickbar,resolve:value=>networkFrontend.resolveText(value),cancel:(actionId,groupId)=>networkFrontend.cancelAction(actionId,groupId),report:(...args)=>runtimeDiagnostics.record(...args)});
const networkSpeech=new NetworkSpeechView(viewport,{assets:()=>networkQuickbar.assets,tables:()=>networkQuickbar.tables,world:()=>networkFrontend?.id?networkFrontend.world:null,resolve:(value,context,options)=>networkFrontend.resolveText(value,context,options),onNotice:message=>{if(message.category==='journal'){networkParty.encourage('journal');const world=networkFrontend.world;void networkGuiAudio?.play({resRef:message.sound,objectId:world.localObjectId,channel:'gui'});}},send:request=>networkFrontend.chat(request),canSend:()=>networkFrontend?.phase==='playing',canFocus:()=>networkFrontend?.phase==='playing'&&!networkDialog.active&&!networkInventory.active&&!networkPanels.active&&!radialMenu.active});
const networkDamageOptions=nativeDamageFeedbackOptions();
// Native game.gore registration6b9987 defaults to1.
const networkCombatVisualOptions={gore:1};
networkFloating=new NetworkFloatingTextView(viewport,{world:()=>networkFrontend?.id?networkFrontend.world:null,scene:()=>networkPresentation,camera:()=>camera,canvas:()=>canvas,getResource:(...args)=>nativeNetwork.getResource(networkFrontend.id,...args),report:(...args)=>runtimeDiagnostics.record(...args)});
const networkFeedback=new NetworkFeedbackView({world:()=>networkFrontend?.id?networkFrontend.world:null,text:()=>networkFrontend?.text,tables:()=>networkQuickbar.tables,display:row=>networkSpeech.append(row),floating:event=>networkFloating.add(event),options:()=>networkDamageOptions,report:(code,message,data)=>runtimeDiagnostics.record(code,message,data)});
const networkExamine=new NetworkExamineView(viewport,{world:()=>networkFrontend?.id?networkFrontend.world:null,resolve:(value,context,options)=>networkFrontend.resolveText(value,context,options),getResource:(...args)=>nativeNetwork.getResource(networkFrontend.id,...args),assets:()=>networkQuickbar.assets});
const networkPanels=new NetworkPanels(viewport,{world:()=>networkFrontend?.id?networkFrontend.world:null,quickbar:networkQuickbar,resolve:value=>networkFrontend.resolveText(value),inventory:()=>networkInventory.toggle(),activate:binding=>networkSpellTarget.begin(binding),prepare:request=>networkFrontend.prepareSpell(request),rest:()=>networkFrontend.rest(),panelRequest:(panel,open,page)=>networkFrontend.hudPanel(panel,open,page),levelUp:request=>networkFrontend.levelUp(request),levelUpResources:async()=>{const id=networkFrontend.id,[base,custom]=await Promise.all([nativeNetwork.talkTable(id,false),nativeNetwork.talkTable(id,true)]);if(networkFrontend.id!==id)throw Error('Level-up resources belong to an old connection');return{resolver:{getResource:(...args)=>nativeNetwork.getResource(id,...args)},text:new GameText({base:parseTalkTable(base),custom:custom?parseTalkTable(custom):null})};},attitude:(playerId,likes)=>networkFrontend.playerAttitude(playerId,likes),settings:()=>({...networkInventoryPreferences,wireframe,cameraMode:networkCamera.controller.mode,floatingFeedback:networkDamageOptions.enabled,damageTotalsOnly:networkDamageOptions.total,gore:networkCombatVisualOptions.gore,shadowCastingLights:rendererShadowBudget.maximum}),setSettings:settings=>{if([1,2,3].includes(settings.shadowCastingLights)){rendererShadowBudget.maximum=settings.shadowCastingLights;try{localStorage.setItem('nwn.graphics.shadowCastingLights',String(settings.shadowCastingLights));}catch{}}if(settings.showCreatureSlots!==undefined){networkInventoryPreferences.showCreatureSlots=Boolean(settings.showCreatureSlots);try{localStorage.setItem('nwn.inventory.showCreatureSlots',String(networkInventoryPreferences.showCreatureSlots));}catch{}}if([0,1,2].includes(settings.gore))networkCombatVisualOptions.gore=settings.gore;if(settings.floatingFeedback!==undefined)networkDamageOptions.enabled=settings.floatingFeedback;if(settings.damageTotalsOnly!==undefined)networkDamageOptions.total=settings.damageTotalsOnly;if(settings.wireframe!==undefined&&settings.wireframe!==wireframe)wireButton.click();if(settings.cameraMode!==undefined){const select=document.querySelector('#network-hud [data-camera-mode]');select.value=settings.cameraMode;select.dispatchEvent(new Event('change',{bubbles:true}));}},disconnect:()=>networkFrontend.disconnect(),onVisibility:(visible,panel)=>{if(panel){if(panel==='journal')networkParty.encourage('journal',false);radialMenu.close();networkSpellTarget.reset();}controls.enabled=!visible&&!networkInventory.active&&!networkDialog.active&&!radialMenu.active;}});
const networkNui=new NetworkNuiView(viewport,{world:()=>networkFrontend?.id?networkFrontend.world:null,input:request=>networkFrontend.nuiInput(request),resolve:value=>networkFrontend.resolveText(value),image:(name,region)=>recordNuiImage(name,region),assets:()=>networkQuickbar.assets,report:(...args)=>runtimeDiagnostics.record(...args)});
async function recordNuiImage(name,region){const assets=networkQuickbar.assets;return assets?nuiImage(assets,name,region):null;}
const networkParty=new NetworkPartyView(viewport,{world:()=>networkFrontend?.id?networkFrontend.world:null,assets:()=>networkQuickbar.assets,tables:()=>networkQuickbar.tables,resolve:(value,id)=>networkFrontend.resolveText(value,id),action:id=>{void networkPanels.open(id);},
  menu:(id,event)=>{const target=networkFrontend.world.registry.get(id);if(target)void openNetworkRadial({object:target},event.clientX,event.clientY);},
  select:id=>{const target=networkFrontend.world.registry.get(id);if(networkSpellTarget.active){void networkSpellTarget.select(target,target.replicated?.position??[0,0,0]).catch(e=>networkQuickbar.failure(e));return;}runtimeDiagnostics.record('network.party-click-unhandled','Native portrait chat/action composition is not connected',{objectId:id});}});
const networkBuffBar=new NetworkBuffBarView(viewport,{world:()=>networkFrontend?.id?networkFrontend.world:null,assets:()=>networkQuickbar.assets,resolve:(value,id)=>networkFrontend.resolveText(value,id),icon:name=>networkQuickbar.icon(name)});
networkFrontend=new NetworkFrontend({bridge:nativeNetwork,
  onMovementSent:sequence=>networkPresentation?.motion.driveSequence(networkFrontend.world.localObjectId,sequence),
  onCreateCharacter:async id=>{const resolver={getResource:(...args)=>nativeNetwork.getResource(id,...args),getTextureResource:ref=>nativeNetwork.getTextureResource(id,ref),resourceNames:()=>nativeNetwork.creationModels(id),portraitNames:()=>nativeNetwork.creationPortraits(id),portraitAvailability:refs=>nativeNetwork.creationPortraitAvailability(id,refs)},[base,custom]=await Promise.all([nativeNetwork.talkTable(id,false),nativeNetwork.talkTable(id,true)]);if(networkFrontend.id!==id)return null;const text=new GameText({base:parseTalkTable(base),custom:custom?parseTalkTable(custom):null});return characterFrontend.choose(resolver,{create:true,createOnly:true,text,moduleName:networkFrontend.lobby?.characterState?.serverInfo?.moduleName??'Server'});},
  canEnter:()=>{if(moduleLoadBusy||moduleSession?.scheduler.pumping||moduleSession?.transitioning)throw new Error('Wait for the current area or script to finish loading');},
  onEnter:()=>{
    networkCamera.reset();networkSpeech.reset();networkFeedback.reset();networkFloating.reset();
    networkActionQueue.reset();networkExamine.reset();networkTiming.reset();networkPanels.reset();networkParty.reset();networkBuffBar.reset();
    networkSpellTarget.reset();
    networkQuickbar.reset();
    networkInventory.reset();networkDialog.close();radialMenu.close();radialIconCache.clear();
    moduleSession=null;gameUi.mode(false);gameUi.detach();gameAudio?.dispose();gameAudio=null;voicePresentation?.dispose();voicePresentation=null;creatureAnimations?.clear();creatureAnimations=null;clientPause=null;
    void networkPresentation?.dispose();networkPresentation=null;clearLoadedScene();setNetworkControls(true);emptyState.classList.add('hidden');movementHud.hidden=true;areaSelect.hidden=true;
    networkGuiAudio?.dispose();const audioSession=networkFrontend.id,audioWorld=networkFrontend.world;
    networkScriptAudio?.dispose();networkAmbientAudio?.dispose();
    networkGuiAudio=new GameAudio({getResource:(...args)=>nativeNetwork.getResource(audioSession,...args)}, {getObject:id=>audioWorld.registry.get(id),getPlayer:()=>({id:audioWorld.localObjectId}),getListener:()=>{
      const binding=networkPresentation?.objects.get(audioWorld.localObjectId),point=binding?.wrapper.position,controller=networkCamera.controller;
      return point?nativeAudioListener([point.x,-point.z,point.y],controller.position,controller.quaternion):null;
    },onState:state=>{canvas.dataset.networkGuiAudio=JSON.stringify(state);}});
    networkScriptAudio=new NetworkAudioPresentation({world:()=>audioWorld,output:networkGuiAudio,ready:()=>Boolean(networkPresentation?.root&&!networkPresentation.closed),report:(code,message,context)=>runtimeDiagnostics.record(code,message,context)});
    networkAmbientAudio=new NetworkAmbientPresentation({output:networkGuiAudio,getResource:(...args)=>nativeNetwork.getAudioResource(audioSession,...args),report:(code,message,context)=>runtimeDiagnostics.record(code,message,context)});
    networkPlacedSounds?.dispose();networkPlacedSounds=new NetworkPlacedSounds({world:()=>audioWorld,output:networkGuiAudio,report:(code,message,context)=>runtimeDiagnostics.record(code,message,context)});
    diagnosticContext={mode:'multiplayer'};setStatus('CONNECTING TO SERVER',true);
    document.querySelector('.source-tag').textContent='SERVER-OWNED WORLD · MULTIPLAYER';
    document.querySelector('#network-hud').hidden=false;
  },
  onExit:async()=>{persistentModelSources.clear();networkNui.reset();networkUiRefreshGeneration++;networkUiRefreshRequested=false;if(characterFrontend.active&&characterFrontend.createOnly)characterFrontend.finish(null);retireNetworkTransition();networkPlacedSounds?.dispose();networkPlacedSounds=null;networkAmbientAudio?.dispose();networkAmbientAudio=null;networkFloating.reset();networkFeedback.reset();networkScriptAudio?.dispose();networkScriptAudio=null;networkGuiAudio?.dispose();networkGuiAudio=null;delete canvas.dataset.networkGuiAudio;delete canvas.dataset.networkAudio;networkSpeech.reset();networkActionQueue.reset();networkExamine.reset();networkTiming.reset();networkPanels.reset();networkParty.reset();networkBuffBar.reset();networkQuickbar.reset();networkInventory.reset();networkDialog.close();radialMenu.close();await networkPresentation?.dispose();networkPresentation=null;clearLoadedScene();setNetworkControls(false);setStatus('MULTIPLAYER DISCONNECTED',false);emptyState.classList.remove('hidden');delete canvas.dataset.networkWorld;delete canvas.dataset.networkScene;delete canvas.dataset.networkDelivery;delete canvas.dataset.networkCombat;delete canvas.dataset.networkProjectiles;document.querySelector('.source-tag').textContent='LOCAL FILE · NOT UPLOADED';document.querySelector('#network-hud').hidden=true;},
  onArea:async(message,world,resolver,current)=>{
    networkPlacedSounds?.detach();
    networkGuiAudio?.clearResourceCache();
    networkAmbientAudio?.detach();
    networkScriptAudio?.areaChanged();
    networkFloating.reset();
    networkActionQueue.reset();networkExamine.reset();networkTiming.reset();networkPanels.reset();networkParty.reset();networkBuffBar.reset();
    networkSpellTarget.reset();
    networkQuickbar.reset();
    networkInventory.reset();networkDialog.close();radialMenu.close();radialIconCache.clear();
    retireNetworkTransition();finishNetworkRendererTransition=networkRendererRetirement.begin();
    try{await networkPresentation?.dispose();}catch(error){retireNetworkTransition();throw error;}rendererShadowBudget.reset();rendererLightSlots.reset();const workers=new ResourceWorkerPool(),vertexWorkers=new ResourceWorkerPool(),modelSources=new ModelSourceCache(resolver,{parse:bytes=>workers.decode('model',bytes),parseTable:bytes=>workers.decode('2da',bytes),persistent:usePersistentModelPreparation,preparedSources:persistentModelSources});modelSources.workers=workers;const frameWork=import.meta.env.VITE_FRAME_BUDGET_LOADING==='1'?new FrameWorkBudget({budgetMs:()=>rendererWarmupCount?8:2}):null;const presentation=new NetworkScene({world,resolver,frameWork,matrixSubtrees:prepareMatrixSubtrees,cachedRootMatrices:import.meta.env.VITE_CACHED_ROOT_MATRICES==='1',loadTable:name=>modelSources.table(name),loadAsset:(...args)=>loadNetworkSceneAsset(...args,modelSources),cancelResources:()=>{workers.dispose();vertexWorkers.dispose();modelSources.dispose();},releaseSources:()=>{runtimeDiagnostics.record('renderer.resource-workers-retired','Area resource workers retired',{...workers.snapshot(),prefetch:presentation.sourcePrefetch.snapshot(),modelSources:{...modelSources.stats},persistentSources:persistentModelSources.snapshot(),vertexWorkers:vertexWorkers.snapshot(),groundHeightIndex:presentation.retiredGroundHeightIndex,frameWork:presentation.retiredFrameWork,texturePreparation:presentation.texturePreparation?.snapshot()??null});networkRendererRetirement.retire(()=>rendererModelPreparation.releaseArea(presentation.root));},gore:()=>networkCombatVisualOptions.gore,
      instantiate:(asset,name)=>{const root=buildObject(asset.model,asset.textures,asset.override,{shareGeometry:true,managedMatrices:true}),animator=createModelAnimator(asset.model,root,'Network · '+name,[],{autoIdle:false});return{root,animator,dispose:()=>networkRendererRetirement.retire(()=>disposeVisualRoot(root))};},
      configureShadow:configureLightShadow,
      oneShot:event=>{if(current()&&networkPresentation===presentation&&!presentation.closed)networkScriptAudio?.oneShot(event);},
      soundFactory:options=>{if(!current()||networkPresentation!==presentation||presentation.closed)throw new Error('Native visual audio scene is closed');return networkGuiAudio.effectSound(options);},
      voiceCaption:event=>{runtimeDiagnostics.record('network.quickchat-overhead-unhandled','Native quick-chat overhead and remote-player profile layout are not connected',{objectId:event.actorId});return networkSpeech.receive({channel:1,objectId:event.actorId,contextId:event.actorId,text:{strRef:event.strRef},current:event.current});},
      prepareAsset:async(asset,name,context)=>{if(presentation.texturePreparation)await presentation.texturePreparation.prepare(asset.textures.values(),{...context,current:()=>!presentation.closed&&networkPresentation===presentation});return rendererModelPreparation.prepare(asset,name,{current:()=>!presentation.closed&&networkPresentation===presentation&&presentation.root.parent===scene&&Boolean(networkFrontend?.id)});},
      prepareAssets:async(entries,context)=>{if(presentation.texturePreparation)await presentation.texturePreparation.prepare(entries.flatMap(({asset})=>[...asset.textures.values()]),{...context,current:()=>!presentation.closed&&networkPresentation===presentation});return rendererModelPreparation.prepareBatch(entries,{current:()=>!presentation.closed&&networkPresentation===presentation&&presentation.root.parent===scene&&Boolean(networkFrontend?.id)});},
      releaseAsset:asset=>networkRendererRetirement.retire(()=>{rendererModelPreparation.release(asset);asset.textures.forEach(t=>t.dispose());}),report:(code,reason,data)=>runtimeDiagnostics.record(code,reason,data)});
    presentation.texturePreparation=frameWork?new RendererTexturePreparation(renderer,frameWork):null;presentation.manageLocalMatrices();
    presentation.resourceWorkers=workers;presentation.vertexWorkers=vertexWorkers;presentation.graphicsPending=true;networkPresentation=presentation;networkFloating.warm();
    void Promise.all(Array.from({length:vertexWorkers.size},()=>vertexWorkers.run('particle-vertices',{buffer:new ArrayBuffer(0),frames:[]}))).catch(error=>{if(!vertexWorkers.closed)runtimeDiagnostics.error(error,'particle.vertex-worker-warmup-failed');});
    rendererWarmupCount++;let graphicsStarted=false;
    try{await presentation.loadArea(message.area);if(!current()||networkPresentation!==presentation){await presentation.dispose();return;}
      await networkQuickbar.attach(resolver,{loadTable:name=>modelSources.table(name)});networkBuffBar.sync();networkNui.ensureSkin();if(!current()||networkPresentation!==presentation){networkQuickbar.reset();await presentation.dispose();return;}void networkActionQueue.sync().catch(e=>runtimeDiagnostics.error(e,'network.action-queue-sync-failed'));await networkParty.sync();setLoadedScene(presentation.root,new Map());
      await installCameraKeyhole(presentation.root,resolver);if(!current()||networkPresentation!==presentation)return;
      setAreaLighting(presentation.lighting(),presentation.root);frameObject(presentation.root);
      const [x,y,z]=message.position;networkCamera.enterArea([x,z,-y]);focusPlayer({position:new THREE.Vector3(x,z,-y)});grid.visible=false;axes.visible=false;
      // Import queued state while color/fade/shadow programs prepare together.
      // Native4/3 admission, drawing and input wait for the graphics barrier.
      prepareRendererLights(scene,camera,{shadowBudget:rendererShadowBudget,lightSlots:rendererLightSlots,lightSelection:rendererLightSelection,focus:controls.target.toArray()});const shaderPrepareStarted=performance.now();
      document.querySelector('#network-feedback').textContent='Preparing area graphics';
      const graphics=startNetworkAreaGraphics(presentation,{retirement:networkRendererRetirement,current:()=>current()&&networkPresentation===presentation,
        prepare:()=>rendererModelPreparation.prepareArea(presentation.root,{current:()=>current()&&networkPresentation===presentation&&!presentation.closed}),
        complete:async()=>{
          runtimeDiagnostics.record('renderer.area-shaders-prepared','Area shader preparation completed',{areaId:message.area.id,durationMs:performance.now()-shaderPrepareStarted,programs:renderer.info.programs?.length??0,keyholeMeshes:cameraKeyhole?.bindings.size??0,lightSlots:rendererLightSlots.state});
          document.querySelector('#model-title').textContent=message.area.name.text??message.area.resRef;document.querySelector('#view-caption').textContent=message.area.resRef.toUpperCase()+' · SERVER WORLD';
          canvas.dataset.networkWorld=JSON.stringify(world.snapshot());canvas.dataset.networkScene=JSON.stringify(networkSceneSnapshot());
          void networkAmbientAudio?.attach(message.area,resolver);networkPlacedSounds?.attach(message.area);document.querySelector('#network-feedback').textContent='Connected';
        },
        failed:async error=>{runtimeDiagnostics.error(error,'network.area-graphics-failed');retireNetworkTransition();await presentation.dispose();if(networkPresentation===presentation){networkPresentation=null;networkQuickbar.reset();networkFrontend.showError(error);}},
        ended:()=>{rendererWarmupCount--;},
      });graphicsStarted=true;void graphics.catch(error=>runtimeDiagnostics.error(error,'network.area-graphics-cleanup-failed'));return{graphics};
    }catch(error){retireNetworkTransition();await presentation.dispose();if(networkPresentation===presentation){networkPresentation=null;networkQuickbar.reset();}throw error;}finally{if(!graphicsStarted)rendererWarmupCount--;}
  },
  onDialog:message=>networkDialog.receive(message),
  onInventoryResult:message=>networkInventory.receive(message),
  onProjectile:header=>{void networkPresentation?.delivery.projectile(header);},
  onAudio:message=>{if(['voice-play','quick-chat'].includes(message.kind)){void networkPresentation?.voices?.receive(message);return;}return message.kind==='ambient-command'?networkAmbientAudio?.receive(message):message.kind==='sound-object'?networkPlacedSounds?.receive(message):networkScriptAudio?.receive(message);},
  onQuickbar:()=>networkQuickbar.sync(),
  onParty:()=>{networkBuffBar.sync();return networkParty.sync();},
  onCamera:message=>{if(networkCamera.receive(message,networkFrontend.world,networkPresentation)){for(const select of document.querySelectorAll('[data-camera-mode]'))select.value=String(networkCamera.controller.mode);}else runtimeDiagnostics.record('network.camera-command-unhandled','Native camera command has no valid presentation handler',message);},
  onUpdates:(message,world)=>{canvas.dataset.networkDelivery=JSON.stringify({at:performance.now(),areaId:world.areaId,objectId:world.localObjectId,position:world.registry.get(world.localObjectId)?.replicated.position,pending:networkPresentation?.delivery.pending??0});const presentation=networkPresentation;if(presentation)void presentation.delivery.updates(world.presentationChanges).catch(e=>runtimeDiagnostics.error(e,'network.scene-sync-failed')).finally(()=>{if(networkPresentation===presentation)retireNetworkTransition();});requestNetworkUiRefresh();canvas.dataset.networkWorld=JSON.stringify(world.snapshot());},
  onHud:async message=>{if(message.kind==='script-targeting'){networkSpellTarget.beginServer();return;}if(message.kind==='script-targeting-data'||message.kind==='spell-targeting-data')return;if(message.kind.startsWith('nui-')){networkNui.sync();return;}if(['combat-feedback','spell-feedback','damage-feedback','attack-feedback','initiative-feedback'].includes(message.kind)){await networkFeedback.receive(message);}else if(message.kind==='tlk-overrides'){networkBuffBar.sync();networkActionQueue.signature=null;void networkActionQueue.sync().catch(e=>runtimeDiagnostics.error(e,'network.action-queue-sync-failed'));await networkQuickbar.sync();await networkParty.sync();await networkPanels.sync();}else if(message.kind==='system-notice'){await networkSpeech.notice(message);}else if(message.kind==='server-speech'){await networkSpeech.receive(message);}else if(message.kind==='container-status'){radialMenu.close();await networkInventory.receiveContainer(message);}else if(message.kind.startsWith('store-')){radialMenu.close();await networkInventory.receiveStore(message);}else if(message.kind==='examine'){radialMenu.close();await networkExamine.receive(message);}else if(message.kind==='gui-timing')await networkTiming.receive(message);else await networkPanels.sync();},
  onObjectVisual:message=>{void networkPresentation?.delivery.objectVisual(message);},
  // Area resources load independently; their own area/closed guards prevent
  // late attachment. A disk/model read must not hold up canonical updates.
  onAreaVisual:message=>{void networkPresentation?.delivery.areaVisual(message);},
  onState:state=>{debugShell.gameOnly(!state.closed&&['area-loading','playing'].includes(state.phase));networkSpeech.sync();if(state.closed){networkSpellTarget.reset();rendererModelPreparation.resetPrograms();}setStatus('MULTIPLAYER · '+state.phase.toUpperCase(),!state.closed);canvas.dataset.networkState=JSON.stringify(state);}
});
let networkPointerPress=null;
window.addEventListener('keydown',event=>{if(networkFrontend.id&&networkSpellTarget.active&&event.key==='Escape'&&!event.target?.closest?.('input,textarea,select,[contenteditable="true"]')){event.preventDefault();event.stopImmediatePropagation();networkSpellTarget.reset();document.querySelector('#network-feedback').textContent='Spell targeting cancelled';}},true);
canvas.addEventListener('pointerdown',event=>{if(networkFrontend.id&&event.button===0)networkPointerPress={id:event.pointerId,x:event.clientX,y:event.clientY};});
canvas.addEventListener('pointercancel',()=>{networkPointerPress=null;});
async function openNetworkRadial(hit,x,y,self=false){
  if(characterFrontend.active||gameUi.blocksWorldInput)return;
  const world=networkFrontend.world,actor=world?.registry.get(world.localObjectId);if(!actor)return;
  const target=self?actor:hit?.object,point=hit&&!hit.object?hit.point.toArray():null;
  const id=networkFrontend.id,generation=networkFrontend.areaGeneration,text=networkFrontend.text;
  try{const options=await prepareNetworkSpellMenus(actor,target,networkQuickbar.tables,{getResource:(...args)=>nativeNetwork.getResource(id,...args)},v=>text.resolve(v,actor.id),(code,message,data)=>runtimeDiagnostics.record(code,message,data),{familiar:networkFamiliar(networkFrontend.world,actor)});if(id!==networkFrontend.id||generation!==networkFrontend.areaGeneration||actor.id!==networkFrontend.world?.localObjectId||characterFrontend.active||gameUi.blocksWorldInput)return;
    const nativePoint=target?[...(target.replicated?.position??target.staticState?.position??[0,0,0])]:point?[point[0],-point[2],point[1]]:[0,0,0];
    radialMenu.open(networkRadialActions(target,actor,options),x,y,{network:true,sessionId:id,areaGeneration:generation,actorId:actor.id,targetId:target?.id??actor.id,spellTargetId:target?.id??OBJECT_INVALID,nativePoint,groundPoint:point});
  }catch(error){if(id===networkFrontend.id&&generation===networkFrontend.areaGeneration){document.querySelector('#network-feedback').textContent=error.message;runtimeDiagnostics.error(error,'network.radial-menu-failed');}}
}
async function activateNetworkItem(itemId){
  const world=networkFrontend.world,item=world?.registry.get(itemId),sessionId=networkFrontend.id,generation=networkFrontend.areaGeneration;if(!item)throw new Error('Native inventory item is unavailable');
  if(networkSpellTarget.active)return networkSpellTarget.select(item,[0,0,0]);
  if(item.inventoryLocation?.channel==='C')return networkInventory.submit(itemId,'move',{destinationId:world.localObjectId});
  const containerTable=await networkFrontend.inventoryBaseItems();if(world!==networkFrontend.world||sessionId!==networkFrontend.id||generation!==networkFrontend.areaGeneration)throw new Error('Item activation belongs to an old area');if(intEntry(containerTable,item.item.baseItem,'Container').value!==0)return networkFrontend.interact(itemId,'object.use');
  const configured=configureNetworkItemShortcut(world,networkQuickbar.tables,emptyQuickbarButton(),{itemId,intParam:0xff00ff},{report:(...args)=>runtimeDiagnostics.record(...args)});if(!configured)throw new Error('That item cannot be activated');
  if((configured.button.intParam&65535)!==255)return networkSpellTarget.begin(configured.button);
  const table=await networkFrontend.inventoryBaseItems();if(world!==networkFrontend.world||sessionId!==networkFrontend.id||generation!==networkFrontend.areaGeneration)throw new Error('Item activation belongs to an old area');if(intEntry(table,item.item.baseItem,'EquipableSlots').value!==0)return networkInventory.submit(itemId,'toggle');
  runtimeDiagnostics.record('network.item-default-action-unhandled','Native container or other non-property item activation is not connected',{itemId});throw new Error('This item action is not connected yet');
}
async function openNetworkInventoryRadial(itemId,name,event){
  const world=networkFrontend.world,actor=world?.registry.get(world.localObjectId),item=world?.registry.get(itemId);if(!actor||!item||networkDialog.active)return;
  if(networkSpellTarget.active){void networkSpellTarget.select(item,[0,0,0]).catch(error=>networkInventory.failure(error));return;}
  const id=networkFrontend.id,generation=networkFrontend.areaGeneration,inventoryGeneration=networkInventory.generation,text=networkFrontend.text;
  try{const options=await prepareNetworkSpellMenus(actor,item,networkQuickbar.tables,{getResource:(...args)=>nativeNetwork.getResource(id,...args)},v=>text.resolve(v,actor.id),(code,message,data)=>runtimeDiagnostics.record(code,message,data),{filter:8,familiar:networkFamiliar(networkFrontend.world,actor)});if(id!==networkFrontend.id||generation!==networkFrontend.areaGeneration||actor.id!==networkFrontend.world?.localObjectId||inventoryGeneration!==networkInventory.generation||!networkInventory.active)return;
    options.itemUseEntries=await prepareNetworkItemMenu(world,itemId,networkQuickbar.tables,v=>text.resolve(v,actor.id),(...args)=>runtimeDiagnostics.record(...args),{quickbarToken:networkQuickbar.token,alive:()=>networkFrontend.world===world&&id===networkFrontend.id&&generation===networkFrontend.areaGeneration&&actor.id===world.localObjectId&&inventoryGeneration===networkInventory.generation&&networkInventory.active});
    if(id!==networkFrontend.id||generation!==networkFrontend.areaGeneration||inventoryGeneration!==networkInventory.generation||!networkInventory.active)return;
    const menu=networkRadialActions(item,actor,options);menu.title=name;radialMenu.open(menu,event.clientX,event.clientY,{network:true,inventory:true,sessionId:id,areaGeneration:generation,actorId:actor.id,targetId:item.id,spellTargetId:item.id,nativePoint:[0,0,0]});
  }catch(error){if(id===networkFrontend.id&&generation===networkFrontend.areaGeneration)networkInventory.failure(error);}
}
async function submitNetworkRadialAction(entry,context){
  const feedback=document.querySelector('#network-feedback');
  try{
    if(context.sessionId!==networkFrontend.id||context.areaGeneration!==networkFrontend.areaGeneration||context.actorId!==undefined&&context.actorId!==networkFrontend.world?.localObjectId)throw new Error('Radial target is no longer available');
    if(entry.action==='character.sheet'){await networkPanels.open('character');}
    else if(entry.action==='spell.variant'){if(context.familyToken!==networkQuickbar.token||!spellFamilyContains(networkQuickbar.tables,context.familyParent,entry.binding.intParam))throw new Error('Spell variant is no longer available');await networkSpellTarget.begin(entry.binding);}
    else if(entry.action==='object.examine'){await networkFrontend.examine(context.targetId);}
    else if(entry.action==='item.use'&&entry.binding){await networkSpellTarget.beginItem(entry.binding.itemId,entry.binding.packed);}
    else if(entry.action==='spell.cast'){const targetId=context.spellTargetId??context.targetId,target=targetId===OBJECT_INVALID?null:networkFrontend.world.registry.get(targetId);if(targetId!==OBJECT_INVALID&&!target)throw new Error('Spell target is no longer available');await networkSpellTarget.radial(entry.binding,target,context.nativePoint);}
    else if(entry.action==='spellLike.use'){const targetId=context.spellTargetId??context.targetId,target=targetId===OBJECT_INVALID?null:networkFrontend.world.registry.get(targetId);if(targetId!==OBJECT_INVALID&&!target)throw new Error('Ability target is no longer available');await networkSpellTarget.radialInnate(entry.binding,target,context.nativePoint);}
    else if(entry.action==='feat.use'){const targetId=context.spellTargetId??context.targetId,target=targetId===OBJECT_INVALID?null:networkFrontend.world.registry.get(targetId);if(targetId!==OBJECT_INVALID&&!target)throw new Error('Ability target is no longer available');await networkSpellTarget.radialFeat(entry.binding,target,context.nativePoint);}
    else if(['associate.possessFamiliar','associate.possess'].includes(entry.action))await networkFrontend.possessFamiliar();
    else if(entry.action==='associate.command')await networkFrontend.associateCommand(context.targetId,entry.command);
    else if(entry.action==='associate.quickChat')await networkFrontend.quickChat(entry.quickChat);
    else if(entry.action==='rest')await networkFrontend.rest();
    else if(entry.action==='item.pickup'){const item=networkFrontend.world.registry.get(context.targetId);if(item?.inventoryLocation?.channel==='C')await networkInventory.submit(item.id,'move',{destinationId:networkFrontend.world.localObjectId});else await networkFrontend.itemAction({itemId:context.targetId,operation:'pickup'});}
    else if(context.inventory&&['item.use','item.drop'].includes(entry.action)){
      const item=networkFrontend.world.registry.get(context.targetId);if(!item)throw new Error('Native inventory item is unavailable');
      if(entry.action==='item.drop')await networkInventory.submit(item.id,'drop');
      else await activateNetworkItem(item.id);
    }else if(entry.action==='movement.moveTo'&&context.groundPoint){const [x,y,z]=context.groundPoint;await networkFrontend.walkTo([x,-z,y],true);}
    else{
      const action=({'placeable.use':'object.use','combat.bash':'combat.attack'})[entry.action]??entry.action;
      if(!['door.open','door.close','door.transition','trigger.transition','conversation.start','object.use','combat.attack'].includes(action)){
        runtimeDiagnostics.record('network.interaction-unimplemented','Native interaction handler is not connected',{action:entry.action,objectId:context.targetId});feedback.textContent=entry.label+' is not connected yet';return;
      }
      await networkFrontend.interact(context.targetId,action,context.run??true);
    }
    feedback.textContent=entry.label+' requested';
  }catch(error){feedback.textContent=error.message;runtimeDiagnostics.error(error,'network.interaction-failed');}
}
canvas.addEventListener('contextmenu',event=>{if(networkFrontend.id)event.preventDefault();});
canvas.addEventListener('pointerdown',event=>{if(networkFrontend.id&&event.button===0)networkKeyboard.clear();});
canvas.addEventListener('pointerdown',event=>{
  if(!networkFrontend.id||!networkPresentation||networkPresentation.graphicsPending||rendererWarmupCount||characterFrontend.active||gameUi.blocksWorldInput||event.button!==2)return;
  if(networkSpellTarget.active){event.preventDefault();networkSpellTarget.reset();document.querySelector('#network-feedback').textContent='Spell targeting cancelled';return;}
  event.preventDefault();const hit=networkPresentation.pick(pointerRay(event.clientX,event.clientY,canvas.getBoundingClientRect(),camera),{includePlayer:true});
  if(hit)openNetworkRadial(hit,event.clientX,event.clientY);
});
canvas.addEventListener('pointerup',event=>{
  const press=networkPointerPress;networkPointerPress=null;
  if(!networkFrontend.id||!networkPresentation)return;
  const blocked=networkPresentation.graphicsPending||rendererWarmupCount?'graphics':characterFrontend.active||gameUi.blocksWorldInput?'frontend':!press?'no-press':event.button!==0?'button':press.id!==event.pointerId?'pointer':Math.hypot(event.clientX-press.x,event.clientY-press.y)>5?'drag':null;
  if(blocked){canvas.dataset.networkPick=JSON.stringify({at:Date.now(),blocked,targeting:networkSpellTarget.active});return;}
  const feedback=document.querySelector('#network-feedback'),hit=networkPresentation.pick(pointerRay(event.clientX,event.clientY,canvas.getBoundingClientRect(),camera),{includePlayer:networkSpellTarget.active});
  canvas.dataset.networkPick=JSON.stringify({at:Date.now(),blocked:null,targeting:networkSpellTarget.active,screen:[event.clientX,event.clientY],hit:hit?{objectId:hit.object?.id??null,objectType:hit.object?.objectType??null,point:hit.point.toArray(),distance:hit.distance}:null});
  if(!hit){feedback.textContent='Select walkable ground';return;}
  if(networkSpellTarget.active){const point=hit.point.toArray();void networkSpellTarget.select(hit.object??null,[point[0],-point[2],point[1]]).catch(error=>{feedback.textContent=error.message;runtimeDiagnostics.error(error,'network.spell-target-failed');});return;}
  if(hit.object){const action=networkDefaultInteraction(hit.object);if(action)void submitNetworkRadialAction({action,label:'Interaction'},{network:true,sessionId:networkFrontend.id,areaGeneration:networkFrontend.areaGeneration,targetId:hit.object.id,run:!event.shiftKey});else{runtimeDiagnostics.record('network.interaction-unimplemented','Native default interaction is not connected',{objectId:hit.object.id,objectType:hit.object.objectType});feedback.textContent='No interaction is available';}return;}
  const point=hit.point.toArray(),native=[point[0],-point[2],point[1]];
  void networkFrontend.walkTo(native,!event.shiftKey).then(({sequence})=>{feedback.textContent='Move requested';canvas.dataset.networkMove=JSON.stringify({sequence,position:native,run:!event.shiftKey});runtimeDiagnostics.record('network.walk-requested','Native waypoint request sent',{sequence,position:native,run:!event.shiftKey},'info');}).catch(error=>{feedback.textContent=error.message;runtimeDiagnostics.error(error,'network.walk-request-failed');});
});


