/*
 * Integração do SmartTraffic AI com Supabase.
 * Carregue este arquivo depois do script principal do index.html:
 * <script src="supabase-integration.js"></script>
 *
 * Usa somente URL e chave publicável (seguras para o navegador, com RLS).
 * Não coloque chaves sb_secret/service_role neste arquivo.
 */
(() => {
    'use strict';

    const SUPABASE_URL = 'https://kvbrrczjyoawojhjewbs.supabase.co';
    // Chave publishable fornecida pelo proprietário do projeto.
    const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_RQx-5MMwnVUVZazi4H0ATw_lDNJgSB_';
    const CDN_URL = 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2';

    let client;
    let feedbackRows = [];
    let selectedCategory = 'TODOS';

    function loadSupabaseLibrary() {
        return new Promise((resolve, reject) => {
            if (window.supabase?.createClient) return resolve();
            const script = document.createElement('script');
            script.src = CDN_URL;
            script.async = true;
            script.onload = () => window.supabase?.createClient
                ? resolve()
                : reject(new Error('A biblioteca Supabase não carregou.'));
            script.onerror = () => reject(new Error('Não foi possível carregar a biblioteca Supabase.'));
            document.head.appendChild(script);
        });
    }

    function showMessage(message, type = 'info') {
        if (typeof window.showToast === 'function') {
            window.showToast(message, type);
        } else {
            window.alert(message);
        }
    }

    function renderFeedback() {
        const container = document.getElementById('feedback-list-container');
        if (!container) return;

        const rows = selectedCategory === 'TODOS'
            ? feedbackRows
            : feedbackRows.filter(row => row.categoria === selectedCategory);

        container.replaceChildren();
        if (!rows.length) {
            const empty = document.createElement('p');
            empty.className = 'text-sm text-slate-400 p-4';
            empty.textContent = 'Ainda não há avaliações para esta categoria.';
            container.appendChild(empty);
            return;
        }

        rows.forEach(row => {
            const card = document.createElement('article');
            card.className = 'bg-slate-900 border border-slate-800 rounded-2xl p-4 space-y-2';

            const heading = document.createElement('div');
            heading.className = 'flex flex-wrap items-center justify-between gap-2';
            const name = document.createElement('strong');
            name.className = 'text-white';
            name.textContent = row.nome;
            const rating = document.createElement('span');
            rating.className = 'text-amber-400';
            rating.textContent = `${'★'.repeat(Number(row.nota))}${'☆'.repeat(5 - Number(row.nota))}`;
            heading.append(name, rating);

            const details = document.createElement('p');
            details.className = 'text-xs text-purple-300';
            details.textContent = `${row.categoria} • ${row.localizacao}`;
            const comment = document.createElement('p');
            comment.className = 'text-sm text-slate-300 whitespace-pre-wrap';
            comment.textContent = row.comentario;
            card.append(heading, details, comment);
            container.appendChild(card);
        });
    }

    async function refreshFeedback() {
        const { data, error } = await client
            .from('feedbacks')
            .select('id,nome,localizacao,categoria,nota,comentario,created_at')
            .order('created_at', { ascending: false })
            .limit(100);
        if (error) throw error;
        feedbackRows = data || [];
        renderFeedback();
    }

    async function saveFeedback(event) {
        event.preventDefault();
        const form = event.currentTarget;
        const payload = {
            nome: document.getElementById('fb-nome').value.trim(),
            localizacao: document.getElementById('fb-local').value.trim(),
            categoria: document.getElementById('fb-categoria').value,
            nota: Number(window.currentRating || 5),
            comentario: document.getElementById('fb-comentario').value.trim()
        };

        const button = form.querySelector('button[type="submit"]');
        if (button) button.disabled = true;
        try {
            const { error } = await client.from('feedbacks').insert(payload);
            if (error) throw error;
            form.reset();
            if (typeof window.setRating === 'function') window.setRating(5);
            await refreshFeedback();
            showMessage('Avaliação enviada com sucesso.', 'success');
        } catch (error) {
            console.error('Erro ao enviar feedback ao Supabase:', error);
            showMessage('Não foi possível enviar a avaliação. Verifique se o schema.sql foi executado no Supabase.', 'warning');
        } finally {
            if (button) button.disabled = false;
        }
    }

    async function saveContact(event) {
        event.preventDefault();
        const form = event.currentTarget;
        const inputs = form.querySelectorAll('input');
        const payload = {
            nome: inputs[0]?.value.trim(),
            email: inputs[1]?.value.trim(),
            orgao: inputs[2]?.value.trim() || null,
            assunto: form.querySelector('select')?.value.trim(),
            mensagem: form.querySelector('textarea')?.value.trim()
        };
        const button = form.querySelector('button[type="submit"]');
        if (button) button.disabled = true;
        try {
            const { error } = await client.from('contatos').insert(payload);
            if (error) throw error;
            form.reset();
            showMessage('Mensagem enviada para a central.', 'success');
        } catch (error) {
            console.error('Erro ao enviar contato ao Supabase:', error);
            showMessage('Não foi possível enviar a mensagem. Verifique se o schema.sql foi executado no Supabase.', 'warning');
        } finally {
            if (button) button.disabled = false;
        }
    }

    function installHandlers() {
        const feedbackForm = document.getElementById('form-feedback');
        if (feedbackForm) feedbackForm.onsubmit = saveFeedback;

        const contactForm = document.getElementById('form-contato');
        if (contactForm) contactForm.onsubmit = saveContact;

        // Não enviar CPF, nascimento ou imagem biométrica anonimamente ao banco.
        const personForm = document.getElementById('form-cadastro-pf');
        if (personForm) {
            personForm.onsubmit = event => {
                event.preventDefault();
                showMessage('O cadastro com CPF e biometria está desativado até configurar autenticação e um backend seguro.', 'warning');
            };
        }

        window.filtrarFeedbackCat = category => {
            selectedCategory = category;
            renderFeedback();
        };
    }

    async function start() {
        try {
            await loadSupabaseLibrary();
            client = window.supabase.createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY);
            installHandlers();
            await refreshFeedback();
        } catch (error) {
            console.error('Não foi possível iniciar a integração Supabase:', error);
            showMessage('Supabase indisponível. Confirme conexão e configuração do projeto.', 'warning');
        }
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', start, { once: true });
    } else {
        start();
    }
})();
