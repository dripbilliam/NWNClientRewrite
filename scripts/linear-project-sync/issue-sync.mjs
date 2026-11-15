import {eligible, identity, makeStatusResolver, renderIssue, PublicationError} from './policy.mjs';
import {sameIssueState} from './repository.mjs';

function managedIdentity(body, namespace) {
  const marker = identity(body);
  if (!marker && body?.includes('<!-- linear-project-sync:')) {
    throw Error('Malformed managed-card marker; repair before importing to prevent duplicate issues.');
  }
  return marker?.namespace === namespace ? marker.issueId : null;
}

function add(map, id, value) {
  const group = map.get(id) || [];
  group.push(value); map.set(id, group);
}

function belongs(issue, repository) {
  return issue.repository?.nameWithOwner?.toLowerCase() === repository.nameWithOwner.toLowerCase();
}

export async function planIssueSync({source, github, repository, config, logger = console}) {
  const snapshot = await source.fetchSnapshot();
  if (snapshot.complete !== true) throw Error('Linear snapshot is incomplete; no changes will be made.');
  const project = await github.fetchProject(), repo = await repository.fetchRepository();
  const items = await github.fetchItems(project), issues = await repository.fetchIssues(repo);
  const status = makeStatusResolver(snapshot.states, project.statusField, config, logger);
  const repoIssues = new Map(), drafts = new Map(), linked = new Map();
  const counts = {created: 0, updated: 0, unchanged: 0, skipped: 0, failed: 0,
    removed: 0, archived: 0, duplicates: 0, linked: 0, migrated: 0};
  for (const issue of issues) {
    const id = managedIdentity(issue.body, config.namespace);
    if (!id) continue;
    if (!issue.id || typeof issue.title !== 'string' || !['OPEN', 'CLOSED'].includes(issue.state)
        || !belongs(issue, repo)) throw Error('Managed repository issue is incomplete or belongs to another repository.');
    add(repoIssues, id, issue);
  }
  for (const item of items) {
    if (!['DraftIssue', 'Issue'].includes(item.content?.__typename)) continue;
    const id = managedIdentity(item.content.body, config.namespace);
    if (!id) continue;
    if (!item.id || !item.content.id) throw Error('Managed project item is incomplete.');
    if (item.content.__typename === 'DraftIssue') add(drafts, id, item);
    else {
      if (!belongs(item.content, repo)) throw Error('Managed board issue belongs to another repository.');
      if (!(repoIssues.get(id) || []).some(issue => issue.id === item.content.id)) {
        throw Error('Managed board issue is missing from the complete repository inventory.');
      }
      add(linked, id, item);
    }
  }
  const conflicts = new Set();
  for (const map of [repoIssues, drafts, linked]) for (const [id, group] of map) {
    if (group.length > 1) { conflicts.add(id); counts.duplicates += group.length - 1; }
  }
  counts.failed += conflicts.size;
  if (conflicts.size) logger.warn('Duplicate UUID markers found; affected tickets will not be imported or changed.');
  const byId = new Map(), actions = [], cleanup = [];
  for (const issue of snapshot.issues) {
    const id = issue.id.toLowerCase();
    if (byId.has(id)) throw Error('Duplicate Linear issue UUID; no changes will be made.');
    byId.set(id, issue);
    if (!eligible(issue, config)) { counts.skipped++; continue; }
    if (conflicts.has(id)) continue;
    let card;
    try { card = renderIssue(issue, config); }
    catch (error) {
      if (!(error instanceof PublicationError)) throw error;
      counts.failed++; logger.warn('Publication blocked for one issue; no source content logged.'); continue;
    }
    const optionId = status.resolve(issue);
    if (!optionId) { counts.skipped++; continue; }
    const target = repoIssues.get(id)?.[0], item = linked.get(id)?.[0], draft = drafts.get(id)?.[0];
    const contentChanged = target && (target.title !== card.title || target.body !== card.body);
    const stateChanged = target && !sameIssueState(target, card);
    const statusChanged = !item || item.fieldValueByName?.optionId !== optionId;
    if (target && item && !contentChanged && !stateChanged && !statusChanged && !item.isArchived && !draft) {
      counts.unchanged++; continue;
    }
    actions.push({kind: target ? 'update' : 'create', issueId: id, identifier: issue.identifier,
      target, item, draft, card, optionId, contentChanged, stateChanged, statusChanged});
  }
  const managedIds = new Set([...repoIssues.keys(), ...drafts.keys(), ...linked.keys()]);
  for (const id of managedIds) {
    const issue = byId.get(id);
    if (conflicts.has(id) || issue && eligible(issue, config)) continue;
    if (config.removalPolicy === 'leave') { counts.skipped++; continue; }
    const reason = issue ? 'excluded-by-filter' : await source.classifyAbsent(id);
    if (reason === 'changed-during-fetch') { counts.skipped++; continue; }
    if (!['excluded-by-filter', 'missing', 'outside-scope'].includes(reason)) throw Error('Unconfirmed source absence.');
    for (const item of [...(drafts.get(id) || []), ...(linked.get(id) || [])]) {
      if (config.removalPolicy === 'archive-status' && item.fieldValueByName?.optionId === status.archiveOption) {
        counts.unchanged++; continue;
      }
      cleanup.push({kind: config.removalPolicy, item, reason, optionId: status.archiveOption});
    }
  }
  if (cleanup.length > config.maxRemovals) throw Error('Removal plan exceeds MAX_REMOVALS.');
  if (cleanup.length && !snapshot.issues.length && !config.allowEmptySource) throw Error('Empty source removal is blocked.');
  return {project, repo, actions, cleanup, counts, sourceCount: snapshot.issues.length,
    itemCount: items.length, repositoryIssueCount: issues.length};
}

