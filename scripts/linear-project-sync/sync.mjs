import {eligible, identity, makeStatusResolver, renderCard, PublicationError} from './policy.mjs';

export async function planSync({source, github, config, logger = console}) {
  // Finish and validate all source/project pagination and absence checks before
  // planning any writes. Exceptions cannot fall through into removal handling.
  const snapshot = await source.fetchSnapshot();
  if (snapshot.complete !== true) throw Error('Linear snapshot is incomplete; no changes will be made.');
  const project = await github.fetchProject();
  const items = await github.fetchItems(project);
  const status = makeStatusResolver(snapshot.states, project.statusField, config, logger);
  const managed = new Map(), counts = {created: 0, updated: 0, unchanged: 0, skipped: 0,
    failed: 0, removed: 0, archived: 0, duplicates: 0};
  for (const item of items) {
    if (item.content?.__typename !== 'DraftIssue') continue;
    const marker = identity(item.content.body);
    if (!marker && item.content.body?.includes('<!-- linear-project-sync:')) {
      throw Error('Malformed managed-card marker; repair it before synchronizing to prevent duplicates.');
    }
    if (!marker || marker.namespace !== config.namespace) continue;
    if (!item.content.id || typeof item.content.title !== 'string') throw Error('Managed draft is incomplete.');
    const group = managed.get(marker.issueId) || [];
    group.push(item); managed.set(marker.issueId, group);
  }
  const byId = new Map(), actions = [], cleanup = [];
  for (const issue of snapshot.issues) {
    const id = issue.id.toLowerCase();
    if (byId.has(id)) throw Error('Duplicate Linear issue UUID; no changes will be made.');
    byId.set(id, issue);
    if (!eligible(issue, config)) { counts.skipped++; continue; }
    const group = managed.get(id) || [];
    if (group.length > 1) {
      counts.duplicates += group.length - 1; counts.failed++;
      logger.warn('Duplicate managed cards for public issue ' + issue.identifier + '; reconcile them manually. No new card will be created.');
      continue;
    }
    let card;
    try { card = renderCard(issue, config); }
    catch (error) {
      if (!(error instanceof PublicationError)) throw error;
      counts.failed++;
      logger.warn('Publication blocked for one issue by content validation; no content logged.');
      continue;
    }
    const optionId = status.resolve(issue);
    if (!optionId) { counts.skipped++; continue; }
    const item = group[0];
    if (!item) {
      actions.push({kind: 'create', issueId: id, identifier: issue.identifier, card, optionId});
    } else {
      const contentChanged = item.content.title !== card.title || item.content.body !== card.body;
      const statusChanged = item.fieldValueByName?.optionId !== optionId;
      if (!contentChanged && !statusChanged && !item.isArchived) counts.unchanged++;
      else actions.push({kind: 'update', issueId: id, identifier: issue.identifier,
        item, card, optionId, contentChanged, statusChanged, unarchive: item.isArchived});
    }
  }
  for (const [id, group] of managed) {
    const issue = byId.get(id);
    if (issue && eligible(issue, config)) continue; // Includes unknown/blocked statuses/content.
    if (group.length > 1) {
      counts.duplicates += group.length - 1; counts.failed++;
      logger.warn('Duplicate managed cards are excluded from removal; reconcile manually.');
      continue;
    }
    const item = group[0];
    if (config.removalPolicy === 'leave') {
      counts.skipped++;
      logger.warn('Retained managed card ' + item.id + ' is no longer eligible or absent; policy=leave.');
      continue;
    }
    const reason = issue ? 'excluded-by-filter' : await source.classifyAbsent(id);
    if (reason === 'changed-during-fetch') {
      counts.skipped++;
      logger.warn('Source changed during fetch; preserving managed card ' + item.id + '.');
      continue;
    }
    if (!['excluded-by-filter', 'missing', 'outside-scope'].includes(reason)) {
      throw Error('Unconfirmed source absence; no changes will be made.');
    }
    if (config.removalPolicy === 'archive-status' && item.fieldValueByName?.optionId === status.archiveOption) {
      counts.unchanged++;
      continue;
    }
    cleanup.push({kind: config.removalPolicy, item, reason, optionId: status.archiveOption});
  }
  if (cleanup.length > config.maxRemovals) throw Error('Removal plan exceeds MAX_REMOVALS; review a dry run and raise the limit explicitly.');
  if (cleanup.length && !snapshot.issues.length && !config.allowEmptySource) {
    throw Error('Empty source removal is blocked; verify access and set ALLOW_EMPTY_SOURCE_REMOVALS only after review.');
  }
  return {project, actions, cleanup, counts, sourceCount: snapshot.issues.length, itemCount: items.length};
}

export async function executePlan(plan, {github, config, dryRun = true, logger = console}) {
  const counts = {...plan.counts};
  const log = action => {
    const option = plan.project.statusField.options.find(row => row.id === action.optionId);
    logger.info((dryRun ? 'WOULD ' : '') + action.kind.toUpperCase() + ' '
      + (action.identifier || action.item.id) + (option ? ' -> ' + option.name : '')
      + (action.reason ? ' (' + action.reason + ')' : ''));
  };
  for (const action of plan.actions) {
    log(action);
    if (dryRun) { counts[action.kind === 'create' ? 'created' : 'updated']++; continue; }
    try {
      let item = action.item;
      if (action.kind === 'create') {
        try { item = await github.create(plan.project, action.card); }
        catch {
          // A request may have succeeded despite a lost response. Re-enumerate
          // rather than replaying a non-idempotent create mutation.
          const existing = (await github.fetchItems(plan.project)).filter(candidate => {
            const marker = candidate.content?.__typename === 'DraftIssue' && identity(candidate.content.body);
            return marker && marker.namespace === config.namespace && marker.issueId === action.issueId;
          });
          if (existing.length !== 1) throw Error('Draft creation is unconfirmed; rerun after reconciliation.');
          item = existing[0];
          if (!item.content.id) throw Error('Reconciled draft has no content ID.');
          if (item.content.title !== action.card.title || item.content.body !== action.card.body) {
            await github.update(item, action.card);
          }
        }
        await github.setStatus(plan.project, item, action.optionId);
        counts.created++;
      } else {
        if (action.unarchive) await github.unarchive(plan.project, item);
        if (action.contentChanged) await github.update(item, action.card);
        if (action.statusChanged) await github.setStatus(plan.project, item, action.optionId);
        counts.updated++;
      }
    } catch {
      counts.failed++;
      logger.error('A managed-card write failed or is unconfirmed; rerun safely. No source content logged.');
      // Stop this run. Do not continue publishing or clean up after any failure.
      counts.skipped += plan.actions.slice(plan.actions.indexOf(action) + 1).length;
      break;
    }
  }
  if (counts.failed) {
    counts.skipped += plan.cleanup.length;
    if (plan.cleanup.length) logger.warn('Removal phase suppressed because the run has failures.');
  } else {
    for (const action of plan.cleanup) {
      log(action);
      try {
        if (action.kind === 'remove') {
          if (!dryRun) await github.remove(plan.project, action.item);
          counts.removed++;
        } else {
          if (!dryRun) await github.setStatus(plan.project, action.item, action.optionId);
          counts.archived++;
        }
      } catch {
        counts.failed++;
        logger.error('Removal/status archival was not confirmed; stopping cleanup.');
        break;
      }
    }
  }
  const result = {...counts, dryRun, sourceIssues: plan.sourceCount, projectItems: plan.itemCount};
  logger.info('Summary: ' + JSON.stringify(result));
  return result;
}
