<script setup>
import { ref, computed, watch } from 'vue'
import CharacterPicker from './components/CharacterPicker.vue'
import ActionPicker from './components/ActionPicker.vue'
import CharacterManager from './components/CharacterManager.vue'
import { ACTION_PRESETS, LONG_PRESSABLE_ACTIONS, ACTION_ICONS } from './data/actions.js'
import { CHARACTER_SEED_NAMES } from './data/characterSeed.js'
import { loadCharacters, saveCharacters, loadRotation, saveRotation } from './storage.js'

function withSeedCharacters(list) {
  const existingNames = new Set(list.map((c) => c.name))
  const seeded = CHARACTER_SEED_NAMES.filter((name) => !existingNames.has(name)).map((name) => ({
    id: crypto.randomUUID(),
    name,
    element: 'none',
    icon: `/photo/${name}.png`,
    actionIcons: {}
  }))
  return [...list, ...seeded]
}

const characters = ref(withSeedCharacters(loadCharacters()))
const showManager = ref(false)
const importInput = ref(null)

function newRow() {
  return { rowId: crypto.randomUUID(), characterId: '', action: '', longPress: false, comment: '' }
}

const rows = ref(loadRotation() || [newRow()])

watch(characters, (list) => saveCharacters(list), { deep: true })
watch(rows, (list) => saveRotation(list), { deep: true })

function onCharactersUpdate(list) {
  characters.value = list
}

function addRow() {
  rows.value.push(newRow())
}

function insertRow(index) {
  rows.value.splice(index + 1, 0, newRow())
}

function removeRow(index) {
  rows.value.splice(index, 1)
  if (rows.value.length === 0) rows.value.push(newRow())
}

function duplicateRow(index) {
  const copy = { ...rows.value[index], rowId: crypto.randomUUID() }
  rows.value.splice(index + 1, 0, copy)
}

function clearAll() {
  if (!confirm('確定要清空整個排軸表嗎？此動作無法復原。')) return
  rows.value = [newRow()]
}

const dragIndex = ref(null)
function onDragStart(index) {
  dragIndex.value = index
}
function onDrop(index) {
  if (dragIndex.value === null || dragIndex.value === index) return
  const list = [...rows.value]
  const [item] = list.splice(dragIndex.value, 1)
  list.splice(index, 0, item)
  rows.value = list
  dragIndex.value = null
}

function characterName(id) {
  return characters.value.find((c) => c.id === id)?.name || ''
}

function actionLabel(row) {
  const base = row.longPress && LONG_PRESSABLE_ACTIONS.includes(row.action) ? `長按${row.action}` : row.action
  const match = row.comment?.trim().match(/^\*\d+$/)
  return match ? `${base} ${match[0]}` : base
}

function actionIcons(row) {
  const c = characters.value.find((x) => x.id === row.characterId)
  return { ...ACTION_ICONS, ...(c?.actionIcons || {}) }
}

const sequenceItems = computed(() => {
  let lastCharacterId = null
  return rows.value
    .filter((r) => r.characterId)
    .map((r) => {
      const c = characters.value.find((x) => x.id === r.characterId)
      const showAvatar = r.characterId !== lastCharacterId
      lastCharacterId = r.characterId
      const isNumComment = /^\*\d+$/.test(r.comment?.trim() || '')
      return {
        rowId: r.rowId,
        avatar: c?.icon || '',
        name: c?.name || '',
        actionIcon: c?.actionIcons?.[r.action] || ACTION_ICONS[r.action] || '',
        actionText: actionLabel(r) || '',
        comment: !isNumComment && r.comment ? r.comment : '',
        showAvatar
      }
    })
})

function copyAsText() {
  const lines = rows.value.map((r, i) => {
    const name = characterName(r.characterId) || '（未選角色）'
    const action = actionLabel(r) || '（未設定動作）'
    const comment = r.comment ? `  // ${r.comment}` : ''
    return `${i + 1}. ${name} - ${action}${comment}`
  })
  navigator.clipboard
    .writeText(lines.join('\n'))
    .then(() => alert('已複製排軸內容到剪貼簿！'))
    .catch(() => alert('複製失敗，請手動選取文字複製。'))
}

