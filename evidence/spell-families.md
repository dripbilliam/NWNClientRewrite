# Spell-family selection

Clicking a family in the multiplayer known-spells list or a prepared family slot opens a variant panel inside the spellbook. Each leaf has its own active-table name, icon and description action and can be dragged to the quickbar. Nested families open another level with a Back button. The parent remains available for preparation, but does not emit a cast shortcut. Existing parent shortcuts open a radial variant chooser on activation. Ordinary spell and innate-ability radials support nested families; the local fallback spellbook expands inline children.

`src/spell_family.js` derives membership from the current `spells.2da` SubRadSpell1..8 columns. It does not identify families by names or fixed IDs. Invalid rows, duplicates, self-links and ancestor cycles are excluded. Shortcut-tree construction is bounded to32 levels/2048 nodes. Rules are supplied by the active resource owner; no global family catalog is cached across servers.

Child bindings retain source class index, metamagic and domain/caster-level fields. Spellbook preparation widgets retain the physical parent ID separately from the child's cast ID. Dropping a child into a preparation slot requests the parent; casting requests the selected child. Prepared uses use the existing native-derived Master mapping; innate shortcut display can follow Master to an owned replicated ability pool. No client-side slot granting, spending or ready-bit changes are introduced. Server responses remain authoritative. Area/session/control/token guards reject stale selections and drags.

## Basis and limits

The existing read-only native metadata mapping in `spell_metadata.js` identifies compacted SubRadSpell1..8 loads at CNWSpellArray::Load `0x1402afb18..0x1402afbcb`. Existing spell-radial, target-preparation and client-use-count instruction oracles remain passing. The pure target-preparation helper's native first-child preview behavior is unchanged; UI entry points now require selecting a leaf before reaching it. The family panel is new presentation chosen for this client, not a claim of original GUI pixel parity.

Native reference remains NWN:EE89.8193.37-17 x64, `../FullDecomp/NwnRootInstall/bin/win32/nwmain.exe`, SHA256 `3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a`. No executable, installation, assets or Ghidra database was modified. No new binary-analysis claim is needed for the panel.

A read-only installed stock-table scan finds22 families and78 leaf choices; all generate leaf bindings while preserving context. The stock Protection from Alignment row321 has only children138/139. The four Good/Evil/Law/Chaos choices are verified with a synthetic active override. Actual server definitions determine which variants appear. This is not a live Arelith casting acceptance result.

## Validation

-34 focused Node checks pass, including existing native spell/innate sender, targeting, radial, preparation and quickbar regressions. New checks cover four-choice and nested/cyclic definitions, table isolation, parent interception, child targeting, shared prepared/innate counts and source fields. An executed production-main local-entry check verifies family interception happens on spell input, item input keeps its separate path, and delayed menus cannot open in a changed session. Log: `backups/animations/creation-experience-spell-family-focused-v1.txt`.
- `scripts/verify-spell-family-catalog.mjs` passes against all22 installed stock families. Derived report: `creation-experience-spell-family-catalog-v1.json` under backups/animations.
- Isolated Chromium fixture uses production NetworkSpellbookView, NetworkQuickbarView, NetworkSpellTargeting, RadialMenu and the local spellbook method. Native pointer clicks open the family panel without losing list scroll. Browser DataTransfer events verify child quickbar assignment and encoded request, shared-parent preparation, metamagic/domain context, prepared-slot picker, legacy parent activation, nested choices, and area/token cleanup. Requests are captured, not sent to a game server. Report `creation-experience-spell-family-v1.json`; final run-v3 exits0, no console errors. Screenshot `creation-experience-spell-family-v1.png` inspected; icons/skin in this fixture are synthetic.
- Final production build passes: `index-BihcTKOh.js` / `index-tTyJGnBp.css`. Existing large-chunk warning remains.

No public/local server was joined for this work, no chat or character upload was sent, and no existing client was interrupted. Restart is required to use the new build. The broader goal remains paused. These changes are unsealed follow-ups after checkpointv49.
