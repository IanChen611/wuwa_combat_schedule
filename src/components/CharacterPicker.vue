<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'

const props = defineProps({
  characters: { type: Array, required: true },
  modelValue: { type: String, default: '' }
})
const emit = defineEmits(['update:modelValue'])

const root = ref(null)
const open = ref(false)
const query = ref('')

const filtered = computed(() => {
  const q = query.value.trim()
  if (!q) return props.characters
  return props.characters.filter((c) => c.name.includes(q))
})

const selected = computed(() => props.characters.find((c) => c.id === props.modelValue))

function select(c) {
  emit('update:modelValue', c.id)
  open.value = false
  query.value = ''
}

function toggle() {
  open.value = !open.value
}

function onDocClick(e) {
  if (root.value && !root.value.contains(e.target)) open.value = false
}

onMounted(() => document.addEventListener('click', onDocClick))
onUnmounted(() => document.removeEventListener('click', onDocClick))
</script>

<template>
  <div class="char-picker" ref="root">
    <button class="char-picker-trigger" type="button" @click="toggle">
      <img v-if="selected?.icon" :src="selected.icon" class="char-avatar" />
      <span v-else class="char-avatar placeholder">?</span>
      <span class="char-name">{{ selected?.name || '選擇角色' }}</span>
    </button>

    <div v-if="open" class="char-picker-panel">
      <input v-model="query" class="char-picker-search" placeholder="搜尋角色名稱..." autofocus />
      <div class="char-picker-list">
        <button
          v-for="c in filtered"
          :key="c.id"
          class="char-picker-item"
          type="button"
          @click="select(c)"
        >
          <img v-if="c.icon" :src="c.icon" class="char-avatar" />
          <span v-else class="char-avatar placeholder">?</span>
          <span>{{ c.name }}</span>
        </button>
        <p v-if="filtered.length === 0" class="char-picker-empty">
          沒有符合的角色，請先到「角色管理」新增。
        </p>
      </div>
    </div>
  </div>
</template>
