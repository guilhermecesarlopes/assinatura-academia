import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  reactStrictMode: true,
  transpilePackages: ['@assinatura-academia/contracts'],
  poweredByHeader: false,
};

export default nextConfig;
