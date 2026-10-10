import { getHealth } from '@/lib/api';

export default async function Home() {
  const health = await getHealth();

  return (
    <main style={{ fontFamily: 'system-ui', padding: 32 }}>
      <h1>Assinatura Academia</h1>
      <p>API: {health ? `${health.status} (v${health.version})` : 'indisponível'}</p>
    </main>
  );
}
