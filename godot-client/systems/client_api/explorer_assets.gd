extends RefCounted
# Embedded source assets are included by the existing .gd release pack rules.
# They are public static bytes; authentication is supplied only by the user.
const PATHS:=["/explorer","/explorer/","/explorer/app.js","/explorer/style.css","/explorer/favicon.svg"]
const POLICY:="default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'; object-src 'none'"
const HTML:="""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="dark"><title>Client Entity Explorer</title><link rel="icon" href="/explorer/favicon.svg" type="image/svg+xml"><link rel="stylesheet" href="/explorer/style.css"><script type="module" src="/explorer/app.js"></script></head>
<body><main>
<header><div><p class="eyebrow">NATIVE CLIENT · READ ONLY</p><h1>Entity Explorer</h1><p class="intro">Inspect what this client knows, independent of visual loading.</p></div><span id="auth-status" class="pill" role="status">Locked</span></header>
<section id="drop-zone" class="connection" aria-label="Local authentication"><div><h2>Connect with a discovery file</h2><p>Choose or drop this launch's discovery JSON. The bearer stays in this page's memory.</p><p id="connection-origin" class="muted"></p></div><div class="connection-actions"><label class="button gold" for="discovery-file">Choose discovery JSON</label><input id="discovery-file" class="file-input" type="file" accept=".json,application/json" aria-label="Choose discovery JSON"><button id="disconnect" disabled>Forget connection</button></div></section>
<p id="notice" class="notice" role="status" aria-live="polite">The page contains no token. Choose the file to authenticate.</p>
<section class="overview" aria-label="Client scope and identities"><article class="card"><h2>Current scope</h2><p id="scope-primary">Not connected</p><pre id="scope-details" class="compact">—</pre></article><article class="card"><h2>Controlled entity</h2><p id="controlled-primary">Not connected</p><p id="controlled-reason" class="muted">Control can differ from the player's character.</p><button id="inspect-controlled" disabled>Inspect controlled</button></article><article class="card"><h2>Player character</h2><p id="player-primary">Not connected</p><p id="player-reason" class="muted">Identity is unavailable unless explicitly received.</p><button id="inspect-player" disabled>Inspect character</button></article></section>
<section class="toolbar"><button id="refresh" class="gold" disabled>Refresh</button><label><input id="poll" type="checkbox" disabled> Poll while visible</label><label>Every <select id="poll-seconds" disabled><option value="5">5 seconds</option><option value="10">10 seconds</option><option value="30">30 seconds</option></select></label><span id="poll-status" class="muted">Manual refresh</span></section>
<section class="workspace"><aside class="panel entity-panel"><div class="panel-heading"><h2>Known entities</h2><span class="muted">Client scope</span></div><form id="filters"><label>Type<select id="object-type" disabled><option value="">All types</option><option value="3">Module · 3</option><option value="4">Area · 4</option><option value="5">Creature · 5</option><option value="6">Item · 6</option><option value="7">Trigger · 7</option><option value="8">Projectile · 8</option><option value="9">Placeable · 9</option><option value="10">Door · 10</option><option value="11">Area of effect · 11</option><option value="12">Waypoint · 12</option><option value="13">Encounter · 13</option><option value="14">Store · 14</option><option value="15">Portal · 15</option><option value="16">Sound · 16</option></select></label><label>Area ID <input id="area-id" inputmode="numeric" placeholder="Any known area" autocomplete="off" disabled></label><div class="filter-row"><label><input id="current-area" type="checkbox" checked disabled> Current area</label><label>Page size <select id="page-size" disabled><option value="10">10</option><option value="25" selected>25</option><option value="50">50</option><option value="100">100</option></select></label></div><button id="apply-filters" type="submit" disabled>Apply filters</button></form><p id="entity-count" class="muted">No authenticated view</p><ul id="entity-list" aria-label="Known entities"></ul><div class="pagination"><button id="first-page" disabled>First page</button><button id="previous-page" disabled>Previous</button><button id="next-page" disabled>Next page</button></div></aside>
<section class="panel details-panel"><div class="panel-heading"><div><h2 id="entity-title">Select an entity</h2><p id="entity-subtitle" class="muted">References identify a connection, area and entity lifetime.</p></div><button id="refresh-entity" disabled>Refresh entity</button></div><div class="details-options"><label><input id="include-presentation" type="checkbox" checked disabled> Request current presentation</label><span id="detail-state" class="pill">No selection</span></div><div class="tabs" role="tablist" aria-label="Entity data source"><button id="received-tab" role="tab" aria-selected="true" class="active">Received / known data</button><button id="presentation-tab" role="tab" aria-selected="false">Presentation</button><button id="all-tab" role="tab" aria-selected="false">Full view</button></div><p id="detail-explanation" class="source-note">Received data is the last accepted full/delta read model. Fast motion may update presentation first.</p><pre id="entity-details" tabindex="0">Choose an entity from the list or an identity card.</pre></section></section>
<footer>External diagnostic page · No gameplay commands · No game renderer or UI is moved into this page.</footer>
</main></body></html>
"""
const CSS:=""":root{font-family:Segoe UI,system-ui,sans-serif;color:#e6e6e1;background:#101519;--gold:#d8b56b;--line:#344047;--dim:#aab5b9;--panel:#182126}*{box-sizing:border-box}body{margin:0;background:radial-gradient(ellipse at 15% 0,#263037 0,transparent 55%),#101519}main{max-width:1480px;margin:auto;padding:32px}header{display:flex;align-items:center;justify-content:space-between;gap:20px;margin-bottom:24px}.eyebrow{font-size:11px;letter-spacing:.2em;color:var(--gold);font-weight:700;margin:0 0 8px}h1{font-size:34px;font-weight:600;letter-spacing:-.03em;margin:0}h2{font-size:15px;font-weight:600;margin:0 0 10px}p{line-height:1.5;margin:6px 0}.intro,.muted{color:var(--dim);font-size:13px}.pill{font-size:11px;text-transform:uppercase;letter-spacing:.08em;padding:7px 10px;border:1px solid #54616a;border-radius:20px;color:#c4ccd0;white-space:nowrap}.pill.connected{border-color:#5c8067;color:#abdab5}.pill.busy{border-color:#b29252;color:var(--gold)}.connection,.panel,.card{background:var(--panel);border:1px solid var(--line);border-radius:9px}.connection{display:flex;align-items:center;justify-content:space-between;gap:20px;padding:20px;border-top:2px solid #927d4e}.connection.drag-over{outline:2px solid var(--gold)}.connection-actions{display:flex;gap:10px;align-items:center;flex-shrink:0}button,.button,select,input{font:inherit}button,.button{display:inline-block;background:#27333a;color:#edf0eb;border:1px solid #4a5a62;border-radius:5px;padding:9px 12px;font-size:12px;font-weight:600;cursor:pointer;text-align:center}button:hover,.button:hover{border-color:var(--gold);background:#344149}button.gold,.button.gold{color:#11181c;background:var(--gold);border-color:var(--gold)}button:disabled,input:disabled,select:disabled{opacity:.4;cursor:not-allowed}button:focus-visible,input:focus-visible,select:focus-visible,.button:focus-visible{outline:2px solid #f0d394;outline-offset:3px}.file-input{position:absolute;width:1px;height:1px;overflow:hidden;opacity:0}.notice{padding:11px 2px;color:#bac7cc;font-size:13px;min-height:40px}.notice.error{color:#efb5a8}.notice.waiting{color:#e6c88f}.overview{display:grid;grid-template-columns:1.1fr 1fr 1fr;gap:14px}.card{padding:18px;min-width:0}.card h2{color:var(--gold)}.card button{margin-top:10px}.compact{margin:9px 0 0;white-space:pre-wrap;font-size:11px;color:#bec9cc}.toolbar{display:flex;align-items:center;gap:18px;margin:22px 0 14px;flex-wrap:wrap}.toolbar label,.details-options label,.filter-row label{font-size:12px;color:#ccd4d6}.toolbar select{width:auto;margin-left:5px}.workspace{display:grid;grid-template-columns:340px minmax(0,1fr);gap:16px}.panel{padding:18px;min-width:0}.panel-heading{display:flex;justify-content:space-between;align-items:flex-start;gap:10px;margin-bottom:14px}.panel-heading h2{margin-bottom:0}.panel-heading .muted{font-size:11px}form{display:grid;gap:11px}form>label{display:grid;gap:6px;font-size:11px;color:#ccd4d6;letter-spacing:.03em}input:not([type=checkbox]):not([type=file]),select{color:#ecf0ec;background:#11191f;border:1px solid #40515a;border-radius:4px;padding:8px;min-width:0;width:100%;font-size:12px}input[type=checkbox]{accent-color:var(--gold);vertical-align:middle;margin-right:5px}.filter-row{display:flex;gap:12px;align-items:center;justify-content:space-between}.filter-row select{width:58px}.entity-panel form button{justify-self:start}#entity-count{font-size:11px;margin:16px 0 10px}#entity-list{margin:0;padding:0;list-style:none;max-height:440px;overflow:auto;border-top:1px solid #2e3c43}#entity-list li{border-bottom:1px solid #2e3c43}#entity-list button{width:100%;text-align:left;background:transparent;border:0;border-radius:0;padding:12px 9px;font-family:Consolas,monospace;font-weight:400;font-size:12px}#entity-list button.selected{background:#383a2b;color:#f0d294;border-left:2px solid var(--gold)}#entity-list .empty{padding:16px 0;color:var(--dim);font-size:12px}.pagination{display:flex;gap:7px;margin-top:15px}.pagination button{padding:8px;font-size:11px;flex:1}.details-options{display:flex;justify-content:space-between;gap:12px;align-items:center;margin-bottom:18px}.tabs{display:flex;border-bottom:1px solid #43515a;gap:4px;flex-wrap:wrap}.tabs button{border:0;border-radius:4px 4px 0 0;background:transparent;color:var(--dim);padding:11px 12px}.tabs button.active{color:var(--gold);background:#283136;border-bottom:2px solid var(--gold)}.source-note{font-size:12px;color:#b9c3c8;padding:12px 0;min-height:58px}#entity-details{margin:0;background:#0f171d;border:1px solid #2d3b43;border-radius:5px;color:#cdd9df;font:12px/1.65 Consolas,monospace;white-space:pre-wrap;overflow-wrap:anywhere;overflow:auto;padding:16px;min-height:380px;max-height:650px}footer{font-size:11px;line-height:1.6;color:#8e9ba2;margin:22px 0 0}@media(max-width:1000px){main{padding:20px}.workspace{grid-template-columns:290px minmax(0,1fr)}.connection{align-items:flex-start;flex-direction:column}.connection-actions{flex-wrap:wrap}.overview{grid-template-columns:1fr 1fr}.overview .card:first-child{grid-column:1/-1}}@media(max-width:740px){main{padding:16px}.workspace,.overview{grid-template-columns:1fr}.overview .card:first-child{grid-column:auto}h1{font-size:28px}.toolbar{gap:12px}.details-options{align-items:flex-start;flex-direction:column}.connection-actions{width:100%}.connection-actions .button{flex:1}#entity-details{max-height:550px}header{align-items:flex-start}}
"""
const JAVASCRIPT:="""const byId = id => document.getElementById(id);
const ui = Object.fromEntries(['auth-status','discovery-file','drop-zone','disconnect','notice','connection-origin','scope-primary','scope-details','controlled-primary','controlled-reason','player-primary','player-reason','inspect-controlled','inspect-player','refresh','poll','poll-seconds','poll-status','filters','object-type','area-id','current-area','page-size','apply-filters','entity-count','entity-list','first-page','previous-page','next-page','entity-title','entity-subtitle','refresh-entity','include-presentation','detail-state','received-tab','presentation-tab','all-tab','detail-explanation','entity-details'].map(id => [id, byId(id)]));
let bearer = '';
let authenticated = false;
let epoch = 0;
let busy = false;
let requestChain = Promise.resolve();
let nextRequestAt = 0;
let cooldownUntil = 0;
let controller = null;
let pollTimer = null;
let selectedReference = null;
let selectedEntity = null;
let selectedTab = 'received';
let currentScopeKey = null;
let controlled = null;
let playerCharacter = null;
let page = null;
let trail = [null];
let trailIndex = 0;
let filters = {current_area:'true', limit:'25'};
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const pretty = value => JSON.stringify(value, null, 2);
class ApiError extends Error { constructor(status, code) { super(code); this.status=status; this.code=code; } }
function notice(text, kind='') { ui.notice.textContent=text; ui.notice.className='notice'+(kind ? ' '+kind : ''); }
function scalar(value) { if (value === null || value === undefined) return 'Unavailable'; return typeof value === 'object' ? (value.$type === 'int64' ? value.value : pretty(value)) : String(value); }
function receivedName(field) {
  if (!field?.available) return null;
  const value=field.value;
  if (typeof value==='string') return value || null;
  if (value && typeof value.text==='string') return value.text || null;
  const raw=part => typeof part==='string' ? part : (part && typeof part.text==='string' ? part.text : '');
  return value ? [raw(value.firstName),raw(value.lastName)].filter(Boolean).join(' ') || null : null;
}
function clearSelection(message='Choose an entity from the list or an identity card.') {
  selectedReference=null; selectedEntity=null;
  ui['entity-title'].textContent='Select an entity'; ui['entity-subtitle'].textContent='References identify a connection, area and entity lifetime.';
  ui['entity-details'].textContent=message; ui['detail-state'].textContent='No selection';
  for (const button of ui['entity-list'].querySelectorAll('button')) button.classList.remove('selected');
}
function renderControls() {
  const enabled=Boolean(bearer) && !busy;
  for (const id of ['refresh','poll','poll-seconds','object-type','area-id','current-area','page-size','apply-filters','include-presentation']) ui[id].disabled=!enabled;
  ui.disconnect.disabled=!bearer;
  ui['first-page'].disabled=!enabled || trailIndex===0; ui['previous-page'].disabled=!enabled || trailIndex===0;
  ui['next-page'].disabled=!enabled || !page?.page?.next_cursor;
  ui['refresh-entity'].disabled=!enabled || !selectedReference;
  ui['inspect-controlled'].disabled=!enabled || !controlled?.reference_token;
  ui['inspect-player'].disabled=!enabled || !playerCharacter?.reference_token;
  for (const button of ui['entity-list'].querySelectorAll('button')) button.disabled=!enabled;
  ui['auth-status'].className='pill'+(bearer ? (busy ? ' busy' : (authenticated ? ' connected' : '')) : '');
  ui['auth-status'].textContent=bearer ? (busy ? 'Reading' : (authenticated ? 'Connected' : 'Token loaded')) : 'Locked';
}
function schedulePoll() {
  clearTimeout(pollTimer); pollTimer=null;
  if (!bearer || !ui.poll.checked) { ui['poll-status'].textContent='Manual refresh'; return; }
  if (document.hidden) { ui['poll-status'].textContent='Polling paused while hidden'; return; }
  ui['poll-status'].textContent='Polling every '+ui['poll-seconds'].value+' seconds';
  if (!busy) pollTimer=setTimeout(() => refresh(), Math.max(5, Number(ui['poll-seconds'].value))*1000);
}
function disconnect(message='Connection forgotten. Choose the current discovery JSON to reconnect.') {
  epoch++; bearer=''; authenticated=false; controller?.abort(); controller=null; requestChain=Promise.resolve(); busy=false;
  clearTimeout(pollTimer); pollTimer=null; currentScopeKey=null; controlled=null; playerCharacter=null; page=null; trail=[null]; trailIndex=0;
  ui['scope-primary'].textContent='Not connected'; ui['scope-details'].textContent='—';
  ui['controlled-primary'].textContent='Not connected'; ui['player-primary'].textContent='Not connected';
  ui['controlled-reason'].textContent='Control can differ from the player character.'; ui['player-reason'].textContent='Identity is unavailable unless explicitly received.';
  ui['entity-list'].replaceChildren(); ui['entity-count'].textContent='No authenticated view';
  clearSelection(); notice(message); renderControls(); schedulePoll();
}
async function apiGet(route, parameters={}) {
  const stamp=epoch;
  const run=async () => {
    for (let attempt=0; attempt<4; attempt++) {
      if (!bearer || stamp!==epoch) throw new ApiError(0,'cancelled');
      await sleep(Math.max(0, nextRequestAt-Date.now(), cooldownUntil-Date.now()));
      if (!bearer || stamp!==epoch) throw new ApiError(0,'cancelled');
      nextRequestAt=Date.now()+200;
      const aborter=new AbortController(); controller=aborter; const timeout=setTimeout(() => aborter.abort(), 5000);
      let response;
      try { response=await fetch('/api/v1'+route+(Object.keys(parameters).length ? '?'+new URLSearchParams(parameters) : ''), {method:'GET',mode:'same-origin',credentials:'omit',cache:'no-store',redirect:'error',headers:{Authorization:'Bearer '+bearer},signal:aborter.signal}); }
      catch { if (stamp!==epoch) throw new ApiError(0,'cancelled'); throw new ApiError(0,'client_unavailable'); }
      finally { clearTimeout(timeout); if (controller===aborter) controller=null; }
      if (stamp!==epoch) throw new ApiError(0,'cancelled');
      if (response.status===429) {
        const seconds=Number(response.headers.get('Retry-After'));
        cooldownUntil=Date.now()+Math.max(1, Math.min(5, Number.isFinite(seconds) ? seconds : 1))*1000;
        notice('The local API is busy. Waiting before retrying…','waiting');
        if (attempt===3) throw new ApiError(429,'rate_limited');
        continue;
      }
      let body; try { body=await response.json(); } catch { throw new ApiError(response.status,'invalid_response'); }
      if (stamp!==epoch) throw new ApiError(0,'cancelled');
      if (response.status===401) { disconnect('The token expired or belongs to another launch. Choose the current discovery JSON.'); throw new ApiError(401,'unauthorized'); }
      if (!response.ok) throw new ApiError(response.status, body?.error?.code || 'request_failed');
      return body;
    }
  };
  const pending=requestChain.then(run,run); requestChain=pending.catch(() => {}); return pending;
}
function describeError(error) {
  if (error.code==='representation_limit') return 'This entity exceeds the bounded HTTP view. No partial stats were returned.';
  if (error.code==='client_unavailable') return 'The client is unavailable. Check that the same launch and local service are still running.';
  if (error.status===429) return 'The API remains busy. Try manual refresh in a moment.';
  return 'Could not read this view: '+error.code+'.';
}
async function operation(task) {
  if (!bearer || busy) return;
  const stamp=epoch; busy=true; renderControls();
  try { await task(stamp); }
  catch (error) { if (stamp===epoch && error.code!=='cancelled') notice(describeError(error),'error'); }
  finally { if (stamp===epoch) { busy=false; renderControls(); schedulePoll(); } }
}
function renderScope(scope) {
  const key=pretty(scope);
  if (currentScopeKey!==null && currentScopeKey!==key) { trail=[null]; trailIndex=0; page=null; controlled=null; playerCharacter=null; renderIdentity('controlled',{available:false,object_id:null,reason:'scope_changed'}); renderIdentity('player',{available:false,object_id:null,reason:'scope_changed'}); clearSelection('The connection or area scope changed. Select a fresh reference.'); }
  currentScopeKey=key;
  ui['scope-primary'].textContent=scope.active ? 'Active client area' : 'No active game session';
  ui['scope-details'].textContent=pretty(scope);
}
function renderIdentity(prefix, result) {
  const name=receivedName(result.entity?.identity?.name);
  ui[prefix+'-primary'].textContent=result.available ? (name ? name+' · ' : '')+'Object '+scalar(result.object_id) : (result.object_id!==null && result.object_id!==undefined ? 'Object '+scalar(result.object_id)+' · data pending' : 'Unavailable');
  ui[prefix+'-reason'].textContent=result.available ? (prefix==='player' ? 'Explicit identity · '+(result.provenance || 'received source') : 'Current control, not assumed to be the player character.') : (result.reason || 'Data not received');
}
async function identity(route, prefix) {
  try { const body=await apiGet(route); renderIdentity(prefix,body.result); return body.result; }
  catch (error) { if (error.status===401 || error.code==='cancelled') throw error; renderIdentity(prefix,{available:false,object_id:null,reason:error.code}); return null; }
}
async function loadPage(cursor, direction='replace') {
  try {
    const body=await apiGet('/entities',{...filters,...(cursor ? {cursor} : {})});
    if (currentScopeKey!==pretty(body.scope)) renderScope(body.scope);
    page=body;
    if (direction==='next') { trail=trail.slice(0,trailIndex+1); trail.push(cursor); trailIndex++; }
    if (direction==='previous') trailIndex=Math.max(0,trailIndex-1);
    if (direction==='first') { trail=[null]; trailIndex=0; }
    const fragment=document.createDocumentFragment();
    for (const item of body.items) {
      const li=document.createElement('li'); const button=document.createElement('button');
      button.type='button'; button.textContent='Object '+scalar(item.object_id); button.dataset.reference=item.reference;
      if (item.reference===selectedReference) button.classList.add('selected');
      button.addEventListener('click',() => select(item.reference)); li.append(button); fragment.append(li);
    }
    if (!body.items.length) { const li=document.createElement('li'); li.className='empty'; li.textContent='No known entities match this view.'; fragment.append(li); }
    ui['entity-list'].replaceChildren(fragment);
    ui['entity-count'].textContent=body.items.length+' on page '+(trailIndex+1)+(body.page.has_more ? ' · More available' : ' · End of current list');
    if (selectedReference && !body.items.some(item => item.reference===selectedReference)) clearSelection('The selected lifetime is no longer on this page. Select a fresh reference.');
    return true;
  } catch (error) {
    if (error.status===410) { page=null; trail=[null]; trailIndex=0; clearSelection('This page belongs to an old area scope. Refresh the entity list.'); ui['entity-list'].replaceChildren(); ui['entity-count'].textContent='Old page retired'; notice('The area scope changed. Press Refresh to read a fresh page.','waiting'); return false; }
    throw error;
  }
}
function renderDetails() {
  if (!selectedEntity) return;
  const entity=selectedEntity;
  for (const name of ['received','presentation','all']) { ui[name+'-tab'].classList.toggle('active',selectedTab===name); ui[name+'-tab'].setAttribute('aria-selected',String(selectedTab===name)); }
  let view=entity;
  if (selectedTab==='received') {
    view={identity:entity.identity,appearance:entity.appearance,replicated:entity.replicated,character:entity.character,received:entity.received,client_data:entity.client_data,unavailable_paths:entity.unavailable_paths};
    ui['detail-explanation'].textContent='Last accepted full/delta read model. Client-initialized caches remain separate; missing data is not zero.';
  } else if (selectedTab==='presentation') {
    view=entity.presentation; ui['detail-explanation'].textContent='Client-simulated / interpolated presentation sampled on request. Coordinates remain NWN; this is not received server state.';
  } else ui['detail-explanation'].textContent='Full detached view. Received and presentation fields keep their separate source labels.';
  ui['entity-details'].textContent=pretty(view);
}
async function readSelected(reference) {
  try {
    const body=await apiGet('/references/'+reference,{presentation:String(ui['include-presentation'].checked)});
    if (selectedReference!==reference) return false;
    selectedEntity=body.entity; const text=receivedName(body.entity.identity?.name);
    ui['entity-title'].textContent=text || 'Object '+scalar(body.entity.identity.object_id);
    ui['entity-subtitle'].textContent='Object '+scalar(body.entity.identity.object_id)+' · '+(body.entity.identity.type_name || 'Unknown type')+' · scoped lifetime';
    ui['detail-state'].textContent='Current reference'; renderDetails(); return true;
  } catch (error) {
    if (error.status===410) { clearSelection('This entity left or was replaced. The old reference will not resolve to a reused ID.'); ui['detail-state'].textContent='Stale reference'; notice('The selected entity lifetime retired. Refresh the list to select a current entity.','waiting'); return false; }
    if (selectedReference===reference) { selectedEntity=null; ui['detail-state'].textContent='Unavailable'; ui['entity-details'].textContent=describeError(error); }
    throw error;
  }
}
function select(reference) {
  return operation(async () => { selectedReference=reference; selectedEntity=null; ui['entity-title'].textContent='Reading entity'; ui['entity-subtitle'].textContent='Waiting for this scoped reference'; ui['entity-details'].textContent='Loading the selected entity…'; ui['detail-state'].textContent='Reading'; for (const button of ui['entity-list'].querySelectorAll('button')) button.classList.toggle('selected',button.dataset.reference===reference); await readSelected(reference); });
}
function refresh() {
  return operation(async () => {
    notice('Reading the current client view…','waiting');
    const scope=await apiGet('/scope'); authenticated=true; renderScope(scope.scope);
    controlled=await identity('/controlled','controlled'); playerCharacter=await identity('/player-character','player');
    if (!await loadPage(trail[trailIndex])) return;
    if (selectedReference && !await readSelected(selectedReference)) return;
    if (bearer) notice('Authenticated to '+location.origin+'. Views contain only client-known data.');
  });
}
async function importDiscovery(file) {
  disconnect('Checking the chosen discovery file…');
  const stamp=epoch;
  try {
    if (!file || file.size>8192) throw new Error('Choose one discovery JSON file smaller than 8 KiB.');
    const data=JSON.parse(await file.text());
    if (stamp!==epoch) return;
    if (!data || data.kind!=='nwn-client-entity-api-rest' || data.api_version!==1 || typeof data.bearer_token!=='string' || !/^[a-f0-9]{64}$/.test(data.bearer_token)) throw new Error('This is not a valid per-launch entity API discovery file.');
    const base=new URL(data.base_url);
    if (location.protocol!=='http:' || !['127.0.0.1','localhost'].includes(location.hostname) || base.protocol!=='http:' || !['127.0.0.1','localhost'].includes(base.hostname) || base.port!==location.port || base.pathname!=='/api/v1' || base.search || base.hash || base.username || base.password) throw new Error('This discovery file belongs to another address or port. Open the explorer for that launch.');
    bearer=data.bearer_token; notice('Discovery loaded. Checking authenticated client data…','waiting'); renderControls(); await refresh();
  } catch (error) { if (stamp===epoch) { disconnect(); notice(error instanceof SyntaxError ? 'The selected file is not valid JSON.' : error.message,'error'); } }
  finally { ui['discovery-file'].value=''; }
}
ui['connection-origin'].textContent='This page: '+location.origin+' · Tokens are never stored in browser storage.';
ui['discovery-file'].addEventListener('change',event => importDiscovery(event.target.files?.[0]));
for (const name of ['dragenter','dragover']) ui['drop-zone'].addEventListener(name,event => { event.preventDefault(); ui['drop-zone'].classList.add('drag-over'); });
ui['drop-zone'].addEventListener('dragleave',() => ui['drop-zone'].classList.remove('drag-over'));
ui['drop-zone'].addEventListener('drop',event => { event.preventDefault(); ui['drop-zone'].classList.remove('drag-over'); importDiscovery(event.dataTransfer?.files?.length===1 ? event.dataTransfer.files[0] : null); });
document.addEventListener('dragover',event => event.preventDefault());
document.addEventListener('drop',event => { event.preventDefault(); if (!ui['drop-zone'].contains(event.target)) notice('Drop discovery JSON on the connection panel. The file is not uploaded.','waiting'); });
ui.disconnect.addEventListener('click',() => disconnect()); ui.refresh.addEventListener('click',() => refresh());
ui['inspect-controlled'].addEventListener('click',() => controlled?.reference_token && select(controlled.reference_token));
ui['inspect-player'].addEventListener('click',() => playerCharacter?.reference_token && select(playerCharacter.reference_token));
ui['refresh-entity'].addEventListener('click',() => selectedReference && select(selectedReference));
ui['include-presentation'].addEventListener('change',() => selectedReference && select(selectedReference));
ui['filters'].addEventListener('submit',event => {
  event.preventDefault(); const area=ui['area-id'].value.trim();
  if (area && (!/^(0|[1-9][0-9]*)$/.test(area) || Number(area)>4294967295 || Number(area)===2130706432)) { notice('Area ID must be a valid canonical unsigned decimal object ID.','error'); return; }
  filters={...(ui['object-type'].value ? {object_type:ui['object-type'].value} : {}),...(area ? {area_id:area} : {}),current_area:String(ui['current-area'].checked),limit:ui['page-size'].value};
  trail=[null]; trailIndex=0; page=null; clearSelection(); operation(async () => { if (await loadPage(null,'first')) notice('Filters applied. Only compact reference metadata was enumerated.'); });
});
ui['first-page'].addEventListener('click',() => operation(async () => { clearSelection(); await loadPage(null,'first'); }));
ui['previous-page'].addEventListener('click',() => operation(async () => { clearSelection(); await loadPage(trail[Math.max(0,trailIndex-1)],'previous'); }));
ui['next-page'].addEventListener('click',() => page?.page?.next_cursor && operation(async () => { clearSelection(); await loadPage(page.page.next_cursor,'next'); }));
for (const name of ['received','presentation','all']) ui[name+'-tab'].addEventListener('click',() => { selectedTab=name; renderDetails(); });
ui.poll.addEventListener('change',schedulePoll); ui['poll-seconds'].addEventListener('change',schedulePoll); document.addEventListener('visibilitychange',schedulePoll);
window.addEventListener('pagehide',() => disconnect()); renderControls(); schedulePoll();
"""
const FAVICON:="""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect width="32" height="32" rx="6" fill="#182126"/><path d="M9 8h15v4H13v3h9v4h-9v3h11v4H9z" fill="#d8b56b"/></svg>"""
static func is_target(target: String) -> bool: return PATHS.has(target)
static func response(target: String) -> Dictionary:
	match target:
		"/explorer","/explorer/": return {"status":200,"bytes":HTML.to_utf8_buffer(),"content_type":"text/html; charset=utf-8","policy":POLICY}
		"/explorer/app.js": return {"status":200,"bytes":JAVASCRIPT.to_utf8_buffer(),"content_type":"text/javascript; charset=utf-8","policy":POLICY}
		"/explorer/style.css": return {"status":200,"bytes":CSS.to_utf8_buffer(),"content_type":"text/css; charset=utf-8","policy":POLICY}
		"/explorer/favicon.svg": return {"status":200,"bytes":FAVICON.to_utf8_buffer(),"content_type":"image/svg+xml","policy":POLICY}
	return {}
