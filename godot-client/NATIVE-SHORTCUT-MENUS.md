# Native shortcut assignment menus

Right-click an empty or populated shortcut to open its assignment wheel.
Choose Items, Spells, Feats, Skills, Abilities or Commands when that character
has choices in the category. Family parents open child choices; larger lists
retain More pages. Clear slot removes the binding. The separate clear button,
three pages, F1–F12 activation and existing item/spell/record dragging remain.

`tools/shortcut-choice-service.mjs` binds the original `NetworkQuickbarView`
data-only `choices`, `ruleName` and `spellChoice` methods to the current world,
rules and text resolver. It does not construct that class or its DOM presenter.
The original `quickbarAssignmentMenu` builds the hierarchy; Godot and the
existing action service own presentation and private menu IDs. Original JS
sources and the working JS frontend remain unchanged.

The backend revalidates current actor/world ownership, shortcut contents and
available choices after asynchronous metadata loading and before sending an
assignment. Native menu selection sends only private menu/request/physical
slot identities. Revoked feats/abilities/items and changed bindings cannot be
authorized by supplying a different binding. Item choices retain the original
configuration rules; family parents are never assigned as castable spells.
Successful writes refresh the native dock and close their own menu. Pending
actions cannot dispatch twice; cancellation cannot publish a late wheel.

Skills require actual server character-sheet records. If those are missing,
`shortcut-stats.mjs` temporarily requests character page 1, waits for replicated
skills, then restores the currently open sheet page or its closed state. It
does not invent ranks, display a hidden character sheet or close a new actor's
panel after retirement. Existing server metadata is reused; timeouts leave an
actionable retry message. Full skill-value freshness after level/buff changes
still needs broader integration coverage.

Right-click coordinates now come from the GUI event transformed to viewport
space, rather than a later OS mouse-position poll. This matters for delayed or
synthetic events and does not change the physical shortcut index.

## Verification

`reports/native-shortcut-choice-local-v4.json` passes 34 actual local checks:

- Menu assignment of the admitted character's Light spell, real cast submission
  and prepared uses changing from 2 to 1.
- Assignment of Follow as original command shortcut type 42 / parameter 22,
  successful command submission and menu clearing of both bindings. This is
  not proof of a companion's behavioral response when no companion is present.
- Existing owned-item and power dragging, four server equipment acknowledgements,
  one potion consumed from 3 to 2, both original clear controls, inventory
  examination, page changes, original icons and window reopen behavior.
- WASD with simultaneous inventory and spellbook after the server returns from
  spell animation 19 to idle 0. Casting interruption remains a separate combat
  acceptance case; the test does not hide it behind menu movement acceptance.

The actual assignment-category screenshot was reviewed: original category
icons and Commands/Spells/Items/Feats/Skills/Clear are visible. The initially
missing Skills category was corrected by requesting real server metadata.
Native exit is 0, disconnect is explicit, no native/renderer errors or rejected
commands are reported, and pending inventory icons are zero. The installed
sample BIC remains read-only; a separate external temporary regression vault
is used. Original NWN PID49160 and the editor stayed open by explicit user
authorization. These functional runs do not establish a clean FPS benchmark.

`reports/shortcut-choice-node-v4.log` passes 69 cases with no failures or skips.
New coverage includes all original category kinds, nested spell and innate
families, More pages, default items, skills/feats, familiar possession and
revocation, private selection, pending writes, cancelled construction and
temporary character-stat subscription restoration/timeout/retirement.

`reports/shortcut-choice-ui-v2.json` passes seven authored Vulkan checks using
synthetic viewport right-clicks, including event coordinates, empty slots,
page identity and retained old buttons. Existing inventory/spellbook/power/drag
native regressions pass 24 / 22 / 14 / 12 checks. The action regression passes
8,000 checks, predominantly its original-derived hit-band oracle, not 8,000
independent gameplay scenarios. All associated engine logs are clean.

Retained failures: authored UI v1 caught the later mouse-position poll. Local
v1 completes the assignment and cast stages but fails the movement test while
the spell is still active; it remains rejected. V2 passes 33 checks after an
explicit server-idle condition. V3 passes 34 including a screenshot, but its
driver sampled a newly rebuilt slot before container layout and lacked Skills
metadata. V4 waits a layout frame and queries missing skills before publishing.
Existing particle and unhandled game-message diagnostics remain open.

## Remaining scope

Actual server checks for each feat/skill/innate/associate assignment category,
large custom catalogs, arbitrary custom commands beyond the original provided
choices, broader assignment persistence across reconnect, physical-device and full
skin/fidelity review remain. [Skill shortcut activation](NATIVE-SKILLS.md) now
has original-codec and local targeting/mode/crafting-dialogue evidence;
broader skill/feat/item/associate outcomes and casting interruption
remain part of the combat/action migration. This menu work does not accept
those handlers, full shortcut parity or full gameplay/performance parity.
No Arelith or other public-server connection was made. The complete migration
goal remains active, with UI before rendering and combat acceptance.

[Saved-character shortcut validation](NATIVE-SHORTCUT-PERSISTENCE.md) now covers
seven item/spell/skill/command bindings on three pages, cross-page drag, actual
export/read-back, an item-ID change and native Ctrl+F activation after reconnect.
Broader families/feats/innates/paired items and pending-work races remain.
