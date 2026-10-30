import { createApp } from 'vue'
import App from './App.vue'
import fivemAPI from "@/fivemAPI/fivemAPI";
import store from './store'

const app = createApp(App).use(store);
app.config.globalProperties.FivemAPI = fivemAPI;
app.config.globalProperties.$store = store;

app.mount('#app');
