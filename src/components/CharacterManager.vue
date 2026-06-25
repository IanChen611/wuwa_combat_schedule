<script setup>
import { ref, computed } from 'vue'
import { ELEMENTS, ACTION_PRESETS } from '../data/actions.js'

const props = defineProps({
  characters: { type: Array, required: true }
})
const emit = defineEmits(['update:characters', 'close'])

const actionIconTypes = ACTION_PRESETS

function emptyForm() {
  return { id: crypto.randomUUID(), name: '', element: 'none', icon: '', actionIcons: {} }
}

const form = ref(emptyForm())
const uploading = ref(false)
const uploadError = ref('')
const actionUploading = ref({})
const actionUploadError = ref({})

function resetForm() {
  form.value = emptyForm()
  uploadError.value = ''
  actionUploading.value = {}
  actionUploadError.value = {}
}

function readAsDataUrl(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(reader.result)
    reader.onerror = reject
    reader.readAsDataURL(file)
  })
}

async function uploadImage(file, { kind, action } = {}) {
  const dataUrl = await readAsDataUrl(file)
  const res = await fetch('/api/save-icon', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ dataUrl, characterId: form.value.id, kind, action })
  })
  const data = await res.json()
  if (!res.ok) throw new Error(data.error || '上傳失敗')
  return data.url
}

async function onFile(e) {
  const file = e.target.files[0]
  if (!file) return
  uploadError.value = ''
  uploading.value = true
  try {
    form.value.icon = await uploadImage(file, { kind: 'avatar' })
  } catch (err) {
    uploadError.value = `圖片儲存失敗：${err.message}`
  } finally {
    uploading.value = false
    e.target.value = ''
  }
}

async function onActionFile(actionName, e) {
  const file = e.target.files[0]
  if (!file) return
  actionUploadError.value = { ...actionUploadError.value, [actionName]: '' }
  actionUploading.value = { ...actionUploading.value, [actionName]: true }
  try {
    const url = await uploadImage(file, { kind: 'action', action: actionName })
    form.value.actionIcons = { ...form.value.actionIcons, [actionName]: url }
  } catch (err) {
    actionUploadError.value = { ...actionUploadError.value, [actionName]: `儲存失敗：${err.message}` }
  } finally {
    actionUploading.value = { ...actionUploading.value, [actionName]: false }
    e.target.value = ''
  }
}

function elementLabel(value) {
  return ELEMENTS.find((e) => e.value === value)?.label || ''
}

function elementColor(value) {
  return ELEMENTS.find((e) => e.value === value)?.color || '#888'
}

// form.id 一開始就會有值（用來對應上傳資料夾），所以用是否已存在於角色清單來判斷是新增還是編輯
const isEditing = computed(() => props.characters.some((c) => c.id === form.value.id))

function submit() {
  if (!form.value.name.trim()) return
  const list = [...props.characters]
  const entry = { ...form.value, actionIcons: { ...form.value.actionIcons } }
  const idx = list.findIndex((c) => c.id === entry.id)
  if (idx !== -1) list[idx] = entry
  else list.push(entry)
  emit('update:characters', list)
  resetForm()
}

function edit(c) {
  form.value = { ...c, actionIcons: { ...(c.actionIcons || {}) } }
  uploadError.value = ''
  actionUploading.value = {}
  actionUploadError.value = {}
}

function remove(c) {
  if (!confirm(`確定刪除角色「${c.name}」？`)) return
  emit('update:characters', props.characters.filter((x) => x.id !== c.id))
  if (form.value.id === c.id) resetForm()
}
</script>

<template>
  <div class="modal-backdrop" @click.self="$emit('close')">
    <div class="modal-panel">
      <div class="modal-header">
        <h2>角色管理</h2>
        <button class="icon-btn" @click="$emit('close')">✕</button>
      </div>

      <div class="char-form">
        <div class="char-form-icon">
          <img v-if="form.icon" :src="form.icon" class="char-avatar lg" />
          <span v-else class="char-avatar lg placeholder">?</span>
          <label class="upload-btn" :class="{ disabled: uploading }">
            {{ uploading ? '上傳中...' : '上傳圖片' }}
            <input type="file" accept="image/*" hidden :disabled="uploading" @change="onFile" />
          </label>
          <p v-if="uploadError" class="upload-error">{{ uploadError }}</p>
        </div>
        <div class="char-form-fields">
          <input v-model="form.name" class="text-input" placeholder="角色名稱" />
          <select v-model="form.element" class="text-input">
            <option v-for="el in ELEMENTS" :key="el.value" :value="el.value">{{ el.label }}</option>
          </select>
          <div class="char-form-actions">
            <button class="btn primary" @click="submit">{{ isEditing ? '更新角色' : '新增角色' }}</button>
            <button v-if="isEditing" class="btn" @click="resetForm">取消編輯</button>
          </div>
        </div>
      </div>

      <div class="action-icons-section">
        <h3>攻擊圖示（普攻、技能等，選填）</h3>
        <div class="action-icons-grid">
          <div v-for="a in actionIconTypes" :key="a" class="action-icon-item">
            <img v-if="form.actionIcons[a]" :src="form.actionIcons[a]" class="action-icon-thumb" />
            <span v-else class="action-icon-thumb placeholder">?</span>
            <span class="action-icon-name">{{ a }}</span>
            <label class="upload-btn small" :class="{ disabled: actionUploading[a] }">
              {{ actionUploading[a] ? '上傳中...' : form.actionIcons[a] ? '更換' : '上傳' }}
              <input
                type="file"
                accept="image/*"
                hidden
                :disabled="actionUploading[a]"
                @change="onActionFile(a, $event)"
              />
            </label>
            <p v-if="actionUploadError[a]" class="upload-error">{{ actionUploadError[a] }}</p>
          </div>
        </div>
      </div>

      <div class="char-list">
        <div v-for="c in characters" :key="c.id" class="char-list-item">
          <img v-if="c.icon" :src="c.icon" class="char-avatar" />
          <span v-else class="char-avatar placeholder">?</span>
          <span class="char-list-name">{{ c.name }}</span>
          <span class="char-list-element" :style="{ color: elementColor(c.element) }">
            {{ elementLabel(c.element) }}
          </span>
          <button class="icon-btn" @click="edit(c)">編輯</button>
          <button class="icon-btn danger" @click="remove(c)">刪除</button>
        </div>
        <p v-if="characters.length === 0" class="empty-hint">尚未新增任何角色，請用上方表單新增。</p>
      </div>
    </div>
  </div>
</template>
