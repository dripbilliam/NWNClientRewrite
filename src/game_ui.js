import { NativeUiAssets, UI_PIXELS_PER_UNIT as PPU } from './native_ui_assets.js';
import { GameText, parseTalkTable } from './talk_table.js';
import { GameUiState, GAME_PANELS, journalRows, nativeControlKind } from './game_ui_state.js';
import { ABILITIES, EQUIPMENT_SLOTS } from './character.js';
import { runtimeDiagnostics } from './runtime_diagnostics.js';
import {actionQueueRecords} from './action_queue_display.js';
import {describeActionQueue} from './action_queue_presentation.js';
import {parse2da} from './area.js';
import {RESOURCE_TYPE,decodeResourceText} from './resource_archive.js';
import {initializeQuickbar,getQuickbarButton,setQuickbarButton,quickbarRequest} from './quickbar.js';
import {QuickbarLayouts} from './quickbar_storage.js';
import {quickbarAssignmentMenu} from './quickbar_menu.js';

const el = (tag, className, text) => { const node = document.createElement(tag); if (className) node.className = className; if (text !== undefined) node.textContent = text; return node; };
const button = (text, action, className = '') => { const b = el('button', `game-button ${className}`, text); b.type = 'button'; b.addEventListener('click', action); return b; };
const titles = Object.fromEntries(GAME_PANELS.map(([id, title]) => [id, title]));
const panelModels = { journal: 'pnl_jnl_panel', inventory: 'pnl_inv', character: 'pnl_chrsht', map: 'pnl_map_area', spells: 'pnl_spellbook', dialogue: 'pnl_dialog', store: 'pnl_store', barter: 'pnl_barter', examine: 'pnl_exam_item' };
const nativeRoutes = {
  pre_main: { NewButton: 'pre_newgame', LoadButton: 'pre_loadgame', MultiButton: 'pre_multiplayer', MoviesButton: 'pre_movies', OptionsButton: 'options_pregame' },
  options_main: { GameButton: 'options_game', SoundOptionsButton: 'options_sound', ControlsButton: 'options_controls', VideoOptionsButton: 'options_video' },
  options_pregame: { SoundButton: 'options_sound', VideoButton: 'options_video', ControlButton: 'options_controls' },
  pre_newgame: { CampaignButton: 'pre_campaign', OtherButton: 'pre_playmod', NewButton: 'pre_campaign' },
  cg_main: { GenderButton: 'cg_sex', RaceButton: 'cg_race', ClassButton: 'cg_class', AlignButton: 'cg_alignment', AbilitiesButton: 'cg_attributes', SkillsButton: 'cg_skills', FeatsButton: 'cg_feats', SpellsButton: 'cg_spells', PortraitButton: 'cg_portrait', CustomizeButton: 'cg_appearance', NameButton: 'cg_char_info', PackagesButton: 'cg_package' },
  pre_multiplayer: { IntJoinButton: 'serverlist_panel', LANJoinButton: 'serverlist_lan', NewButton: 'pre_newgamem', LoadButton: 'pre_loadgamem' },
  cg_appearance: { NameButton: 'cg_char_info' }
};

