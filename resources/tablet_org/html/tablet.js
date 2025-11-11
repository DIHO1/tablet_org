const RESOURCE_NAME = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'tablet_org';

const state = {
  name: null,
  owner: null,
  createdAt: null,
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

function formatDate(isoString) {
  if (!isoString) {
    return 'Brak';
  }

  const date = new Date(isoString);
  if (Number.isNaN(date.getTime())) {
    return 'Brak';
  }

  return date.toLocaleString('pl-PL', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function setTextContent(selector, value) {
  const element = typeof selector === 'string' ? document.querySelector(selector) : selector;
  if (!element) return;
  element.textContent = value;
}

function toggleVisibility(visible) {
  document.body.classList.toggle('tablet--hidden', !visible);
}

function renderOrganization(data) {
  const organization = data || state;
  const hasOrganization = Boolean(organization.name);

  setTextContent('[data-org-name]', hasOrganization ? organization.name : 'Brak organizacji');
  setTextContent('[data-org-status]', hasOrganization ? 'Aktywna' : 'Nieaktywna');
  setTextContent(
    '[data-org-message]',
    hasOrganization
      ? `Panel aktywny dla organizacji „${organization.name}”.`
      : 'Skonfiguruj swoją organizację, aby odblokować pełny panel.'
  );
  document
    .querySelectorAll('[data-org-owner]')
    .forEach((element) => setTextContent(element, organization.owner || 'Nie przypisano'));
  setTextContent('[data-org-created]', formatDate(organization.createdAt));

  const form = document.getElementById('org-form');
  if (!form) return;

  const nameInput = form.querySelector('input[name="name"]');
  const ownerInput = form.querySelector('input[name="owner"]');
  const submitButton = form.querySelector('button[type="submit"]');

  if (hasOrganization) {
    if (nameInput) {
      nameInput.value = organization.name;
      nameInput.readOnly = true;
    }

    if (ownerInput && organization.owner) {
      ownerInput.value = organization.owner;
    }

    if (submitButton) {
      submitButton.textContent = 'Aktualizuj właściciela';
    }
  } else {
    if (nameInput) {
      nameInput.value = 'Best';
      nameInput.readOnly = false;
    }

    if (ownerInput) {
      ownerInput.value = '';
    }

    if (submitButton) {
      submitButton.textContent = 'Utwórz organizację';
    }
  }
}

function showFeedback(message, type = 'info') {
  const feedback = document.querySelector('[data-feedback]');
  if (!feedback) return;

  feedback.textContent = message || '';
  feedback.classList.remove('config-form__feedback--error', 'config-form__feedback--success');

  if (type === 'error') {
    feedback.classList.add('config-form__feedback--error');
  } else if (type === 'success') {
    feedback.classList.add('config-form__feedback--success');
  }
}

function syncState(newState) {
  const incoming = newState || {};

  state.name = typeof incoming.name === 'undefined' ? null : incoming.name;
  state.owner = typeof incoming.owner === 'undefined' ? null : incoming.owner;
  state.createdAt = typeof incoming.createdAt === 'undefined' ? null : incoming.createdAt;

  renderOrganization(state);
}

function handleMessage(event) {
  const payload = event.data || {};

  if (payload.action === 'open') {
    if (payload.data) {
      syncState(payload.data);
    }

    showFeedback('');
    toggleVisibility(true);
    return;
  }

  if (payload.action === 'close') {
    toggleVisibility(false);
    showFeedback('');
    return;
  }

  if (payload.action === 'notify') {
    if (payload.type === 'error') {
      showFeedback(payload.message || 'Wystąpił błąd.', 'error');
    } else if (payload.message) {
      showFeedback(payload.message, 'success');
    }
    return;
  }

  if (payload.action === 'update') {
    if (payload.data) {
      syncState(payload.data);
    }
  }

  if (payload.message) {
    showFeedback(payload.message, 'success');
  }

  if (payload.error) {
    showFeedback(payload.error, 'error');
  }
}

function handleFormSubmit(event) {
  event.preventDefault();

  const form = event.currentTarget;
  const formData = new FormData(form);
  const name = String(formData.get('name') || '').trim();
  const owner = String(formData.get('owner') || '').trim();

  if (!name || !owner) {
    showFeedback('Uzupełnij wszystkie pola formularza.', 'error');
    return;
  }

  showFeedback('Zapisywanie...', 'info');
  postNui('create', { name, owner });
}

function bindInteractions() {
  const form = document.getElementById('org-form');
  if (form) {
    form.addEventListener('submit', handleFormSubmit);
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
  window.addEventListener('message', handleMessage);
  toggleVisibility(false);
  postNui('ready');
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', bootstrap);
} else {
  bootstrap();
}
