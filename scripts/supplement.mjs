import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const taskDir = path.dirname(fileURLToPath(import.meta.url));
if (!process.argv[2]) throw new Error('Usage: node scripts/supplement.mjs <Cursor resources/app path>');
const appRoot = path.resolve(process.argv[2]);
const rel = 'out/vs/workbench/workbench.glass.main.js';
const file = path.join(appRoot, rel);
const before = fs.readFileSync(file, 'utf8');
let text = before;
const replacements = [
  ['M6l="New Chat"', 'M6l="新对话"'],
  ['label:W?"New Chat":"New Agent"', 'label:W?"新对话":"新智能体"'],
  ['columnHeader:"Repositories"', 'columnHeader:"仓库"'],
  ['collectionLabel:"Repositories"', 'collectionLabel:"仓库"'],
  ['w="Repositories",T="group"', 'w="仓库",T="group"'],
  ['voice:"Voice","git-prs":"Source Control"', 'voice:"语音","git-prs":"版本控制"'],
  ['QSc={docs:"Docs",contact:"Contact"}', 'QSc={docs:"文档",contact:"联系我们"}'],
  ['title:"Create a dashboard"', 'title:"创建仪表盘"'],
  ['subtitle:"Visualize information in a custom interface"', 'subtitle:"在自定义界面中将信息可视化"'],
  ['"Import your Claude Code conversations"', '"导入 Claude Code 对话"'],
  ['"Sync your chats and continue them in Cursor"', '"同步聊天记录并在 Cursor 中继续对话"'],
  ['i?"Close Settings":"Settings"', 'i?"关闭设置":"设置"'],
  ['"aria-label":"Open Cursor Account"', '"aria-label":"打开 Cursor 账户"'],
  ['children:["Open",_]', 'children:["打开",_]'],
  ['?"Upgrade to Pro":', '?"升级至 Pro":'],
  ['return"Upgrade to Pro"', 'return"升级至 Pro"'],
  ['"Entry-level plan with access to premium models, unlimited Tab completions, and more."', '"入门套餐，可使用高级模型、无限 Tab 代码补全等功能。"'],
  ['children:["Upgrade",', 'children:["升级",'],
  ['"Data Sharing Enabled"', '"已启用数据共享"'],
  ['"Your codebase, prompts, edits and other usage data will be stored and trained on by Cursor to improve the product."', '"Cursor 会存储你的代码库、提示词、编辑和其他使用数据，并用于训练以改进产品。"'],
  ['dismissLabel:"Dismiss"', 'dismissLabel:"关闭提示"'],
  ['?"Dismiss":"Cancel"', '?"关闭提示":"取消"'],
  ['===void 0?"Dismiss":', '===void 0?"关闭提示":'],
  ['"aria-label":"Chat actions"', '"aria-label":"对话操作"'],
  ['"aria-label":"Show Apps"', '"aria-label":"显示应用"'],
  ['"aria-label":"Start voice input"', '"aria-label":"开始语音输入"']
];
let total = 0;
for (const [from, to] of replacements) {
  const count = text.split(from).length - 1;
  if (count) { text = text.split(from).join(to); total += count; }
  console.log(`${count}: ${from}`);
}
if (total === 0) throw new Error('No matching UI text; no changes applied');
const backup = path.join(taskDir, 'glass.before-supplement.js');
if (fs.existsSync(backup)) throw new Error('Backup already exists; refusing to overwrite');
const temp = file + '.zh-supplement.js';
fs.writeFileSync(backup, before);
fs.writeFileSync(temp, text, { flag: 'wx' });
const check = spawnSync(process.execPath, ['--check', temp], { encoding: 'utf8', windowsHide: true });
if (check.status !== 0) { fs.unlinkSync(temp); throw new Error(check.stderr); }
fs.renameSync(temp, file);
const productFile = path.join(appRoot, 'product.json');
const originalProduct = fs.readFileSync(productFile, 'utf8');
fs.writeFileSync(path.join(taskDir, 'product.before-supplement.json'), originalProduct, { flag: 'wx' });
const product = JSON.parse(originalProduct);
product.checksums[rel.replace(/^out\//, '')] = crypto.createHash('sha256').update(text).digest('base64').replace(/=+$/, '');
fs.writeFileSync(productFile, JSON.stringify(product, null, '\t') + '\n');
fs.writeFileSync(path.join(taskDir, 'supplement-result.json'), JSON.stringify({ replacements: total, syntaxCheck: true, appliedAt: new Date().toISOString(), backup }, null, 2));
console.log(`Applied ${total} UI translations; syntax verified.`);
