param([string]$CursorPath, [switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
function Invoke-CursorNode([string]$Executable, [string[]]$NodeArguments, [string]$LogDirectory) {
    $logId = [guid]::NewGuid().ToString('N')
    $stdout = Join-Path $LogDirectory "$logId.out.log"
    $stderr = Join-Path $LogDirectory "$logId.err.log"
    $quoted = @($NodeArguments | ForEach-Object { '"' + $_ + '"' })
    $child = Start-Process -FilePath $Executable -ArgumentList $quoted -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    Get-Content -LiteralPath $stdout -Encoding UTF8 | Write-Host
    Get-Content -LiteralPath $stderr -Encoding UTF8 | Write-Host
    if ($child.ExitCode -ne 0) { throw "汉化步骤失败（$($child.ExitCode)），日志：$LogDirectory" }
}
try {
    if (-not $CursorPath) {
        $candidates = @(
            "$env:LOCALAPPDATA\Programs\cursor\Cursor.exe",
            "$env:ProgramFiles\cursor\Cursor.exe",
            "$env:LOCALAPPDATA\Programs\CursorChinese\Cursor.exe"
        ) | Where-Object { Test-Path -LiteralPath $_ }
        if (-not $candidates) { throw '没有找到 Cursor。请先安装官方 Windows Cursor，或把 Cursor.exe 拖到 Start-Chinese.cmd 上。' }
        $CursorPath = $candidates[0]
    }
    $CursorPath = (Resolve-Path -LiteralPath $CursorPath).Path
    $source = Split-Path $CursorPath
    $product = Get-Content -Raw -Encoding UTF8 -LiteralPath "$source\resources\app\product.json" | ConvertFrom-Json
    if ($product.version -ne '3.27.14') { throw "检测到 Cursor $($product.version)。本包只验证过 3.27.14，未修改任何程序。请使用适配版本的汉化包。" }
    $archive = Join-Path $PSScriptRoot 'vendor\language-pack-1.1.1.tgz'
    $hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
    $expected = (Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $PSScriptRoot 'vendor\SHA256.txt')).Trim()
    if ($hash -ne $expected) { throw '语言包校验失败，请重新下载。' }
    if ($CheckOnly) { Write-Host 'PASS: 已检测到兼容 Cursor，离线语言包校验通过。'; exit 0 }
    Write-Host '请保存 Cursor 中正在编辑的文件。本工具将正常关闭 Cursor，不会强制结束进程。'
    foreach ($process in @(Get-Process -Name Cursor -ErrorAction SilentlyContinue)) {
        if ($process.MainWindowHandle -ne 0) { [void]$process.CloseMainWindow() }
    }
    $deadline = (Get-Date).AddSeconds(30)
    while ((Get-Process -Name Cursor -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 500 }
    if (Get-Process -Name Cursor -ErrorAction SilentlyContinue) { throw 'Cursor 尚未退出（可能有未保存提示或托盘进程）。请手动退出后重新双击。本工具不会强制关闭。' }
    $target = Join-Path $env:LOCALAPPDATA ('Programs\CursorChinese-OneClick-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    if (Test-Path -LiteralPath $target) { throw '目标目录已存在，请稍后重试。' }
    New-Item -ItemType Directory -Path $target | Out-Null
    Write-Host '正在创建独立中文版，约复制 1 GB 文件，请稍候……'
    & robocopy.exe $source $target /E /COPY:DAT /DCOPY:DAT /R:1 /W:1 /NFL /NDL /NJH /NJS /NP
    if ($LASTEXITCODE -gt 7) { throw "程序复制失败：$LASTEXITCODE。原安装未被修改。" }
    $work = Join-Path $target 'ChineseSetup'
    New-Item -ItemType Directory -Path $work | Out-Null
    & tar.exe -xzf $archive -C $work
    if ($LASTEXITCODE -ne 0) { throw '解压语言包失败。' }
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'scripts\supplement.mjs') -Destination $work
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'scripts\finish.mjs') -Destination $work
    $runtime = Join-Path $target 'Cursor.exe'
    $appRoot = Join-Path $target 'resources\app'
    # A previously translated installation needs its verified originals in the
    # new copy before upstream can establish its own backup journal.
    $records = Join-Path $env:USERPROFILE '.cursor\cursor-language-pack\installs'
    if (Test-Path -LiteralPath $records) {
        foreach ($recordFile in @(Get-ChildItem -LiteralPath $records -Filter rewrite.json -Recurse -File)) {
            $record = Get-Content -Raw -Encoding UTF8 -LiteralPath $recordFile.FullName | ConvertFrom-Json
            if ($record.installRoot.TrimEnd('\') -ine $source.TrimEnd('\') -or $record.cursorVersion -ne $product.version -or $record.commit -ne $product.commit) { continue }
            foreach ($entry in $record.files.PSObject.Properties) {
                $relative = $entry.Name
                if ($relative -notin @('out/vs/workbench/workbench.desktop.main.js','out/vs/workbench/workbench.glass.main.js','out/vs/workbench/workbench.anysphere-ui-automations.js','out/vs/workbench/workbench.xai-commerce-prepaid.js')) { throw '备份记录含未知文件，已停止。' }
                $currentFile = Join-Path $appRoot $relative
                $currentHash = (Get-FileHash -LiteralPath $currentFile -Algorithm SHA256).Hash
                if ($currentHash -ieq $entry.Value.original) { continue }
                if ($currentHash -ine $entry.Value.patched) { throw '源安装含额外修改，请选择未经补充修改的官方安装。' }
                if ((Get-FileHash -LiteralPath $entry.Value.backup -Algorithm SHA256).Hash -ine $entry.Value.original) { throw '原始备份校验失败。' }
                Copy-Item -LiteralPath $entry.Value.backup -Destination $currentFile -Force
                $restoredSha = [Security.Cryptography.SHA256]::Create()
                try { $restoredHash = [Convert]::ToBase64String($restoredSha.ComputeHash([IO.File]::ReadAllBytes($currentFile))).TrimEnd('=') } finally { $restoredSha.Dispose() }
                $key = $relative.Substring(4)
                $product.checksums | Add-Member -MemberType NoteProperty -Name $key -Value $restoredHash -Force
            }
            $product | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath "$appRoot\product.json" -Encoding UTF8
            # PowerShell 5 emits a BOM, which product.json must not contain.
            $productText = Get-Content -Raw -Encoding UTF8 -LiteralPath "$appRoot\product.json"
            [IO.File]::WriteAllText("$appRoot\product.json", $productText, [Text.UTF8Encoding]::new($false))
            break
        }
    }
    $previousElectron = $env:ELECTRON_RUN_AS_NODE
    try {
        $env:ELECTRON_RUN_AS_NODE = '1'
        Write-Host '安装完整中文语言包……'
        Invoke-CursorNode $runtime @((Join-Path $work 'package\bin\cli.mjs'), 'install', "--dir=$target", '--locale=zh-cn') $work
        Write-Host '补齐首页和设置漏译……'
        Invoke-CursorNode $runtime @((Join-Path $work 'supplement.mjs'), $appRoot) $work
        Invoke-CursorNode $runtime @((Join-Path $work 'finish.mjs'), $appRoot) $work
    } finally { $env:ELECTRON_RUN_AS_NODE = $previousElectron }
    $patched = Get-Content -Raw -Encoding UTF8 -LiteralPath "$appRoot\product.json" | ConvertFrom-Json
    $bytes = [IO.File]::ReadAllBytes("$appRoot\out\vs\workbench\workbench.glass.main.js")
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $actual = [Convert]::ToBase64String($sha.ComputeHash($bytes)).TrimEnd('=') } finally { $sha.Dispose() }
    if ($actual -ne $patched.checksums.'vs/workbench/workbench.glass.main.js') { throw '资源校验失败。' }
    $desktop = [Environment]::GetFolderPath('Desktop')
    $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut((Join-Path $desktop 'Cursor 中文版.lnk'))
    $shortcut.TargetPath = $runtime
    $shortcut.WorkingDirectory = $target
    $shortcut.Arguments = '--locale=zh-cn'
    $shortcut.IconLocation = "$runtime,0"
    $shortcut.Save()
    @{ original = $CursorPath; chinese = $runtime; version = $product.version } | ConvertTo-Json | Set-Content -LiteralPath "$work\installation.json" -Encoding UTF8
    Write-Host '完成。以后双击桌面 Cursor 中文版。原安装保留，可随时从原入口返回。'
    Start-Process -FilePath $runtime -ArgumentList '--locale=zh-cn' -WindowStyle Hidden
    exit 0
} catch {
    Write-Host ('安装未完成：' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
