const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'rsg-cooking';
const $ = (id) => document.getElementById(id);

const state = { recipes: [], imagePath: '', maxBatch: 10, L: {}, category: null, selected: null, qty: 1, cooking: null };

function post(name, data = {}) {
    return fetch(`https://${RES}/${name}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' }, body: JSON.stringify(data),
    }).then((r) => r.json()).catch(() => ({}));
}

const t = (key, ...args) => {
    let s = state.L[key] || key;
    args.forEach((a) => { s = s.replace('%s', a); });
    return s;
};
const img = (file) => (file ? state.imagePath + file : '');
const fmtTime = (ms) => {
    const s = Math.ceil(ms / 1000);
    return s >= 60 ? t('minutes_seconds', Math.floor(s / 60), s % 60) : t('seconds', s);
};

/* ---------- rendering ---------- */
function renderTabs() {
    const cats = [...new Set(state.recipes.map((r) => r.category))].sort();
    if (!cats.includes(state.category)) state.category = cats[0];
    $('tabs').innerHTML = '';
    cats.forEach((c) => {
        const b = document.createElement('div');
        b.className = 'tab' + (c === state.category ? ' active' : '');
        b.textContent = c;
        b.onclick = () => { if (state.cooking) return; state.category = c; renderTabs(); renderRecipes(); };
        $('tabs').appendChild(b);
    });
}

function renderRecipes() {
    const box = $('recipes');
    box.innerHTML = '';
    state.recipes.filter((r) => r.category === state.category).forEach((r) => {
        const c = document.createElement('div');
        c.className = 'card' + (r.locked ? ' locked' : '') + (state.selected && state.selected.id === r.id ? ' selected' : '');
        const pill = r.locked ? `<span class="pill bad">${t('ui_locked')}</span>`
            : `<span class="pill ${r.maxCraftable > 0 ? 'ok' : 'bad'}">x${r.maxCraftable}</span>`;
        c.innerHTML = `${pill}<img src="${img(r.image)}" onerror="this.style.visibility='hidden'">
            <div class="name"></div><div class="sub"></div>`;
        c.querySelector('.name').textContent = r.label;
        c.querySelector('.sub').textContent = r.locked ? t('recipe_locked', r.requiredxp)
            : `${t('ui_makes', r.giveamount)} · ${fmtTime(r.cooktime)}`;
        c.onclick = () => {
            if (r.locked || state.cooking) return;
            state.selected = r;
            state.qty = 1;
            setStatus();
            renderRecipes();
            renderDetail();
        };
        box.appendChild(c);
    });
}

function clampQty(q) {
    const r = state.selected;
    const max = Math.max(1, Math.min(state.maxBatch, r ? r.maxCraftable : 1));
    q = parseInt(q, 10);
    if (isNaN(q) || q < 1) q = 1;
    return Math.min(q, max);
}

function renderDetail() {
    const r = state.selected;
    $('emptyDetail').classList.toggle('hidden', !!r);
    $('detailContent').classList.toggle('hidden', !r);
    if (!r) return;

    state.qty = clampQty(state.qty);
    const q = state.qty;
    $('dImg').src = img(r.image);
    $('dName').textContent = r.label;
    const meta = [`${t('meta_cook_time')}: ${fmtTime(r.cooktime)} ${t('ui_each')}`];
    if (r.xpreward > 0) meta.push(`${t('meta_xp_reward')}: ${r.xpreward} ${t('ui_each')}`);
    if (r.requiredjob) meta.push(`${t('meta_required_job')}: ${r.requiredjob}`);
    $('dMeta').replaceChildren(...meta.map((m) => Object.assign(document.createElement('div'), { textContent: m })));
    $('perLabel').textContent = `(${t('ui_for', q)})`;

    const ing = $('dIngredients');
    ing.innerHTML = '';
    r.ingredients.forEach((i) => {
        const need = i.amount * q;
        const row = document.createElement('div');
        row.className = 'ing';
        row.innerHTML = `<div class="icon"><img src="${img(i.image)}" onerror="this.style.visibility='hidden'"></div>
            <div class="label"></div><div class="amt ${i.have >= need ? 'ok' : 'bad'}">${i.have} / ${need}</div>`;
        row.querySelector('.label').textContent = i.label;
        ing.appendChild(row);
    });

    $('qty').value = q;
    $('qty').max = Math.min(state.maxBatch, Math.max(1, r.maxCraftable));
    const canCook = r.maxCraftable >= q && q >= 1;
    $('summary').textContent = `${t('ui_total')}: ${r.giveamount * q}x ${r.label} · ${fmtTime(r.cooktime * q)}`
        + (r.xpreward > 0 ? ` · ${t('ui_xp', r.xpreward * q)}` : '');
    $('cookBtn').disabled = !canCook;
    $('cookBtn').textContent = canCook ? t('ui_cook', q) : t('ui_missing');
}

/* ---------- status line (inline result / error, no pop-ups) ---------- */
function setStatus(message, ok) {
    const el = $('status');
    el.classList.toggle('hidden', !message);
    el.className = 'status' + (message ? (ok ? ' ok' : ' bad') : ' hidden');
    el.textContent = message || '';
}

function applyStaticLocale() {
    document.querySelectorAll('[data-l]').forEach((el) => { el.textContent = t(el.dataset.l); });
    document.querySelectorAll('[data-lt]').forEach((el) => { el.title = t(el.dataset.lt); });
}

/* ---------- progress ---------- */
function setCookingUI(on) {
    $('controls').classList.toggle('hidden', on);
    $('progressBox').classList.toggle('hidden', !on);
}

function startProgress(duration, label) {
    const start = performance.now();
    state.cooking = { start, duration };
    $('pLabel').textContent = label;
    setCookingUI(true);
    const fill = $('pFill');
    const tick = () => {
        if (!state.cooking) return;
        const pct = Math.min(1, (performance.now() - start) / duration);
        fill.style.width = `${pct * 100}%`;
        fill.className = 'bar-fill ' + (pct >= 1 ? 'stat-good' : 'stat-warn');
        $('pPct').textContent = `${Math.floor(pct * 100)}%`;
        $('pTime').textContent = `${fmtTime(Math.max(0, duration - (performance.now() - start)))} ${t('ui_left')}`;
        if (pct < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
}

function stopProgress() {
    state.cooking = null;
    $('pFill').style.width = '0%';
    setCookingUI(false);
}

/* ---------- actions ---------- */
$('qDown').onclick = () => { state.qty = clampQty(state.qty - 1); renderDetail(); };
$('qUp').onclick = () => { state.qty = clampQty(state.qty + 1); renderDetail(); };
$('qMin').onclick = () => { state.qty = 1; renderDetail(); };
$('qMax').onclick = () => { state.qty = clampQty(999); renderDetail(); };
$('qty').onchange = (e) => { state.qty = clampQty(e.target.value); renderDetail(); };

$('cookBtn').onclick = async () => {
    const r = state.selected;
    if (!r || state.cooking) return;
    $('cookBtn').disabled = true;
    setStatus();
    const res = await post('cook', { id: r.id, qty: state.qty });
    if (res && res.ok) {
        startProgress(res.cooktime, t('progress_cooking', `${res.qty}x ${res.label}`));
    } else {
        setStatus(res && res.error, false);
        renderDetail();
    }
};

$('cancelBtn').onclick = () => { if (state.cooking) post('cancel'); };
$('closeBtn').onclick = () => post('close');
document.addEventListener('keyup', (e) => { if (e.key === 'Escape') post('close'); });

/* ---------- messages from lua ---------- */
window.addEventListener('message', ({ data }) => {
    switch (data.action) {
        case 'open':
            state.imagePath = data.imagePath;
            state.maxBatch = data.maxBatch || 10;
            state.L = data.locale || {};
            $('title').textContent = data.title;
            applyStaticLocale();
            setStatus();
            // fallthrough to refresh
        case 'refresh': {
            state.recipes = data.recipes || [];
            $('xp').textContent = t('menu_current_xp', data.xp ?? 0);
            if (state.selected) state.selected = state.recipes.find((r) => r.id === state.selected.id) || null;
            renderTabs();
            renderRecipes();
            renderDetail();
            $('app').classList.remove('hidden');
            break;
        }
        case 'finished':
            stopProgress();
            setStatus(data.message, data.ok);
            break;
        case 'cancelled':
            stopProgress();
            renderDetail();
            break;
        case 'close':
            stopProgress();
            state.selected = null;
            $('app').classList.add('hidden');
            break;
    }
});
