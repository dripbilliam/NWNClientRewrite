# Preserve the closed test captures and exclude active client/checkpoint logs.
& (Join-Path $PSScriptRoot 'checkpoint-combat.ps1') -Name 'multiplayer-examine-20261018-v1' -ExcludeCaptureNames @(
  'network-spellbook-interactive-v88.txt',
  'network-spellbook-interactive-v88-stderr.txt',
  'network-spellbook-live-v88.json',
  'network-renderer-control-v88.json',
  'network-spellbook-checkpoint-v1.txt',
  'network-hud-buttons-interactive-v90.txt',
  'network-hud-buttons-interactive-v90-stderr.txt',
  'network-hud-buttons-live-v90.json',
  'network-renderer-control-v90.json',
  'network-hud-buttons-checkpoint-v1.txt',
  'network-hud-buttons-checkpoint-v2.txt',
  'network-movement-interactive-v92.txt',
  'network-movement-interactive-v92-stderr.txt',
  'network-movement-live-v92.json',
  'network-renderer-control-v92.json',
  'network-movement-facing-checkpoint-v1.txt',
  'network-examine-interactive-v95.txt',
  'network-examine-interactive-v95-stderr.txt',
  'network-examine-live-v95.json',
  'network-renderer-control-v95.json',
  'network-examine-checkpoint-v1.txt'
)
