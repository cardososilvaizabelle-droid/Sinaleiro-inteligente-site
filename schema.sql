-- 2. Criar ENUMs para padronização (com verificação para não duplicar)
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
-- Criar enum para funções de acesso no sistema
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'funcao_usuario_enum') THEN
        CREATE TYPE funcao_usuario_enum AS ENUM ('VISITANTE', 'ADMINISTRADOR');
    END IF;
END $$;

-- Tabela de Contas de Acesso ao Painel/Site
CREATE TABLE contas_acesso (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome VARCHAR(150) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    senha_hash VARCHAR(255) NOT NULL, -- Senha criptografada (ex: bcrypt/argon2)
    funcao funcao_usuario_enum NOT NULL DEFAULT 'VISITANTE',
    ativo BOOLEAN DEFAULT TRUE,
    criado_em TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Inserir um Administrador Padrão de Exemplo
INSERT INTO contas_acesso (nome, email, senha_hash, funcao)
VALUES ('Administrador Master', 'admin@smarttraffic.ai', '$2b$10$ExemploDeHashDeSenhaSegura', 'ADMINISTRADOR');
