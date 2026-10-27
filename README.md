# Cursor 中文漏译补充脚本

为 Windows 上的 Cursor **3.27.14** 补齐首页和设置中的部分英文文案。

这份仓库保存实际使用过的两个补充脚本，并将本机绝对路径改为命令行参数。**它不是完整语言包**；使用前需要安装并应用上游 [polang233/cursor-language-pack](https://github.com/polang233/cursor-language-pack)。

## 已验证范围

- Windows、Cursor 3.27.14、上游语言包 1.1.1。
- 首页：新对话、仓库、创建仪表盘、导入 Claude Code 对话等。
- 设置：语音、版本控制、文档、套餐提示等。
- 原补充脚本实际替换 34 处，收尾脚本替换 13 处。
- 实际启动核对首页和通用设置；修改后 JavaScript 语法与资源校验值检查通过。
- 发布前在隔离的原始资源副本上执行带路径参数的两个脚本，输出与已验证中文版资源的 SHA256 完全一致。

没有对其他 Cursor 版本、全部隐藏页面或后续远端下发文案作覆盖承诺。脚本中存在针对 3.27.14 压缩变量名的匹配，不能盲用于新版。

## 使用

需要 Node.js 22 或更新版本。先完全退出 Cursor，并确保目标目录可写。

1. 按上游项目说明安装语言包并应用其汉化补丁。
2. 找到 Cursor 安装目录下的 `resources/app`。
3. 在本仓库根目录按顺序执行，替换示例路径：

```powershell
node scripts/supplement.mjs 'D:\Apps\Cursor\resources\app'
node scripts/finish.mjs 'D:\Apps\Cursor\resources\app'
```

4. 设置显示语言为 `zh-cn`，完全退出并重新打开 Cursor，再核对页面。

这两个脚本只处理本地 `workbench.glass.main.js` 与 `product.json` 的相关资源校验项，不安装语言包、不请求网络、不修改账户或项目代码，也不改变隐私和安全设置。

## 备份和回退

脚本将备份写入本仓库的 `scripts` 目录，已加入 Git 忽略规则：

- `glass.before-supplement.js`：补充汉化前的资源。
- `product.before-supplement.json`：补充汉化前的资源校验配置。
- `glass.before-finish.js`：收尾汉化前的资源。

同名备份存在时脚本会停止，不会覆盖原备份。不要为了重跑而删除唯一备份。

若要撤销两个补充脚本，请完全退出 Cursor，仅在 **同一安装、同一版本且未再应用其他补丁** 的情况下，把 `glass.before-supplement.js` 复制回目标的 `out/vs/workbench/workbench.glass.main.js`，把 `product.before-supplement.json` 复制回目标的 `product.json`。这会回到应用本仓库脚本之前的上游汉化状态。升级后不要用旧备份覆盖新程序。

脚本不是跨文件原子事务；权限或磁盘故障可能中断写入，须保留备份。Cursor 更新可能覆盖汉化，更新前后应先检查适配。

## 仓库内容

只保存脚本和文档。不包含 Cursor 安装程序、应用资源、第三方包副本、个人日志、账号数据、凭据或本机备份。保留原安装作回退比把约 1 GB 程序上传 GitHub 更合适。

## 上游与边界

完整语言包来自 [polang233/cursor-language-pack](https://github.com/polang233/cursor-language-pack)，其许可和声明以该项目为准。本仓库是独立的本地补充工作，与 Anysphere、Microsoft 无隶属关系。参见 [第三方说明](THIRD_PARTY_NOTICES.md)。
