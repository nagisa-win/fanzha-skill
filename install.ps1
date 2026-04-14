#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [ValidateSet("global","project","g","p")]
    [string]$Mode
)

$Repo = "nagisa-win/fanzha-skill"
$RepoUrl = "https://github.com/$Repo.git"
$ZipUrl = "https://github.com/$Repo/archive/refs/heads/master.zip"

function Write-Info($msg)  { Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-Ok($msg)    { Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn($msg)  { Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Err($msg)   { Write-Host "[ERROR] $msg" -ForegroundColor Red }

function Download-Repo($dest) {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Write-Info "使用 git clone 下载..."
        git clone --depth 1 $RepoUrl $dest 2>$null
        if ($LASTEXITCODE -ne 0) {
            Download-Zip $dest
        }
    } else {
        Download-Zip $dest
    }
}

function Download-Zip($dest) {
    Write-Info "使用下载 zip..."
    $zipPath = Join-Path $dest "repo.zip"
    try {
        Invoke-WebRequest -Uri $ZipUrl -OutFile $zipPath -UseBasicParsing
        Expand-Archive -Path $zipPath -DestinationPath $dest -Force
        Remove-Item $zipPath -Force
        $extracted = Join-Path $dest "fanzha-skill-master"
        if (Test-Path $extracted) {
            Get-ChildItem $extracted | Move-Item -Destination $dest -Force
            Remove-Item $extracted -Recurse -Force
        }
    } catch {
        Write-Err "下载失败: $_"
        exit 1
    }
}

function Install-To($target, $src) {
    $claudeDir = Join-Path $target ".claude"
    $skillDir = Join-Path $claudeDir "skills"
    $rulesDir = Join-Path $claudeDir "rules"
    $fanzhaDir = Join-Path $skillDir "反诈"
    $refsDir = Join-Path $fanzhaDir "references"

    New-Item -ItemType Directory -Path $refsDir -Force | Out-Null
    New-Item -ItemType Directory -Path $rulesDir -Force | Out-Null

    $srcSkill = Join-Path $src "skills\反诈"
    Copy-Item -Path "$srcSkill\*" -Destination $fanzhaDir -Recurse -Force
    Copy-Item -Path (Join-Path $src "rules\反诈-guard.md") -Destination $rulesDir -Force

    Write-Ok "已安装到 $claudeDir"
}

function Install-Global($src) {
    $homeDir = $HOME
    if (-not $homeDir -or -not (Test-Path $homeDir)) {
        Write-Err "无法确定 HOME 目录"
        exit 1
    }
    Install-To $homeDir $src
    Write-Ok "全局安装完成 — 所有 Claude Code 项目将自动生效"
}

function Install-Project($src) {
    $targetDir = if ($env:FANZHA_PROJECT_DIR) { $env:FANZHA_PROJECT_DIR } else { $PWD.Path }
    if (-not (Test-Path (Join-Path $targetDir ".claude"))) {
        Write-Info "当前目录 $targetDir 未检测到 .claude 目录，将自动创建"
    }
    Install-To $targetDir $src
    Write-Ok "项目级安装完成 — 仅在 $targetDir 下生效"
}

function Print-Banner {
    Write-Host ""
    Write-Host "  🛡️  反诈守护 Skill 安装器" -ForegroundColor White
    Write-Host "  ━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor White
    Write-Host "  平台: $($env:OS ?? "Windows")" 
    Write-Host ""
}

function Print-Result {
    Write-Host ""
    Write-Host "  ━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor White
    Write-Host "  安装成功！" -ForegroundColor Green
    Write-Host ""
    Write-Host "  接下来："
    Write-Host "  1. 在项目目录启动 Claude Code / Ducc"
    Write-Host "  2. Skill 和 Rule 将自动加载"
    Write-Host "  3. 尝试发送「反诈检查」测试"
    Write-Host ""
    Write-Host "  手动触发关键词："
    Write-Host "  反诈检查 / 帮我检查是否是诈骗 / 这是真的吗"
    Write-Host "  感觉被骗了 / 有点可疑 / 核实一下 / 举报诈骗"
    Write-Host ""
}

Print-Banner

if (-not $Mode) {
    Write-Host "  选择安装模式："
    Write-Host "    1) 全局安装（推荐，所有项目生效）" -ForegroundColor White
    Write-Host "    2) 项目级安装（仅当前目录生效）" -ForegroundColor White
    Write-Host ""
    $choice = Read-Host "  请输入 [1/2]"
    switch ($choice) {
        "1" { $Mode = "global" }
        "2" { $Mode = "project" }
        default { Write-Err "无效选择"; exit 1 }
    }
}

switch ($Mode) {
    { $_ -in "global","g" } { $Mode = "global" }
    { $_ -in "project","p" } { $Mode = "project" }
}

$tmpDir = Join-Path $env:TEMP "fanzha-skill-$(Get-Random)"
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

try {
    Write-Info "下载 fanzha-skill 仓库..."
    Download-Repo $tmpDir

    $skillPath = Join-Path $tmpDir "skills\反诈"
    if (-not (Test-Path $skillPath)) {
        Write-Err "下载的仓库结构异常，未找到 skills\反诈 目录"
        exit 1
    }

    Write-Info "执行$Mode安装..."
    switch ($Mode) {
        "global"  { Install-Global $tmpDir }
        "project" { Install-Project $tmpDir }
    }

    Print-Result
} finally {
    Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}
