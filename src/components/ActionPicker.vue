<script setup>
const props = defineProps({
  options: { type: Array, required: true },
  icons: { type: Object, default: () => ({}) },
  modelValue: { type: String, default: '' },
  longPress: { type: Boolean, default: false },
  longPressable: { type: Array, default: () => [] }
})
const emit = defineEmits(['update:modelValue', 'update:longPress'])

function select(a) {
  emit('update:modelValue', a)
  emit('update:longPress', false)
}

function selectLongPress(a) {
  if (!props.longPressable.includes(a)) return
  emit('update:modelValue', a)
  emit('update:longPress', true)
}
</script>

<template>
  <div class="action-picker">
    <button
      v-for="a in options"
      :key="a"
      type="button"
      class="action-picker-item"
      :class="{ active: modelValue === a && !longPress, 'long-press': modelValue === a && longPress }"
      @click="select(a)"
      @contextmenu.prevent="selectLongPress(a)"
    >
      <img v-if="icons[a]" :src="icons[a]" class="action-picker-icon" />
      <span v-else class="action-picker-icon placeholder">?</span>
      <span class="action-picker-label">{{ a }}</span>
    </button>
  </div>
</template>