export class GameUi {
  constructor(viewport, { getSession, getWorld, getSelected, radialActive, hasPendingAction, onCancelAction, onInputCapture, onRequest, onOpenModule, onSettings, onQuickbarMenu } = {}) {
    Object.assign(this, { viewport, getSession, getWorld, getSelected, radialActive, hasPendingAction, onCancelAction, onInputCapture, onRequest, onOpenModule, onSettings, onQuickbarMenu });
    this.quickbarLayouts=new QuickbarLayouts();this.quickbarIcons=new Map();this.modifierPage=null;
    this.state = new GameUiState(); this.text = new GameText(); this.assets = null; this.session = null; this.messages = []; this.visible = true; this.renderVersion = 0; this.lastRefresh = 0;
    this.root = el('div', 'game-ui'); this.root.id = 'game-ui'; this.root.hidden = true; viewport.append(this.root);
    this.hud = el('div', 'game-hud'); this.root.append(this.hud);
    this.layer = el('div', 'game-window-layer'); this.root.append(this.layer);
    this.notice = el('div', 'game-notice'); this.notice.setAttribute('role', 'status'); this.root.append(this.notice);
    this.root.addEventListener('contextmenu', e => e.preventDefault());
    for (const event of ['pointerdown', 'pointerup', 'click', 'dblclick', 'wheel']) this.root.addEventListener(event, e => e.stopPropagation());
    window.addEventListener('keydown', event => this.key(event), true);
    window.addEventListener('keyup', event => { if(['Shift','Control'].includes(event.key)){this.modifierPage=event.ctrlKey?2:event.shiftKey?1:null;this.updateQuickbar();} if (this.captured || this.root.contains(event.target)) event.stopImmediatePropagation(); }, true);
    window.addEventListener('blur',()=>{this.modifierPage=null;this.updateQuickbar();});
    this.catalog = document.querySelector('#ui-resource-select');
    this.catalog?.addEventListener('change', () => { if (this.catalog.value) this.open(`native:${this.catalog.value}`); });
    this.panelCatalog = document.querySelector('#ui-panel-select');
    this.panelCatalog?.addEventListener('change', () => { if (this.panelCatalog.value) this.toggle(this.panelCatalog.value); });
  }
  get captured() { return Boolean(this.externalCapture || this.state.panel); }
  async attach(session, resolver) {
    if (this.session === session) return;
    this.renderVersion++; this.layer.replaceChildren(); this.assets?.dispose(); this.session = session; this.state.reset(); this.messages = []; this.signature = '';
    this.assets = new NativeUiAssets(resolver); this.root.hidden = false; this.portraitKey = null;this.quickbarIcons.clear();
    if(!session.player.nativeQuickbar4e0)initializeQuickbar(session.player);
    if(session.quickbarProfileKey)try{const saved=await this.quickbarLayouts.get(session.quickbarProfileKey);if(saved){session.loadPlayerQuickbar(session.player,saved.QBList??saved);for(const [i,source]of (saved.itemSources??[]).entries()){const b=getQuickbarButton(session.player,i);if(b?.type===1&&source&&(session.registry.get(b.itemId)?.sourceKey!==source.primary||(source.secondary&&session.registry.get(b.secondaryItemId)?.sourceKey!==source.secondary))){setQuickbarButton(session.player,i,null);runtimeDiagnostics.record('quickbar.item-not-restored','Saved local shortcut item is absent from the imported character',{slot:i,source});}}}}catch(error){runtimeDiagnostics.error(error,'quickbar.layout-load-failed');}
    await this.assets.initializeFonts();
    this.catalog?.replaceChildren(new Option('Native UI resources', ''), ...this.assets.names().map(n => new Option(n, n)));
    this.panelCatalog?.replaceChildren(new Option('Game UI panels', ''), ...GAME_PANELS.map(([id, title]) => new Option(title, id)));
    if (this.panelCatalog) this.panelCatalog.disabled = false;
    this.buildHud(); this.notify('Module loaded'); this.onInputCapture?.(false);
    if (this.languageFiles) await this.loadLanguage(this.languageFiles);
    this.root.dataset.nativeLayouts = String(this.assets.names().length);
    this.refresh(true);
  }
  async attachFrontend(resolver) {
    this.assets?.dispose(); this.session = null; this.state.reset(); this.assets = new NativeUiAssets(resolver);
    await this.assets.initializeFonts(); this.root.hidden = false; this.hud.replaceChildren();
    const top = el('div', 'game-top-actions'); top.append(button('Load Character', () => this.request('character.load')), button('Open Module', () => this.onOpenModule?.()), button('Tools', () => { this.mode(false); this.closeAll(); this.root.hidden = true; })); this.hud.append(top);
    this.catalog?.replaceChildren(new Option('Native UI resources', ''), ...this.assets.names().map(n => new Option(n, n)));
    if (this.panelCatalog) this.panelCatalog.disabled = true;
    this.mode(true); this.open('main');
  }
  detach() { this.renderVersion++; this.assets?.dispose(); this.assets = null; this.session = null; this.root.hidden = true; this.closeAll(); }
  async loadLanguage(files) {
    this.languageFiles = [...files];
    const base = [...files].find(f => f.name.toLowerCase() === 'dialog.tlk');
    if (!base) throw new Error('Choose the language data folder containing dialog.tlk');
    const customName = String(this.session?.ifo.Mod_CustomTlk ?? '').replace(/\.tlk$/i, '').toLowerCase();
    const custom = [...files].find(f => f.name.toLowerCase() === `${customName}.tlk`);
    this.text = new GameText({ base: parseTalkTable(await base.arrayBuffer()), custom: custom ? parseTalkTable(await custom.arrayBuffer()) : null });
    this.text.language = this.text.base.language; this.signature = ''; this.refresh(true); if (this.state.panel) await this.renderPanel();
  }
  mode(enabled) { document.body.classList.toggle('game-mode', enabled); document.querySelector('#game-mode-button')?.setAttribute('aria-pressed', String(enabled)); }
  open(panel) { if (!this.assets || this.session?.player.cutscene?.enabled && panel !== 'dialogue') return; this.visible = true; this.root.hidden = false; this.state.open(panel); this.onInputCapture?.(true); void this.renderPanel(); }
  toggle(panel) { if (!this.assets || this.session?.player.cutscene?.enabled && panel !== 'dialogue') return; this.state.toggle(panel); this.onInputCapture?.(this.captured); void this.renderPanel(); }
  close() {
    if (this.state.panel === 'dialogue' && this.session?.conversation.state) {
      this.request('conversation.close', { aborted: !this.session.conversation.state.complete, version: this.session.conversation.version }); return;
    }
    this.state.close(); this.onInputCapture?.(this.captured); void this.renderPanel(); if (!this.session && !this.captured) { this.mode(false); this.root.hidden = true; }
  }
  conversationChanged() {
    this.dialogVersion = this.session?.conversation.version;
    if (this.session?.conversation.state) { this.mode(true); if (this.state.panel !== 'dialogue') this.open('dialogue'); else void this.renderPanel(); }
    else if (this.state.panel === 'dialogue') { this.state.close(); this.onInputCapture?.(this.captured); void this.renderPanel(); }
  }
  closeAll() { this.renderVersion++; this.state.stack = []; this.layer.replaceChildren(); this.root.dataset.panel = ''; this.onInputCapture?.(false); if (!this.session) { this.mode(false); this.root.hidden = true; } }
  notify(message) { this.notice.textContent = message; clearTimeout(this.noticeTimer); this.noticeTimer = setTimeout(() => { this.notice.textContent = ''; }, 6500); }
  message(message, type = 'system') {
    const text = typeof message === 'string' ? message : message.type === 'oneLiner' ? this.dialogueText(message.text, this.session?.registry.get(message.tokenTargetId) ?? null, message.gender) : message.text;
    if (!text || this.messages.at(-1)?.text === text && this.messages.at(-1)?.type === type) return;
    this.messages.push({ text, type }); if (this.messages.length > 100) this.messages.shift();
    this.updateLog(); this.notify(text);
  }
  request(action, detail = {}) {
    if (this.getSession()?.player.cutscene?.enabled && !['conversation.reply', 'conversation.close'].includes(action)) return;
    const player = this.getSession()?.player;
    const request = { action, actorId: player?.id, areaId: player?.areaId, ...detail };
    this.root.dataset.lastRequest = JSON.stringify(request); this.onRequest?.(request);
  }
  async art(node, model, state = 'up') {
    const assets = this.assets;
    try { const skin = await assets.skin(model, state); if (assets !== this.assets || !skin?.url) return; node.style.backgroundImage = `url("${skin.url}")`; node.dataset.nativeModel = model; return skin; }
    catch (e) { if (assets === this.assets) { assets.warnings.add(`${model}: ${e.message}`); console.warn('[UI asset]', e.message); } }
  }
  async positionedArt(parent, model, x = 0, y = 0) {
    const image = el('div', 'native-art'); parent.append(image); const skin = await this.art(image, model);
    if (skin) Object.assign(image.style, { left: `${x + skin.min[0] * PPU}px`, top: `${y - skin.max[1] * PPU}px`, width: `${skin.width}px`, height: `${skin.height}px` });
    return skin;
  }
  buildHud() {
    this.hud.replaceChildren();
    this.queueSignature='';this.queueActions=null;this.queueTableError=false;
    const queue=el('div','game-action-queue');queue.setAttribute('aria-label','Action queue');this.hud.append(queue);this.queueButtons=[];
    for(let index=0;index<10;index++){
      const node=button('',()=>{const record=this.queueRows?.[index];if(record)this.request('action.queue.cancel',{actionId:record.code,groupId:record.group,queueIndex:index});},'game-queued-action');
      node.hidden=true;node.style.left=`${3+index*43}px`;node.style.top='3px';node.dataset.queueIndex=String(index);queue.append(node);this.queueButtons.push(node);void this.art(node,'ctl_actionqueue');
    }
    const session=this.session,assets=this.assets;
    void assets.resolver.getResource('actions',RESOURCE_TYPE.TWO_DA).then(bytes=>{
      if(this.session!==session||this.assets!==assets)return;this.queueActions=parse2da(decodeResourceText(bytes));this.queueSignature='';this.refresh(true);
    }).catch(error=>{if(this.assets===assets){this.queueTableError=true;runtimeDiagnostics.error(error,'ui.action-queue-table-unavailable');}});
    const party = el('div', 'game-party'); party.setAttribute('aria-label', 'Player and party'); this.hud.append(party);
    void this.art(party, 'pnl_party_bar');
    const portrait = button('', () => this.toggle('character'), 'game-portrait'); portrait.title = 'Character Sheet (C)'; portrait.setAttribute('aria-label', portrait.title); party.append(portrait);
    const silhouette = el('span', 'game-portrait-silhouette', '♙'); portrait.append(silhouette);
    const health = el('div', 'game-health', '—'); health.title = 'Hit points unavailable until a character is loaded'; party.append(health);
    const buttons = [['map', 'pb_but_map'], ['inventory', 'pb_but_inv'], ['journal', 'pb_but_jour'], ['character', 'pb_but_char'], ['rest', 'pb_but_rest'], ['spells', 'pb_but_spell'], ['options', 'pb_but_opts'], ['pvp', 'pb_but_pvp']];
    const actions = el('div', 'game-party-buttons'); party.append(actions);
    for (const [id, model] of buttons) {
      const title = titles[id] ?? (id === 'rest' ? 'Rest' : 'Player versus Player');
      const b = button('', () => titles[id] ? this.toggle(id) : this.request(id), 'game-hud-icon'); b.dataset.panel = id; b.title = title; b.setAttribute('aria-label', title); void this.art(b, model); actions.append(b);
    }
    const identity = el('div', 'game-identity'); identity.id = 'game-player-name'; party.append(identity);
    const quick = el('div', 'game-quickbar'); quick.setAttribute('aria-label', 'Quickbar'); this.hud.append(quick);
    const pages = el('div', 'game-quick-pages'); quick.append(pages);
    for (let p = 0; p < 3; p++) pages.append(button(String(p + 1), () => { this.state.quickbarPage = p; this.updateQuickbar(); }, 'game-quick-page'));
    const slots = el('div', 'game-quick-slots'); quick.append(slots);
    for (let i = 0; i < 12; i++) {
      const b = button('', () => this.useQuickbar(this.quickbarPage(), i), 'game-quick-slot'); b.dataset.slot = i; b.title = `F${i + 1} · Drag an item, spell or feat here, or right-click to assign`; b.setAttribute('aria-label', `Quickbar slot ${i + 1}`);
      b.append(el('span', 'game-slot-number', `F${i + 1}`), el('span', 'game-slot-icon'));
      void this.art(b, 'qb_but66');
      b.addEventListener('contextmenu', e => { e.preventDefault();this.onQuickbarMenu?.(quickbarAssignmentMenu(`Assign F${i+1}`,this.quickbarChoices()),this.quickbarPage()*12+i,e); });
      b.draggable=true;
      b.addEventListener('dragstart',e=>{const index=this.quickbarPage()*12+i,binding=getQuickbarButton(this.session.player,index);if(!binding?.type){e.preventDefault();return;}this.writeQuickbarDrag(e,binding,index);});
      b.addEventListener('dragover',e=>{if(e.dataTransfer.types.includes('application/x-nwn-quickbar')){e.preventDefault();e.dataTransfer.dropEffect='move';b.classList.add('drag-over');}});
      b.addEventListener('dragleave',()=>b.classList.remove('drag-over'));
      b.addEventListener('drop',e=>{e.preventDefault();b.classList.remove('drag-over');try{const payload=JSON.parse(e.dataTransfer.getData('application/x-nwn-quickbar'));if(payload.actorId!==this.session.player.id)throw new Error('Quickbar drag belongs to another character');const index=this.quickbarPage()*12+i;this.assignQuickbar(index,payload.binding);if(Number.isInteger(payload.sourceIndex)&&payload.sourceIndex!==index)this.assignQuickbar(payload.sourceIndex,null);}catch(error){runtimeDiagnostics.error(error,'quickbar.drop-failed');this.notify(error.message);}});
      slots.append(b);
    }
    const log = el('section', 'game-log'); log.setAttribute('aria-label', 'Game messages');
    const logTabs = el('div', 'game-log-tabs'); logTabs.append(button('Messages', () => { this.logType = null; this.updateLog(); }), button('System', () => { this.logType = 'system'; this.updateLog(); }));
    this.logBody = el('div', 'game-log-body'); this.logBody.setAttribute('role', 'log');
    const form = el('form', 'game-chat'); const input = el('input'); input.placeholder = 'Talk'; input.setAttribute('aria-label', 'Chat message'); input.maxLength = 512;
    const send = el('button', 'game-button', 'Send'); send.type = 'submit'; form.append(input, send); form.addEventListener('submit', e => { e.preventDefault(); if (input.value.trim()) { this.request('chat.send', { text: input.value.trim() }); input.value = ''; } });
    input.addEventListener('focus', () => this.onInputCapture?.(true)); input.addEventListener('blur', () => this.onInputCapture?.(this.captured));
    log.append(logTabs, this.logBody, form); this.hud.append(log);
    const top = el('div', 'game-top-actions'); top.append(button('Main Menu', () => this.open('main')), button('Conversation', () => this.toggle('dialogue')), button('Tools', () => this.mode(false))); this.hud.append(top);
    this.areaLabel = el('div', 'game-area-name'); this.hud.append(this.areaLabel); this.updateQuickbar(); this.updateLog();
  }
  updateQuickbar() {
    if(!this.session)return;
    const page=this.quickbarPage();
    for (const b of this.hud.querySelectorAll('.game-quick-slot')) {
      const binding=getQuickbarButton(this.session.player,page*12+Number(b.dataset.slot)),description=this.quickbarDescription(binding);
      const key=JSON.stringify(binding);b.dataset.page=String(page);b.dataset.quickbarIndex=String(page*12+Number(b.dataset.slot));b.dataset.quickbarType=String(binding?.type??0);
      b.dataset.targetId=binding?.type===1?String(binding.itemId):'';
      b.title=description?.label??`F${Number(b.dataset.slot)+1} · Drag here or right-click to assign`;
      if(b.dataset.binding!==key){b.dataset.binding=key;const icon=b.querySelector('.game-slot-icon');icon.replaceChildren();if(description){icon.textContent=description.label.slice(0,4);if(description.icon)void this.quickbarIcon(description.icon,icon,key,b);}}
    }
    [...this.hud.querySelectorAll('.game-quick-page')].forEach((b, i) => b.setAttribute('aria-pressed', String(i === page)));
    this.root.dataset.quickbar=JSON.stringify(this.session.player.nativeQuickbar4e0);
  }
  quickbarPage(){return this.modifierPage??this.state.quickbarPage;}
  writeQuickbarDrag(event,binding,sourceIndex){event.dataTransfer.effectAllowed='copyMove';event.dataTransfer.setData('application/x-nwn-quickbar',JSON.stringify({actorId:this.session.player.id,binding,sourceIndex}));}
  makeQuickbarSource(node,binding){node.draggable=true;node.dataset.quickbarBinding=JSON.stringify(binding);node.addEventListener('dragstart',e=>this.writeQuickbarDrag(e,binding));return node;}
  assignQuickbar(index,binding){
    if(!this.session||!setQuickbarButton(this.session.player,index,binding))return;
    this.updateQuickbar();this.notify(binding?.type?`Assigned ${this.quickbarDescription(binding)?.label??'action'} to F${index%12+1}`:`Cleared F${index%12+1}`);
    const session=this.session;if(session.quickbarProfileKey){const saved={QBList:session.savePlayerQuickbar(),itemSources:session.player.nativeQuickbar4e0.map(b=>b.type===1?{primary:session.registry.get(b.itemId)?.sourceKey,secondary:session.registry.get(b.secondaryItemId)?.sourceKey}:null)};this.quickbarSave=(this.quickbarSave??Promise.resolve()).catch(()=>{}).then(()=>this.quickbarLayouts.put(session.quickbarProfileKey,saved));void this.quickbarSave.catch(error=>runtimeDiagnostics.error(error,'quickbar.layout-save-failed'));}
  }
  quickbarDescription(b){
    if(!b?.type)return null;const rules=this.session.characterRules,row=(table,id)=>rules?.[table]?.orderedRows?.[id]??rules?.[table]?.rows?.get(id);
    if(b.type===1){const item=this.session.registry.get(b.itemId);return {label:item?this.objectName(item):'Unavailable item',icon:row('baseitems',item?.baseItem)?.ItemIcon??null};}
    if(b.type===2||b.type===44)return {label:this.ruleName('spells',b.intParam),icon:row('spells',b.intParam)?.IconResRef};
    if(b.type===4)return {label:this.ruleName('feat',b.intParam,'FEAT'),icon:row('feat',b.intParam)?.ICON};
    if(b.type===3)return {label:this.ruleName('skills',b.intParam),icon:row('skills',b.intParam)?.Icon};
    return {label:b.commandLabel||b.toolTip||`Quickbar action ${b.type}`,icon:null};
  }
  async quickbarIcon(name,host,key,slot){
    if(!name||name==='****')return;
    try{if(!this.quickbarIcons.has(name))this.quickbarIcons.set(name,(async()=>{const {image}=await this.assets.texture(name),canvas=document.createElement('canvas');canvas.width=image.width;canvas.height=image.height;canvas.getContext('2d').putImageData(new ImageData(new Uint8ClampedArray(image.data),image.width,image.height),0,0);return canvas.toDataURL();})());const url=await this.quickbarIcons.get(name);if(slot.dataset.binding===key&&host.isConnected){const img=el('img');img.alt='';img.src=url;host.replaceChildren(img);}}
    catch(error){runtimeDiagnostics.error(error,'quickbar.icon-unavailable',{resRef:name});}
  }
  quickbarChoices(){
    const p=this.session.player,groups=[{slot:2,label:'Items',icon:'IR_USE',entries:[]},{slot:1,label:'Spells',icon:'IR_CAST',entries:[]},{slot:3,label:'Feats',icon:'IR_XABILITY',entries:[]},{slot:4,label:'Skills',icon:'IR_STEALTH',entries:[]}];
    for(const id of p.inventory??[]){const item=this.session.registry.get(id);if(item)groups[0].entries.push({label:this.objectName(item),binding:{type:1,itemId:id,intParam:0xff00ff}});}
    for(const [classIndex,c]of (p.creatureData??p.authored).ClassList?.entries()??[]){const state=p.nativeTalentClasses?.[classIndex];if(!state)continue;const seen=new Set();for(const level of [0,1,2,3,4,5,6,7,8,9])for(const spell of [...state.known[level].map(id=>({id,metamagic:0})),...state.memorized[level].filter(Boolean)]){const key=`${spell.id}:${spell.metamagic??0}`;if(seen.has(key))continue;seen.add(key);groups[1].entries.push({label:`${this.ruleName('spells',spell.id)} · ${this.ruleName('classes',c.Class)}`,binding:{type:2,intParam:spell.id,classIndex,metamagic:spell.metamagic??0,domainLevel:0}});}}
    for(const id of p.stats?.feats??[])groups[2].entries.push({label:this.ruleName('feat',id,'FEAT'),binding:{type:4,intParam:id}});
    for(const [id,rank]of (p.stats?.skills??[]).entries())if(rank>0)groups[3].entries.push({label:this.ruleName('skills',id),binding:{type:3,intParam:id}});
    return groups;
  }
  useQuickbar(page, slot) {
    const session = this.getSession(); if (!session) return;
    const action = quickbarRequest(session.player,getQuickbarButton(session.player,page*12+slot),session.registry,this.getSelected?.()?.id);
    if (action) this.request(action.action,action);
    else this.notify('Quickbar slot is empty or its target is unavailable');
  }
  updateLog() {
    if (!this.logBody) return; this.logBody.replaceChildren(...this.messages.filter(m => !this.logType || m.type === this.logType).slice(-30).map(m => el('div', `game-message ${m.type}`, m.text))); this.logBody.scrollTop = this.logBody.scrollHeight;
  }
  refresh(force = false) {
    if (!this.session || !this.assets || !this.hud.querySelector('#game-player-name')) return;
    const now = performance.now(); if (!force && now - this.lastRefresh < 200) return; this.lastRefresh = now;
    const session = this.getSession(); if (session !== this.session) return;
    this.root.hidden = !this.visible; this.areaLabel.textContent = session.currentArea?.name || session.currentArea?.resRef || '';
    this.hud.querySelector('#game-player-name').textContent = session.player.name;
    const stats = session.player.stats, health = this.hud.querySelector('.game-health');
    health.textContent = stats ? `${session.hitPoints(session.player.id, false)}/${stats.maxHP}` : '—';
    health.title = stats ? `Hit points · ${stats.limitations.join(' ')}` : 'Hit points unavailable until a character is loaded';
    this.root.dataset.characterXP = stats?.xp ?? ''; this.root.dataset.characterLoaded = String(Boolean(session.player.characterLoaded));
    this.root.dataset.cutscene = String(Boolean(session.player.cutscene?.enabled));
    this.updateActionQueue();
    this.updateQuickbar();
    if (this.dialogVersion !== session.conversation?.version) this.conversationChanged();
    if (session.player.characterLoaded && this.portraitKey !== session.player.authored.Portrait) {
      this.portraitKey = session.player.authored.Portrait; void this.loadPortrait(this.portraitKey);
    }
    const sig = JSON.stringify([session.player.id, session.player.areaId, [...session.player.journal], session.player.inventory ?? [], stats,
      this.state.panel==='spells'?session.player.nativeTalentClasses:null]);
    this.root.dataset.playerId = session.player.id; this.root.dataset.journalEntries = session.player.journal.size;
    if (sig !== this.signature) { this.signature = sig; if (['journal', 'inventory', 'character', 'party', 'spells'].includes(this.state.panel)) void this.renderPanel(); }
    if (this.state.panel === 'map') this.drawMap();
  }
  updateActionQueue(){
    const records=actionQueueRecords(this.session.player);this.root.dataset.nativeActionQueue=JSON.stringify(records);
    if(!this.queueActions||!this.queueButtons)return;
    const signature=JSON.stringify(records);if(signature===this.queueSignature)return;this.queueSignature=signature;
    try{this.queueRows=describeActionQueue(records,this.queueActions,this.session.characterRules?.spells,this.text);}
    catch(error){runtimeDiagnostics.error(error,'ui.action-queue-description-unavailable');return;}
    for(let index=0;index<10;index++){
      const node=this.queueButtons[index],row=this.queueRows[index];node.hidden=!row;if(!row)continue;
      const target=this.session.registry.get(row.targetId),caption=`${row.label}${target?` · ${target.name||target.tag||target.kind}`:''}`;
      node.title=caption;node.setAttribute('aria-label',caption);node.dataset.action=String(row.code);node.dataset.groupId=String(row.group);node.dataset.targetId=String(row.targetId);
      const previous=node.querySelector('.game-queue-icon');previous?.remove();node.dataset.icon=row.icon??'';
      if(row.icon){const assets=this.assets,name=row.icon;
        void assets.texture(name).then(texture=>{
          if(assets!==this.assets||node.dataset.icon!==name||node.hidden)return;
          const {width,height,data}=texture.image,icon=el('canvas','game-queue-icon');icon.width=width;icon.height=height;
          icon.getContext('2d').putImageData(new ImageData(new Uint8ClampedArray(data),width,height),0,0);node.querySelector('.game-queue-icon')?.remove();node.append(icon);
        }).catch(error=>{if(assets===this.assets)runtimeDiagnostics.error(error,'ui.action-queue-icon-unavailable',{resource:name});});
      }
    }
  }
  async loadPortrait(name) {
    const assets = this.assets;
    if (!name) return;
    try {
      const texture = await assets.texture(`${name}s`);
      if (this.assets !== assets || this.portraitKey !== name) return;
      const { width, height, data } = texture.image, c = document.createElement('canvas'); c.width = width; c.height = height;
      c.getContext('2d').putImageData(new ImageData(new Uint8ClampedArray(data), width, height), 0, 0);
      const portrait = this.hud.querySelector('.game-portrait'); portrait.style.backgroundImage = `url("${c.toDataURL()}")`;
      portrait.querySelector('.game-portrait-silhouette').hidden = true;
    } catch (error) { assets.warnings.add(`Portrait ${name}: ${error.message}`); }
  }
  ruleName(table, id, field = 'Name') {
    const row = this.session.characterRules?.[table]?.rows.get(id), ref = row?.[field];
    return ref && ref !== '****' ? this.text.resolve({ strRef: Number(ref), entries: [] }) || row.Label || row.LABEL || `${table} ${id}` : row?.Label || row?.LABEL || `${table} ${id}`;
  }
  objectName(object) { return this.text.resolve(object.authored?.LocalizedName) || object.name || object.tag || `${object.kind} ${object.id}`; }
  key(event) {
    if (this.externalCapture) return;
    if (!this.assets || event.defaultPrevented) return;
    if (this.radialActive?.()) return;
    const editing = /INPUT|TEXTAREA|SELECT/.test(event.target.tagName);
    if (editing) { if (event.key === 'Escape') event.target.blur(); event.stopImmediatePropagation(); return; }
    const key = event.key.toLowerCase(); let handled = true;
    if(['Shift','Control'].includes(event.key)){this.modifierPage=event.key==='Control'||event.ctrlKey?2:1;this.updateQuickbar();return;}
    const conversation = this.session?.conversation;
    if (this.state.panel === 'dialogue' && conversation?.state && /^[1-9]$/.test(key)) {
      const reply = conversation.state.replies[Number(key) - 1];
      if (reply) this.request('conversation.reply', { ordinal: reply.ordinal, version: conversation.version });
      event.preventDefault(); event.stopImmediatePropagation(); return;
    }
    if (this.session?.player.cutscene?.enabled && !conversation?.state) { event.preventDefault(); event.stopImmediatePropagation(); return; }
    if (event.repeat) { if (this.captured) { event.preventDefault(); event.stopImmediatePropagation(); } return; }
    if (key === 'escape') { if (this.captured) this.close(); else if (this.hasPendingAction?.()) this.onCancelAction?.(); else if (this.session) this.open('options'); else { this.mode(false); this.root.hidden = true; } }
    else if (key === 'h') { this.visible = !this.visible; if (!this.visible) this.closeAll(); this.root.hidden = !this.visible; }
    else if (this.session && GAME_PANELS.some(p => p[2] === key)) this.toggle(GAME_PANELS.find(p => p[2] === key)[0]);
    else if (/^F(?:[1-9]|1[012])$/.test(event.key)) this.useQuickbar(event.ctrlKey ? 2 : event.shiftKey ? 1 : this.state.quickbarPage, Number(event.key.slice(1)) - 1);
    else if (key === 'enter' && this.session && !this.captured) this.hud.querySelector('.game-chat input').focus();
    else if (this.captured) { event.stopImmediatePropagation(); return; }
    else handled = false;
    if (handled) { event.preventDefault(); event.stopImmediatePropagation(); }
  }
  async renderPanel() {
    const version = ++this.renderVersion, id = this.state.panel; this.layer.replaceChildren(); this.root.dataset.panel = id ?? '';
    if (!id || !this.assets) return;
    if (id.startsWith('native:')) { await this.renderNative(id.slice(7), version); return; }
    if (id === 'main') { await this.renderNative('pre_main', version); return; }
    const panel = el('section', `game-panel game-panel-${id}`); panel.dataset.panel = id; panel.setAttribute('role', 'dialog'); panel.setAttribute('aria-label', titles[id] ?? id);
    const title = el('header', 'game-panel-title'); title.append(el('span', '', titles[id]), button('×', () => this.close(), 'game-close')); panel.append(title);
    const tabs = el('nav', 'game-panel-tabs'); const body = el('div', 'game-panel-body'); panel.append(tabs, body); this.layer.append(panel);
    if (panelModels[id]) void this.positionedArt(panel, panelModels[id]);
    if (id === 'journal') {
      for (const [tab, label, model] of [['quests', 'Quests', 'ctl_jnl_btn_tab'], ['completed', 'Completed Quests', 'ctl_jnl_btn_tab2'], ['notes', 'Notes', 'ctl_jnl_btn_tab3']]) {
        const b = button(label, () => { this.state.journalTab = tab; void this.renderPanel(); }); b.dataset.tab = tab; b.setAttribute('aria-selected', String(tab === this.state.journalTab)); void this.art(b, model, tab === this.state.journalTab ? 'checkedup' : 'uncheckedup'); tabs.append(b);
      }
      void this.positionedArt(panel, 'pnl_jnl_page1', 0, 58); this.renderJournal(body);
    } else if (id === 'inventory') this.renderInventory(body, tabs);
    else if (id === 'character') this.renderCharacter(body, tabs);
    else if (id === 'map') { this.mapCanvas = el('canvas', 'game-map'); this.mapCanvas.width = this.mapCanvas.height = 320; body.append(this.mapCanvas, el('p', 'game-muted', 'Area overview · exploration and map pins pending')); this.drawMap(); }
    else if (id === 'options') this.renderOptions(body);
    else if (id === 'spells') this.renderSpells(body, tabs);
    else if (id === 'party') { body.append(button(this.session.player.name, () => this.open('character')), button('Invite player', () => this.request('party.invite'))); }
    else if (id === 'examine') this.renderExamine(body);
    else if (id === 'dialogue' && this.session.conversation.state) this.renderConversation(body);
    else { body.append(el('p', '', id === 'dialogue' ? 'No conversation is active.' : id === 'store' ? 'No merchant is active.' : 'No trade is active.')); body.append(button(id === 'dialogue' ? 'Talk to selected creature' : 'Use selected object', () => this.request(id === 'dialogue' ? 'conversation.start' : `${id}.open`, { targetId: this.getSelected?.()?.id }))); }
    const footer = el('footer', 'game-panel-footer'); footer.append(button('Close', () => this.close())); panel.append(footer);
    await this.art(title.querySelector('.game-close'), 'ctl_btn_x');
    if (version !== this.renderVersion) return;
    panel.querySelector('button')?.focus({ preventScroll: true });
  }
  dialogueText(value, player = this.session.player, gender = null) {
    const text = gender === null ? this.text : Object.assign(Object.create(this.text), { female: gender === 1 });
    const tokens = { FIRSTNAME: player?.authored?.FirstName ? text.resolve(player.authored.FirstName) : player?.name, LASTNAME: text.resolve(player?.authored?.LastName), FULLNAME: player?.name, PLAYERNAME: player?.playerName };
    return text.resolve(value).replace(/<(FIRSTNAME|LASTNAME|FULLNAME|PLAYERNAME)>/gi, (_, key) => tokens[key.toUpperCase()] ?? '')
      .replace(/<\/?(?:StartAction|StartCheck|StartHighlight|Start|End)>/gi, '');
  }
  renderConversation(body) {
    const conversation = this.session.conversation, state = conversation.state;
    this.root.dataset.conversationOwner = String(state.ownerId); this.root.dataset.conversationEntry = String(state.entryIndex); this.root.dataset.conversationVersion = String(conversation.version);
    const speaker = this.session.registry.get(state.speakerId), line = state.history.at(-1);
    body.append(el('h3', 'game-dialogue-speaker', speaker ? this.objectName(speaker) : ''), el('p', 'game-dialogue-text', this.dialogueText(line?.text)));
    if (state.error) body.append(el('p', 'game-dialogue-error', state.error));
    const choices = el('div', 'game-dialogue-replies');
    for (const [i, reply] of state.replies.entries()) {
      const b = button(`${i + 1}. ${this.dialogueText(reply.node.Text) || 'Continue'}`, () => this.request('conversation.reply', { ordinal: reply.ordinal, version: conversation.version }), 'game-dialogue-reply');
      b.dataset.replyOrdinal = String(reply.ordinal); b.dataset.replyIndex = String(reply.index); b.disabled = conversation.busy || state.paused; choices.append(b);
    }
    if (state.complete && !state.error) choices.append(button('Continue', () => this.request('conversation.close', { aborted: false, version: conversation.version })));
    body.append(choices);
  }
  renderJournal(body) {
    const player = this.session.player, tab = this.state.journalTab;
    if (tab === 'notes') {
      const notes = el('textarea', 'game-notes'); notes.setAttribute('aria-label', 'Personal journal notes'); notes.placeholder = 'Personal notes'; notes.value = this.state.notes.get(player.id) ?? '';
      notes.addEventListener('input', () => this.state.notes.set(player.id, notes.value)); body.append(notes, el('p', 'game-muted', 'Notes are retained for this module session. Saving is pending.')); return;
    }
    if (tab === 'world') { body.append(el('p', 'game-muted', 'No world journal entries received.')); return; }
    const sort = el('select', 'game-journal-sort'); sort.setAttribute('aria-label', 'Sort journal');
    sort.append(new Option('Name', 'name'), new Option('Priority', 'priority'), new Option('Received', 'received')); sort.value = this.state.journalSort;
    sort.addEventListener('change', () => { this.state.journalSort = sort.value; void this.renderPanel(); }); body.append(sort);
    const rows = journalRows(player, this.session.journalDefinitions, this.text, { tab, sort: this.state.journalSort });
    this.root.dataset.visibleJournalEntries = rows.length;
    if (!rows.length) body.append(el('p', 'game-muted', 'No entries.'));
    for (const row of rows) {
      const entry = el('details', 'game-journal-entry'); entry.dataset.tag = row.tag; entry.dataset.state = row.state; entry.open = this.state.selectedQuest === row.tag;
      const heading = el('summary', '', row.name); const text = el('div', 'game-journal-text', row.text); entry.append(heading, text);
      entry.addEventListener('toggle', () => { if (entry.open) this.state.selectedQuest = row.tag; }); body.append(entry);
    }
  }
  renderInventory(body, tabs) {
    tabs.append(button('Equipment', () => { this.inventoryTab = 'equipment'; void this.renderPanel(); }), button('Contents', () => { this.inventoryTab = 'contents'; void this.renderPanel(); }));
    const items = (this.session.player.inventory ?? []).map(id => this.session.registry.get(id)).filter(Boolean);
    if (!items.length) body.append(el('p', 'game-muted', 'No player inventory loaded.'));
    if (this.inventoryTab === 'equipment') {
      const equipped = el('dl', 'game-equipment');
      for (const [index, name] of EQUIPMENT_SLOTS.entries()) {
        const item = items.find(i => i.equipmentSlot === 1 << index), value = el('dd');
        if (item) { const b = button(this.objectName(item), () => { this.examineId = item.id; this.open('examine'); });this.makeQuickbarSource(b,{type:1,itemId:item.id,intParam:0xff00ff}); b.dataset.objectId = item.id; value.append(b); } else value.textContent = '—';
        equipped.append(el('dt', '', name), value);
      }
      body.append(equipped);
    } else {
    const grid = el('div', 'game-inventory-grid');
    const carried = items.filter(i => i.equipmentSlot === null);
    for (let i = 0; i < Math.max(60, carried.length); i++) { const item = carried[i], slot = button(item ? this.objectName(item) : '', () => { if (item) { this.examineId = item.id; this.open('examine'); } }, 'game-item-slot'); slot.dataset.objectId = item?.id ?? ''; if (item){this.makeQuickbarSource(slot,{type:1,itemId:item.id,intParam:0xff00ff});slot.title = `${this.objectName(item)} · Stack ${item.authored.StackSize ?? 1} · Position ${item.inventoryPosition?.join(', ') ?? 'unknown'}`;} grid.append(slot); } body.append(grid);
    }
    body.append(el('p', 'game-muted', `Gold ${this.session.player.stats?.gold ?? '—'} · Equip/use and carry-weight rules pending`));
  }
  renderCharacter(body, tabs) {
    for (const name of ['Character', 'Skills', 'Feats']) tabs.append(button(name, () => { this.characterTab = name; void this.renderPanel(); }));
    const p = this.session.player;
    body.append(el('h3', '', p.name), el('p', 'game-muted', p.characterLoaded ? p.characterFile : 'A player character file has not been loaded.'));
    if (this.characterTab === 'Skills' || this.characterTab === 'Feats') {
      if (!p.stats) { body.append(el('p', '', `${this.characterTab} unavailable.`)); return; }
      const list = el('dl', 'game-stats');
      if (this.characterTab === 'Skills') for (const [id, rank] of p.stats.skills.entries()) { list.append(el('dt', '', this.ruleName('skills', id)), el('dd', '', `${rank} ranks`)); }
      else for (const id of p.stats.feats) body.append(this.makeQuickbarSource(el('p', 'game-feat', this.ruleName('feat', id, 'FEAT')),{type:4,intParam:id}));
      body.append(list); return;
    }
    const stats = el('dl', 'game-stats');
    const s = p.stats;
    const rows = [['Race', s ? this.ruleName('racialtypes', s.race) : '—'], ['Classes', s?.classes.map(c => `${this.ruleName('classes', c.id)} ${c.level}`).join(' / ') ?? '—'],
      ...['Strength', 'Dexterity', 'Constitution', 'Intelligence', 'Wisdom', 'Charisma'].map((name, i) => [name, s ? `${s.equippedAbilities[ABILITIES[i]]}${s.equippedBonuses[ABILITIES[i]] ? ` (${s.baseAbilities[ABILITIES[i]]} base)` : ''}` : '—']),
      ['Hit points', s ? `${this.session.hitPoints(p.id, false)}/${s.maxHP}` : '—'],
      ...(s?.combat ? [['Base attack bonus', s.combat.baseAttackBonus], ['Base Fortitude', s.combat.baseSaves.fortitude], ['Base Reflex', s.combat.baseSaves.reflex], ['Base Will', s.combat.baseSaves.will]] : []),
      ...(s?.combat?.saves ? [['Armor class', s.combat.armorClass], ['Melee attack bonus', s.combat.attackBonuses.melee],
        ['Offhand attack bonus', s.combat.attackBonuses.offhand], ['Ranged attack bonus', s.combat.attackBonuses.ranged],
        ['Fortitude', s.combat.saves.fortitude], ['Reflex', s.combat.saves.reflex], ['Will', s.combat.saves.will]] : []),
      ['Experience', s?.xp ?? '—'], ['Next level', s?.canLevelUp ? 'Level up available' : s?.nextXP ?? '—'], ['Gold', s?.gold ?? '—']];
    for (const [name, value] of rows) { const dd = el('dd', '', value); if (name === 'Experience') dd.dataset.stat = 'xp'; stats.append(el('dt', '', name), dd); }
    body.append(stats, button('Create character', () => this.request('character.create')), button('Characters', () => this.request('character.load')));
    if (s) body.append(el('p', 'game-muted', s.limitations.join(' ')));
  }
  renderSpells(body, tabs) {
    for (const name of ['Spellbook', 'Memorized', 'Feats']) tabs.append(button(name, () => { this.spellTab = name; void this.renderPanel(); }));
    const player = this.session.player;
    if (!player.stats) { body.append(el('p', '', 'No character spell or feat data loaded.')); return; }
    let count = 0;
    if (this.spellTab === 'Feats') {
      for (const id of player.stats.feats) { body.append(this.makeQuickbarSource(button(this.ruleName('feat', id, 'FEAT'), () => this.request('feat.use', { featId: id })),{type:4,intParam:id})); count++; }
    } else for (const [index,c] of (player.creatureData ?? player.authored).ClassList.entries()) {
      const state=player.nativeTalentClasses?.[index];if(!state)throw new Error('Live spellbook class storage is unavailable');
      const section = el('section', 'game-spell-class'); section.append(el('h3', '', this.ruleName('classes', c.Class)));
      for (let level = 0; level < 10; level++) {
        const list = this.spellTab==='Memorized'?state.memorized[level]:state.known[level].map(id=>({id,metamagic:0}));
        if (list.length) section.append(el('h4', '', `Spell level ${level}`));
        for (const [slot, spell] of list.entries()) {
          if (!spell) continue;
          const domainLevel=spell.domain?(level-this.session.spellBook.metamagicCost(spell.metamagic??0))&255:0;
          const b = button(`${this.ruleName('spells', spell.id)}${this.spellTab === 'Memorized' ? spell.ready ? ' · Ready' : ' · Used' : ''}${spell.metamagic ? ` · Metamagic ${spell.metamagic}` : ''}`, () => this.request('spell.cast', { classIndex:index, spellId: spell.id, metamagic:spell.metamagic??0,domainLevel }));
          b.dataset.spellId = spell.id;b.dataset.spellClassIndex=index;if(this.spellTab==='Memorized')b.dataset.spellReady=Number(spell.ready!==0);section.append(b); count++;
          this.makeQuickbarSource(b,{type:2,classIndex:index,intParam:spell.id,metamagic:spell.metamagic??0,domainLevel});
        }
      }
      body.append(section);
    }
    if (!count) body.append(el('p', '', 'No entries in this list.'));
    body.append(el('p', 'game-muted', 'Choose a spell, then its target. Memorization changes and feat actions are pending.'));
  }
  renderExamine(body) {
    const object = this.session.registry.get(this.examineId ?? this.getSelected?.()?.id);
    if (!object) { body.append(el('p', '', 'Select an object to examine.')); return; }
    body.dataset.objectId = object.id; body.append(el('h3', '', this.objectName(object)));
    const description = this.text.resolve(object.kind === 'item' && object.authored.Identified ? object.authored.DescIdentified : object.authored?.Description);
    body.append(el('p', '', description || 'No description available.'));
    if (object.kind === 'door') body.append(el('p', '', `${object.animationState ? 'Open' : 'Closed'}${object.locked ? ' · Locked' : ''}`));
    if (object.kind === 'item') body.append(el('p', 'game-muted', `Object ${object.id} · Owner ${object.ownerId} · Stack ${object.authored.StackSize ?? 1}`));
  }
  renderOptions(body) {
    for (const [label, panel] of [['Game Options', 'options_game'], ['Video Options', 'options_video'], ['Sound Options', 'options_sound'], ['Controls', 'options_controls'], ['Feedback', 'options_feedback']]) body.append(button(label, () => this.open(`native:${panel}`)));
    const wire = el('label', 'game-setting'); const input = el('input'); input.type = 'checkbox'; input.checked = document.querySelector('#wireframe-button').getAttribute('aria-pressed') === 'true'; input.addEventListener('change', () => this.onSettings?.({ wireframe: input.checked })); wire.append(input, el('span', '', 'Wireframe')); body.append(wire);
    body.append(button('Save Game', () => this.open('native:pre_savegame')), button('Load Game', () => this.open('native:pre_loadgame')), button('Main Menu', () => this.open('main')), button('Return to Game', () => this.closeAll()));
  }
  drawMap() {
    const world = this.getWorld?.(), c = this.mapCanvas; if (!c || !world?.triangles?.length || !c.isConnected) return;
    const ctx = c.getContext('2d'); let minX = Infinity, maxX = -Infinity, minZ = Infinity, maxZ = -Infinity;
    for (const t of world.triangles) for (const p of t.vertices) { minX = Math.min(minX, p[0]); maxX = Math.max(maxX, p[0]); minZ = Math.min(minZ, p[2]); maxZ = Math.max(maxZ, p[2]); }
    const scale = 300 / Math.max(maxX - minX, maxZ - minZ, 1), x = p => 10 + (p[0] - minX) * scale, y = p => 10 + (p[2] - minZ) * scale;
    ctx.fillStyle = '#06080b'; ctx.fillRect(0, 0, 320, 320); ctx.strokeStyle = '#45565f'; ctx.fillStyle = '#1b2931'; ctx.lineWidth = .5;
    for (const t of world.triangles) { ctx.beginPath(); t.vertices.forEach((p, i) => i ? ctx.lineTo(x(p), y(p)) : ctx.moveTo(x(p), y(p))); ctx.closePath(); ctx.fill(); ctx.stroke(); }
    for (const o of world.objects?.objects?.values() ?? []) if (o.kind === 'door') { ctx.fillStyle = '#b9a066'; ctx.fillRect(x(o.position) - 2, y(o.position) - 2, 4, 4); }
    const p = this.session.player.position; ctx.fillStyle = '#ffffa0'; ctx.beginPath(); ctx.arc(x(p), y(p), 4, 0, Math.PI * 2); ctx.fill();
  }
  async renderNative(name, version) {
    const assets = this.assets;
    try {
      const layout = await assets.layout(name); if (version !== this.renderVersion) return;
      const panel = el('section', 'game-native-panel'); panel.dataset.nativeGui = name; panel.setAttribute('role', 'dialog'); panel.setAttribute('aria-label', name);
      const stage = el('div', 'game-native-stage'); panel.append(stage); this.layer.append(panel);
      const bounds = { minX: 0, minY: 0, maxX: 0, maxY: 0 };
      const include = (left, top, width, height) => { bounds.minX = Math.min(bounds.minX, left); bounds.minY = Math.min(bounds.minY, top); bounds.maxX = Math.max(bounds.maxX, left + width); bounds.maxY = Math.max(bounds.maxY, top + height); };
      const draw = async (record, px = 0, py = 0, root = false) => {
        const x = px + (root ? 0 : Number(record.Obj_X ?? record.Obj_Label_X ?? 0) * PPU), y = py - (root ? 0 : Number(record.Obj_Y ?? record.Obj_Label_Y ?? 0) * PPU);
        const type = record.Obj_Type, kind = nativeControlKind(record), interactive = ['button', 'checkbox'].includes(kind);
        let node = interactive ? button('', () => this.nativeAction(name, record.Obj_Tag, type), 'native-control') : el('div', 'native-control');
        node.dataset.tag = record.Obj_Tag ?? ''; node.dataset.type = type; let skin;
        if (record.Obj_ResRef) skin = await assets.skin(record.Obj_ResRef).catch(e => { assets.warnings.add(e.message); return null; });
        if (version !== this.renderVersion) return;
        let left = x + (skin?.min[0] ?? 0) * PPU, top = y - (skin?.max[1] ?? 0) * PPU;
        let width = skin?.width || Number(record.Obj_Label_Width ?? 1.4) * PPU, height = skin?.height || Number(record.Obj_Label_Height ?? .25) * PPU;
        if (kind === 'edit' || kind === 'slider') {
          const input = el('input', `native-edit native-${kind}`); input.type = kind === 'slider' ? 'range' : /password/i.test(record.Obj_Tag) ? 'password' : 'text';
          if (kind === 'slider') { input.min = '0'; input.max = '1'; input.step = '.01'; }
          input.setAttribute('aria-label', record.Obj_Tag); input.addEventListener('input', () => { this.nativeDraft ??= {}; this.nativeDraft[`${name}:${record.Obj_Tag}`] = input.value; });
          input.addEventListener('change', () => this.request('native.control', { screen: name, control: record.Obj_Tag, value: input.value }));
          input.value = this.nativeDraft?.[`${name}:${record.Obj_Tag}`] ?? (kind === 'slider' ? .5 : ''); node = input; node.dataset.tag = record.Obj_Tag ?? '';
        } else if (kind === 'list') { node = el('div', 'native-control native-list'); node.setAttribute('role', 'listbox'); node.setAttribute('aria-label', record.Obj_Tag); node.dataset.tag = record.Obj_Tag ?? ''; }
        else if (kind === 'text') { node = el('div', 'native-control native-text'); node.dataset.tag = record.Obj_Tag ?? ''; }
        else if (kind === 'checkbox') { node.setAttribute('role', 'checkbox'); node.setAttribute('aria-checked', String(this.nativeDraft?.[`${name}:${record.Obj_Tag}`] ?? Boolean(record.Obj_Checked))); }
        Object.assign(node.style, { left: `${left}px`, top: `${top}px`, width: `${width}px`, height: `${height}px`, zIndex: String(Math.max(0, record.Obj_Layer ?? 0) + 1) });
        if (skin?.url) node.style.backgroundImage = `url("${skin.url}")`;
        const caption = this.text.resolve(record.Obj_Caption, type === 1 && /XButton/.test(record.Obj_Tag) ? '×' : '');
        if (caption && !['edit', 'slider'].includes(kind)) {
          const label = el('span', 'native-caption', caption), style = record.Obj_Caption ?? {};
          label.style.justifyContent = style.AurString_AlignH === .5 ? 'center' : style.AurString_AlignH === 1 ? 'flex-end' : 'flex-start';
          label.style.alignItems = style.AurString_AlignV === .5 ? 'center' : style.AurString_AlignV === 1 ? 'flex-end' : 'flex-start';
          label.style.color = `rgba(${Math.round((style.AurString_ColorR ?? 1) * 255)},${Math.round((style.AurString_ColorG ?? 1) * 255)},${Math.round((style.AurString_ColorB ?? 1) * 255)},${style.AurString_ColorA ?? 1})`;
          node.append(label); node.setAttribute('aria-label', caption);
        }
        if (interactive && !caption) { node.title = record.Obj_Tag; node.setAttribute('aria-label', record.Obj_Tag); }
        stage.append(node); include(left, top, width, height);
        await Promise.all((record.Obj_ChildList ?? []).map(child => draw(child, x, y)));
      };
      await draw(layout, 0, 0, true); if (version !== this.renderVersion) return;
      const width = Math.ceil(Math.max(360, bounds.maxX - bounds.minX)) + 2, height = Math.ceil(Math.max(250, bounds.maxY - bounds.minY)) + 2;
      // Children use authored coordinates. A translated full-size stage would
      // count its own empty box twice and create spurious browser scrollbars.
      Object.assign(stage.style, { width: '0px', height: '0px', transform: `translate(${-bounds.minX}px, ${-bounds.minY}px)` });
      Object.assign(panel.style, { width: `${width}px`, height: `${height + 55}px` });
      const controls = el('footer', 'game-native-footer'); controls.append(button('Back', () => this.close()), button('Return to Game', () => this.closeAll())); panel.append(controls);
      const status = el('div', 'game-native-status'); status.textContent = this.nativeStatus(name); controls.prepend(status);
      if (status.textContent) runtimeDiagnostics.record('ui.system-unimplemented', status.textContent, { panel: name });
      if (!this.text.base) status.textContent = 'Load Language Data in Tools to resolve the game’s interface text.';
      panel.querySelector('button')?.focus({ preventScroll: true });
    } catch (error) { runtimeDiagnostics.error(error, 'ui.layout-failed', { resRef: name, panel: this.state.panel }); if (version === this.renderVersion) { this.message(`UI resource ${name}: ${error.message}`); this.layer.append(button('Back', () => this.close())); } }
  }
  nativeStatus(name) {
    if (name.startsWith('cg_')) return 'Native creation layout preview. Open the working wizard through Create Character.';
    if (/loadgame|savegame/.test(name)) return 'Save-game loading and writing are pending.';
    if (/multi|server|connect/.test(name)) return 'Networking is pending.';
    if (/movie/.test(name)) return 'Movie playback is pending.';
    if (/options/.test(name)) return 'Unimplemented settings report a request in the console.';
    return '';
  }
  nativeAction(screen, tag, type) {
    if (/^(XButton|CancelButton|BackButton|CloseButton|ExitButton)$/.test(tag)) { this.close(); return; }
    if (screen.startsWith('cg_')) { this.request('character.create'); return; }
    const route = nativeRoutes[screen]?.[tag]; if (route) { this.open(`native:${route}`); return; }
    if (/playmod|loadmod/.test(screen) && /load|play|start|open/i.test(tag)) { this.onOpenModule?.(); return; }
    if (screen === 'pre_newgame' && /module|custom|other/i.test(tag)) { this.onOpenModule?.(); return; }
    if (screen === 'pre_newgame' && /Chapter|Prelude/.test(tag)) { this.onOpenModule?.(); return; }
    if (screen.startsWith('cg_') && screen !== 'cg_main' && /ok|next|accept|done/i.test(tag)) { this.request('character.creation.step', { screen, control: tag, values: this.nativeDraft }); return; }
    if (type === 2) { this.nativeDraft ??= {}; const key = `${screen}:${tag}`, node = this.root.querySelector(`[data-tag="${CSS.escape(tag)}"]`); this.nativeDraft[key] = !(this.nativeDraft[key] ?? node?.getAttribute('aria-checked') === 'true'); node?.setAttribute('aria-checked', String(this.nativeDraft[key])); node?.setAttribute('aria-pressed', String(this.nativeDraft[key])); }
    this.request('native.control', { screen, control: tag, values: this.nativeDraft ? { ...this.nativeDraft } : {} });
  }
}
