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