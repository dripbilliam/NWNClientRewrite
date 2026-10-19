# Native captured stacks and script code ownership

Target: read-only NWN:EE89.8193.37-17 x64, `nwmain.exe` SHA256
`3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`.
This follows `object-action-load.md`; complete saved VM state remains open.

## Findings and implementation

Whole CopyFromStack14027fd60..140280019 clears the destination, shifts both
signed byte counts right2, defaults both zero regions to current BP/SP, clamps
each region independently to65536, takes the end of the base region and end of
the entire active stack, and allocates copied-count+16 cells when nonempty.
Empty snapshots have size/capacity/BP0. Unknown element types retain Type with
constructor-zero data. Primitive bits, owned strings and engine-structure copy
dispatch follow separate branches. Out-of-range source reads are diagnosed.
`script_stack_copy.js` ports this owner and `NwScriptVm.capture` now uses it.
Engine-structure copying remains an explicit lower provider; the live VM's
existing value-copy representation is retained, not claimed fully equivalent
to native engine wrappers/refcounts. SQL/solver/JSON ownership still needs work.

Whole StackPopCommand_Internal285e80..286020 sets saved script+8 from the
ORIGINAL stack pointer before copying selected regions; saved stack pointer
and capacity therefore differ from this field. It writes SecondaryPtr0 and
stored InstructionPtr, shares code/NDB, copies name/JmpData/chunk. Its fresh
script constructor27db60 sets event field48 to0, which this capture owner does
not overwrite. The live capture now explicitly retains original stack size,
copied capacity and native instruction pointer. This owner is statically read,
not claimed to have all lower copy/shared-pointer owners emulated.

ReadScriptFile2836a0 passes `pcVar5+13` and length-13 to DataBlock::Append;
RunScript283990 calls RunScriptFile284590 with start0. Thus the native code blob
excludes the NCS header and native PCs are relative to that body. Host parser
PCs deliberately include the header. `parseNcs` now retains an owned copy of the
native code body, and capture converts stored host PC to native PC by-13. The
previous comment asserting equal native/host offsets was incorrect and fixed.
InitializeScript2829b0..282a89 shares the body/empty NDB supplied by file loading
and clears the jump map; its default script InstructionPtr13 is not the start
argument used by ordinary RunScriptFile(0). These distinct owners must not be
collapsed into a header-inclusive serialized blob or guessed saved PC.

STORE_IP opcode1c clears both captured region sizes; STORE_STATE2c stores the
first immediate in VM814 (base bytes), second in810 (top bytes), and target in
80c. This confirms the parser's existing first/base and second/top assignment.
The interpreter-bytecode owner itself does not require aligned positive sizes;
the native copier shifts/clamps them, which replaces the host capture's former
unaligned rejection. Other VM opcodes retain their existing validation.

## Verification

- `inspect-native-script-stack-copy.py`:110 unchanged full original-copy cases,
  including all primitive/engine-copy dispatch types, embedded-NUL strings,
  overlapping regions, negative/unaligned counts,100 randomized regions and
  individual/both65536 clamps. Original full payload/order/capacity compare in
  `script-stack-copy-native.test.js`. Fresh clear/heap/element constructors,
  string assignment and opaque engine copies are captured boundaries. Engine
  markers prove dispatch, not wrapper serialization/refcount completion.
- `inspect-native-store-state.py`:8 original ExecuteCode entry/opcode cases,
  stopped at the next interpreter-loop boundary. Covers STORE_IP/STORE_STATE,
  body PC offsets, type-byte targets and signed immediate bits. This is partial
  ExecuteCode-path coverage, not a whole interpreter completion claim. V1 used
  instruction-limit0 and correctly failed before opcode execution; v2 supplies
  a valid limit1000 and passes. Failure evidence retained.
- `script-stack-copy-focused-v2.txt`:45 focused tests pass: native comparisons,
  capture metadata/code ownership, script arithmetic/calls/capture/scheduler,
  canonical DoCommand, action load, AI-event clocks, item/feat/talent VM calls
  and diagnostics. Build script-stack-copy-build-v1 PASS. No full suite run.
- `installed-vm-capture-v1.json`:installed Prelude/wizard/session/active API,
  with an explicitly constructed NCS fixture. Actual STORE_STATE and
  ActionDoCommand capture local123, queue a type5 situation, then the real
  action runner resumes SetLocalInt on OBJECT_SELF and disposes the snapshot.
  Original SP1/captured cells1/capacity17, nativePC27/hostPC40 and header-excluded
  code are checked. Registry, allocator cursors and effect IDs are unchanged.
  Startup/general AI isolated; diagnostics retained. This is not a claim that
  a particular shipped script or campaign encounter was completed.

## Remaining work / research retained

Full script-situation Save284d00 and Load282ab0..283229, stack Load283230,
engine Save552d60..552e66/Load5521d0..552435/Copy50ce00, CopyEffect423ce0 and
RunScriptSituation284830 bodies are now read and retained. Save/Load engine
structures use nested label `GameDefinedStrct` and type-specific owners:
effect/itemproperty, event, location, talent, SQL/solver/JSON virtual methods.
Notably engine-effect loading uses constructor(1), consuming a fresh effect ID
before LoadGameEffect replaces the stored ID, whereas object-state effect
loading uses constructor(0). Engine effect copying uses constructor(0) plus
CopyEffect(...,0), which copies SkipOnLoad, unlike the clearing copy constructor.

Stack load reads BP/SP/capacity, logs failure lines0x165/0x166/0x167 for negatives,
0x170 for missing list and0x175 for missing element; callers may ignore its result.
It calls engine Load via the implementer using the current element's output
pointer. SaveScriptSituation's decompiler omits its fifth engine-save argument;
audit actual ABI before binding. JmpList hash order, engine wrapper contents,
NDB/chunk/event ownership and restored VM execution remain to finish. Live
type5 save/load still diagnose missing owners; no empty VM snapshot is emitted.
Raw code and captured stack metadata now exist for that next real integration.
Full creature save/load/CopyObject, spell/combat and campaign goal stays ACTIVE.
The format and primitive queued-script round trip have since been connected;
see [VM snapshot serialization](vm-snapshot-serialization.md). Engine values
and actual jump-map ownership remain open.

Verified checkpoint `backups/vm-situation-capture-20261017-v1.zip`:
11489 files/174378509 bytes, every archived length and SHA256 verified.
Writer17155 terminal0 consumed; `vm-situation-capture-checkpoint-v1.txt`.
This verification/line-number clarification was added after sealing.
