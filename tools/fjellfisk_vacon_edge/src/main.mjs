import {EdgeApiClient, EdgeLogger, VaconEdgeRunner, loadEdgeConfig} from './edge.mjs';

const configPath = process.env.FJELLFISK_VACON_EDGE_CONFIG ?? '/etc/fjellfisk-vacon-edge/edge.json';
const controller = new AbortController();
process.once('SIGINT', () => controller.abort());
process.once('SIGTERM', () => controller.abort());

try {
  const config = await loadEdgeConfig(configPath);
  const logger = new EdgeLogger();
  const runner = new VaconEdgeRunner({config, api: new EdgeApiClient(config), logger});
  await runner.start(controller.signal);
} catch (error) {
  const code = error instanceof Error ? error.message : 'startup-failed';
  console.error(`[fjellfisk-vacon-edge] startup_failed code=${code}`);
  process.exitCode = 1;
}
