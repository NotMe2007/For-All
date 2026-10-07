// SeneX icon pack builder.
//   cd "My own rayfield/icons-src" && npm install && node build_icons.mjs
//
// Renders every Lucide icon (lucide-static) to white 48 px PNG cells on 1000x1000
// sprite sheets, copies the non-icon UI images (shadows / gradient / dot), renders a
// SeneX banner, and writes ../icons/pack.json - the index SeneX (GUI.lua) downloads
// once into the executor's SeneX/icons folder and then loads icons from by name.
//
// White strokes on transparency so the UI can tint them with ImageColor3.
// Bump PACK_VERSION whenever the layout or the icon set changes, then bump
// ICON_PACK_VERSION in GUI.lua to the same number so clients re-download.
import fs from 'node:fs'
import path from 'node:path'
import { createRequire } from 'node:module'
import { fileURLToPath } from 'node:url'
import { Resvg } from '@resvg/resvg-js'
import { PNG } from 'pngjs'

const PACK_VERSION = 1
const CELL = 48   // rendered icon size (px)
const PITCH = 50  // cell + 1 px transparent gutter on each side (no bleeding when scaled)
const COLS = 20   // 20 x 20 cells = 1000 x 1000 px per sheet
const PER_SHEET = COLS * COLS

const require = createRequire(import.meta.url)
const here = path.dirname(fileURLToPath(import.meta.url))
const lucideDir = path.dirname(require.resolve('lucide-static/package.json'))
const lucideVersion = JSON.parse(fs.readFileSync(path.join(lucideDir, 'package.json'), 'utf8')).version
const iconDir = path.join(lucideDir, 'icons')
const outDir = path.join(here, '..', 'icons')
fs.mkdirSync(outDir, { recursive: true })

// Inner markup of an icon svg (everything between <svg ...> and </svg>).
const inner = (svg) => svg.slice(svg.indexOf('>', svg.indexOf('<svg')) + 1, svg.lastIndexOf('</svg>')).trim()

// 1. Canonical icons = icon-nodes.json keys; other svg files are aliases (same drawing).
const canonical = Object.keys(JSON.parse(fs.readFileSync(path.join(lucideDir, 'icon-nodes.json'), 'utf8'))).sort()
const canonicalSet = new Set(canonical)
const body = {}
for (const file of fs.readdirSync(iconDir)) {
	if (file.endsWith('.svg')) body[file.slice(0, -4)] = inner(fs.readFileSync(path.join(iconDir, file), 'utf8'))
}
const byBody = new Map()
for (const name of canonical) {
	if (!body[name]) throw new Error('missing svg for ' + name)
	if (!byBody.has(body[name])) byBody.set(body[name], name)
}
const aliases = {}
for (const name of Object.keys(body).sort()) {
	if (canonicalSet.has(name)) continue
	const target = byBody.get(body[name])
	if (target) aliases[name] = target
	else console.warn('alias without a matching drawing, skipped:', name)
}

// 2. Sprite sheets: one big svg per sheet with every icon as a nested <svg>.
// Render to a white grey+alpha PNG: only the alpha channel carries the drawing, and the
// colour stays white even where alpha is 0, so scaled / filtered edges never pick up a
// dark fringe. Grey+alpha is also ~3x smaller than resvg's RGBA output.
const render = (svg, opts = {}) => {
	const image = new Resvg(svg, { background: 'rgba(0,0,0,0)', ...opts }).render()
	const rgba = Buffer.from(image.pixels)
	for (let i = 0; i < rgba.length; i += 4) rgba[i] = rgba[i + 1] = rgba[i + 2] = 255
	const png = new PNG({ width: image.width, height: image.height })
	png.data = rgba
	return PNG.sync.write(png, { colorType: 4, inputColorType: 6, deflateLevel: 9 })
}
const sheets = []
for (let s = 0; s * PER_SHEET < canonical.length; s++) {
	const names = canonical.slice(s * PER_SHEET, (s + 1) * PER_SHEET)
	const rows = Math.ceil(names.length / COLS)
	const parts = names.map((name, i) => {
		const x = (i % COLS) * PITCH + 1
		const y = Math.floor(i / COLS) * PITCH + 1
		return `<svg x="${x}" y="${y}" width="${CELL}" height="${CELL}" viewBox="0 0 24 24" fill="none" stroke="#ffffff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${body[name].replaceAll('currentColor', '#ffffff')}</svg>`
	})
	const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${COLS * PITCH}" height="${rows * PITCH}">${parts.join('')}</svg>`
	const file = `lucide_${s + 1}.png`
	fs.writeFileSync(path.join(outDir, file), render(svg))
	sheets.push(file)
}

// 3. Non-icon UI images (blurred shadows, colour-picker shade, picker dot).
const extras = {}
for (const file of fs.readdirSync(path.join(here, 'extras')).sort()) {
	if (!file.endsWith('.png')) continue
	fs.copyFileSync(path.join(here, 'extras', file), path.join(outDir, file))
	extras[file.slice(0, -4)] = file
}

// 4. Banner for the first-load splash (replaces the Rayfield logo): sparkles + "SeneX".
const sparkles = body['sparkles'].replaceAll('currentColor', '#ffffff')
const bannerSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="420" height="96">
<svg x="14" y="16" width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="#ffffff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${sparkles}</svg>
<text x="96" y="68" font-family="Segoe UI, Arial, sans-serif" font-weight="700" font-size="56" fill="#ffffff">SeneX</text></svg>`
fs.writeFileSync(path.join(outDir, 'banner.png'), render(bannerSvg, { font: { loadSystemFonts: true, defaultFontFamily: 'Segoe UI' } }))
extras.banner = 'banner.png'

// 5. pack.json - names in sheet order; `files` lists every file with its exact byte size
//    so the client can reject truncated downloads and HTML error pages.
const files = {}
for (const file of [...sheets, ...Object.values(extras)]) files[file] = fs.statSync(path.join(outDir, file)).size
const pack = { version: PACK_VERSION, lucide: lucideVersion, cell: CELL, pitch: PITCH, cols: COLS, perSheet: PER_SHEET, sheets, extras, files, names: canonical, aliases }
fs.writeFileSync(path.join(outDir, 'pack.json'), JSON.stringify(pack))

const total = Object.values(files).reduce((a, b) => a + b, 0)
console.log(`lucide ${lucideVersion}: ${canonical.length} icons + ${Object.keys(aliases).length} aliases on ${sheets.length} sheets, ${Object.keys(extras).length} extras, ${(total / 1024).toFixed(0)} KB`)
