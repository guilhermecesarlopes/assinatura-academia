import { HealthResponseSchema } from '@assinatura-academia/contracts';
import { describe, expect, it } from 'vitest';
import app from '../src/index';

const env = {
  DATABASE_URL: 'postgresql://test',
  APP_VERSION: 'test',
  ALLOWED_ORIGIN: 'http://localhost:3000',
};

describe('GET /health', () => {
  it('responde no formato do contrato', async () => {
    const res = await app.request('/health', {}, env);
    expect(res.status).toBe(200);
    expect(HealthResponseSchema.safeParse(await res.json()).success).toBe(true);
  });

  it('rota inexistente devolve 404 no formato de erro', async () => {
    const res = await app.request('/nao-existe', {}, env);
    expect(res.status).toBe(404);
  });
});
