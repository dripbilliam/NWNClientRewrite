import { runtimeDiagnostics } from './runtime_diagnostics.js';
import {scriptTalent} from './talent.js';
export const OBJECT_INVALID = 0x7f000000;
const TYPES = { int: 3, float: 4, string: 5, object: 6, effect: 0x10, event: 0x11, location: 0x12, talent: 0x13, itemproperty: 0x14, sqlquery: 0x15, cassowary: 0x16, json: 0x17 };
const clone = cell => ({ type: cell.type, value: typeof cell.value === 'object' && cell.value !== null ? structuredClone(cell.value) : cell.value });
const slots = bytes => { if (!Number.isInteger(bytes) || bytes % 4) throw new Error(`Unaligned stack offset ${bytes}`); return bytes / 4; };

export class ScriptError extends Error {
  constructor(program, pc, message) { super(`${program.name}@0x${pc.toString(16)}: ${message}`); this.name = 'ScriptError'; this.script = program.name; this.pc = pc; }
}

export class NwScriptVm {
  constructor({ api, command, instructionLimit = 100_000, stackLimit = 65_536, diagnostics = runtimeDiagnostics, diagnosticContext = () => ({}), limitations = {} }) {
    Object.assign(this, { api, command, instructionLimit, stackLimit, diagnostics, diagnosticContext, limitations });
  }
  async run(program, self = OBJECT_INVALID, { situation = null, budget = { remaining: this.instructionLimit }, depth = 0, scriptEventContext=-1 } = {}) {
    if(!Number.isInteger(scriptEventContext))throw new Error('Native script event context is unavailable');
    if (depth >= 8) {
      const error = new ScriptError(program, 13, 'Nested script limit exceeded');
      error.diagnosticCode = 'script.failure'; error.diagnosticContext = { ...this.diagnosticContext(self), script: program.name, pc: 13, objectId: self };
      this.diagnostics.error(error); throw error;
    }
    const frame = { program, self, pc: situation?.pc ?? 13, stack: situation?.stack.map(clone) ?? [], bp: situation?.bp ?? 0, returns: [], stored: null, budget, depth,scriptEventContext:scriptEventContext|0 };
    let executingPc = frame.pc;
    try {
      while (frame.pc !== null) {
        executingPc = frame.pc;
        if (--budget.remaining < 0) throw new Error('Instruction budget exceeded');
        const ins = program.instructions.get(frame.pc);
        if (!ins) throw new Error('Instruction pointer outside program');
        frame.pc = ins.next;
        await this.step(frame, ins);
        if (frame.stack.length > this.stackLimit) throw new Error('Stack limit exceeded');
      }
      return { stack: frame.stack.map(clone), bp: frame.bp, instructionsRemaining: budget.remaining };
    } catch (error) {
      if (error instanceof ScriptError) { this.diagnostics.error(error, 'script.failure', { ...this.diagnosticContext(self), ...error.diagnosticContext, script: error.script, pc: error.pc }); throw error; }
      const failure = new ScriptError(program, executingPc, error.message);
      const instruction = program.instructions.get(executingPc), spec = instruction?.op === 5 ? this.api[instruction.command] : null;
      failure.cause = error;
      failure.diagnosticCode = instruction?.op === 5 ? (/not implemented|unsupported|unavailable|have not been loaded/i.test(error.message) ? 'engine.unimplemented' : 'engine.failure') : 'script.failure';
      failure.diagnosticContext = { ...this.diagnosticContext(self), script: program.name, pc: executingPc, pcHex: `0x${executingPc.toString(16)}`, objectId: self,
        ...(instruction?.op === 5 ? frame.engineContext : {}),
        opcode: instruction?.op, engineCall: spec?.name, engineId: instruction?.op === 5 ? instruction.command : undefined, argumentCount: instruction?.op === 5 ? instruction.argc : undefined };
      this.diagnostics.error(failure); throw failure;
    }
  }
  push(frame, type, value) {
    if (type === 'vector') { for (const component of value) this.push(frame, 'float', component); return; }
    const code = typeof type === 'string' ? TYPES[type] : type;
    if (!code) throw new Error(`Unsupported value type ${type}`);
    frame.stack.push({ type: code, value: code === 3 ? value | 0 : code === 4 ? Math.fround(value) : code === 6 ? value >>> 0 : value });
  }
  pop(frame, type) {
    if (type === 'vector') { const z = this.pop(frame, 'float'), y = this.pop(frame, 'float'), x = this.pop(frame, 'float'); return [x, y, z]; }
    if (type === 'action') return this.capture(frame);
    const code = typeof type === 'string' ? TYPES[type] : type, cell = frame.stack.pop();
    if (!cell || cell.type !== code) throw new Error(`Stack type mismatch: expected ${type}, got ${cell?.type ?? 'empty'}`);
    return cell.value;
  }
  capture(frame) {
    if (!frame.stored) throw new Error('Action argument has no STORE_STATE');
    let base = slots(frame.stored.baseSize), top = slots(frame.stored.stackSize);
    if (!base && !top) { base = frame.bp; top = frame.stack.length - base; }
    base = Math.min(Math.max(base, 0), frame.bp, this.stackLimit); top = Math.min(Math.max(top, 0), this.stackLimit);
    if (top > frame.stack.length) throw new Error('Captured stack exceeds active stack');
    // Native copies the END of the base region and END of the active stack.
    return { program: frame.program, pc: frame.stored.pc, bp: base,
      stack: [...frame.stack.slice(frame.bp - base, frame.bp), ...frame.stack.slice(frame.stack.length - top)].map(clone) };
  }
  region(frame, index, count) {
    if (index < 0 || count < 0 || index + count > frame.stack.length) throw new Error('Stack access out of bounds');
    return frame.stack.slice(index, index + count).map(clone);
  }
  async step(f, i) {
    const s = f.stack, pop = type => this.pop(f, type), push = (type, value) => this.push(f, type, value);
    switch (i.op) {
      case 1: case 3: case 0x26: case 0x27: {
        if (i.type !== 1) throw new Error('Invalid stack copy type');
        const index = (i.op >= 0x26 ? f.bp : s.length) + slots(i.offset), count = slots(i.size);
        if (i.op === 3 || i.op === 0x27) s.push(...this.region(f, index, count));
        else { const values = this.region(f, s.length - count, count); this.region(f, index, count); values.forEach((cell, n) => { s[index + n] = cell; }); }
        return;
      }
      case 2:
        if (![3, 4, 5, 6].includes(i.type) && (i.type < 0x10 || i.type > 0x19)) throw new Error('Invalid RSADD type');
        // CreateGameDefinedStructure14050d208..14050d222 allocates a
        // constructor-initialized talent for RSADD, never a null pointer.
        push(i.type, i.type === 5 ? '' : i.type === 6 ? OBJECT_INVALID : i.type===0x13?scriptTalent():i.type >= 0x10 ? null : 0); return;
      case 4:
        if (i.type === 6) push(6, i.value === 0 ? f.self : OBJECT_INVALID);
        else if (i.type === 0x12) { if (i.value !== 0) throw new Error('Invalid location constant'); push('location', null); }
        else if (i.type === 0x17) throw new Error('JSON constants are not implemented');
        else push(i.type, i.value); return;
      case 5: {
        const spec = this.api[i.command];
        // Inspect typed object references without popping/capturing an action.
        // Do not dump arbitrary script strings or engine structure payloads.
        let cursor = f.stack.length - 1;
        const objectArguments = [];
        for (const [index, arg] of (spec?.args.slice(0, i.argc) ?? []).entries()) {
          if (arg.type === 'object' && f.stack[cursor]?.type === 6) objectArguments.push({ index, name: arg.name, objectId: f.stack[cursor].value >>> 0 });
          cursor -= arg.type === 'action' ? 0 : arg.type === 'vector' ? 3 : 1;
        }
        f.engineContext = { objectArguments };
        if (!spec || i.argc > spec.args.length || spec.args.slice(i.argc).some(arg => !arg.optional)) throw new Error(`Invalid engine command/arity ${i.command}/${i.argc}`);
        // Refuse unsupported calls BEFORE popping arguments/capturing actions.
        const handler = this.command(spec.name);
        if (!handler) throw new Error(`Engine call ${spec.name} is not implemented`);
        if (this.limitations[spec.name]) this.diagnostics.record('engine.partial', this.limitations[spec.name], { ...this.diagnosticContext(f.self), ...f.engineContext, script: f.program.name, pc: i.pc, objectId: f.self, engineCall: spec.name, engineId: i.command });
        // A mapped native owner can conditionally pop its arguments. For
        // example ActionUseTalent leaves the target untouched on an invalid
        // talent/absent self; eager generic popping would change script state.
        const result = typeof handler.nativeStack === 'function'
          ? await handler.nativeStack(this, f, spec, i.argc)
          : await handler(spec.args.slice(0, i.argc).map(arg => pop(arg.type)), f, spec);
        if (spec.returns !== 'void') push(spec.returns, result);
        return;
      }
      case 0x1b: {
        const next = s.length + slots(i.offset);
        if (next < 0 || next > s.length) throw new Error('Invalid MOVSP'); s.length = next; return;
      }
      case 0x1c: case 0x2c: f.stored = { pc: i.target, baseSize: i.baseSize ?? 0, stackSize: i.stackSize ?? 0 }; return;
      case 0x1d: f.pc = i.target; return;
      case 0x1e: if (f.returns.length >= 127) throw new Error('Subroutine return stack limit exceeded'); f.returns.push(i.next); f.pc = i.target; return;
      case 0x1f: case 0x25: { const value = pop(3); if ((value === 0) === (i.op === 0x1f)) f.pc = i.target; return; }
      case 0x20: f.pc = f.returns.pop() ?? null; return;
      case 0x21: {
        const count = slots(i.total), start = slots(i.start), keep = slots(i.size), base = s.length - count;
        if (start + keep > count) throw new Error('Invalid DESTRUCT');
        const values = this.region(f, base + start, keep); this.region(f, base, count); s.splice(base, count, ...values); return;
      }
      case 0x23: case 0x24: case 0x28: case 0x29: {
        const index = (i.op >= 0x28 ? f.bp : s.length) + slots(i.offset);
        if (i.type !== 3 || s[index]?.type !== 3) throw new Error('Invalid integer increment');
        s[index].value = (s[index].value + (i.op === 0x24 || i.op === 0x29 ? 1 : -1)) | 0; return;
      }
      case 0x2a: { const previousSp = s.length; push(3, f.bp); f.bp = previousSp; return; }
      case 0x2b: f.bp = pop(3); if (f.bp < 0 || f.bp > s.length) throw new Error('Invalid restored BP'); return;
      case 0x2d: return;
      case 0x19: case 0x1a: case 0x22: {
        if ((i.op !== 0x19 && i.type !== 3) || ![3, 4].includes(i.type)) throw new Error('Invalid unary type');
        const a = pop(i.type); push(i.type, i.op === 0x19 ? -a : i.op === 0x1a ? ~a : Number(!a)); return;
      }
      default: this.binary(f, i);
    }
  }
  binary(f, i) {
    if ([0xb, 0xc].includes(i.op) && i.type === 0x24) {
      const count = slots(i.size), right = this.region(f, f.stack.length - count, count); f.stack.length -= count;
      const left = this.region(f, f.stack.length - count, count); f.stack.length -= count;
      if (left.some(c => c.type >= 0x10)) throw new Error('Engine structure equality is not implemented');
      this.push(f, 3, Number(left.every((c, n) => c.type === right[n].type && c.value === right[n].value)) ^ Number(i.op === 0xc)); return;
    }
    const pair = { 0x20: [3, 3], 0x21: [4, 4], 0x22: [6, 6], 0x23: [5, 5], 0x25: [3, 4], 0x26: [4, 3], 0x3a: ['vector', 'vector'], 0x3b: ['vector', 4], 0x3c: [4, 'vector'] }[i.type];
    if (!pair) throw new Error(`Unsupported binary type ${i.type}`);
    const b = this.pop(f, pair[1]), a = this.pop(f, pair[0]);
    if (i.type >= 0x3a) {
      if (i.type === 0x3a && [0x14, 0x15].includes(i.op)) this.push(f, 'vector', a.map((v, n) => i.op === 0x14 ? v + b[n] : v - b[n]));
      else if ([0x3b, 0x3c].includes(i.type) && [0x16, 0x17].includes(i.op)) {
        const vector = i.type === 0x3b ? a : b, scalar = i.type === 0x3b ? b : a;
        if (i.op === 0x17 && !scalar) throw new Error('Division by zero');
        const scale = i.op === 0x17 ? Math.fround(1 / scalar) : scalar;
        this.push(f, 'vector', vector.map(v => v * scale));
      } else throw new Error('Invalid vector operation');
      return;
    }
    let value, type = 3;
    if ([6, 7, 8, 9, 10, 0x11, 0x12, 0x13, 0x18].includes(i.op) && i.type !== 0x20) throw new Error('Invalid integer binary operation');
    if ([0xb, 0xc].includes(i.op) && ![0x20, 0x21, 0x22, 0x23].includes(i.type)) throw new Error('Invalid equality type');
    if ([0xd, 0xe, 0xf, 0x10].includes(i.op) && ![0x20, 0x21].includes(i.type)) throw new Error('Invalid comparison type');
    if ([0x14, 0x15, 0x16, 0x17].includes(i.op)) {
      if (![0x20, 0x21, 0x25, 0x26].includes(i.type) && !(i.op === 0x14 && i.type === 0x23)) throw new Error('Invalid arithmetic type');
      type = i.type === 0x20 ? 3 : i.type === 0x23 ? 5 : 4;
    }
    const x = type === 4 ? Math.fround(a) : a, y = type === 4 ? Math.fround(b) : b;
    switch (i.op) {
      case 6: value = Number(Boolean(a) && Boolean(b)); break;
      case 7: value = Number(Boolean(a) || Boolean(b)); break;
      case 8: value = a | b; break; case 9: value = a ^ b; break; case 10: value = a & b; break;
      case 0xb: value = Number(a === b); break; case 0xc: value = Number(a !== b); break;
      case 0xd: value = Number(a >= b); break; case 0xe: value = Number(a > b); break;
      case 0xf: value = Number(a < b); break; case 0x10: value = Number(a <= b); break;
      case 0x11: value = a << (b & 31); break;
      case 0x12: value = a < 0 ? -((-a | 0) >> (b & 31)) : a >> (b & 31); break;
      // Despite its name, the target's USHRIGHT uses SAR (sign extending).
      case 0x13: value = a >> (b & 31); break;
      case 0x14: value = x + y; break; case 0x15: value = x - y; break;
      case 0x16: value = type === 3 ? Math.imul(a, b) : x * y; break;
      case 0x17:
        if (!y) throw new Error('Division by zero');
        if (type === 3 && a === -2147483648 && b === -1) throw new Error('Integer division overflow');
        value = type === 3 ? Math.trunc(x / y) : x / y; break;
      case 0x18:
        if (!b) throw new Error('Modulo by zero');
        if (a === -2147483648 && b === -1) throw new Error('Integer division overflow');
        value = a % b; break;
      default: throw new Error(`Unsupported opcode ${i.op}`);
    }
    this.push(f, type, value);
  }
}
