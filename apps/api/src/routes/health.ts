import type { HealthResponse } from '@assinatura-academia/contracts';
import { Hono } from 'hono';
import type { Env } from '../env';

export const health = new Hono<Env>().get('/', (c) => {
  const body: HealthResponse = {
    status: 'ok',
    version: c.env.APP_VERSION,
    time: new Date().toISOString(),
  };
  return c.json(body);
});
