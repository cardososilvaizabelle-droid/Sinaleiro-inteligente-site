-- Banco de dados PostgreSQL / Supabase para SmartTraffic AI
-- Execute este SQL no SQL Editor do Supabase

-- 1) ENUMS
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'categoria_prioridade_enum') THEN
        CREATE TYPE categoria_prioridade_enum AS ENUM (
            'Pedestre Geral',
            'Idoso (60+ anos)',
            'Pessoa com Deficiência / Cadeirante',
            'Deficiente Visual',
            'Gestante / Lactante',
            'Condutor de Emergência (SAMU / Bombeiros)'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'status_camera_enum') THEN
        CREATE TYPE status_camera_enum AS ENUM (
            'ONLINE',
            'OFFLINE',
            'MANUTENCAO'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'categoria_feedback_enum') THEN
        CREATE TYPE categoria_feedback_enum AS ENUM (
            'Elogio',
            'Sugestão de Tempo',
            'Alerta de Segurança'
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'funcao_usuario_enum') THEN
        CREATE TYPE funcao_usuario_enum AS ENUM ('VISITANTE', 'ADMINISTRADOR');
    END IF;
END $$;

-- 2) Tabela de acesso ao painel/site
CREATE TABLE IF NOT EXISTS contas_acesso (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome VARCHAR(150) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    senha_hash VARCHAR(255) NOT NULL,
    funcao funcao_usuario_enum NOT NULL DEFAULT 'VISITANTE',
    ativo BOOLEAN DEFAULT TRUE,
    criado_em TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO contas_acesso (nome, email, senha_hash, funcao)
VALUES ('Administrador Master', 'admin@smarttraffic.ai', '$2b$10$ExemploDeHashDeSenhaSegura', 'ADMINISTRADOR')
ON CONFLICT (email) DO NOTHING;

-- 3) Cadastro de pessoas físicas
CREATE TABLE IF NOT EXISTS pessoas_fisicas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome TEXT NOT NULL,
    cpf TEXT NOT NULL UNIQUE,
    data_nascimento DATE NOT NULL,
    categoria categoria_prioridade_enum NOT NULL,
    foto_url TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_pessoas_fisicas_cpf ON pessoas_fisicas (cpf);
CREATE INDEX IF NOT EXISTS idx_pessoas_fisicas_nome ON pessoas_fisicas (nome);

-- 4) Feedback dos cidadãos
CREATE TABLE IF NOT EXISTS feedbacks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome TEXT NOT NULL,
    localizacao TEXT NOT NULL,
    categoria categoria_feedback_enum NOT NULL,
    nota SMALLINT NOT NULL CHECK (nota BETWEEN 1 AND 5),
    comentario TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_feedbacks_categoria ON feedbacks (categoria);
CREATE INDEX IF NOT EXISTS idx_feedbacks_created_at ON feedbacks (created_at DESC);

-- 5) Contato com a central
CREATE TABLE IF NOT EXISTS contatos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome TEXT NOT NULL,
    email TEXT NOT NULL,
    orgao TEXT,
    assunto TEXT NOT NULL,
    mensagem TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_contatos_email ON contatos (email);

-- 6) Habilita RLS
ALTER TABLE contas_acesso ENABLE ROW LEVEL SECURITY;
ALTER TABLE pessoas_fisicas ENABLE ROW LEVEL SECURITY;
ALTER TABLE feedbacks ENABLE ROW LEVEL SECURITY;
ALTER TABLE contatos ENABLE ROW LEVEL SECURITY;

-- 7) Policies públicas para permitir INSERT via site (Supabase anon key)
DROP POLICY IF EXISTS "Permite insert em pessoas_fisicas" ON pessoas_fisicas;
CREATE POLICY "Permite insert em pessoas_fisicas"
ON pessoas_fisicas FOR INSERT
WITH CHECK (TRUE);

DROP POLICY IF EXISTS "Permite insert em feedbacks" ON feedbacks;
CREATE POLICY "Permite insert em feedbacks"
ON feedbacks FOR INSERT
WITH CHECK (TRUE);

DROP POLICY IF EXISTS "Permite insert em contatos" ON contatos;
CREATE POLICY "Permite insert em contatos"
ON contatos FOR INSERT
WITH CHECK (TRUE);

DROP POLICY IF EXISTS "Permite select em pessoas_fisicas" ON pessoas_fisicas;
CREATE POLICY "Permite select em pessoas_fisicas"
ON pessoas_fisicas FOR SELECT
USING (TRUE);

DROP POLICY IF EXISTS "Permite select em feedbacks" ON feedbacks;
CREATE POLICY "Permite select em feedbacks"
ON feedbacks FOR SELECT
USING (TRUE);

DROP POLICY IF EXISTS "Permite select em contatos" ON contatos;
CREATE POLICY "Permite select em contatos"
ON contatos FOR SELECT
USING (TRUE);

-- 8) Trigger para atualizar updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_pessoas_fisicas_updated_at ON pessoas_fisicas;
CREATE TRIGGER trg_update_pessoas_fisicas_updated_at
BEFORE UPDATE ON pessoas_fisicas
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Observação:
-- Para uso em produção, prefira regras mais restritas no RLS.
-- O ideal é permitir somente INSERT/SELECT para registros públicos,
-- e usar service_role somente no backend, nunca no frontend.
