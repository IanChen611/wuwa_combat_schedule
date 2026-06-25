const CHAR_KEY = 'ww-rb-characters'
const ROTATION_KEY = 'ww-rb-rotation'

export function loadCharacters() {
  try {
    const raw = localStorage.getItem(CHAR_KEY)
    return raw ? JSON.parse(raw) : []
  } catch {
    return []
  }
}

export function saveCharacters(list) {
  localStorage.setItem(CHAR_KEY, JSON.stringify(list))
}

export function loadRotation() {
  try {
    const raw = localStorage.getItem(ROTATION_KEY)
    return raw ? JSON.parse(raw) : null
  } catch {
    return null
  }
}

export function saveRotation(rows) {
  localStorage.setItem(ROTATION_KEY, JSON.stringify(rows))
}
