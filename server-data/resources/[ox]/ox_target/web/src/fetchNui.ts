declare function GetParentResourceName(): string;

const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'ox_target';

export async function fetchNui<T = unknown>(eventName: string, data?: unknown): Promise<T | null> {
  try {
    const resp = await fetch(`https://${resourceName}/${eventName}`, {
      method: 'post',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data),
    });

    return await resp.json();
  } catch {
    return null;
  }
}
