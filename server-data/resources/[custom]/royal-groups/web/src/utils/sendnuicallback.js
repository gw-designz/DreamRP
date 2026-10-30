import isEnvBrowser from './isEnvBrowser';

const SendNuiCallback = async (endpoint, data = {}, cb) => {
    if (isEnvBrowser()) {
        if (cb) cb({});
        return {};
    }

    try {
        const response = await fetch(`https://${GetParentResourceName()}/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data || {}),
        });
        const responseData = await response.json();
        if (cb) cb(responseData);
        return responseData;
    } catch (error) {
        console.error('Callback Error:', error);
        if (cb) cb(null);
        return null;
    }
};

export default SendNuiCallback;
