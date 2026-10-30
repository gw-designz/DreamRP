const container = document.getElementById('notifications');

const icons = {
    success: '✓',
    inform: '!',
    error: '×'
};

function createNotification(data) {
    let type = String(data.type || 'inform').toLowerCase();
    if (type === 'sucess') type = 'success';
    if (!icons[type]) type = 'inform';

    const duration = Math.max(500, Math.min(Number(data.duration) || 4000, 30000));

    const item = document.createElement('div');
    item.className = `notification ${type}`;

    const iconBox = document.createElement('div');
    iconBox.className = 'icon-box';

    const icon = document.createElement('span');
    icon.className = 'icon';
    icon.textContent = icons[type];

    const messageBox = document.createElement('div');
    messageBox.className = 'message-box';

    const message = document.createElement('span');
    message.className = 'message';
    message.textContent = String(data.message ?? '');

    iconBox.appendChild(icon);
    messageBox.appendChild(message);
    item.append(iconBox, messageBox);
    container.appendChild(item);

    requestAnimationFrame(() => requestAnimationFrame(() => item.classList.add('show')));

    setTimeout(() => {
        item.classList.remove('show');
        item.classList.add('hide');
        setTimeout(() => item.remove(), 320);
    }, duration);
}

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || data.action !== 'notify') return;
    createNotification(data);
});
