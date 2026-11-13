import {UUID} from './config.mjs';

const markerPattern = /^<!-- linear-project-sync:v1 ([a-z0-9][a-z0-9._/-]{0,99}) ([0-9a-f-]{36}) -->$/gm;
const normalize = value => value.trim().toLowerCase();

export class PublicationError extends Error {}

export function identity(body) {
  if (typeof body !== 'string') return null;
  const matches = [...body.matchAll(markerPattern)];
  if (matches.length !== 1 || !UUID.test(matches[0][2])) return null;
  return {namespace: matches[0][1], issueId: matches[0][2].toLowerCase()};
}

export function eligible(issue, config) {
  if (!config.includeArchived && issue.archivedAt) return false;
  return config.publicationMode === 'all'
    || issue.labels.some(label => normalize(label.name) === normalize(config.publicLabel));
}

function publicDescription(description, mode) {
  if (mode === 'title-only') return '';
  let text = description || '';
  if (mode === 'approved') {
    const start = '<!-- linear-github-public:start -->', end = '<!-- linear-github-public:end -->';
    if (text.split(start).length !== 2 || text.split(end).length !== 2) return '';
    const from = text.indexOf(start) + start.length, to = text.indexOf(end);
    if (to < from) return '';
    text = text.slice(from, to);
  }
  // Only description prose is considered. Comments and attachments are never
  // queried. Embedded images/uploads, code/log fences and agent-note blocks
  // are also excluded, including when full-description mode is opted into.
  const lines = [], source = text.replace(/\r\n?/g, '\n').split('\n');
  let agentDelimiter = null, fence = null;
  for (const line of source) {
    if (agentDelimiter) {
      if (line.trim() === agentDelimiter) agentDelimiter = null;
      continue;
    }
    const agent = /^\s*(\+\+\+|>>>)\s*Agent notes?\b/i.exec(line);
    if (agent) { agentDelimiter = agent[1]; continue; }
    const code = /^\s*(\x60{3,}|~{3,})/.exec(line);
    if (fence) {
      if (code && code[1][0] === fence[0] && code[1].length >= fence.length) fence = null;
      continue;
    }
    if (code) { fence = code[1]; continue; }
    if (/!\[|<(?:img|video|audio|iframe|object)\b|uploads\.linear\.app|github\.com\/user-attachments|\bdata:/i.test(line)) continue;
    lines.push(line);
  }
  return lines.join('\n').replace(/<!--[\s\S]*?-->/g, '').replace(/<[^>]*>/g, '').trim();
}

function assertPublicSafe(text) {
  if (/(?:github_pat_|gh[pousr]_|lin_api_)[a-z0-9_]{12,}/i.test(text)
      || /-----BEGIN [A-Z ]*PRIVATE KEY-----/.test(text)
      || /\b(?:api[_ -]?key|access[_ -]?token|auth(?:orization)?|password|secret|cd[_ -]?key)["']?\s*[:=]\s*\S+/i.test(text)
      || /\bBearer\s+[a-z0-9._~-]{12,}/i.test(text)
      || /https?:\/\/[^\s/]+@[^\s/]+/i.test(text)
      || /[?&](?:token|key|api_key|password|signature|sig|authorization)=/i.test(text)) {
    throw new PublicationError('Content blocked by the credential-pattern check; review the approved public text.');
  }
}

export function renderCard(issue, config) {
  if (!UUID.test(issue.id) || !/^[A-Z0-9_-]+-\d+$/i.test(issue.identifier)) {
    throw new PublicationError('Issue identity is not suitable for publication.');
  }
  let url;
  try { url = new URL(issue.url); } catch { throw new PublicationError('Invalid Linear issue URL.'); }
  if (url.protocol !== 'https:' || url.hostname !== 'linear.app' || url.port || url.username || url.password
      || url.search || url.hash || !url.pathname.includes('/issue/') || /[<>\s()]/.test(issue.url)) {
    throw new PublicationError('Unexpected Linear issue URL; review before publication.');
  }
  const rawTitle = issue.title.trim().replace(/[\r\n]+/g, ' ');
  if (!rawTitle || rawTitle.length > 240 || /[\x00-\x08\x0b\x0c\x0e-\x1f]/.test(rawTitle)) {
    throw new PublicationError('Issue title is empty, oversized or contains control characters.');
  }
  const description = publicDescription(issue.description, config.descriptionMode);
  if (description.length > 50000) throw new PublicationError('Public description exceeds the supported length.');
  assertPublicSafe(rawTitle + '\n' + description);
  // Prefixing prevents a URL-only title being treated as an existing Issue/PR
  // by addProjectV2DraftIssue. Matching always uses the UUID marker, never title.
  const title = '[' + issue.identifier + '] ' + rawTitle;
  const body = 'Source: [' + issue.identifier + '](' + issue.url + ')\n\n'
    + (description ? description + '\n\n' : '')
    + '<!-- linear-project-sync:v1 ' + config.namespace + ' ' + issue.id.toLowerCase() + ' -->';
  return {title, body};
}

export function makeStatusResolver(states, field, config, logger = console) {
  const options = new Map(), mappings = new Map();
  for (const option of field.options) {
    const name = normalize(option.name);
    if (options.has(name)) throw Error('Ambiguous GitHub status option names.');
    options.set(name, option.id);
  }
  for (const [source, target] of Object.entries(config.statusMapping)) {
    const key = normalize(source), optionId = options.get(normalize(target));
    if (mappings.has(key) || !optionId) throw Error('STATUS_MAPPING_JSON has an ambiguous key or missing target option.');
    mappings.set(key, optionId);
  }
  if (config.unknownStatusPolicy === 'fallback' && !options.has(normalize(config.fallbackStatus))) {
    throw Error('STATUS_FALLBACK is not an existing GitHub status option.');
  }
  if (config.removalPolicy === 'archive-status' && !options.has(normalize(config.archiveStatus))) {
    throw Error('ARCHIVE_STATUS is not an existing GitHub status option.');
  }
  const actual = new Map(states.map(state => [state.id, state]));
  return {
    resolve(issue) {
      const state = actual.get(issue.state.id);
      const optionId = state && (mappings.get(normalize(state.id))
        || mappings.get(normalize(state.name)) || options.get(normalize(state.name)));
      if (optionId) return optionId;
      logger.warn('Unknown or unmapped workflow status for public issue ' + issue.identifier
        + '; policy=' + config.unknownStatusPolicy + '.');
      if (config.unknownStatusPolicy === 'error') throw Error('A public issue has no configured status mapping.');
      return config.unknownStatusPolicy === 'fallback' ? options.get(normalize(config.fallbackStatus)) : null;
    },
    archiveOption: options.get(normalize(config.archiveStatus)),
  };
}
