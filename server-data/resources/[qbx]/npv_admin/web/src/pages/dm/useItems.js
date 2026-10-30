import { useEffect, useState } from 'react'
import { rpc } from '../../services/nui.js'

// ox_inventory item list ({ name, label }[]). Fetched once per page load and shared.
let cache = null
let pending = null

export function useItems() {
  const [items, setItems] = useState(cache)
  useEffect(() => {
    if (cache) return undefined
    let alive = true
    pending = pending || rpc('dm.items').then((res) => { cache = res.ok ? res.data : []; return cache })
    pending.then((list) => { if (alive) setItems(list) })
    return () => { alive = false }
  }, [])
  return items
}
