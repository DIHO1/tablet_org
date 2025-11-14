const RESOURCE_NAME = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'tablet_org';

const MAX_PLAN_ROWS = 8;
const DEFAULT_PERMISSION_MESSAGE = 'Postaraj się o rangę na DC, aby utworzyć organizację.';

const state = {
  name: null,
  owner: null,
  motto: null,
  recruitment: null,
  funds: 0,
  note: null,
  createdAt: null,
  updatedAt: null,
  dailyPlan: [],
  permissions: {
    canCreate: true,
    reason: '',
  },
};

function postNui(action, payload = {}) {
  fetch(`https://${RESOURCE_NAME}/${action}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: JSON.stringify(payload),
  }).catch(() => {});
}

function formatDate(isoString, fallback = 'Brak') {
  if (!isoString) {
    return fallback;
  }

  const date = new Date(isoString);
  if (Number.isNaN(date.getTime())) {
    return fallback;
  }

  return date.toLocaleString('pl-PL', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function formatCurrency(value) {
  const amount = Number(value) || 0;
  return `${amount.toLocaleString('pl-PL')} $`;
}

function setTextContent(selector, value) {
  const element = typeof selector === 'string' ? document.querySelector(selector) : selector;
  if (!element) return;
  element.textContent = value;
}

let currentPage = 'dashboard';

function activatePage(pageId) {
  const target = typeof pageId === 'string' && pageId.trim() !== '' ? pageId : 'dashboard';
  const container = document.querySelector('[data-page-container]');
  if (!container) {
    currentPage = target;
    return;
  }

  const pages = container.querySelectorAll('[data-page]');
  pages.forEach((page) => {
    page.classList.toggle('page--active', page.dataset.page === target);
  });

  document.querySelectorAll('[data-page-target]').forEach((button) => {
    button.classList.toggle('sidebar__item--active', button.dataset.pageTarget === target);
  });

  currentPage = target;
}

function sanitizePlanEntries(entries) {
  if (!Array.isArray(entries)) {
    return [];
  }

  return entries
    .map((entry) => ({
      time: typeof entry.time === 'string' ? entry.time.trim() : '',
      label: typeof entry.label === 'string' ? entry.label.trim() : typeof entry.task === 'string' ? entry.task.trim() : '',
    }))
    .filter((entry) => entry.time !== '' || entry.label !== '')
    .slice(0, MAX_PLAN_ROWS);
}

function createPlanRow({ time = '', label = '' } = {}) {
  const row = document.createElement('div');
  row.className = 'plan-row';
  const safeTime = typeof time === 'string' ? time : '';
  const safeLabel = typeof label === 'string'
    ? label
        .replace(/&/g, '&amp;')
        .replace(/"/g, '&quot;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
    : '';
  row.innerHTML = `
    <input class="plan-row__input" type="time" value="${safeTime}" data-plan-time />
    <input class="plan-row__input" type="text" value="${safeLabel}" placeholder="Opisz aktywność" maxlength="64" data-plan-label />
    <button class="plan-row__remove" type="button" aria-label="Usuń pozycję">×</button>
  `;

  return row;
}

function renderPlanLists(entries) {
  const preview = document.querySelector('[data-plan-preview]');
  const detail = document.querySelector('[data-plan-detail]');
  const items = sanitizePlanEntries(entries);

  const renderList = (root, listItems) => {
    if (!root) return;

    root.innerHTML = '';

    if (!listItems.length) {
      const empty = document.createElement('li');
      empty.className = 'schedule-preview__empty';
      empty.textContent = 'Brak zaplanowanych aktywności.';
      root.appendChild(empty);
      return;
    }

    listItems.forEach((entry) => {
      const item = document.createElement('li');
      item.className = 'schedule-preview__item';

      const time = document.createElement('span');
      time.className = 'schedule-preview__time';
      time.textContent = entry.time || '— —';

      const label = document.createElement('p');
      label.className = 'schedule-preview__label';
      label.textContent = entry.label || 'Aktywność bez nazwy';

      item.append(time, label);
      root.appendChild(item);
    });
  };

  renderList(preview, items.slice(0, 3));
  renderList(detail, items);
}

function syncPlanForm(entries) {
  const rowsContainer = document.querySelector('[data-plan-rows]');
  if (!rowsContainer) return;

  rowsContainer.innerHTML = '';

  const items = sanitizePlanEntries(entries);
  const rows = items.length ? items : [{}];

  rows.forEach((entry) => {
    rowsContainer.appendChild(createPlanRow(entry));
  });
}

function appendPlanRow() {
  const rowsContainer = document.querySelector('[data-plan-rows]');
  if (!rowsContainer) return;

  const existing = rowsContainer.querySelectorAll('.plan-row').length;
  if (existing >= MAX_PLAN_ROWS) {
    setFeedback(`Możesz zaplanować maksymalnie ${MAX_PLAN_ROWS} aktywności.`, 'error', 'plan');
    return;
  }

  rowsContainer.appendChild(createPlanRow());
}

function handlePlanSubmit(event) {
  event.preventDefault();

  const form = event.currentTarget;
  const rows = Array.from(form.querySelectorAll('.plan-row'));
  const entries = [];
  let hasError = false;

  rows.forEach((row) => {
    const timeInput = row.querySelector('[data-plan-time]');
    const labelInput = row.querySelector('[data-plan-label]');

    const timeValue = timeInput ? String(timeInput.value || '').trim() : '';
    const labelValue = labelInput ? String(labelInput.value || '').trim() : '';

    if (!timeValue && !labelValue) {
      return;
    }

    if (timeValue && !/^\d{2}:\d{2}$/.test(timeValue)) {
      hasError = true;
    }

    entries.push({ time: timeValue, label: labelValue });
  });

  if (hasError) {
    setFeedback('Użyj formatu HH:MM dla godzin w planie dnia.', 'error', 'plan');
    return;
  }

  if (entries.length > MAX_PLAN_ROWS) {
    setFeedback(`Możesz zaplanować maksymalnie ${MAX_PLAN_ROWS} aktywności.`, 'error', 'plan');
    return;
  }

  setFeedback('Zapisywanie planu...', 'info', 'plan');
  postNui('updatePlan', { entries });
}

function toggleVisibility(visible) {
  const body = document.body;
  const root = document.querySelector('[data-tablet-root]');

  if (body) {
    if (!body.classList.contains('tablet-shell')) {
      body.classList.add('tablet-shell');
    }

    body.classList.toggle('tablet-shell--active', Boolean(visible));
  }

  if (root) {
    root.classList.toggle('tablet--hidden', !visible);
  }

  if (visible) {
    activatePage(currentPage || 'dashboard');
    updateCreationGuard();
  } else {
    currentPage = 'dashboard';
    activatePage('dashboard');
    updateCreationGuard();
  }
}

function syncPermissions(incoming) {
  if (!incoming || typeof incoming !== 'object') {
    state.permissions = { canCreate: true, reason: '' };
  } else {
    const canCreate = incoming.canCreate !== false;
    const reason = typeof incoming.reason === 'string' ? incoming.reason.trim() : '';
    state.permissions = {
      canCreate,
      reason,
    };
  }

  updateCreationGuard();
}

function updateCreationGuard() {
  const guardWrapper = document.querySelector('[data-form-guard]');
  const overlay = document.querySelector('[data-create-overlay]');
  const message = document.querySelector('[data-create-message]');
  const form = document.getElementById('org-form');
  const shouldLock = !state.name && state.permissions && state.permissions.canCreate === false;
  const reasonText = state.permissions && typeof state.permissions.reason === 'string' && state.permissions.reason.trim() !== ''
    ? state.permissions.reason.trim()
    : DEFAULT_PERMISSION_MESSAGE;

  if (guardWrapper) {
    guardWrapper.classList.toggle('config-form__guard--locked', shouldLock);
  }

  if (overlay) {
    overlay.hidden = !shouldLock;
    overlay.setAttribute('aria-hidden', shouldLock ? 'false' : 'true');
  }

  if (message) {
    message.textContent = reasonText;
  }

  if (form) {
    form.setAttribute('aria-disabled', shouldLock ? 'true' : 'false');
    const inputs = form.querySelectorAll('input, textarea, button, select');
    inputs.forEach((element) => {
      if (element.dataset.lockBypass === 'true') {
        return;
      }

      element.disabled = shouldLock;
    });
  }
}

function setFeedback(message, type = 'info', context = 'setup') {
  const feedback = document.querySelector(`[data-feedback="${context}"]`);
  if (!feedback) return;

  feedback.textContent = message || '';
  feedback.classList.remove('config-form__feedback--error', 'config-form__feedback--success');

  if (!message) {
    return;
  }

  if (type === 'error') {
    feedback.classList.add('config-form__feedback--error');
  } else if (type === 'success') {
    feedback.classList.add('config-form__feedback--success');
  }
}

function syncFormValues(form) {
  if (!form) return;

  const nameInput = form.querySelector('input[name="name"]');
  const ownerInput = form.querySelector('input[name="owner"]');
  const mottoInput = form.querySelector('input[name="motto"]');
  const recruitmentInput = form.querySelector('textarea[name="recruitment"]');
  const submitButton = form.querySelector('button[type="submit"]');

  if (nameInput) {
    nameInput.value = state.name || '';
  }

  if (ownerInput) {
    ownerInput.value = state.owner || '';
  }

  if (mottoInput) {
    mottoInput.value = state.motto || '';
  }

  if (recruitmentInput) {
    recruitmentInput.value = state.recruitment || '';
  }

  if (submitButton) {
    submitButton.textContent = state.name ? 'Zapisz zmiany' : 'Utwórz organizację';
  }
}

function syncNoteForm() {
  const noteInput = document.querySelector('#org-note');
  if (noteInput) {
    noteInput.value = state.note || '';
  }
}

function renderOrganization(data) {
  const organization = data || state;
  const hasOrganization = Boolean(organization.name);
  const statusText = hasOrganization ? 'Aktywna' : 'Nieaktywna';
  const fundsText = formatCurrency(organization.funds);
  const createdText = hasOrganization ? formatDate(organization.createdAt) : 'Brak';
  const updatedText = organization.updatedAt ? formatDate(organization.updatedAt) : 'Brak aktualizacji';
  const mottoText = organization.motto || 'Dodaj motto, aby wyróżnić charakter Twojej drużyny.';
  const recruitmentText = organization.recruitment || 'Brak';
  const hasNote = organization.note && organization.note.trim() !== '';
  const displayNote = hasNote
    ? organization.note
    : 'Brak zapisanej notatki. Uzupełnij tablicę, aby przekazać priorytetowe zadania.';

  setTextContent('[data-org-name]', hasOrganization ? organization.name : 'Brak organizacji');
  setTextContent('[data-org-status]', statusText);
  setTextContent('[data-org-status-large]', statusText);
  setTextContent('[data-org-status-pill]', statusText);

  const message = hasOrganization
    ? `Panel aktywny dla organizacji „${organization.name}”.`
    : 'Skonfiguruj swoją organizację, aby odblokować pełny panel.';
  setTextContent('[data-org-message]', message);

  document
    .querySelectorAll('[data-org-owner]')
    .forEach((element) => setTextContent(element, organization.owner || 'Nie przypisano'));

  document.querySelectorAll('[data-org-created]').forEach((element) => {
    setTextContent(element, createdText);
  });
  document.querySelectorAll('[data-org-created-badge]').forEach((element) => {
    setTextContent(element, createdText);
  });

  setTextContent('[data-org-updated]', updatedText);
  setTextContent('[data-org-updated-footer]', updatedText);

  setTextContent('[data-org-funds]', fundsText);
  setTextContent('[data-org-funds-badge]', fundsText);
  setTextContent('[data-org-funds-strong]', fundsText);
  setTextContent('[data-org-funds-card]', fundsText);

  setTextContent('[data-org-recruitment]', recruitmentText);
  setTextContent('[data-org-recruitment-card]', recruitmentText);

  setTextContent('[data-org-motto]', mottoText);

  const noteTitle = hasNote ? organization.note.split('\n')[0] : 'Brak notatki';
  const noteSnippet = hasNote
    ? (organization.note.length > 120 ? `${organization.note.slice(0, 117)}...` : organization.note)
    : 'Dodaj krótką informację, by zespół wiedział jakie są priorytety.';

  setTextContent('[data-org-note]', displayNote);
  setTextContent('[data-org-note-title]', noteTitle);
  setTextContent('[data-org-note-snippet]', noteSnippet);

  const planEntries = sanitizePlanEntries(organization.dailyPlan || state.dailyPlan);
  renderPlanLists(planEntries);
  syncPlanForm(planEntries);

  const hasPlan = planEntries.length > 0;
  const planUpdatedText = hasPlan
    ? (organization.updatedAt ? `Plan zaktualizowano: ${updatedText}` : 'Plan zapisany w tej sesji.')
    : 'Plan nie został jeszcze przygotowany.';

  const noteUpdatedText = hasNote
    ? (organization.updatedAt ? `Ostatnia aktualizacja: ${updatedText}` : 'Notatka zapisana w tej sesji.')
    : 'Notatka nie została jeszcze zapisana.';

  setTextContent('[data-plan-updated]', planUpdatedText);
  setTextContent('[data-note-updated]', noteUpdatedText);
  setTextContent('[data-funds-updated]', `Ostatnie saldo: ${fundsText}`);

  syncFormValues(document.getElementById('org-form'));
  syncNoteForm();
  updateCreationGuard();
}

function syncState(newState) {
  const incoming = newState || {};

  state.name = typeof incoming.name === 'undefined' ? null : incoming.name;
  state.owner = typeof incoming.owner === 'undefined' ? null : incoming.owner;
  state.motto = typeof incoming.motto === 'undefined' ? null : incoming.motto;
  state.recruitment = typeof incoming.recruitment === 'undefined' ? null : incoming.recruitment;
  state.funds = typeof incoming.funds === 'undefined' ? 0 : Number(incoming.funds) || 0;
  state.note = typeof incoming.note === 'undefined' ? null : incoming.note;
  state.createdAt = typeof incoming.createdAt === 'undefined' ? null : incoming.createdAt;
  state.updatedAt = typeof incoming.updatedAt === 'undefined' ? null : incoming.updatedAt;
  const incomingPlan = Array.isArray(incoming.dailyPlan)
    ? incoming.dailyPlan
    : Array.isArray(incoming.plan)
      ? incoming.plan
      : [];
  state.dailyPlan = sanitizePlanEntries(incomingPlan);

  renderOrganization(state);
}

function handleMessage(event) {
  const payload = event.data || {};

  if (payload.permissions) {
    syncPermissions(payload.permissions);
  }

  if (payload.action === 'open') {
    if (payload.data) {
      syncState(payload.data);
    }

    setFeedback('', 'info', 'setup');
    setFeedback('', 'info', 'funds');
    setFeedback('', 'info', 'note');
    setFeedback('', 'info', 'plan');
    toggleVisibility(true);
    return;
  }

  if (payload.action === 'close') {
    toggleVisibility(false);
    setFeedback('', 'info', 'setup');
    setFeedback('', 'info', 'funds');
    setFeedback('', 'info', 'note');
    setFeedback('', 'info', 'plan');
    return;
  }

  if (payload.action === 'notify') {
    const context = payload.context || 'setup';
    if (payload.type === 'error') {
      setFeedback(payload.message || 'Wystąpił błąd.', 'error', context);
    } else if (payload.message) {
      setFeedback(payload.message, 'success', context);
      if (context === 'funds') {
        const amountInput = document.querySelector('#funds-amount');
        if (amountInput) {
          amountInput.value = '';
        }
      }
    }
    return;
  }

  if (payload.action === 'update') {
    if (payload.data) {
      syncState(payload.data);
    }
  }

  if (payload.data) {
    syncState(payload.data);
  }

  if (payload.message) {
    setFeedback(payload.message, 'success', payload.context || 'setup');
    if (payload.context === 'funds') {
      const amountInput = document.querySelector('#funds-amount');
      if (amountInput) {
        amountInput.value = '';
      }
    }
  }

  if (payload.error) {
    setFeedback(payload.error, 'error', payload.context || 'setup');
  }
}

function handleOrgFormSubmit(event) {
  event.preventDefault();

  const form = event.currentTarget;
  const formData = new FormData(form);
  const name = String(formData.get('name') || '').trim();
  const owner = String(formData.get('owner') || '').trim();
  const motto = String(formData.get('motto') || '').trim();
  const recruitment = String(formData.get('recruitment') || '').trim();

  if (!state.name && state.permissions && state.permissions.canCreate === false) {
    const reason = state.permissions && typeof state.permissions.reason === 'string' && state.permissions.reason.trim() !== ''
      ? state.permissions.reason.trim()
      : DEFAULT_PERMISSION_MESSAGE;
    setFeedback(reason, 'error', 'setup');
    return;
  }

  if (!name || !owner) {
    setFeedback('Uzupełnij nazwę i właściciela.', 'error', 'setup');
    return;
  }

  setFeedback('Zapisywanie...', 'info', 'setup');
  postNui('create', { name, owner, motto, recruitment });
}

function handleFundsSubmit(event) {
  event.preventDefault();

  const submitter = event.submitter;
  const direction = submitter && submitter.dataset.direction ? submitter.dataset.direction : 'deposit';
  const form = event.currentTarget;
  const amountInput = form.querySelector('input[name="amount"]');
  const amount = amountInput ? Number(amountInput.value) : NaN;

  if (!amount || amount <= 0) {
    setFeedback('Podaj dodatnią kwotę.', 'error', 'funds');
    return;
  }

  setFeedback('Przetwarzanie operacji...', 'info', 'funds');
  postNui('adjustFunds', { amount, direction });
}

function handleNoteSubmit(event) {
  event.preventDefault();

  const form = event.currentTarget;
  const formData = new FormData(form);
  const note = String(formData.get('note') || '').trim();

  if (!note) {
    setFeedback('Dodaj treść notatki, aby zapisać.', 'error', 'note');
    return;
  }

  setFeedback('Zapisywanie...', 'info', 'note');
  postNui('updateNote', { note });
}

function bindInteractions() {
  const nav = document.querySelector('[data-page-nav]');
  if (nav) {
    nav.addEventListener('click', (event) => {
      const button = event.target.closest('[data-page-target]');
      if (!button) {
        return;
      }

      event.preventDefault();
      activatePage(button.dataset.pageTarget);
    });
  }

  document.querySelectorAll('[data-open-page]').forEach((element) => {
    element.addEventListener('click', () => {
      activatePage(element.dataset.openPage);
    });
  });

  const orgForm = document.getElementById('org-form');
  if (orgForm) {
    orgForm.addEventListener('submit', handleOrgFormSubmit);
  }

  const fundsForm = document.getElementById('funds-form');
  if (fundsForm) {
    fundsForm.addEventListener('submit', handleFundsSubmit);
  }

  const noteForm = document.getElementById('note-form');
  if (noteForm) {
    noteForm.addEventListener('submit', handleNoteSubmit);
  }

  const planForm = document.getElementById('plan-form');
  if (planForm) {
    planForm.addEventListener('submit', handlePlanSubmit);
  }

  const planRows = document.querySelector('[data-plan-rows]');
  if (planRows) {
    planRows.addEventListener('click', (event) => {
      const removeButton = event.target.closest('.plan-row__remove');
      if (!removeButton) {
        return;
      }

      event.preventDefault();
      const row = removeButton.closest('.plan-row');
      if (row) {
        row.remove();
      }

      if (planRows.querySelectorAll('.plan-row').length === 0) {
        appendPlanRow();
      }

      setFeedback('', 'info', 'plan');
    });
  }

  const addPlanButton = document.querySelector('[data-action="add-plan-row"]');
  if (addPlanButton) {
    addPlanButton.addEventListener('click', (event) => {
      event.preventDefault();
      appendPlanRow();
      setFeedback('', 'info', 'plan');
    });
  }

  document.querySelectorAll('[data-action="close"]').forEach((element) => {
    element.addEventListener('click', () => {
      postNui('close');
    });
  });

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') {
      postNui('close');
    }
  });
}

function bootstrap() {
  bindInteractions();
  syncPlanForm(state.dailyPlan);
  window.addEventListener('message', handleMessage);
  toggleVisibility(false);
  postNui('ready');
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', bootstrap);
} else {
  bootstrap();
}
