import store from "../store";
const RESOURCE_PATH = `https://prp-heists/`;

class FivemAPI {
    constructor() {
        this.log = store.state.isDev;

        window.addEventListener('message', event => {
            const eventType = event.data.event;
            if (eventType !== undefined && typeof this['on_' + eventType] === 'function') {
                this['on_' + eventType](event.data);
            }
        });
    }

    async postInternal(path, method, data, json=false) {
        data = data === undefined ? '{}' : JSON.stringify(data);

        if(process.env.NODE_ENV !== "production") return;
        const resp = await fetch(path + method, {body: data, method: "POST"});

        if(json) {
            return await resp.json();
        }
        return await resp.text();
    }

    async post(method, data=undefined, json=true) {
        return this.postInternal(RESOURCE_PATH, method, data, json);
    }

    async postForResource(resource, method, data, json) {
        return this.postInternal(`https://${resource}/`, method, data, json);
    }

    async on_sendAppEvent({app, action, payload}) {
        await store.dispatch(`${app}/${action}`, payload);
    }
}

export default new FivemAPI();