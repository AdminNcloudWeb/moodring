/* ===== Moodring — Phase 1 MVP =====
 * Vanilla JS, localStorage-backed, single-device, no login.
 */
(function () {
  'use strict';

  // ---------- Constants ----------
  const STORAGE_KEY = 'moodring.v1';
  const MIN_EMOJI = 2;
  const MAX_EMOJI = 12;

  // Default emoji set from the brief. `value` = valence rank (1 low → 10 high)
  // used for the trend line. Non-valence moods get a best-effort mid value.
  const DEFAULT_EMOJIS = [
    { id: 'e1', emoji: '😭', label: 'Crying',   value: 1 },
    { id: 'e2', emoji: '😔', label: 'Low',      value: 2 },
    { id: 'e3', emoji: '😟', label: 'Anxious',  value: 3 },
    { id: 'e4', emoji: '😐', label: 'Neutral',  value: 5 },
    { id: 'e5', emoji: '😌', label: 'Calm',     value: 6 },
    { id: 'e6', emoji: '🙂', label: 'Okay',     value: 6 },
    { id: 'e7', emoji: '💪', label: 'Healthy',  value: 8 },
    { id: 'e8', emoji: '😊', label: 'Good',     value: 8 },
    { id: 'e9', emoji: '😄', label: 'Great',    value: 9 },
    { id: 'e10', emoji: '🤩', label: 'Ecstatic', value: 10 },
  ];

  const DEFAULT_BOOSTERS = [
    'Go for a short walk',
    'Drink a glass of water',
  ];

  // Suggestion pool. `trigger` decides when a card is eligible.
  const SUGGESTIONS = [
    { id: 's_walk',    text: 'Mood has been low for a while — a 5-minute walk outside can help reset.', trigger: 'lowRecent' },
    { id: 's_breathe', text: 'Try a slow breathing exercise: inhale 4s, hold 4s, exhale 6s.',          trigger: 'lowRecent' },
    { id: 's_water',   text: 'Have you had water recently? Hydration affects mood more than we think.', trigger: 'always' },
    { id: 's_sun',     text: 'Step into some sunlight for a few minutes if you can.',                   trigger: 'always' },
    { id: 's_reach',   text: 'Reach out to someone you like — a quick message counts.',                 trigger: 'lowRecent' },
    { id: 's_log',     text: 'You logged a great mood! What did you do today? Add it as a booster.',    trigger: 'highRecent' },
    { id: 's_stretch', text: 'A quick stretch can lift your energy. Reach for the ceiling.',            trigger: 'always' },
  ];

  // ---------- State ----------
  let state = load();

  // Auth / cloud-sync runtime handles (set up in initAuth)
  let supa = null;
  let session = null;
  let authPanel = 'signin'; // which auth screen is showing: 'signin' | 'signup'
  let pushTimer = null;

  function defaultState() {
    return {
      emojis: DEFAULT_EMOJIS.map((e) => ({ ...e })),
      logs: [],            // { id, emoji, label, value, ts }
      boosters: DEFAULT_BOOSTERS.map((text, i) => ({ id: 'b' + i, text })),
      dismissedSuggestions: [],
      savedSuggestions: [],
      todayBoost: null,    // { date: <startOfDay ts>, id, done }
      theme: null,         // null = follow system
    };
  }

  function load() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return defaultState();
      const parsed = JSON.parse(raw);
      return Object.assign(defaultState(), parsed);
    } catch (e) {
      console.warn('Moodring: failed to load state, starting fresh.', e);
      return defaultState();
    }
  }

  function save() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    } catch (e) {
      console.error('Moodring: failed to save.', e);
    }
    schedulePush(); // sync to cloud if signed in (no-op otherwise)
  }

  // ---------- Helpers ----------
  const $ = (sel) => document.querySelector(sel);
  const $$ = (sel) => Array.from(document.querySelectorAll(sel));
  const uid = () => Date.now().toString(36) + Math.random().toString(36).slice(2, 7);

  function startOfDay(ts) {
    const d = new Date(ts);
    d.setHours(0, 0, 0, 0);
    return d.getTime();
  }

  function fmtTime(ts) {
    return new Date(ts).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' });
  }

  function dayLabel(ts) {
    const today = startOfDay(Date.now());
    const day = startOfDay(ts);
    const diff = Math.round((today - day) / 86400000);
    if (diff === 0) return 'Today';
    if (diff === 1) return 'Yesterday';
    return new Date(ts).toLocaleDateString([], { weekday: 'long', month: 'short', day: 'numeric' });
  }

  function logsInLastDays(days) {
    const cutoff = startOfDay(Date.now()) - (days - 1) * 86400000;
    return state.logs.filter((l) => l.ts >= cutoff);
  }

  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    }[c]));
  }

  let toastTimer;
  function toast(msg) {
    const t = $('#toast');
    t.textContent = msg;
    t.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => t.classList.remove('show'), 1800);
  }

  // ---------- Theme ----------
  function applyTheme() {
    const sysDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
    const dark = state.theme === null ? sysDark : state.theme === 'dark';
    document.documentElement.setAttribute('data-theme', dark ? 'dark' : 'light');
    $('#theme-toggle').textContent = dark ? '☀️' : '🌙';
  }

  function toggleTheme() {
    const sysDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
    const currentlyDark = state.theme === null ? sysDark : state.theme === 'dark';
    state.theme = currentlyDark ? 'light' : 'dark';
    save();
    applyTheme();
  }

  // ---------- Logging ----------
  let pendingLog = null; // the log awaiting an optional note

  function renderEmojiRow() {
    const row = $('#emoji-row');
    row.innerHTML = '';
    state.emojis.forEach((e) => {
      const btn = document.createElement('button');
      btn.className = 'emoji-btn';
      btn.setAttribute('role', 'option');
      btn.setAttribute('aria-label', e.label);
      btn.innerHTML = `<span class="e">${escapeHtml(e.emoji)}</span><span class="l">${escapeHtml(e.label)}</span>`;
      btn.addEventListener('click', () => logMood(e, btn));
      row.appendChild(btn);
    });
  }

  function logMood(e, btn) {
    const entry = { id: uid(), emoji: e.emoji, label: e.label, value: e.value || 5, ts: Date.now() };
    state.logs.push(entry);
    save();
    pendingLog = entry;

    if (btn) {
      btn.classList.remove('pop');
      void btn.offsetWidth; // restart animation
      btn.classList.add('pop');
    }
    toast(`${e.emoji} logged`);

    // Reveal optional note input
    const area = $('#note-area');
    $('#note-selected').textContent = e.emoji + '  ' + e.label;
    $('#note-input').value = '';
    area.hidden = false;
    setTimeout(() => $('#note-input').focus(), 50);

    renderTodayLogs();
  }

  function saveNote() {
    if (!pendingLog) return;
    const note = $('#note-input').value.trim();
    if (note) {
      const log = state.logs.find((l) => l.id === pendingLog.id);
      if (log) { log.note = note; save(); }
    }
    closeNote();
    renderTodayLogs();
  }

  function closeNote() {
    $('#note-area').hidden = true;
    pendingLog = null;
  }

  function deleteLog(id) {
    state.logs = state.logs.filter((l) => l.id !== id);
    save();
    renderTodayLogs();
    if ($('#view-history').classList.contains('active')) renderHistory();
  }

  function renderTodayLogs() {
    const wrap = $('#today-logs');
    const today = startOfDay(Date.now());
    const todays = state.logs.filter((l) => startOfDay(l.ts) === today).sort((a, b) => b.ts - a.ts);
    if (!todays.length) {
      wrap.innerHTML = '<p class="empty">No logs yet today. Tap an emoji above.</p>';
      return;
    }
    wrap.innerHTML = todays.map((l) => `
      <span class="log-chip">
        <span class="ce">${escapeHtml(l.emoji)}</span>
        <span>${fmtTime(l.ts)}</span>
        ${l.note ? `<span class="note">“${escapeHtml(l.note)}”</span>` : ''}
        <button class="del" data-id="${l.id}" aria-label="Delete">✕</button>
      </span>`).join('');
    wrap.querySelectorAll('.del').forEach((b) =>
      b.addEventListener('click', () => deleteLog(b.dataset.id)));
  }

  // ---------- Today's boost ----------
  // Picks one booster for the day. Persists the choice so it's stable across
  // reloads, and re-picks automatically on a new day or if the booster was
  // deleted. Returns null when the user has no boosters.
  function getTodayBoost() {
    const today = startOfDay(Date.now());
    const tb = state.todayBoost;
    const valid = tb && tb.date === today && state.boosters.some((b) => b.id === tb.id);
    if (valid) return tb;
    if (!state.boosters.length) {
      if (state.todayBoost) { state.todayBoost = null; save(); }
      return null;
    }
    const pick = state.boosters[Math.floor(Math.random() * state.boosters.length)];
    state.todayBoost = { date: today, id: pick.id, done: false };
    save();
    return state.todayBoost;
  }

  function renderTodayBoost() {
    const wrap = $('#today-boost');
    if (!wrap) return;
    const tb = getTodayBoost();
    if (!tb) {
      wrap.innerHTML = '<p class="empty">No boosters yet — add one in the Boosters tab to get a daily pick.</p>';
      return;
    }
    const booster = state.boosters.find((b) => b.id === tb.id);
    const done = !!tb.done;
    wrap.innerHTML = `
      <div class="boost-card${done ? ' done' : ''}">
        <div class="boost-text">${escapeHtml(booster.text)}</div>
        <div class="boost-actions">
          <button class="boost-icon-btn" id="boost-shuffle" title="Shuffle to a different boost" aria-label="Shuffle to a different boost">🔀</button>
          <button class="boost-icon-btn boost-check${done ? ' done' : ''}" id="boost-done" title="${done ? 'Done today — tap to undo' : 'Mark done for today'}" aria-label="${done ? 'Mark not done' : 'Mark done for today'}">✓</button>
        </div>
      </div>`;
    $('#boost-shuffle').addEventListener('click', shuffleTodayBoost);
    $('#boost-done').addEventListener('click', toggleTodayBoostDone);
  }

  function shuffleTodayBoost() {
    if (state.boosters.length < 2) { toast('Add more boosters to shuffle'); return; }
    const today = startOfDay(Date.now());
    const currentId = state.todayBoost && state.todayBoost.id;
    const choices = state.boosters.filter((b) => b.id !== currentId);
    const pick = choices[Math.floor(Math.random() * choices.length)];
    state.todayBoost = { date: today, id: pick.id, done: false };
    save();
    renderTodayBoost();
    toast('New boost for today');
  }

  function toggleTodayBoostDone() {
    const tb = getTodayBoost();
    if (!tb) return;
    tb.done = !tb.done;
    save();
    renderTodayBoost();
    toast(tb.done ? 'Nice — boost done 🎉' : 'Marked not done');
  }

  // ---------- History ----------
  function renderHistory() {
    renderTrend();
    renderWeeklySummary();
    renderTimeline();
  }

  function dailyAverages(days) {
    // Returns array of { day, avg|null } oldest → newest.
    const out = [];
    const todayStart = startOfDay(Date.now());
    for (let i = days - 1; i >= 0; i--) {
      const dayStart = todayStart - i * 86400000;
      const dayLogs = state.logs.filter((l) => startOfDay(l.ts) === dayStart);
      const avg = dayLogs.length
        ? dayLogs.reduce((s, l) => s + (l.value || 5), 0) / dayLogs.length
        : null;
      out.push({ day: dayStart, avg });
    }
    return out;
  }

  function renderTrend() {
    const data = dailyAverages(7);
    const points = data.filter((d) => d.avg !== null);
    const el = $('#trend');

    if (points.length < 2) {
      el.innerHTML = '<p class="empty">Log moods across a couple of days to see your trend.</p>';
      return;
    }

    const W = 100, H = 100, pad = 8;
    const xStep = (W - pad * 2) / (data.length - 1);
    const toY = (v) => H - pad - ((v - 1) / 9) * (H - pad * 2);

    let path = '';
    const dots = [];
    data.forEach((d, i) => {
      if (d.avg === null) return;
      const x = pad + i * xStep;
      const y = toY(d.avg);
      path += (path ? ' L' : 'M') + x.toFixed(1) + ' ' + y.toFixed(1);
      dots.push(`<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="1.8" fill="var(--accent)"/>`);
    });

    // Direction: compare first vs last available daily average
    const first = points[0].avg, last = points[points.length - 1].avg;
    const delta = last - first;
    let verdict, arrow;
    if (delta > 0.6) { verdict = 'trending up'; arrow = '↗'; }
    else if (delta < -0.6) { verdict = 'trending down'; arrow = '↘'; }
    else { verdict = 'holding steady'; arrow = '→'; }

    el.innerHTML = `
      <svg viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true">
        <path d="${path}" fill="none" stroke="var(--accent)" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>
        ${dots.join('')}
      </svg>
      <p class="trend-label">${arrow} Things are <strong>${verdict}</strong> over the week.</p>`;
  }

  function renderWeeklySummary() {
    const logs = logsInLastDays(7);
    const el = $('#weekly-summary');
    if (!logs.length) { el.style.display = 'none'; return; }
    el.style.display = '';

    const peak = logs.reduce((a, b) => (b.value > a.value ? b : a));
    const dip = logs.reduce((a, b) => (b.value < a.value ? b : a));
    const counts = {};
    logs.forEach((l) => { counts[l.emoji + ' ' + l.label] = (counts[l.emoji + ' ' + l.label] || 0) + 1; });
    const common = Object.entries(counts).sort((a, b) => b[1] - a[1])[0];

    el.innerHTML = `
      <strong>This week:</strong> ${logs.length} log${logs.length === 1 ? '' : 's'}.
      Most often you felt <strong>${escapeHtml(common[0])}</strong>.
      Peak was ${escapeHtml(peak.emoji)} ${escapeHtml(peak.label)} on ${dayLabel(peak.ts)};
      lowest was ${escapeHtml(dip.emoji)} ${escapeHtml(dip.label)} on ${dayLabel(dip.ts)}.`;
  }

  function renderTimeline() {
    const wrap = $('#timeline');
    const logs = logsInLastDays(7).sort((a, b) => b.ts - a.ts);
    if (!logs.length) {
      wrap.innerHTML = '<p class="empty">Nothing logged in the last 7 days yet.</p>';
      return;
    }
    // Group by day
    const groups = {};
    logs.forEach((l) => {
      const key = startOfDay(l.ts);
      (groups[key] = groups[key] || []).push(l);
    });

    wrap.innerHTML = Object.keys(groups)
      .sort((a, b) => b - a)
      .map((key) => {
        const entries = groups[key].sort((a, b) => b.ts - a.ts);
        return `
        <div class="day-group">
          <div class="day-head">
            <span class="day-name">${dayLabel(Number(key))}</span>
            <span class="day-count">${entries.length} log${entries.length === 1 ? '' : 's'}</span>
          </div>
          <div class="day-entries">
            ${entries.map((e) => `
              <div class="entry">
                <span class="et">${fmtTime(e.ts)}</span>
                <span class="ee">${escapeHtml(e.emoji)}</span>
                <span>${escapeHtml(e.label)}</span>
                ${e.note ? `<span class="en">— “${escapeHtml(e.note)}”</span>` : ''}
              </div>`).join('')}
          </div>
        </div>`;
      }).join('');
  }

  // ---------- Boosters & Suggestions ----------
  function recentMoodContext() {
    // Look at logs in the last 6 hours for context.
    const sixHrs = Date.now() - 6 * 3600000;
    const recent = state.logs.filter((l) => l.ts >= sixHrs);
    if (!recent.length) return { lowRecent: false, highRecent: false };
    const avg = recent.reduce((s, l) => s + (l.value || 5), 0) / recent.length;
    return { lowRecent: avg <= 4, highRecent: avg >= 8 };
  }

  function eligibleSuggestions() {
    const ctx = recentMoodContext();
    return SUGGESTIONS.filter((s) => {
      if (state.dismissedSuggestions.includes(s.id)) return false;
      if (state.savedSuggestions.includes(s.id)) return false;
      if (s.trigger === 'always') return true;
      if (s.trigger === 'lowRecent') return ctx.lowRecent;
      if (s.trigger === 'highRecent') return ctx.highRecent;
      return false;
    }).slice(0, 3);
  }

  function renderSuggestions() {
    const wrap = $('#suggestions');
    const list = eligibleSuggestions();
    if (!list.length) {
      wrap.innerHTML = '<p class="empty">No suggestions right now — check back after logging a few moods.</p>';
      return;
    }
    wrap.innerHTML = list.map((s) => `
      <div class="suggestion-card" data-id="${s.id}">
        <div class="s-text">${escapeHtml(s.text)}</div>
        <div class="s-actions">
          <button class="btn primary save" data-id="${s.id}">Save to my list</button>
          <button class="btn ghost dismiss" data-id="${s.id}">Dismiss</button>
        </div>
      </div>`).join('');

    wrap.querySelectorAll('.save').forEach((b) =>
      b.addEventListener('click', () => saveSuggestion(b.dataset.id)));
    wrap.querySelectorAll('.dismiss').forEach((b) =>
      b.addEventListener('click', () => dismissSuggestion(b.dataset.id)));
  }

  function saveSuggestion(id) {
    const s = SUGGESTIONS.find((x) => x.id === id);
    if (!s) return;
    state.boosters.push({ id: uid(), text: s.text });
    state.savedSuggestions.push(id);
    save();
    toast('Saved to your boosters');
    renderSuggestions();
    renderBoosters();
  }

  function dismissSuggestion(id) {
    if (!state.dismissedSuggestions.includes(id)) state.dismissedSuggestions.push(id);
    save();
    renderSuggestions();
  }

  function renderBoosters() {
    const ul = $('#booster-list');
    if (!state.boosters.length) {
      ul.innerHTML = '<li class="empty">No boosters yet. Add one above.</li>';
      return;
    }
    ul.innerHTML = state.boosters.map((b) => `
      <li class="booster-item">
        <span>${escapeHtml(b.text)}</span>
        <button class="del" data-id="${b.id}" aria-label="Remove">✕</button>
      </li>`).join('');
    ul.querySelectorAll('.del').forEach((btn) =>
      btn.addEventListener('click', () => {
        state.boosters = state.boosters.filter((x) => x.id !== btn.dataset.id);
        save();
        renderBoosters();
      }));
  }

  function addBooster() {
    const input = $('#booster-input');
    const text = input.value.trim();
    if (!text) return;
    state.boosters.push({ id: uid(), text });
    save();
    input.value = '';
    renderBoosters();
    toast('Booster added');
  }

  // ---------- Settings: emoji editor ----------
  let dragId = null;

  function renderEmojiEditor() {
    const ul = $('#emoji-edit-list');
    ul.innerHTML = state.emojis.map((e) => `
      <li class="emoji-edit-item" draggable="true" data-id="${e.id}">
        <span class="grip" aria-hidden="true">⠿</span>
        <span class="ce">${escapeHtml(e.emoji)}</span>
        <span class="lbl">${escapeHtml(e.label)}</span>
        <button class="del" data-id="${e.id}" aria-label="Remove">✕</button>
      </li>`).join('');

    ul.querySelectorAll('.del').forEach((b) =>
      b.addEventListener('click', () => removeEmoji(b.dataset.id)));

    ul.querySelectorAll('.emoji-edit-item').forEach((li) => {
      li.addEventListener('dragstart', (ev) => {
        dragId = li.dataset.id;
        li.classList.add('dragging');
        ev.dataTransfer.effectAllowed = 'move';
      });
      li.addEventListener('dragend', () => {
        dragId = null;
        ul.querySelectorAll('.emoji-edit-item').forEach((x) => x.classList.remove('dragging', 'drag-over'));
      });
      li.addEventListener('dragover', (ev) => {
        ev.preventDefault();
        li.classList.add('drag-over');
      });
      li.addEventListener('dragleave', () => li.classList.remove('drag-over'));
      li.addEventListener('drop', (ev) => {
        ev.preventDefault();
        li.classList.remove('drag-over');
        reorderEmoji(dragId, li.dataset.id);
      });
    });
  }

  function reorderEmoji(fromId, toId) {
    if (!fromId || fromId === toId) return;
    const from = state.emojis.findIndex((e) => e.id === fromId);
    const to = state.emojis.findIndex((e) => e.id === toId);
    if (from < 0 || to < 0) return;
    const [moved] = state.emojis.splice(from, 1);
    state.emojis.splice(to, 0, moved);
    save();
    renderEmojiEditor();
    renderEmojiRow();
  }

  function removeEmoji(id) {
    if (state.emojis.length <= MIN_EMOJI) {
      toast(`Keep at least ${MIN_EMOJI} emojis`);
      return;
    }
    state.emojis = state.emojis.filter((e) => e.id !== id);
    save();
    renderEmojiEditor();
    renderEmojiRow();
  }

  function addEmoji() {
    const charEl = $('#emoji-add-char');
    const labelEl = $('#emoji-add-label');
    const emoji = charEl.value.trim();
    const label = labelEl.value.trim() || 'Custom';
    if (!emoji) { toast('Pick an emoji'); return; }
    if (state.emojis.length >= MAX_EMOJI) { toast(`Max ${MAX_EMOJI} emojis`); return; }
    state.emojis.push({ id: uid(), emoji, label, value: 5 });
    save();
    charEl.value = '';
    labelEl.value = '';
    renderEmojiEditor();
    renderEmojiRow();
    toast('Emoji added');
  }

  // ---------- Data export / reset ----------
  function download(filename, text, type) {
    const blob = new Blob([text], { type });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.click();
    URL.revokeObjectURL(url);
  }

  function exportJson() {
    download('moodring-export.json', JSON.stringify(state, null, 2), 'application/json');
  }

  function exportCsv() {
    const rows = [['timestamp', 'iso', 'emoji', 'label', 'value', 'note']];
    state.logs.slice().sort((a, b) => a.ts - b.ts).forEach((l) => {
      rows.push([l.ts, new Date(l.ts).toISOString(), l.emoji, l.label, l.value || '', (l.note || '').replace(/"/g, '""')]);
    });
    const csv = rows.map((r) => r.map((c) => `"${c}"`).join(',')).join('\n');
    download('moodring-logs.csv', csv, 'text/csv');
  }

  function resetData() {
    if (!confirm('Delete all logs, boosters and custom emojis? This cannot be undone.')) return;
    state = defaultState();
    save();
    renderAll();
    toast('All data reset');
  }

  // ---------- Auth & cloud sync (Supabase) ----------
  const cfg = window.MOODRING_CONFIG || {};
  const supaConfigured = !!(cfg.SUPABASE_URL && cfg.SUPABASE_ANON_KEY);

  function initAuth() {
    updateAccountButton();

    if (!supaConfigured) {
      // No credentials → local-only mode. Show the gentle config hint only if
      // the user opens the login screen via the account button (hidden here).
      const warn = $('#auth-config-warn');
      if (warn) warn.hidden = false;
      return;
    }
    if (!window.supabase || !window.supabase.createClient) {
      console.warn('Moodring: Supabase library failed to load — running local-only.');
      return;
    }

    supa = window.supabase.createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY);

    supa.auth.getSession().then(({ data }) => {
      session = data.session;
      if (session) onSignedIn();
      else showAuthOverlay();
      updateAccountButton();
    });

    supa.auth.onAuthStateChange((_event, newSession) => {
      const wasSignedIn = !!session;
      session = newSession;
      if (session && !wasSignedIn) onSignedIn();
      if (!session) showAuthOverlay();
      updateAccountButton();
    });
  }

  function showAuthOverlay() {
    const o = $('#auth-overlay');
    if (o) o.hidden = false;
    showAuthPanel('signin');
    startLogoCycle();
  }
  function hideAuthOverlay() {
    const o = $('#auth-overlay');
    if (o) o.hidden = true;
    stopLogoCycle();
  }

  // Cycle the auth logo through the mood spectrum (crisis → peak) so the brand
  // mark reflects what the app is about. Runs only while the overlay is shown.
  const LOGO_EMOJIS = ['😭', '😔', '😟', '😐', '😌', '🙂', '💪', '😊', '😄', '🤩'];
  let logoTimer = null;
  let logoIdx = 0;
  function startLogoCycle() {
    const el = $('#auth-logo');
    if (!el || logoTimer) return;
    logoTimer = setInterval(() => {
      el.classList.add('swap');
      setTimeout(() => {
        logoIdx = (logoIdx + 1) % LOGO_EMOJIS.length;
        el.textContent = LOGO_EMOJIS[logoIdx];
        el.classList.remove('swap');
      }, 180);
    }, 1500);
  }
  function stopLogoCycle() {
    if (logoTimer) { clearInterval(logoTimer); logoTimer = null; }
  }

  // Switch between the sign-in and create-account screens.
  function showAuthPanel(name) {
    authPanel = name === 'signup' ? 'signup' : 'signin';
    const signin = $('#auth-panel-signin');
    const signup = $('#auth-panel-signup');
    if (signin) signin.hidden = authPanel !== 'signin';
    if (signup) signup.hidden = authPanel !== 'signup';
    authError(''); // clear any stale message when changing screens
    const focus = $(authPanel === 'signup' ? '#signup-email' : '#signin-email');
    if (focus) focus.focus();
  }

  // The message element belongs to whichever panel is currently visible.
  function authMsgEl() {
    return $(authPanel === 'signup' ? '#signup-msg' : '#signin-msg');
  }

  function authError(msg) {
    const el = authMsgEl();
    if (!el) return;
    el.textContent = msg || '';
    el.classList.remove('success');
    el.hidden = !msg;
  }

  function authNotice(msg) {
    const el = authMsgEl();
    if (!el) return;
    el.textContent = msg || '';
    el.classList.add('success');
    el.hidden = !msg;
  }

  // Disable a button and show progress text while an async auth call runs.
  async function withAuthBusy(btn, busyText, fn) {
    const original = btn ? btn.textContent : '';
    if (btn) { btn.disabled = true; btn.textContent = busyText; }
    try {
      return await fn();
    } finally {
      if (btn) { btn.disabled = false; btn.textContent = original; }
    }
  }

  function requireSupa() {
    if (!supa) { authError('Add your Supabase credentials in config.js first.'); return false; }
    return true;
  }

  async function signIn() {
    if (!requireSupa()) return;
    const email = $('#signin-email').value.trim();
    const password = $('#signin-password').value;
    if (!email || !password) return authError('Enter your email and password.');
    authError('');
    await withAuthBusy($('#auth-signin'), 'Signing in…', async () => {
      const { error } = await supa.auth.signInWithPassword({ email, password });
      if (error) authError(error.message);
      // success → onAuthStateChange fires onSignedIn() and hides the overlay.
    });
  }

  async function signUp() {
    if (!requireSupa()) return;
    const email = $('#signup-email').value.trim();
    const password = $('#signup-password').value;
    if (!email || password.length < 6) return authError('Enter an email and a 6+ character password.');
    authError('');
    await withAuthBusy($('#auth-signup'), 'Creating account…', async () => {
      const { data, error } = await supa.auth.signUp({ email, password });
      if (error) return authError(error.message);
      if (data.session) {
        authNotice('Account created — signing you in…'); // auto-confirm → onAuthStateChange takes over
      } else {
        authNotice('Account created. Check ' + email + ' to confirm, then sign in.');
      }
    });
  }

  async function magicLink() {
    if (!requireSupa()) return;
    const email = $('#signin-email').value.trim();
    if (!email) return authError('Enter your email first.');
    authError('');
    await withAuthBusy($('#auth-magic'), 'Sending…', async () => {
      const { error } = await supa.auth.signInWithOtp({
        email, options: { emailRedirectTo: window.location.href },
      });
      if (error) return authError(error.message);
      authNotice('Magic link sent — check ' + email + '.');
    });
  }

  async function signOut() {
    if (supa) await supa.auth.signOut();
    session = null;
    updateAccountButton();
    showAuthOverlay();
  }


  function updateAccountButton() {
    const btn = $('#account-btn');
    if (!btn) return;
    if (session && session.user) {
      btn.hidden = false;
      btn.textContent = '⏏';
      btn.title = 'Sign out (' + session.user.email + ')';
    } else if (supaConfigured) {
      btn.hidden = false;
      btn.textContent = '👤';
      btn.title = 'Sign in';
    } else {
      btn.hidden = true;
    }
  }

  async function onSignedIn() {
    hideAuthOverlay();
    await pullRemote();
  }

  async function pullRemote() {
    if (!supa || !session) return;
    const { data, error } = await supa
      .from('moodring_state')
      .select('data')
      .eq('user_id', session.user.id)
      .maybeSingle();
    if (error) { console.warn('Moodring pullRemote:', error.message); return; }

    if (data && data.data) {
      // Adopt cloud copy (enables multi-device).
      state = Object.assign(defaultState(), data.data);
      try { localStorage.setItem(STORAGE_KEY, JSON.stringify(state)); } catch (e) {}
      applyTheme();
      renderAll();
      toast('Synced from cloud');
    } else {
      // First sign-in for this account → seed the cloud with local data.
      await pushRemote();
    }
  }

  function schedulePush() {
    if (!supa || !session) return;
    clearTimeout(pushTimer);
    pushTimer = setTimeout(pushRemote, 800);
  }

  async function pushRemote() {
    if (!supa || !session) return;
    const { error } = await supa.from('moodring_state').upsert({
      user_id: session.user.id,
      data: state,
      updated_at: new Date().toISOString(),
    });
    if (error) console.warn('Moodring pushRemote:', error.message);
  }

  // ---------- Navigation ----------
  function switchView(name) {
    $$('.view').forEach((v) => v.classList.remove('active'));
    $('#view-' + name).classList.add('active');
    $$('.tab').forEach((t) => t.classList.toggle('active', t.dataset.view === name));
    if (name === 'log') renderTodayBoost();
    if (name === 'history') renderHistory();
    if (name === 'boosters') { renderSuggestions(); renderBoosters(); }
    if (name === 'settings') renderEmojiEditor();
    window.scrollTo(0, 0);
  }

  // ---------- Render everything ----------
  function renderAll() {
    renderEmojiRow();
    renderTodayBoost();
    renderTodayLogs();
    renderBoosters();
    renderSuggestions();
    renderEmojiEditor();
  }

  // ---------- Wiring ----------
  function init() {
    applyTheme();
    renderAll();

    $('#theme-toggle').addEventListener('click', toggleTheme);
    $$('.tab').forEach((t) => t.addEventListener('click', () => switchView(t.dataset.view)));

    $('#note-save').addEventListener('click', saveNote);
    $('#note-skip').addEventListener('click', closeNote);
    $('#note-input').addEventListener('keydown', (e) => { if (e.key === 'Enter') saveNote(); });

    $('#booster-add-btn').addEventListener('click', addBooster);
    $('#booster-input').addEventListener('keydown', (e) => { if (e.key === 'Enter') addBooster(); });

    $('#emoji-add-btn').addEventListener('click', addEmoji);
    $('#export-json').addEventListener('click', exportJson);
    $('#export-csv').addEventListener('click', exportCsv);
    $('#reset-data').addEventListener('click', resetData);

    // Auth
    $('#account-btn').addEventListener('click', () => (session ? signOut() : showAuthOverlay()));
    $('#auth-signin').addEventListener('click', signIn);
    $('#auth-signup').addEventListener('click', signUp);
    $('#auth-magic').addEventListener('click', magicLink);
    $('#auth-goto-signup').addEventListener('click', () => showAuthPanel('signup'));
    $('#auth-goto-signin').addEventListener('click', () => showAuthPanel('signin'));
    $('#auth-back').addEventListener('click', () => showAuthPanel('signin'));
    $('#signin-password').addEventListener('keydown', (e) => { if (e.key === 'Enter') signIn(); });
    $('#signup-password').addEventListener('keydown', (e) => { if (e.key === 'Enter') signUp(); });
    initAuth();

    // React to system theme changes when following system
    if (window.matchMedia) {
      window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
        if (state.theme === null) applyTheme();
      });
    }
  }

  document.addEventListener('DOMContentLoaded', init);
})();
