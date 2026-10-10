import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { secureHeaders } from 'hono/secure-headers';
import type { Env } from './env';
import { errorHandler } from './middleware/error';
import { health } from './routes/health';

const app = new Hono<Env>();

app.use('*', secureHeaders());
app.use('*', (c, next) => cors({ origin: c.env.ALLOWED_ORIGIN, credentials: true })(c, next));

app.route('/health', health);

app.notFound((c) => c.json({ error: { code: 'not_found', message: 'Rota não encontrada' } }, 404));
app.onError(errorHandler);

export default app;
export type AppType = typeof app;
