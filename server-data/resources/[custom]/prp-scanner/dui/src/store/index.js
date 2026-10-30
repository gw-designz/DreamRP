import { createStore } from 'vuex'
import os from "@/store/os.store";

export default createStore({
    state: {
        isDev: process.env.NODE_ENV !== "production",
    },
    modules: {
        os,
    }
})
