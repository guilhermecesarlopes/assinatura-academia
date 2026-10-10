import type { ApiError } from '@assinatura-academia/contracts';
import type { ErrorHandler } from 'hono';
import { HTTPException } from 'hono/http-exception';

// Nunca devolve stack trace nem detalhes internos ao cliente.
export const errorHandler: ErrorHandler = (err, c) => {
  if (err instanceof HTTPException) {
    const body: ApiError = { error: { code: 'http_error', message: err.message } };
    return c.json(body, err.status);
  }
  console.error(err);
  const body: ApiError = { error: { code: 'internal_error', message: 'Erro interno' } };
  return c.json(body, 500);
};
