import { fileURLToPath } from 'node:url'
import path from 'node:path'
import fs from 'node:fs'
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const ICONS_DIR = path.join(__dirname, 'public', 'icons')

const EXT_BY_MIME = {
  'image/png': 'png',
  'image/jpeg': 'jpg',
  'image/webp': 'webp',
  'image/gif': 'gif',
  'image/svg+xml': 'svg'
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

function sanitizeName(name) {
  const cleaned = String(name || '').replace(/[\\/:*?"<>|]/g, '').trim()
  return cleaned || 'icon'
}

// 開發伺服器專用的小型 API：把玩家上傳的角色縮圖／攻擊招式圖示，
// 依角色 ID 分資料夾實際寫進 public/icons/<characterId>/，
// 而不是只存在瀏覽器的 localStorage 裡。
function saveIconPlugin() {
  return {
    name: 'save-icon-middleware',
    configureServer(server) {
      server.middlewares.use('/api/save-icon', (req, res) => {
        if (req.method !== 'POST') {
          res.statusCode = 405
          res.end('Method Not Allowed')
          return
        }

        let body = ''
        req.on('data', (chunk) => {
          body += chunk
        })
        req.on('end', () => {
          try {
            const { dataUrl, characterId, kind, action } = JSON.parse(body)

            if (!UUID_RE.test(characterId || '')) throw new Error('角色 ID 無效')

            const match = /^data:(image\/[\w.+-]+);base64,(.+)$/.exec(dataUrl || '')
            if (!match) throw new Error('不是有效的圖片資料')

            const ext = EXT_BY_MIME[match[1]] || 'png'
            const filename = kind === 'action' ? `${sanitizeName(action)}.${ext}` : `avatar.${ext}`

            const charDir = path.join(ICONS_DIR, characterId)
            fs.mkdirSync(charDir, { recursive: true })

            // 重新上傳同一個圖示時，先清掉舊檔（副檔名可能不同）避免殘留
            const targetBase = filename.slice(0, filename.lastIndexOf('.'))
            for (const f of fs.readdirSync(charDir)) {
              if (f.slice(0, f.lastIndexOf('.')) === targetBase) fs.unlinkSync(path.join(charDir, f))
            }

            fs.writeFileSync(path.join(charDir, filename), Buffer.from(match[2], 'base64'))

            res.setHeader('Content-Type', 'application/json')
            res.end(JSON.stringify({ url: `/icons/${characterId}/${filename}` }))
          } catch (err) {
            res.statusCode = 400
            res.setHeader('Content-Type', 'application/json')
            res.end(JSON.stringify({ error: err.message }))
          }
        })
      })
    }
  }
}

export default defineConfig({
  plugins: [vue(), saveIconPlugin()],
  server: {
    port: 5173,
    strictPort: true
  }
})