function exportJson() {
  const payload = { characters: characters.value, rotation: rows.value }
  const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `rotation-${new Date().toISOString().slice(0, 10)}.json`
  a.click()
  URL.revokeObjectURL(url)
}

function triggerImport() {
  importInput.value.click()
}

function onImportFile(e) {
  const file = e.target.files[0]
  if (!file) return
  const reader = new FileReader()
  reader.onload = () => {
    try {
      const data = JSON.parse(reader.result)
      if (Array.isArray(data.characters)) characters.value = data.characters
      if (Array.isArray(data.rotation)) rows.value = data.rotation
    } catch {
      alert('檔案格式錯誤，匯入失敗。')
    }
  }
  reader.readAsText(file)
  e.target.value = ''
}
</script>

<template>
  <div class="app-shell">
    <header class="app-header">
      <h1>鳴潮排軸工具</h1>
      <div class="header-actions">
        <button class="btn" @click="showManager = true">角色管理</button>
      </div>
    </header>

    <div class="toolbar">
      <button class="btn primary" @click="addRow">＋ 新增一行</button>
      <button class="btn" @click="copyAsText">複製為文字</button>
      <button class="btn" @click="exportJson">匯出 JSON</button>
      <button class="btn" @click="triggerImport">匯入 JSON</button>
      <input ref="importInput" type="file" accept="application/json" hidden @change="onImportFile" />
      <button class="btn danger" @click="clearAll">清空</button>
    </div>

    <div class="rotation-table">
      <div class="rotation-row rotation-head">
        <span class="col-drag"></span>
        <span class="col-index">#</span>
        <span class="col-char">角色</span>
        <span class="col-action">動作</span>
        <span class="col-comment">備註</span>
        <span class="col-ops">操作</span>
      </div>

      <div
        v-for="(row, index) in rows"
        :key="row.rowId"
        class="rotation-row"
        draggable="true"
        @dragstart="onDragStart(index)"
        @dragover.prevent
        @drop="onDrop(index)"
      >
        <span class="col-drag drag-handle" title="拖曳排序">⠿</span>
        <span class="col-index">{{ index + 1 }}</span>
        <span class="col-char">
          <CharacterPicker :characters="characters" v-model="row.characterId" />
        </span>
        <span class="col-action">
          <ActionPicker
            :options="ACTION_PRESETS"
            :icons="actionIcons(row)"
            :longPressable="LONG_PRESSABLE_ACTIONS"
            v-model="row.action"
            v-model:longPress="row.longPress"
          />
        </span>
        <span class="col-comment">
          <input v-model="row.comment" class="text-input" placeholder="備註（選填）" />
        </span>
        <span class="col-ops">
          <button class="icon-btn" title="在下方插入一行" @click="insertRow(index)">＋</button>
          <button class="icon-btn" title="複製此行" @click="duplicateRow(index)">⧉</button>
          <button class="icon-btn danger" title="刪除此行" @click="removeRow(index)">✕</button>
        </span>
      </div>
    </div>

    <section v-if="sequenceItems.length" class="sequence-section">
      <h2 class="sequence-title">排軸順序預覽</h2>
      <div class="sequence-strip">
        <template v-for="(item, i) in sequenceItems" :key="item.rowId">
          <div class="sequence-item" :title="`${item.name || '未選角色'} - ${item.actionText || '未設定動作'}`">
            <div class="sequence-main">
              <template v-if="item.showAvatar">
                <img v-if="item.avatar" :src="item.avatar" class="char-avatar" />
                <span v-else class="char-avatar placeholder">?</span>
              </template>
              <div class="sequence-action">
                <img v-if="item.actionIcon" :src="item.actionIcon" class="sequence-action-icon" />
                <span class="sequence-action-text"
                  >{{ item.actionText || '?' }}<span v-if="item.comment" class="sequence-comment">({{ item.comment }})</span></span
                >
              </div>
            </div>
          </div>
          <span v-if="i < sequenceItems.length - 1" class="sequence-arrow">▶</span>
        </template>
      </div>
    </section>

    <CharacterManager
      v-if="showManager"
      :characters="characters"
      @update:characters="onCharactersUpdate"
      @close="showManager = false"
    />
  </div>
</template>
