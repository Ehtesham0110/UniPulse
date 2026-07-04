import { createApp } from './app.js';
import { connectDatabase } from './config/database.js';
import { env } from './config/env.js';

async function bootstrap() {
  await connectDatabase();
  const app = createApp();
  app.listen(env.port, () => {
    console.log(`UniPulse API listening on port ${env.port}`);
  });
}

bootstrap().catch((error) => {
  console.error('Failed to start UniPulse API', error);
  process.exit(1);
});

