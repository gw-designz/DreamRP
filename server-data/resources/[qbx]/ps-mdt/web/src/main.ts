import { mount } from "svelte";
import "material-icons/iconfont/filled.css";
import "@fontsource-variable/inter";
import "@/styles/tailwind.css";
import "./styles/variables.css";
import "./styles/globals.css";
import "./styles/records.css";
import App from "./App.svelte";
import { installSelectMenus } from "./utils/selectMenu";

installSelectMenus();

const app = mount(App, {
	target: document.getElementById("app")!,
});

export default app;
