import { HealthResponseSchema, type HealthResponse } from '@assinatura-academia/contracts';

const API_URL = process.env['NEXT_PUBLIC_API_URL'] ?? 'http://localhost:8787';

// Toda resposta da API é validada contra o contrato antes de ser usada.
export async function getHealth(): Promise<HealthResponse | null> {
  try {
    const res = await fetch(`${API_URL}/health`, { cache: 'no-store' });
    if (!res.ok) return null;
    const parsed = HealthResponseSchema.safeParse(await res.json());
    return parsed.success ? parsed.data : null;
  } catch {
    return null;
  }
}
