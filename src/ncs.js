// Instruction offsets include the 13-byte NCS header, as in the native VM.
export const NCS_OP = Object.freeze(Object.fromEntries((
  'CPDOWNSP RSADD CPTOPSP CONST ACTION LOGAND LOGOR INCOR EXCOR BOOLAND EQUAL NEQUAL GEQ GT LT LEQ SHLEFT SHRIGHT USHRIGHT ADD SUB MUL DIV MOD NEG COMP MOVSP STOREIP JMP JSR JZ RETN DESTRUCT NOT DECSP INCSP JNZ CPDOWNBP CPTOPBP DECBP INCBP SAVEBP RESTOREBP STORESTATE NOP'
).split(' ').map((name, i) => [name, i + 1])));

export function parseNcs(input, name = '<script>') {
  const bytes = input instanceof ArrayBuffer ? new Uint8Array(input) : new Uint8Array(input.buffer, input.byteOffset, input.byteLength);
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const check = (pc, size) => { if (pc + size > bytes.length) throw new Error(`${name}: truncated NCS at ${pc}`); };
  check(0, 13);
  if (new TextDecoder().decode(bytes.subarray(0, 8)) !== 'NCS V1.0' || bytes[8] !== 0x42 || view.getUint32(9) !== bytes.length) throw new Error(`${name}: invalid NCS header/size`);
  const instructions = new Map();
  for (let pc = 13; pc < bytes.length;) {
    check(pc, 2);
    const op = bytes[pc], type = bytes[pc + 1], ins = { pc, op, type };
    let size = 2;
    if (op < 1 || op > 0x2d) throw new Error(`${name}: unknown opcode ${op} at ${pc}`);
    if (op === 4) {
      if ([3, 4, 6, 0x12].includes(type)) {
        size = 6; check(pc, size);
        ins.value = type === 4 ? view.getFloat32(pc + 2) : type === 3 ? view.getInt32(pc + 2) : view.getUint32(pc + 2);
      } else if ([5, 0x17].includes(type)) {
        check(pc, 4); size = 4 + view.getUint16(pc + 2); check(pc, size);
        ins.value = new TextDecoder('windows-1252').decode(bytes.subarray(pc + 4, pc + size));
      } else throw new Error(`${name}: unsupported constant type ${type} at ${pc}`);
    } else if (op === 5) {
      size = 5; check(pc, size); ins.command = view.getUint16(pc + 2); ins.argc = bytes[pc + 4];
    } else if ([1, 3, 0x26, 0x27].includes(op)) {
      size = 8; check(pc, size); ins.offset = view.getInt32(pc + 2); ins.size = view.getUint16(pc + 6);
    } else if (op === 0x21) {
      size = 8; check(pc, size); ins.total = view.getUint16(pc + 2); ins.start = view.getUint16(pc + 4); ins.size = view.getUint16(pc + 6);
    } else if (op === 0x2c) {
      size = 10; check(pc, size); ins.baseSize = view.getInt32(pc + 2); ins.stackSize = view.getInt32(pc + 6); ins.target = pc + type;
    } else if (op === 0x1c) ins.target = pc + type;
    else if ([0x1b, 0x1d, 0x1e, 0x1f, 0x23, 0x24, 0x25, 0x28, 0x29].includes(op)) {
      size = 6; check(pc, size); ins.offset = view.getInt32(pc + 2);
      if ([0x1d, 0x1e, 0x1f, 0x25].includes(op)) ins.target = pc + ins.offset;
    } else if ([0xb, 0xc].includes(op) && type === 0x24) {
      size = 4; check(pc, size); ins.size = view.getUint16(pc + 2);
    }
    ins.next = pc + size; instructions.set(pc, Object.freeze(ins)); pc += size;
  }
  for (const ins of instructions.values()) if (ins.target !== undefined && !instructions.has(ins.target)) throw new Error(`${name}: branch at ${ins.pc} targets a non-instruction (${ins.target})`);
  return Object.freeze({ name, instructions });
}

// The installed nwscript.nss declares the engine command table in ordinal order.
// Keep that authoritative table in the resource resolver, rather than copying it.
export function parseScriptApi(source) {
  const text = source.replace(/\/\*[\s\S]*?\*\//g, '').replace(/\/\/[^\n]*/g, '');
  const declarations = [...text.matchAll(/\b(void|int|float|string|object|vector|effect|event|location|talent|itemproperty|json|sqlquery|cassowary)\s+(\w+)\s*\(([^;]*?)\)\s*;/g)];
  return declarations.map(([_, returns, name, args], id) => ({ id, name, returns,
    args: args.split(/,(?![^\[]*\])/).filter(s => s.trim()).map(s => {
      const match = s.trim().match(/^(\w+)\s+(\w+)(?:\s*=\s*([\s\S]+))?$/);
      if (!match) throw new Error(`Cannot parse ${name} parameter ${s}`);
      return { type: match[1], name: match[2], optional: match[3] !== undefined, defaultSource: match[3] };
    })
  }));
}
