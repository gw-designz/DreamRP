const resourceName = typeof GetParentResourceName === "function" ? GetParentResourceName() : "karma-progressbar";
const body = document.body;
const progressLabel = document.getElementById("progress-label");
const progressFill = document.getElementById("progress-fill");

let progressFrame = 0;
let progressStartedAt = 0;
let progressDuration = 0;

function post(name, payload = {}) {
    return fetch(`https://${resourceName}/${name}`, {
        method: "POST",
        headers: { "Content-Type": "application/json; charset=UTF-8" },
        body: JSON.stringify(payload)
    });
}

function startProgress(payload) {
    cancelAnimationFrame(progressFrame);
    progressDuration = Math.max(1, Number(payload.duration) || 1);
    progressStartedAt = performance.now();
    progressLabel.textContent = payload.label || "PROGRESS...";
    progressFill.style.width = "0%";
    body.classList.add("progress-active");

    const tick = (now) => {
        const progress = Math.min(1, (now - progressStartedAt) / progressDuration);
        progressFill.style.width = `${progress * 100}%`;

        if (progress < 1 && body.classList.contains("progress-active")) {
            progressFrame = requestAnimationFrame(tick);
        }
    };

    progressFrame = requestAnimationFrame(tick);
}

function stopProgress() {
    cancelAnimationFrame(progressFrame);
    progressFill.style.width = "0%";
    body.classList.remove("progress-active");
}

document.addEventListener("keydown", (event) => {
    if (!body.classList.contains("progress-active") || event.key !== "Escape") return;

    event.preventDefault();
    post("progressCancel");
    stopProgress();
});

window.addEventListener("message", (event) => {
    const payload = event.data || {};

    switch (payload.action) {
        case "progress:start":
            startProgress(payload);
            break;
        case "progress:stop":
            stopProgress();
            break;
        default:
            break;
    }
});
