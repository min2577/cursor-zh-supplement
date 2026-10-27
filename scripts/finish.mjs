import fs from 'node:fs';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
if (!process.argv[2]) throw new Error('Usage: node scripts/finish.mjs <Cursor resources/app path>');
const root = process.argv[2];
const file = root + '/out/vs/workbench/workbench.glass.main.js';
let text = fs.readFileSync(file, 'utf8');
fs.copyFileSync(file, new URL('./glass.before-finish.js', import.meta.url), fs.constants.COPYFILE_EXCL);
for (const [from, to] of [
  ['"Upgrade your plan"', '"升级套餐"'],
  ['"Choose a plan with more usage"', '"选择用量更多的套餐"'],
  ['children:[y,"Upgrade"]', 'children:[y,"升级"]'],
  ['children:"Upgrade"', 'children:"升级"'],
  ['ctaLabel:m??h??"Upgrade"', 'ctaLabel:m??h??"升级"'],
  ['return"Upgrade"', 'return"升级"'],
  ['"Chat actions"', '"对话操作"'],
  ['"Show Apps"', '"显示应用"'],
  ['"Start voice input"', '"开始语音输入"']
]) { console.log(`${text.split(from).length - 1}: ${from}`); text = text.split(from).join(to); }
const temp = file + '.finish.js';
fs.writeFileSync(temp, text, {flag:'wx'});
const checked = spawnSync(process.execPath, ['--check', temp], {encoding:'utf8',windowsHide:true});
if (checked.status !== 0) { fs.unlinkSync(temp); throw new Error(checked.stderr); }
fs.renameSync(temp, file);
const productPath = root + '/product.json';
const product = JSON.parse(fs.readFileSync(productPath,'utf8'));
product.checksums['vs/workbench/workbench.glass.main.js'] = crypto.createHash('sha256').update(text).digest('base64').replace(/=+$/, '');
fs.writeFileSync(productPath, JSON.stringify(product,null,'\t')+'\n');
console.log('Final translations applied; syntax verified.');
