-- Banco de dados PostgreSQL / Supabase para SmartTraffic AI
-- Execute no SQL Editor do Supabase.
-- IMPORTANTE: dados de pessoas (CPF, nascimento e biometria) são sensíveis.
-- Este schema NÃO permite acesso público de leitura/gravação à tabela de pessoas.

-- ENUMS
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
        CREATE TYPE status_camera_enum AS ENUM ('ONLINE', 'OFFLINE', 'MANUTENCAO');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'categoria_feedback_enum') THEN
        CREATE TYPE categoria_feedback_enum AS ENUM ('Elogio', 'Sugestão de Tempo', 'Alerta de Segurança');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'funcao_usuario_enum') THEN
        CREATE TYPE funcao_usuario_enum AS ENUM ('VISITANTE', 'ADMINISTRADOR');
    END IF;
END $$;

-- Contas administrativas: autenticação deve ser feita pelo Supabase Auth.
-- Esta tabela não é usada para guardar senhas nem hashes próprios.
CREATE TABLE IF NOT EXISTS contas_acesso (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome VARCHAR(150) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    funcao funcao_usuario_enum NOT NULL DEFAULT 'VISITANTE',
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Cadastro pessoal: sem policies para anon/authenticated por padrão.
-- Gerencie apenas por backend confiável ou policies baseadas em usuário autenticado.
CREATE TABLE IF NOT EXISTS pessoas_fisicas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome TEXT NOT NULL,
    cpf TEXT NOT NULL UNIQUE,
    data_nascimento DATE NOT NULL,
    categoria categoria_prioridade_enum NOT NULL,
    foto_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_pessoas_fisicas_nome ON pessoas_fisicas (nome);
ALTER TABLE pessoas_fisicas ENABLE ROW LEVEL SECURITY;
ALTER TABLE pessoas_fisicas FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE pessoas_fisicas FROM anon, authenticated;

-- Feedback público: visitantes podem inserir e ler; sem edição ou exclusão públicas.
CREATE TABLE IF NOT EXISTS feedbacks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome TEXT NOT NULL,
    localizacao TEXT NOT NULL,
    categoria categoria_feedback_enum NOT NULL,
    nota SMALLINT NOT NULL CHECK (nota BETWEEN 1 AND 5),
    comentario TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_feedbacks_categoria ON feedbacks (categoria);
CREATE INDEX IF NOT EXISTS idx_feedbacks_created_at ON feedbacks (created_at DESC);
ALTER TABLE feedbacks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permite insert em feedbacks" ON feedbacks;
CREATE POLICY "Permite insert em feedbacks" ON feedbacks FOR INSERT TO anon, authenticated WITH CHECK (TRUE);
DROP POLICY IF EXISTS "Permite select em feedbacks" ON feedbacks;
CREATE POLICY "Permite select em feedbacks" ON feedbacks FOR SELECT TO anon, authenticated USING (TRUE);
GRANT INSERT, SELECT ON TABLE feedbacks TO anon, authenticated;

-- Mensagens de contato: apenas inserir como visitante; leitura restrita a backend/administrador.
CREATE TABLE IF NOT EXISTS contatos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome TEXT NOT NULL,
    email TEXT NOT NULL,
    orgao TEXT,
    assunto TEXT NOT NULL,
    mensagem TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_contatos_email ON contatos (email);
ALTER TABLE contatos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Permite insert em contatos" ON contatos;
CREATE POLICY "Permite insert em contatos" ON contatos FOR INSERT TO anon, authenticated WITH CHECK (TRUE);
DROP POLICY IF EXISTS "Permite select em contatos" ON contatos;
DROP POLICY IF EXISTS "Permite select em contatos" ON contatos;
REVOKE ALL ON TABLE contatos FROM anon, authenticated;
GRANT INSERT ON TABLE contatos TO anon, authenticated;

-- Contas de acesso: sem acesso direto do browser.
ALTER TABLE contas_acesso ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE contas_acesso FROM anon, authenticated;

-- Trigger de atualização
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
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Não crie policy pública para pessoas_fisicas nem exponha CPF/foto no feed.
-- Nunca use a chave service_role no frontend. Configure permissões administrativas
-- somente após implementar autenticação e autorização apropriadas.
INSERT INTO contas_acesso (nome, email, senha_hash, funcao, ativo)
VALUES 
    ('Eduardo Ribeiro Silva', 'eduardo.ribeiro.silva14@escola.pr.gov.br', '$2b$10$SupabaseAuthManagedPassword', 'ADMINISTRADOR', TRUE),
    ('Fernando Emidio', 'fernando.emidio@escola.pr.gov.br', '$2b$10$SupabaseAuthManagedPassword', 'ADMINISTRADOR', TRUE),
    ('Izabelle Cardoso Silva', 'cardoso.silva.izabelle@escola.pr.gov.br', '$2b$10$SupabaseAuthManagedPassword', 'ADMINISTRADOR', TRUE),
    ('Ronivaldo Silva', 'silva.ronivaldo@escola.pr.gov.br', '$2b$10$SupabaseAuthManagedPassword', 'ADMINISTRADOR', TRUE)
ON CONFLICT (email) 
DO UPDATE SET funcao = 'ADMINISTRADOR', ativo = TRUE;
