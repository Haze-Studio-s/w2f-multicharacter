/**
 * W2F Multicharacter — NUI Controller
 * Padrão Oficial: Lation Modern UI (Emerald Edition)
 */

const dom = {
    app: document.getElementById('app'),
    topBar: document.getElementById('topBar'),
    brandTitle: document.getElementById('brandTitle'),
    brandSubtitle: document.getElementById('brandSubtitle'),
    slotsNav: document.getElementById('slotsNav'),
    hint: document.getElementById('hint'),

    // Dossier Panel (Ficha do Cidadão)
    dossierPanel: document.getElementById('dossierPanel'),
    dossierAvatar: document.getElementById('dossierAvatar'),
    dossierSlot: document.getElementById('dossierSlot'),
    dossierCid: document.getElementById('dossierCid'),
    dossierName: document.getElementById('dossierName'),
    dossierJob: document.getElementById('dossierJob'),
    dossierCash: document.getElementById('dossierCash'),
    dossierBank: document.getElementById('dossierBank'),
    dossierPhone: document.getElementById('dossierPhone'),
    dossierAge: document.getElementById('dossierAge'),
    dossierPlaytime: document.getElementById('dossierPlaytime'),
    dossierLocation: document.getElementById('dossierLocation'),

    // Actions
    spawnBtn: document.getElementById('spawnBtn'),
    deleteBtn: document.getElementById('deleteBtn'),
    closeDetailsBtn: document.getElementById('closeDetailsBtn'),

    // Modal de Confirmação de Deleção
    confirmDelete: document.getElementById('confirmDelete'),
    confirmName: document.getElementById('confirmName'),
    confirmInput: document.getElementById('confirmInput'),
    confirmDeleteBtn: document.getElementById('confirmDeleteBtn'),
    confirmCancelBtn: document.getElementById('confirmCancelBtn'),

    // Modal de Criação
    createPanel: document.getElementById('createPanel'),
    createForm: document.getElementById('createForm'),
    createSlotLabel: document.getElementById('createSlotLabel'),
    createNationality: document.getElementById('createNationality'),
    createBirthdate: document.getElementById('createBirthdate'),
    createError: document.getElementById('createError'),
    createCancelBtn: document.getElementById('createCancelBtn'),
    createSubmitBtn: document.getElementById('createSubmitBtn'),

    // Spawn Picker Panel
    skySpawnPanel: document.getElementById('skySpawnPanel'),
    skySpawnGrid: document.getElementById('skySpawnGrid'),
    spawnTitle: document.getElementById('spawnTitle'),

    // Toasts
    toastsContainer: document.getElementById('w2fToasts'),
};

const resourceName = typeof GetParentResourceName === 'function'
    ? GetParentResourceName()
    : 'w2f-multicharacter';

const state = {
    selectionActive: false,
    skyMode: false,
    spawnBusy: false,
    selectedSlot: null,
    selectedCharacterName: null,
    characters: {},
    maxSlots: 3,
    createOpen: false,
    createSlot: null,
    createBusy: false,
    createConfig: null,
    confirmOpen: false,
    confirmBusy: false,
    lastFocus: null,
};

const TIMEOUTS = {
    spawn: 20000,
    create: 12000,
    confirm: 20000,
};

const timers = {};

function clearTimer(key) {
    if (timers[key]) {
        clearTimeout(timers[key]);
        timers[key] = null;
    }
}

function armTimer(key, ms, onTrip) {
    clearTimer(key);
    timers[key] = setTimeout(() => {
        timers[key] = null;
        onTrip();
    }, ms);
}

