// The browser side of the anonymous bookmark backend. localStorage holds the
// list's token (the only credential) plus a cache of the keys, which paints
// instantly on load and stands in whenever the backend is unreachable.
// All functions return { token, keys } (keys as a Set) or null on failure.

const BOOKMARKS_KEY = "ibk-dashboard-bookmarks"
const TOKEN_KEY = "ibk-dashboard-bookmark-token"

export function cachedKeys() {
  try {
    return new Set(JSON.parse(localStorage.getItem(BOOKMARKS_KEY)) ?? [])
  } catch {
    return new Set()
  }
}

export function cacheKeys(keys) {
  localStorage.setItem(BOOKMARKS_KEY, JSON.stringify([...keys]))
}

export function storedToken() {
  return localStorage.getItem(TOKEN_KEY)
}

// Fetch the list for this browser's token; null when there is no token yet.
export async function pull() {
  const token = storedToken()
  if (!token) return null
  return request(`/bookmarks?token=${encodeURIComponent(token)}`, "GET")
}

// Apply a change. When this browser has no list yet, the backend creates one
// and we seed it with the whole cache — which also migrates bookmarks saved
// back when they lived only in localStorage.
export async function push({ add = [], remove = [] } = {}) {
  const token = storedToken()
  const body = token
    ? { token, add, remove }
    : { add: [...new Set([...cachedKeys(), ...add])].filter((key) => !remove.includes(key)) }
  return request("/bookmarks", "PATCH", body)
}

// Device sync: pour this browser's list into the shared one (from the sync
// link) and use that list from then on.
export async function merge(other) {
  return request("/bookmarks/merge", "POST", { token: storedToken(), other })
}

async function request(path, method, body) {
  try {
    const response = await fetch(path, {
      method,
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content
      },
      body: body ? JSON.stringify(body) : undefined
    })
    if (!response.ok) return null
    return adopt(await response.json())
  } catch {
    return null
  }
}

function adopt({ token, keys }) {
  localStorage.setItem(TOKEN_KEY, token)
  const set = new Set(keys)
  cacheKeys(set)
  return { token, keys: set }
}
