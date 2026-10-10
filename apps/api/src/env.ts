// Bindings disponíveis no Worker. Adicione aqui todo segredo/variável nova.
export type Env = {
  Bindings: {
    DATABASE_URL: string;
    APP_VERSION: string;
    ALLOWED_ORIGIN: string;
  };
};