function post(endpoint, data = {}) {
    return fetch(`https://${resourceName}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).catch((err) => {
        console.warn(`[w2f-mc] post(${endpoint}) failed:`, err);
    });
}

function setVisible(el, visible) {
    if (!el) return;
    el.classList.toggle('hidden', !visible);
    el.classList.toggle('visible', visible);
    if (!visible) {
        el.setAttribute('aria-hidden', 'true');
    } else {
        el.removeAttribute('aria-hidden');
    }
}

function showApp() {
    dom.app.classList.remove('hidden');
    dom.app.classList.add('visible');
}

function hideApp() {
    dom.app.classList.add('hidden');
    dom.app.classList.remove('visible');
}

function pad2(n) {
    n = Number(n);
    if (!isFinite(n) || n < 0) return '00';
    return n < 10 ? `0${n}` : String(n);
}

function getInitials(name) {
    if (!name || name === '—') return 'VP';
    const parts = name.trim().split(/\s+/);
    if (parts.length === 1) return parts[0].substring(0, 2).toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

function formatMoney(val) {
    if (typeof val === 'number') {
        return 'R$ ' + val.toLocaleString('pt-BR');
    }
    if (typeof val === 'string') {
        if (val.startsWith('$')) {
            val = val.substring(1);
        }
        const num = parseFloat(val.replace(/,/g, ''));
        if (!isNaN(num)) {
            return 'R$ ' + num.toLocaleString('pt-BR');
        }
    }
    return val || 'R$ 0';
}

/* ============================================================
 * Toast Notification Surface (Lation Emerald)
 * ============================================================ */
function showToast(level, message, durationMs = 4200) {
    if (!message) return;
    const node = document.createElement('div');
    node.className = `w2f-toast w2f-toast-${level || 'info'}`;
    node.textContent = String(message);
    dom.toastsContainer.appendChild(node);
    requestAnimationFrame(() => node.classList.add('shown'));

    const ttl = Math.max(1500, Number(durationMs) || 4200);
    setTimeout(() => {
        node.classList.remove('shown');
        node.addEventListener('transitionend', () => node.remove(), { once: true });
        setTimeout(() => node.remove(), 800);
    }, ttl);
}

/* ============================================================
 * Navegador de Slots (Top Bar)
 * ============================================================ */
function renderSlotsNav() {
    dom.slotsNav.innerHTML = '';
    const max = state.maxSlots || 3;

    for (let slot = 1; slot <= max; slot++) {
        const char = state.characters[slot];
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'slot-pill';
        btn.dataset.slot = slot;

        if (slot === state.selectedSlot) {
            btn.classList.add('active');
        }

        if (char && !char.isEmpty && char.name) {
            btn.innerHTML = `
                <span class="slot-pill-num">${pad2(slot)}</span>
                <span class="slot-pill-name">${char.name}</span>
            `;
            btn.addEventListener('click', () => {
                if (state.spawnBusy || state.createBusy) return;
                post('selectSlot', { slot: slot });
            });
        } else {
            btn.classList.add('empty');
            btn.innerHTML = `
                <span class="slot-pill-num">${pad2(slot)}</span>
                <span class="slot-pill-name">+ Criar Cidadão</span>
            `;
            btn.addEventListener('click', () => {
                if (state.spawnBusy || state.createBusy) return;
                post('selectEmptySlot', { slot: slot });
            });
        }

        dom.slotsNav.appendChild(btn);
    }
}

/* ============================================================
 * Dossier Panel (Ficha do Cidadão)
 * ============================================================ */
function applyDossierData(data) {
    if (!data) return;
    const name = data.name || 'Desconhecido';
    state.selectedCharacterName = name;

    dom.dossierAvatar.textContent = getInitials(name);
    dom.dossierSlot.textContent = `SLOT ${data.slot ? pad2(data.slot) : '01'}`;
    dom.dossierCid.textContent = data.citizenid ? `CID: ${data.citizenid}` : 'CID: —';
    dom.dossierName.textContent = name;
    dom.dossierJob.textContent = data.job || 'Desempregado';

    dom.dossierCash.textContent = formatMoney(data.cash);
    dom.dossierBank.textContent = formatMoney(data.bank);
    dom.dossierPhone.textContent = data.phone || '—';
    dom.dossierAge.textContent = data.age !== null && data.age !== undefined ? `${data.age} anos` : '—';
    dom.dossierPlaytime.textContent = data.playtime || '0h 0m';
    dom.dossierLocation.textContent = data.lastLocation || 'Los Santos';
}

function showDossier(data) {
    if (state.createOpen) return;
    applyDossierData(data);
    setVisible(dom.dossierPanel, true);
    setVisible(dom.hint, false);
    renderSlotsNav();
}

function hideDossier() {
    setVisible(dom.dossierPanel, false);
    if (!state.skyMode && state.selectionActive) {
        setVisible(dom.hint, true);
    }
    renderSlotsNav();
}

/* ============================================================
 * Modal de Confirmação de Exclusão
 * ============================================================ */
function openConfirmDelete() {
    if (!state.selectedSlot || state.confirmOpen) return;
    state.confirmOpen = true;
    state.lastFocus = document.activeElement;
    dom.confirmInput.value = '';
    dom.confirmDeleteBtn.disabled = true;
    dom.confirmName.textContent = state.selectedCharacterName || 'este personagem';
    setVisible(dom.confirmDelete, true);
    setTimeout(() => dom.confirmInput.focus(), 50);
}

function closeConfirmDelete() {
    state.confirmOpen = false;
    state.confirmBusy = false;
    clearTimer('confirm');
    setVisible(dom.confirmDelete, false);
    dom.confirmInput.value = '';
    dom.confirmDeleteBtn.disabled = true;
    if (state.lastFocus && document.contains(state.lastFocus)) {
        try { state.lastFocus.focus(); } catch (_) {}
    }
}

/* ============================================================
 * Modal de Criação de Cidadão
 * ============================================================ */
function populateNationalities(cfg) {
    if (!dom.createNationality || !cfg) return;
    dom.createNationality.innerHTML = '';
    const list = cfg.nationalities || [
        'Brasileiro', 'Americano', 'Canadense', 'Espanhol', 'Italiano',
        'Francês', 'Alemão', 'Inglês', 'Japonês', 'Outro'
    ];
    list.forEach((nat) => {
        const opt = document.createElement('option');
        opt.value = nat;
        opt.textContent = nat;
        if (nat === (cfg.defaultNationality || 'Brasileiro')) {
            opt.selected = true;
        }
        dom.createNationality.appendChild(opt);
    });
}

function showCreateError(msg) {
    if (!dom.createError) return;
    if (!msg) {
        dom.createError.textContent = '';
        dom.createError.classList.add('hidden');
        return;
    }
    dom.createError.textContent = msg;
    dom.createError.classList.remove('hidden');
}

function openCreatePanel(data) {
    state.createOpen = true;
    state.createBusy = false;
    state.lastFocus = document.activeElement;
    document.body.classList.add('create-mode');
    closeConfirmDelete();

    state.createSlot = data?.slot ?? null;
    if (data?.config) state.createConfig = data.config;
    if (dom.createSlotLabel && state.createSlot != null) {
        dom.createSlotLabel.textContent = `SLOT ${pad2(state.createSlot)}`;
    }

    populateNationalities(state.createConfig || {});
    if (dom.createBirthdate && state.createConfig) {
        dom.createBirthdate.min = state.createConfig.birthdateMin || '1940-01-01';
        dom.createBirthdate.max = state.createConfig.birthdateMax || '2006-12-31';
        dom.createBirthdate.value = state.createConfig.birthdateMax || '2006-12-31';
    }

    showCreateError('');
    if (dom.createForm) dom.createForm.reset();
    populateNationalities(state.createConfig || {});

    setVisible(dom.hint, false);
    setVisible(dom.dossierPanel, false);
    setVisible(dom.createPanel, true);

    setTimeout(() => {
        document.getElementById('createFirst')?.focus();
    }, 50);
}

function closeCreatePanel(restoreHints) {
    state.createOpen = false;
    state.createSlot = null;
    state.createBusy = false;
    clearTimer('create');
    document.body.classList.remove('create-mode');

    if (dom.createPanel) {
        setVisible(dom.createPanel, false);
    }
    showCreateError('');
    if (restoreHints !== false && state.selectionActive && !state.skyMode) {
        setVisible(dom.hint, true);
    }
    if (state.lastFocus && document.contains(state.lastFocus)) {
        try { state.lastFocus.focus(); } catch (_) {}
    }
}

/* ============================================================
 * Spawn Picker (Zonas de Desembarque)
 * ============================================================ */
function escapeHtml(value) {
    return String(value ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

function buildSkyCards(spawns) {
    dom.skySpawnGrid.innerHTML = '';
    (spawns || []).forEach((spawn) => {
        const card = document.createElement('button');
        card.type = 'button';
        const isApartment = spawn.kind === 'apartment';
        card.className = `sky-card${isApartment ? ' sky-card-apartment' : ''}`;
        card.dataset.id = spawn.id;

        const tag = isApartment
            ? '<span class="sky-card-tag">APARTAMENTO</span>'
            : '';

        card.innerHTML = `
            ${tag}
            <span class="sky-card-label">${escapeHtml(spawn.label)}</span>
            <span class="sky-card-desc">${escapeHtml(spawn.description || '')}</span>
        `;

        card.addEventListener('click', () => {
            if (state.spawnBusy) return;
            state.spawnBusy = true;
            card.classList.add('selected');
            armTimer('spawn', TIMEOUTS.spawn, () => {
                showToast('error', 'Tempo limite de carregamento atingido. Tente novamente.');
                spawnFailed({ error: 'timeout' });
            });
            post('chooseSkySpawn', { id: spawn.id });
        });

        card.addEventListener('mouseenter', () => {
            card.classList.add('hover');
            post('previewSkySpawn', { id: spawn.id });
        });

        card.addEventListener('mouseleave', () => {
            card.classList.remove('hover');
            post('previewSkySpawn', { id: null });
        });

        dom.skySpawnGrid.appendChild(card);
    });
}

function showSkySpawnOptions(data) {
    state.skyMode = true;
    state.spawnBusy = false;
    clearTimer('spawn');

    setVisible(dom.hint, false);
    setVisible(dom.dossierPanel, false);

    const spawns = (data && (data.spawns || data.entries)) || data || [];
    const isNew = !!(data && data.isNewCharacter);

    if (dom.spawnTitle) {
        dom.spawnTitle.textContent = (data && data.title) || (isNew ? 'PRIMEIRO DESEMBARQUE' : 'ZONA DE DESEMBARQUE');
    }

    buildSkyCards(spawns);
    setVisible(dom.skySpawnPanel, true);
    dom.skySpawnGrid.scrollTop = 0;
}

function hideSkySpawnOptions() {
    state.skyMode = false;
    clearTimer('spawn');
    post('previewSkySpawn', { id: null });
    setVisible(dom.skySpawnPanel, false);
}

function beginSpawnSequence() {
    if (state.spawnBusy) return;
    state.spawnBusy = true;
    hideDossier();
    armTimer('spawn', TIMEOUTS.spawn, () => {
        showToast('error', 'Tempo limite de carregamento esgotado.');
        spawnFailed({ error: 'timeout' });
    });
}

function resetSelectionUI() {
    state.selectionActive = false;
    state.skyMode = false;
    state.spawnBusy = false;
    state.selectedSlot = null;
    state.selectedCharacterName = null;
    state.confirmBusy = false;
    state.createBusy = false;
    Object.keys(timers).forEach(clearTimer);
    hideDossier();
    hideSkySpawnOptions();
    closeCreatePanel();
    closeConfirmDelete();
    hideApp();
}

/* ============================================================
 * Humanização de Erros em pt-BR
 * ============================================================ */
function humanizeError(code, fallback) {
    if (!code) return fallback || 'Ocorreu um erro inesperado.';
    const map = {
        rate_limited: 'Ação realizada muito rapidamente. Aguarde um instante.',
        denied_ownership: 'Este personagem não pertence à sua conta.',
        missing_slot: 'Nenhum slot disponível para criação.',
        slot_in_use: 'Este slot já está ocupado. Escolha outro.',
        name_taken: 'Este nome já está em uso por outro cidadão.',
        invalid_name: 'Nome inválido. Use apenas letras sem símbolos ou números.',
        invalid_birthdate: 'Por favor, selecione uma data de nascimento válida.',
        invalid_payload: 'Dados do formulário incorretos. Revise os campos.',
        load_failed: 'Falha ao carregar o personagem selecionado.',
        timeout: 'Tempo limite esgotado ao aguardar o servidor.',
        apartment_unavailable: 'Apartamento inicial indisponível no momento.',
        appearance_failed: 'Não foi possível salvar a personalização de roupas.',
    };
    return map[String(code)] || fallback || String(code);
}

function spawnFailed(data) {
    state.spawnBusy = false;
    state.skyMode = false;
    clearTimer('spawn');
    setVisible(dom.skySpawnPanel, false);
    setVisible(dom.hint, true);
    showApp();
    const err = data?.error || data?.message || 'Falha ao entrar na cidade.';
    showToast('error', humanizeError(err, 'Falha ao entrar na cidade.'), 5500);
}

function createCharacterResult(data) {
    state.createBusy = false;
    clearTimer('create');
    if (data?.ok) {
        showCreateError('');
        return;
    }
    const err = data?.error || data?.message || 'Erro ao criar cidadão.';
    showCreateError(humanizeError(err, 'Não foi possível registrar o personagem.'));
}

/* ============================================================
 * Message Dispatcher (Lua -> NUI)
 * ============================================================ */
const handlers = {
    showSelection: (data) => {
        state.selectionActive = true;
        if (data?.createConfig) state.createConfig = data.createConfig;
        if (data?.maxSlots) state.maxSlots = data.maxSlots;
        if (data?.brandTitle && dom.brandTitle) dom.brandTitle.textContent = data.brandTitle;
        if (data?.brandSubtitle && dom.brandSubtitle) dom.brandSubtitle.textContent = data.brandSubtitle;
        showApp();
        renderSlotsNav();
        setVisible(dom.hint, data?.showControlHints !== false);
    },

    setCharactersList: (data) => {
        const raw = data?.characters;
        const map = {};
        if (Array.isArray(raw)) {
            raw.forEach((item, idx) => {
                if (item) {
                    const slotNum = Number(item.slot) || (idx + 1);
                    map[slotNum] = item;
                }
            });
        } else if (raw && typeof raw === 'object') {
            Object.entries(raw).forEach(([k, v]) => {
                if (v) {
                    const slotNum = Number(v.slot) || Number(k);
                    map[slotNum] = v;
                }
            });
        }
        state.characters = map;
        state.maxSlots = data?.maxSlots || state.maxSlots || 3;
        renderSlotsNav();
    },

    openCreateCharacter: (data) => {
        showApp();
        openCreatePanel(data);
    },

    closeCreateCharacter: () => closeCreatePanel(false),

    showCharacterDetails: (data) => {
        showApp();
        state.selectedSlot = data?.slot ?? state.selectedSlot;
        if (data?.slot && !state.characters[data.slot]) {
            state.characters[data.slot] = data;
        }
        showDossier(data);
    },

    hideCharacterDetails: () => hideDossier(),

    showEmptySlotDetails: (data) => {
        showApp();
        state.selectedSlot = data?.slot ?? state.selectedSlot;
        hideDossier();
        renderSlotsNav();
    },

    openConfirmDeleteModal: () => {
        if (state.selectedSlot !== null) {
            openConfirmDelete();
        }
    },

    hideSelectionHints: () => setVisible(dom.hint, false),

    updateHologram: (payload) => {
        // Compatibilidade com eventos do hud.lua
        if (!payload || payload.visible === false) {
            hideDossier();
            return;
        }
        if (payload.data) {
            applyDossierData(payload.data);
            state.selectedSlot = payload.data.slot ?? state.selectedSlot;
            setVisible(dom.dossierPanel, true);
            renderSlotsNav();
        }
    },

    showSkySpawnOptions: (data) => {
        showApp();
        showSkySpawnOptions(data);
    },

    hideSkySpawnOptions: () => hideSkySpawnOptions(),

    updateHoveredPed: (data) => {
        document.body.dataset.hoveredSlot = data?.slot ?? '';
    },

    updateSelectedPed: (data) => {
        state.selectedSlot = data?.slot ?? null;
        document.body.dataset.selectedSlot = state.selectedSlot ?? '';

        if (state.selectedSlot === null) {
            hideDossier();
            closeConfirmDelete();
            state.selectedCharacterName = null;
        }
        renderSlotsNav();
    },

    beginSpawnSequence: () => beginSpawnSequence(),

    resetSelectionUI: () => resetSelectionUI(),

    setVisible: (data) => {
        if (data && data.visible === false) {
            hideApp();
            return;
        }
        if (data && data.visible === true) {
            showApp();
        }
    },

    hide: () => hideApp(),

    spawnFailed: (data) => spawnFailed(data),

    createCharacterResult: (data) => createCharacterResult(data),

    toast: (data) => {
        if (!data) return;
        showToast(data.level || 'info', data.message, data.durationMs);
    },

    characterDeleted: () => {
        state.confirmBusy = false;
        clearTimer('confirm');
        closeConfirmDelete();
        if (state.selectedSlot) {
            delete state.characters[state.selectedSlot];
        }
        hideDossier();
        renderSlotsNav();
        showToast('info', 'Registro civil excluído com sucesso.');
    },

    characterDeleteFailed: (data) => {
        state.confirmBusy = false;
        clearTimer('confirm');
        dom.confirmDeleteBtn.disabled = false;
        showToast('error', data?.error || 'Falha ao excluir personagem.');
    },

    /* ---- Prelúdio: Cartão do Personagem ---- */
    showPreludeCard: (data) => {
        const overlay = document.getElementById('preludeOverlay');
        const card    = document.getElementById('preludeCard');
        if (!overlay || !card) return;

        overlay.classList.remove('hidden');
        overlay.classList.add('active');

        const nameEl = document.getElementById('preludeName');
        const ageEl  = document.getElementById('preludeAge');
        const natEl  = document.getElementById('preludeNationality');

        if (nameEl) nameEl.textContent = data?.name || '—';
        if (ageEl)  ageEl.textContent  = data?.age  ? `${data.age} anos` : '';
        if (natEl)  natEl.textContent  = data?.nationality || '';

        card.classList.remove('hidden');
        requestAnimationFrame(() => card.classList.add('slam-in'));
    },

    showChapterCard: (data) => {
        const preludeCard = document.getElementById('preludeCard');
        const chapterCard = document.getElementById('chapterCard');
        if (!chapterCard) return;

        if (preludeCard) preludeCard.classList.add('fade-out');

        const titleEl = document.getElementById('chapterTitle');
        const placeEl = document.getElementById('chapterPlace');
        const timeEl  = document.getElementById('chapterTime');

        if (titleEl) titleEl.textContent = data?.title || 'Capítulo Final';
        if (placeEl) placeEl.textContent = data?.place || 'Los Santos';
        if (timeEl)  timeEl.textContent  = data?.time  || '';

        chapterCard.classList.remove('hidden');
        requestAnimationFrame(() => chapterCard.classList.add('diagonal-in'));

        setTimeout(() => {
            chapterCard.classList.add('diagonal-out');
        }, (data?.durationMs || 2800) - 400);
    },

    hidePrelude: () => {
        const overlay = document.getElementById('preludeOverlay');
        if (overlay) {
            overlay.classList.add('fade-out-fast');
            setTimeout(() => {
                overlay.classList.add('hidden');
                overlay.classList.remove('active', 'fade-out-fast');
                const card    = document.getElementById('preludeCard');
                const chapter = document.getElementById('chapterCard');
                if (card)    { card.classList.remove('slam-in', 'fade-out', 'hidden'); card.classList.add('hidden'); }
                if (chapter) { chapter.classList.remove('diagonal-in', 'diagonal-out', 'hidden'); chapter.classList.add('hidden'); }
            }, 400);
        }
    },

    /* ---- Chegada: Legendas de história ---- */
    showArrivalSubtitle: (data) => {
        const el   = document.getElementById('arrivalSubtitle');
        const text = document.getElementById('arrivalSubtitleText');
        if (!el || !text) return;

        text.textContent = data?.text || '';
        el.classList.remove('hidden', 'subtitle-hide');
        el.classList.add('subtitle-show');

        const ms = data?.durationMs || 3000;
        setTimeout(() => {
            el.classList.add('subtitle-hide');
            setTimeout(() => {
                el.classList.add('hidden');
                el.classList.remove('subtitle-show', 'subtitle-hide');
            }, 600);
        }, ms - 600);
    },

    hideArrivalSubtitle: () => {
        const el = document.getElementById('arrivalSubtitle');
        if (el) {
            el.classList.add('hidden');
            el.classList.remove('subtitle-show', 'subtitle-hide');
        }
    },
};

window.addEventListener('message', (event) => {
    const { action, data } = event.data || {};
    const handler = handlers[action];
    if (!handler) return;
    try {
        handler(data);
    } catch (err) {
        console.warn(`[w2f-mc] handler ${action} threw:`, err);
    }
});

/* ============================================================
 * Event Listeners & Wiring
 * ============================================================ */
dom.spawnBtn.addEventListener('click', () => {
    if (state.spawnBusy || state.selectedSlot === null) return;
    beginSpawnSequence();
    post('pressSpawn');
});

dom.closeDetailsBtn.addEventListener('click', () => {
    if (state.spawnBusy) return;
    post('cancelDetails');
});

dom.deleteBtn?.addEventListener('click', () => {
    if (state.spawnBusy || state.selectedSlot === null) return;
    openConfirmDelete();
});

dom.confirmCancelBtn?.addEventListener('click', () => {
    if (state.confirmBusy) return;
    closeConfirmDelete();
});

dom.confirmInput?.addEventListener('input', () => {
    const val = dom.confirmInput.value.trim().toUpperCase();
    dom.confirmDeleteBtn.disabled = (val !== 'DELETAR' && val !== 'DELETE');
});

dom.confirmDeleteBtn?.addEventListener('click', () => {
    if (state.confirmBusy) return;
    const val = dom.confirmInput.value.trim().toUpperCase();
    if (val !== 'DELETAR' && val !== 'DELETE') return;

    state.confirmBusy = true;
    dom.confirmDeleteBtn.disabled = true;
    armTimer('confirm', TIMEOUTS.confirm, () => {
        state.confirmBusy = false;
        dom.confirmDeleteBtn.disabled = false;
        showToast('error', 'Tempo limite atingido. Tente novamente.');
    });
    post('deleteCharacter');
});

dom.createCancelBtn?.addEventListener('click', () => {
    if (state.createBusy) return;
    post('cancelCreateCharacter');
    closeCreatePanel();
});

dom.createForm?.addEventListener('submit', (e) => {
    e.preventDefault();
    if (state.createBusy || state.createSlot == null) return;
    state.createBusy = true;
    showCreateError('');

    const firstname = document.getElementById('createFirst')?.value?.trim();
    const lastname = document.getElementById('createLast')?.value?.trim();
    const nationality = dom.createNationality?.value;
    const gender = document.querySelector('input[name="gender"]:checked')?.value || '0';
    const birthdate = dom.createBirthdate?.value;

    if (!firstname || !lastname || !birthdate) {
        state.createBusy = false;
        showCreateError('Por favor, preencha todos os campos obrigatórios.');
        return;
    }

    const nameRegex = /^[A-Za-zÀ-ÖØ-öø-ÿ\s'-]{2,24}$/;
    if (!nameRegex.test(firstname) || !nameRegex.test(lastname)) {
        state.createBusy = false;
        showCreateError('Nomes devem conter apenas letras (2 a 24 caracteres), sem símbolos ou números.');
        return;
    }

    armTimer('create', TIMEOUTS.create, () => {
        state.createBusy = false;
        showCreateError('Tempo limite esgotado. Tente novamente.');
    });

    const arrivalId = document.querySelector('input[name="arrivalId"]:checked')?.value || 'none';

    post('submitCreateCharacter', {
        slot: state.createSlot,
        firstname,
        lastname,
        nationality,
        gender,
        birthdate,
        arrivalId,
    });
});

/* ============================================================
 * World Click Forwarder (NUI CEF -> Lua Raycast)
 * ============================================================ */
window.addEventListener('click', (e) => {
    if (!state.selectionActive || state.createOpen || state.confirmOpen || state.spawnBusy) return;

    if (e.target.closest('button') ||
        e.target.closest('input') ||
        e.target.closest('select') ||
        e.target.closest('.slot-pill') ||
        e.target.closest('.lation-card') ||
        e.target.closest('.modal-card') ||
        e.target.closest('.hint-bar')) {
        return;
    }

    post('clickWorld', {
        x: e.clientX,
        y: e.clientY
    });
});

/* ============================================================
 * Keyboard Management
 * ============================================================ */
document.addEventListener('keydown', (e) => {
    if (state.skyMode || state.spawnBusy) {
        if (state.skyMode && e.key === 'Escape' && !state.spawnBusy) {
            post('cancelSkySpawn');
        }
        return;
    }
    if (state.confirmOpen) {
        if (e.key === 'Escape' && !state.confirmBusy) {
            closeConfirmDelete();
        } else if (e.key === 'Enter' && !state.confirmBusy && !dom.confirmDeleteBtn.disabled) {
            dom.confirmDeleteBtn.click();
        }
        return;
    }
    if (state.createOpen) {
        if (e.key === 'Escape' && !state.createBusy) {
            post('cancelCreateCharacter');
            closeCreatePanel();
        }
        return;
    }

    // Atalhos numéricos (1, 2, 3, 4, 5) para selecionar slots diretamente
    if (['1', '2', '3', '4', '5'].includes(e.key)) {
        const slot = Number(e.key);
        if (slot <= (state.maxSlots || 3)) {
            const char = state.characters[slot];
            if (char && !char.isEmpty && char.name) {
                post('selectSlot', { slot: slot });
            } else {
                post('selectEmptySlot', { slot: slot });
            }
            return;
        }
    }

    // Navegação por setas ou A/D para alternar entre slots
    if (e.key === 'ArrowRight' || e.key === 'd' || e.key === 'D') {
        post('navigateSlot', { direction: 1 });
        return;
    }

    if (e.key === 'ArrowLeft' || e.key === 'a' || e.key === 'A') {
        post('navigateSlot', { direction: -1 });
        return;
    }

    // W ou Seta Cima -> Confirmar Entrada ou Criar
    if (e.key === 'ArrowUp' || e.key === 'w' || e.key === 'W') {
        post('confirmSlot');
        return;
    }

    // S ou Seta Baixo -> Cancelar / Voltar para Overview geral
    if (e.key === 'ArrowDown' || e.key === 's' || e.key === 'S') {
        post('cancelDetails');
        return;
    }

    // Ações de confirmação, cancelamento e exclusão
    if (e.key === 'Escape' && state.selectedSlot !== null) {
        post('cancelDetails');
    } else if (e.key === 'Enter') {
        post('confirmSlot');
    } else if ((e.key === 'Delete' || e.key === 'Del') && state.selectedSlot !== null) {
        openConfirmDelete();
    }
});

function notifyNuiReady() {
    post('nuiReady', {});
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', notifyNuiReady);
} else {
    notifyNuiReady();
}
