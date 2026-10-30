export default {
  title: 'EntireDecomp research wiki',
  // Only documentation is published. Runtime captures, game assets and code stay local.
  roots: ['evidence', 'godot-client', 'scripts', 'references'],
  rootFiles: ['README.md', 'RESEARCH_TRACKER.md', 'REPLACEMENT_CLIENT_ROADMAP.md', 'CASTING_RESUME_NOTE.md', 'wiki/README.md'],
  excludedDirectories: ['.git', '.github', '.codex', '.agents', '.cache', '.godot', '.tools', 'node_modules', 'backups', 'dist', 'runtime-logs', 'reports', 'captures', '_site'],
  topics: [
    { id: 'native-client', title: 'Native client and migration', description: 'Godot ownership, launch paths, migration milestones and local playability.', pattern: /native|migration|local-playability|local-multiplayer|base-gameplay|systems/i },
    { id: 'rendering', title: 'Rendering and performance', description: 'Models, animation, lighting, particles, cameras and measured frame costs.', pattern: /render|model|animat|light|particle|shadow|camera|skin|terrain|sky|weather|visual|performance|hotpath|dense|frame-schedul|material|geometry|horizon|ground-height|chunk|point-wind/i },
    { id: 'networking', title: 'Networking and multiplayer', description: 'Authentication, protocol messages, replication, sessions and area transfers.', pattern: /multiplayer|network|login|connect|protocol|nwsync|server-browser|server-vault|admission|handoff|sync-recovery|session|arelith|portal-transfer|area-message/i },
    { id: 'combat', title: 'Combat and character rules', description: 'Attack resolution, damage, defenses, character progression and creature statistics.', pattern: /combat|damage|attack|defense|stat-|stats|saving|save-dc|character|creation|progression|level-up|skills|polymorph|form-equipment|immortality|death|corpse|reputation|factions|perception|sanctuary/i },
    { id: 'spells', title: 'Spells and effects', description: 'Casting, spellbooks, projectiles, effects, talents and spell lifecycle evidence.', pattern: /spell|cast|effect|projectile|talent|on-hit|summon|entangle|curse|time-stop|rest-lifecycle|feat/i },
    { id: 'world', title: 'World objects and movement', description: 'Resource-backed world state, object lifetimes, movement, collision and transitions.', pattern: /world|area|object|movement|drive|path-|door|transition|placement|template|action|trigger|jump|motion|bump|associate|henchm|body-bag|follow|ground/i },
    { id: 'interface', title: 'Interface and interaction', description: 'HUDs, inventory, menus, NUI, dialogue, maps and user input.', pattern: /ui|hud|inventory|container|quickbar|shortcut|menu|radial|dialog|conversation|map-|automap|journal|input|keyboard|cursor|target|examine|store|item|feedback|window|portrait|text|talk|speech|token|chat/i },
    { id: 'resources', title: 'Resources and persistence', description: 'Resource discovery, archives, native data readers, save state and asset ownership.', pattern: /resource|content|asset|archive|loading|load$|save|persist|serialization|snapshot|cache|catalog|prepar|uuid|reference|ownership|streaming|workshop|prefetch|talk-table/i },
    { id: 'scripting', title: 'Scripting and simulation', description: 'VM state, script APIs, event clocks, AI and simulation lifecycle.', pattern: /script|vm-|event|clock|timer|pause|ai-|calendar|lifecycle|utilities/i },
    { id: 'audio', title: 'Audio and speech', description: 'Ambient and placed sounds, voices, music and sound presentation.', pattern: /audio|sound|voice|speech|quick-chat/i },
    { id: 'research', title: 'Research methods and checkpoints', description: 'Evidence standards, binary investigation, diagnostics, plans and retained checkpoints.', pattern: /research|roadmap|resume|binary-inventory|rea-|diagnostic|goal|checkpoint|trial|test-plan|tracker|readme|contract/i }
  ],
  entryPoints: [
    { path: 'godot-client/README.md', label: 'Native client entry', description: 'Start with launch paths and the overview of the Godot client.' },
    { path: 'godot-client/NATIVE-OWNERSHIP.md', label: 'Architecture and ownership', description: 'Read the intended native architecture and remaining service boundaries.' },
    { path: 'godot-client/LOCAL-PLAYABILITY.md', label: 'Local campaign acceptance', description: 'Find the scoped campaign checks and remaining playability work.' },
    { path: 'evidence/binary-inventory.md', label: 'Target binary and evidence', description: 'Identify the executable build and the original investigation inputs.' },
    { path: 'RESEARCH_TRACKER.md', label: 'Research tracker', description: 'Browse the retained research checkpoints; their dates describe each checkpoint.' },
    { path: 'wiki/README.md', label: 'Maintain this wiki', description: 'Build, preview, publish and add cross-references.' }
  ]
};
