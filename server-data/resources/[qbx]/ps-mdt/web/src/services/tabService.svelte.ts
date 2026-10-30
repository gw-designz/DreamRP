import type { ComponentId, MDTTab } from "../constants";
import { TAB_TO_COMPONENT_MAP } from "../constants";
import type { TabInstance } from "../interfaces/IMDT";
import {
	loadInstancesFromStorage,
	saveInstancesToStorage,
	validateSerializableData,
	validateInstanceCreation,
	validateTab,
} from "../utils/tabValidation";

export function createTabService() {
	let activeTab = $state<MDTTab>("Dashboard");
	let instances = $state<TabInstance[]>([]);

	// Per-instance navigation history for the header back/forward buttons.
	// Session-only: not persisted alongside the instances.
	let history = $state<Record<string, { stack: MDTTab[]; index: number }>>({});

	function recordHistory(instanceId: ComponentId, tab: MDTTab): void {
		const entry = history[instanceId];
		if (!entry) {
			history[instanceId] = { stack: [tab], index: 0 };
			return;
		}
		if (entry.stack[entry.index] === tab) return;
		entry.stack = [...entry.stack.slice(0, entry.index + 1), tab].slice(-50);
		entry.index = entry.stack.length - 1;
	}

	function stepHistory(instanceId: ComponentId, delta: number): void {
		const entry = history[instanceId];
		if (!entry) return;
		const next = entry.index + delta;
		if (next < 0 || next >= entry.stack.length) return;
		const instance = instances.find((i) => i.id === instanceId);
		if (!instance) return;
		entry.index = next;
		instance.currentTab = entry.stack[next];
	}

	// Load from localStorage on creation, preserving each instance's last tab
	instances = loadInstancesFromStorage();
	if (instances.length) {
		let hasActive = false;
		for (const instance of instances) {
			if (instance.isActive) {
				if (hasActive) {
					instance.isActive = false;
				} else {
					hasActive = true;
					activeTab = instance.currentTab || "Dashboard";
				}
			}
		}
		if (!hasActive) {
			instances[0].isActive = true;
			activeTab = instances[0].currentTab || "Dashboard";
		}
	}

	// Initialize with default instance if none exist
	$effect(() => {
		if (instances.length === 0) {
			instances.push({
				id: "instance-1" as ComponentId,
				instanceName: "Instance 1",
				currentTab: "Dashboard",
				isActive: true,
				data: undefined,
			});
		}
	});

	// Auto-save to localStorage when instances change
	$effect(() => {
		saveInstancesToStorage(instances);
	});

	return {
		get activeTab() {
			return activeTab;
		},

		get instances(): TabInstance[] {
			return instances;
		},

		setActiveTab(tab: MDTTab): void {
			activeTab = tab;
		},

		getActiveComponent(): ComponentId {
			try {
				// Get the active instance and return its current tab component
				const activeInstance = this.getActiveInstance();
				if (activeInstance) {
					const componentId = TAB_TO_COMPONENT_MAP[
						activeInstance.currentTab as keyof typeof TAB_TO_COMPONENT_MAP
					] as ComponentId;
					if (!componentId) {
						console.warn(
							`MDT: Unknown tab '${activeInstance.currentTab}', using Dashboard`,
						);
						return TAB_TO_COMPONENT_MAP["Dashboard"];
					}
					return componentId;
				}
				// Fallback to global active tab if no instance is active
				const fallbackComponent = TAB_TO_COMPONENT_MAP[activeTab];
				if (!fallbackComponent) {
					console.warn(
						`MDT: Unknown tab '${activeTab}', using Dashboard`,
					);
					return TAB_TO_COMPONENT_MAP["Dashboard"];
				}
				return fallbackComponent;
			} catch (error) {
				console.error("MDT: Error getting component:", error);
				return TAB_TO_COMPONENT_MAP["Dashboard"];
			}
		},

		// Set the current tab for a specific instance
		setInstanceTab(instanceId: ComponentId, tab: MDTTab): void {
			if (!validateTab(tab)) {
				return;
			}

			const instance = instances.find(
				(instance) => instance.id === instanceId,
			);
			if (instance) {
				if (!history[instanceId]) recordHistory(instanceId, instance.currentTab);
				instance.currentTab = tab;
				recordHistory(instanceId, tab);
			} else {
				console.warn(`MDT: Instance '${instanceId}' not found`);
			}
		},

		canGoBack(): boolean {
			const inst = this.getActiveInstance();
			const entry = inst ? history[inst.id] : undefined;
			return !!entry && entry.index > 0;
		},

		canGoForward(): boolean {
			const inst = this.getActiveInstance();
			const entry = inst ? history[inst.id] : undefined;
			return !!entry && entry.index < entry.stack.length - 1;
		},

		goBack(): void {
			const inst = this.getActiveInstance();
			if (inst) stepHistory(inst.id, -1);
		},

		goForward(): void {
			const inst = this.getActiveInstance();
			if (inst) stepHistory(inst.id, 1);
		},

		// Open a page in a brand-new instance tab and focus it
		openInNewInstance(tab: MDTTab): ComponentId | undefined {
			if (!validateTab(tab)) return undefined;
			const id = `instance-${Date.now()}` as ComponentId;
			this.addInstance(id, `Instance ${instances.length + 1}`);
			this.setInstanceTab(id, tab);
			return id;
		},

		// Get the current tab for a specific instance
		getInstanceTab(instanceId: ComponentId): MDTTab | undefined {
			const instance = instances.find(
				(instance) => instance.id === instanceId,
			);
			return instance?.currentTab;
		},

		// Get the current tab for the active instance
		getActiveInstanceTab(): MDTTab {
			const activeInstance = this.getActiveInstance();
			return activeInstance?.currentTab || activeTab;
		},

		addInstance(id: ComponentId, instanceName: string, data?: any): void {
			// Security validation first
			if (!validateInstanceCreation(id, instanceName)) {
				return;
			}

			// Check if instance already exists
			const existingInstance = instances.find(
				(instance) => instance.id === id,
			);
			if (existingInstance) {
				// If it exists, just make it active
				this.setActiveInstance(id);
				return;
			}

			// Validate and clean data if provided
			const validatedData = validateSerializableData(data);

			// Deactivate all other instances
			instances.forEach((instance) => (instance.isActive = false));

			// Add new instance - always starts on Dashboard
			const newInstance: TabInstance = {
				id,
				instanceName,
				currentTab: "Dashboard",
				isActive: true,
				data: validatedData,
			};

			instances.push(newInstance);
		},

		removeInstance(id: ComponentId): void {
			const instanceIndex = instances.findIndex(
				(instance) => instance.id === id,
			);
			if (instanceIndex === -1) {
				console.warn(`MDT: Instance '${id}' not found`);
				return;
			}

			const removedInstance = instances[instanceIndex];
			instances.splice(instanceIndex, 1);
			delete history[id];

			// If we removed the active instance, activate another one
			if (removedInstance.isActive && instances.length > 0) {
				// Activate the instance to the left, or the first instance if we removed the first one
				const newActiveIndex = Math.max(0, instanceIndex - 1);
				instances[newActiveIndex].isActive = true;
			}
		},

		setActiveInstance(id: ComponentId): void {
			const targetInstance = instances.find(
				(instance) => instance.id === id,
			);
			if (!targetInstance) {
				console.warn(`MDT: Instance '${id}' not found`);
				return;
			}

			instances.forEach((instance) => {
				instance.isActive = instance.id === id;
			});
		},

		getActiveInstance(): TabInstance | undefined {
			return instances.find((instance) => instance.isActive);
		},

		hasInstance(id: ComponentId): boolean {
			return instances.some((instance) => instance.id === id);
		},

		updateInstanceName(id: ComponentId, instanceName: string): void {
			const instance = instances.find((instance) => instance.id === id);
			if (instance) {
				instance.instanceName = instanceName;
			} else {
				console.warn(`MDT: Instance '${id}' not found`);
			}
		},

		updateInstanceData(id: ComponentId, data: any): void {
			// Validate and clean data if provided
			const validatedData = validateSerializableData(data);

			const instance = instances.find((instance) => instance.id === id);
			if (instance) {
				instance.data = validatedData;
			} else {
				console.warn(`MDT: Instance '${id}' not found`);
			}
		},

		getInstanceData(id: ComponentId): any {
			const instance = instances.find((instance) => instance.id === id);
			return instance?.data;
		},

		clearAll(): void {
			instances.length = 0;
		},
	};
}

export type TabService = ReturnType<typeof createTabService>;

// Re-export TabInstance for convenience
export type { TabInstance } from "../interfaces/IMDT";
