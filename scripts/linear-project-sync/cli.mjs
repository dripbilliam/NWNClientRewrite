import {parseArgs} from 'node:util';
import {pathToFileURL} from 'node:url';
import {loadConfig} from './config.mjs';
import {createGraphqlClient} from './api.mjs';
import {LinearSource} from './linear.mjs';
import {GithubProject} from './github.mjs';
import {planSync, executePlan} from './sync.mjs';

export async function main(args = process.argv.slice(2), env = process.env, logger = console) {
  try {
    const {values} = parseArgs({args, options: {
      'dry-run': {type: 'boolean'}, apply: {type: 'boolean'},
      verbose: {type: 'boolean'}, help: {type: 'boolean'},
    }, strict: true, allowPositionals: false});
    if (values.help) {
      logger.info('Usage: node scripts/linear-project-sync/cli.mjs --dry-run|--apply [--verbose]');
      logger.info('Configuration: scripts/linear-project-sync/README.md. No publication without --apply.');
      return 0;
    }
    if (Boolean(values['dry-run']) === Boolean(values.apply)) throw Error('Choose exactly one of --dry-run or --apply.');
    const config = loadConfig(env), dryRun = Boolean(values['dry-run']);
    const linear = createGraphqlClient({service: 'Linear', token: env.LINEAR_API_KEY, config, readOnly: true, logger});
    const githubClient = createGraphqlClient({service: 'GitHub', token: env.GH_PROJECT_TOKEN, config, readOnly: dryRun, logger});
    const source = new LinearSource(linear, config), github = new GithubProject(githubClient, config);
    logger.info('Linear to GitHub draft-card sync; mode=' + (dryRun ? 'dry-run' : 'apply')
      + ', publication=' + config.publicationMode + ', descriptions=' + config.descriptionMode + '.');
    const plan = await planSync({source, github, config, logger});
    if (values.verbose) {
      logger.info('Fetched ' + plan.sourceCount + ' source issues and ' + plan.itemCount + ' project items.');
      logger.info('Planned ' + plan.actions.length + ' card writes and ' + plan.cleanup.length + ' retirement actions.');
      logger.info('Titles, descriptions, private labels, provider payloads and credentials are never logged.');
    }
    const summary = await executePlan(plan, {github, config, dryRun, logger});
    return summary.failed ? 1 : 0;
  } catch (error) {
    logger.error('Sync stopped: ' + error.message);
    logger.info('Summary: ' + JSON.stringify({created: 0, updated: 0, unchanged: 0, skipped: 0, failed: 1,
      note: 'Preflight or source/project fetch failed; no synchronization plan was applied.'}));
    return 1;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.exitCode = await main();
}
