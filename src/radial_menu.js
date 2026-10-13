import { radialHit } from './radial_actions.js';

// Shared modal presentation. Object/action policy lives in radial_actions.js.
export class RadialMenu {
  constructor(viewport,{ onAction,onVisibility = () => {},loadIcon = async () => null }) {
    Object.assign(this,{ viewport,onAction,onVisibility,loadIcon });
    this.host = document.createElement('div'); this.host.className = 'radial-overlay'; this.host.hidden = true;
    this.host.innerHTML = '<div class="radial-menu" role="menu"><button class="radial-center" type="button"></button><div class="radial-title"></div><div class="radial-slots"></div><div class="radial-help"></div></div>';
    viewport.append(this.host);
    this.stage = this.host.querySelector('.radial-menu');
    this.centerButton = this.host.querySelector('.radial-center');
    this.title = this.host.querySelector('.radial-title');
    this.slots = this.host.querySelector('.radial-slots');
    this.help = this.host.querySelector('.radial-help');
    this.host.addEventListener('contextmenu',event => event.preventDefault());
    this.centerButton.addEventListener('click',() => this.back());
    this.host.addEventListener('click',event => { if (event.target === this.host) this.close(); });
    window.addEventListener('pointermove',event => {
      if (!this.active) return;
      this.pointer(event.clientX,event.clientY); event.stopPropagation();
      if (Math.hypot(event.clientX-this.gestureStart.x,event.clientY-this.gestureStart.y) > 5) this.dragged = true;
    },true);
    window.addEventListener('pointerdown',event => {
      if (!this.active || event.button !== 2) return;
      this.clickMode = false; this.initialGesture = false; this.moved = true; this.pointer(event.clientX,event.clientY);
      event.preventDefault(); event.stopPropagation();
    },true);
    window.addEventListener('pointerup',event => {
      if (!this.active || event.button !== 2) return;
      this.pointer(event.clientX,event.clientY);
      event.preventDefault(); event.stopPropagation();
      if (this.initialGesture && !this.dragged && Math.hypot(event.clientX-this.gestureStart.x,event.clientY-this.gestureStart.y) <= 5) {
        this.clickMode = true; this.help.textContent = 'Click an action · center to cancel · Esc';
      } else if (this.hit.zone === 'select' || this.hit.zone === 'submenu') this.choose(this.hit.octant);
      else this.back();
      this.initialGesture = false;
    },true);
    window.addEventListener('keydown',event => {
      if (!this.active) return;
      event.preventDefault(); event.stopPropagation();
      if (event.key === 'Escape') { this.close(); return; }
      if (event.key === 'Backspace' || event.key === '0') { this.back(); return; }
      const keys = {Numpad8:0,Numpad9:1,Numpad6:2,Numpad3:3,Numpad2:4,Numpad1:5,Numpad4:6,Numpad7:7};
      if (event.code in keys) { this.choose(keys[event.code]); return; }
      if (/^[1-8]$/.test(event.key)) { this.choose(Number(event.key)-1); return; }
      if (event.key === 'Enter' || event.key === ' ') { if (this.selected !== null) this.choose(this.selected); return; }
      if (['ArrowRight','ArrowDown','ArrowLeft','ArrowUp'].includes(event.key)) {
        const available = this.menu.entries.filter(entry => !entry.disabled).map(entry => entry.slot).sort((a,b)=>a-b);
        if (!available.length) return;
        const direction = ['ArrowRight','ArrowDown'].includes(event.key) ? 1 : -1;
        let index = available.indexOf(this.selected);
        index = index < 0 ? (direction > 0 ? 0 : available.length-1) : (index+direction+available.length)%available.length;
        this.highlight(available[index]);
      }
    },true);
    window.addEventListener('blur',() => this.close());
    window.addEventListener('resize',() => this.close());
    document.addEventListener('visibilitychange',() => { if (document.hidden) this.close(); });
  }
  get active() { return !this.host.hidden; }
  open(menu,x,y,context) {
    this.close();
    this.context = context; this.stack = []; this.menu = menu; this.clickMode = false; this.moved = false;
    this.gestureStart = {x,y}; this.dragged = false; this.initialGesture = true;
    const rect = this.viewport.getBoundingClientRect();
    this.scale = Math.min(1,(rect.width-12)/320,(rect.height-12)/320);
    const margin = 155*this.scale;
    const left = Math.max(margin,Math.min(rect.width-margin,x-rect.left));
    const top = Math.max(margin,Math.min(rect.height-margin,y-rect.top));
    this.origin = { x:rect.left+left,y:rect.top+top };
    this.stage.style.left = `${left}px`; this.stage.style.top = `${top}px`;
    this.stage.style.setProperty('--radial-scale',this.scale);
    this.host.hidden = false; this.hit = {zone:'center',octant:0}; this.selected = null;
    this.render(); this.onVisibility(true);
  }
  close() {
    clearTimeout(this.hoverTimer); this.hoverTimer = null;
    if (!this.active) return;
    this.host.hidden = true; this.slots.replaceChildren(); this.stack = [];
    this.onVisibility(false);
  }
  back() {
    clearTimeout(this.hoverTimer);
    if (!this.stack.length) { this.close(); return; }
    this.menu = this.stack.pop(); this.selected = null; this.render();
  }
  pointer(x,y) {
    const hit = radialHit(x-this.origin.x,y-this.origin.y,this.scale);
    if (hit.zone !== 'center') this.moved = true;
    const changed = hit.octant !== this.hit.octant || hit.zone !== this.hit.zone;
    this.hit = hit;
    this.highlight(['select','submenu'].includes(hit.zone) ? hit.octant : null);
    if (!changed) return;
    clearTimeout(this.hoverTimer);
    const entry = this.menu.entries.find(entry => entry.slot === hit.octant);
    if (!this.clickMode && hit.zone === 'submenu' && entry?.children && !entry.disabled) {
      this.hoverTimer = setTimeout(() => {
        if (this.active && !this.clickMode && this.hit.zone === 'submenu' && this.hit.octant === entry.slot) this.choose(entry.slot);
      },150);
    }
  }
  highlight(slot) {
    this.selected = slot;
    for (const button of this.slots.children) button.classList.toggle('selected',Number(button.dataset.slot) === slot);
    const entry = this.menu.entries.find(entry => entry.slot === slot);
    if (entry) this.help.textContent = entry.disabled ? `${entry.label} · unavailable in current state` : `${entry.label}${entry.children ? ' · submenu' : ''}`;
    else this.help.textContent = this.stack.length ? 'Center · back · Esc · close' : 'Right-drag and release · or click an action · Esc';
  }
  choose(slot) {
    const entry = this.menu.entries.find(entry => entry.slot === slot);
    if (!entry || entry.disabled) return;
    clearTimeout(this.hoverTimer);
    if (entry.children) {
      this.stack.push(this.menu); this.menu = entry.children(); this.selected = null; this.render(); return;
    }
    const context = this.context;
    this.close(); this.onAction(entry,context);
  }
  render() {
    this.slots.replaceChildren();
    this.title.textContent = this.menu.title;
    this.stage.setAttribute('aria-label',this.menu.title);
    this.stage.dataset.depth = String(this.stack.length);
    this.stage.dataset.target = this.context.targetId;
    this.centerButton.textContent = this.stack.length ? '↩' : '×';
    this.centerButton.setAttribute('aria-label',this.stack.length ? 'Back' : 'Cancel');
    for (const entry of this.menu.entries) {
      const button = document.createElement('button'); button.type = 'button'; button.className = 'radial-entry';
      button.setAttribute('role','menuitem'); button.setAttribute('aria-label',entry.label);
      button.disabled = Boolean(entry.disabled); button.dataset.slot = String(entry.slot); button.dataset.action = entry.action ?? 'submenu';
      if (entry.children) button.setAttribute('aria-haspopup','menu');
      const angle = entry.slot*Math.PI/4;
      button.style.left = `${Math.sin(angle)*100}px`; button.style.top = `${-Math.cos(angle)*100}px`;
      const glyph = document.createElement('span'); glyph.className = 'radial-glyph'; glyph.textContent = entry.children ? '↗' : entry.slot === 0 ? '◎' : entry.action === 'door.toggle' ? '✋' : '◆';
      const label = document.createElement('span'); label.className = 'radial-label'; label.textContent = entry.label;
      button.append(glyph,label); button.addEventListener('click',event => {event.stopPropagation();this.choose(entry.slot);});
      this.slots.append(button);
      // Resource icons are optional; useful labels remain when game data lacks one.
      this.loadIcon(entry.icon).then(url => {
        if (!url || !button.isConnected) return;
        const img = document.createElement('img'); img.src = url; img.alt = ''; img.draggable = false;
        glyph.replaceChildren(img);
      }).catch(() => {});
    }
    this.highlight(null);
  }
}
