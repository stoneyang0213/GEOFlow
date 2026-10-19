<#
.SYNOPSIS
    同步上游 GEOFlow 到本地产品分支，可选重建镜像。

.DESCRIPTION
    流程：
      1. fetch upstream（原作者库，只读）
      2. upstream-main 快进到 upstream/main（或指定 tag）
      3. 合并到 main（merge，不 rebase）
      4. 可选：代码风格检查、相关测试、重建 Docker 镜像

.PARAMETER Ref
    指定上游基线，默认 upstream/main。发布期建议用 tag，例如 -Ref v3.2.0。

.PARAMETER Test
    合并后运行 PHP 风格检查与相关测试（需要本地 vendor）。

.PARAMETER Rebuild
    合并后重建 app 镜像并滚动重启。

.EXAMPLE
    pwsh scripts/custom-sync.ps1 -Test
    pwsh scripts/custom-sync.ps1 -Ref v3.2.0 -Test -Rebuild
#>
[CmdletBinding()]
param(
    [string]$Ref = 'upstream/main',
    [switch]$Test,
    [switch]$Rebuild
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot

function Invoke-Git {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    & git @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') 失败（exit $LASTEXITCODE）"
    }
}

try {
    Write-Host '==> 1/4 拉取上游' -ForegroundColor Cyan
    Invoke-Git fetch upstream --tags --prune

    $resolved = (& git rev-parse --verify $Ref) 2>$null
    if (-not $resolved) { throw "找不到上游引用：$Ref" }
    $target = (& git rev-parse --short $Ref).Trim()
    Write-Host "    上游目标：$Ref ($target)"

    Write-Host '==> 2/4 快进镜像分支 upstream-main' -ForegroundColor Cyan
    Invoke-Git switch upstream-main
    Invoke-Git merge --ff-only $Ref

    Write-Host '==> 3/4 合并到 main' -ForegroundColor Cyan
    Invoke-Git switch main
    & git merge --no-edit upstream-main
    if ($LASTEXITCODE -ne 0) {
        throw @'
合并产生冲突。处理步骤：
  1) 解决冲突文件，git add 后 git merge --continue
  2) 对照 docs/upstream-divergence.md 检查被改动的核心文件
  3) 跑测试后再发布
如需放弃本次合并：git merge --abort
'@
    }

    if ($Test) {
        Write-Host '==> 4/4 检查与测试' -ForegroundColor Cyan
        if (-not (Test-Path 'vendor/bin/pint')) {
            Write-Warning '未找到 vendor/bin/pint，跳过代码风格检查（先执行 composer install）'
        } else {
            & vendor/bin/pint --test
            if ($LASTEXITCODE -ne 0) { throw 'Pint 风格检查未通过，执行 vendor/bin/pint 修复后重试。' }
        }
        if (Test-Path 'vendor/bin/phpunit') {
            & vendor/bin/phpunit tests/Feature/AdminAiSourceProvidersPageTest.php tests/Feature/AdminAiSystemConfigurationBoundaryTest.php
            if ($LASTEXITCODE -ne 0) { throw '相关测试未通过，请修复后再发布。' }
        } else {
            Write-Warning '未找到 vendor/bin/phpunit，跳过测试'
        }
    }

    if ($Rebuild) {
        Write-Host '==> 重建并重启容器' -ForegroundColor Cyan
        & docker compose --env-file .env.prod -f docker-compose.prod.yml build app
        if ($LASTEXITCODE -ne 0) { throw '镜像构建失败' }
        & docker compose --env-file .env.prod -f docker-compose.prod.yml up -d
        if ($LASTEXITCODE -ne 0) { throw '容器重建失败' }
    }

    Write-Host ''
    Write-Host '同步完成。当前状态：' -ForegroundColor Green
    & git status -sb
    & git log --oneline -5
}
finally {
    Pop-Location
}
