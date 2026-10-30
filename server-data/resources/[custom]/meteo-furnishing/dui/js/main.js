function hexToRgb(hex) {
    hex = hex.replace('#', '');
    if (hex.length === 3) {
        hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2];
    }
    var r = parseInt(hex.substring(0, 2), 16);
    var g = parseInt(hex.substring(2, 4), 16);
    var b = parseInt(hex.substring(4, 6), 16);
    return r + ', ' + g + ', ' + b;
}

function updateDisplay(org) {
    if (!org) return;

    var display = document.getElementById('display');
    var color = org.color || '#57EFAF';
    var colorRgb = hexToRgb(color);

    display.style.setProperty('--color', color);
    display.style.setProperty('--color-rgb', colorRgb);

    document.getElementById('orgTag').textContent = org.tag || '';
    document.getElementById('orgName').textContent = org.name || '';
    document.getElementById('orgLevel').textContent = org.level || 1;

    display.classList.add('visible');
}

window.addEventListener('message', function(event) {
    var data = event.data;
    if (data.action === 'update') {
        updateDisplay(data.org);
    }
});