export async function executeIssuePlan(plan, {github, repository, config, dryRun = true, logger = console}) {
  const counts = {...plan.counts};
  for (const [index, action] of plan.actions.entries()) {
    logger.info((dryRun ? 'WOULD ' : '') + action.kind.toUpperCase() + ' ISSUE ' + action.identifier);
    if (dryRun) {
      counts[action.kind === 'create' ? 'created' : 'updated']++;
      if (!action.item) counts.linked++;
      if (action.draft) counts.migrated++;
      continue;
    }
    try {
      let issue = action.target, item = action.item;
      if (!issue) {
        try { issue = await repository.create(plan.repo, action.card); }
        catch {
          const found = (await repository.fetchIssues(plan.repo)).filter(candidate => {
            const marker = identity(candidate.body);
            return marker?.namespace === config.namespace && marker.issueId === action.issueId;
          });
          if (found.length !== 1 || !belongs(found[0], plan.repo)) throw Error('Issue creation is unconfirmed; rerun to reconcile.');
          issue = found[0];
        }
      }
      if (issue.title !== action.card.title || issue.body !== action.card.body) await repository.update(issue, action.card);
      if (!sameIssueState(issue, action.card)) await repository.setState(issue, action.card);
      if (!item) {
        try { item = await github.addIssue(plan.project, issue); }
        catch {
          const found = (await github.fetchItems(plan.project)).filter(candidate =>
            candidate.content?.__typename === 'Issue' && candidate.content.id === issue.id);
          if (found.length !== 1) throw Error('Issue project link is unconfirmed; rerun to reconcile.');
          item = found[0];
        }
        counts.linked++;
      }
      if (item.isArchived) await github.unarchive(plan.project, item);
      // A close/reopen can trigger board automation; restore Linear's exact column.
      if (action.statusChanged || action.stateChanged || !action.item) {
        await github.setStatus(plan.project, item, action.optionId);
      }
      // The issue, state and board status must all succeed before removing its old draft.
      // Issue numbers, comments and manually applied repository labels are preserved.
      if (action.draft) { await github.remove(plan.project, action.draft); counts.migrated++; }
      counts[action.kind === 'create' ? 'created' : 'updated']++;
    } catch {
      counts.failed++; counts.skipped += plan.actions.length - index - 1;
      logger.error('Issue/board write failed or is unconfirmed; stopping. Existing issues reconcile by UUID on the next run.');
      break;
    }
  }
  if (counts.failed) counts.skipped += plan.cleanup.length;
  else for (const action of plan.cleanup) {
    try {
      if (action.kind === 'remove') {
        if (!dryRun) await github.remove(plan.project, action.item);
        counts.removed++;
      } else {
        if (!dryRun) await github.setStatus(plan.project, action.item, action.optionId);
        counts.archived++;
      }
    } catch {
      counts.failed++; logger.error('Board retirement failed; stopping cleanup.'); break;
    }
  }
  const result = {...counts, dryRun, sourceIssues: plan.sourceCount, projectItems: plan.itemCount,
    repositoryIssues: plan.repositoryIssueCount};
  logger.info('Summary: ' + JSON.stringify(result));
  return result;
}
