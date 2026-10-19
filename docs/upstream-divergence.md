# 上游差异登记 / Upstream divergence registry

本仓库是 [yaojingang/GEOFlow](https://github.com/yaojingang/GEOFlow) 的下游产品线（AGPL-3.0）。
所有对上游代码的改动都登记在这里，同步上游时按此表检查冲突。

## 仓库模型

| 远端 | 地址 | 用途 |
| --- | --- | --- |
| `origin` | `stoneyang0213/GEOFlow` | 本仓库（可写），产品发布与备份 |
| `upstream` | `yaojingang/GEOFlow` | 原作者库（**只读**，push 已禁用） |

| 分支 | 说明 |
| --- | --- |
| `upstream-main` | 上游镜像，只允许 `merge --ff-only`，禁止提交 |
| `main` | 产品分支 = 上游基线 + 本仓库改动，永远可部署 |
| `feature/*` | 短期功能分支，合入 `main` 后删除 |
| `codex/*` | 向上游提交 PR 时使用的分支（复用本仓库推送） |

## 同步上游

```powershell
# 一条命令（推荐）
pwsh scripts/custom-sync.ps1

# 手工等价流程
git fetch upstream --tags --prune
git switch upstream-main
git merge --ff-only upstream/main
git switch main
git merge --no-edit upstream-main
```

规则：

1. 合并用 **merge**，不要 rebase（rebase 会让冲突重复出现并改写已发布历史）。
2. `upstream-main` 永远不做提交，冲突只在一个 merge commit 里解决。
3. 优先锁定上游 tag（`v3.2.0`）而不是追 `main`，避免上游改坏时被动。

## 核心文件改动

| 文件 | 改动 | 上游 PR | 备注 |
| --- | --- | --- | --- |
| `app/Http/Controllers/Admin/AiSourceProviderController.php` | AI 配置测试失败时按上游错误分类返回可操作提示（`failureHint`），`error_code` 契约不变 | #163 | 通用改进，作者合并后应从本表移除 |
| `lang/zh_CN/admin.php` | 新增 5 条 `failure_hint_*` 文案 | #163 | |
| `lang/zh_TW/admin.php` | 同上 | #163 | |
| `lang/en/admin.php` | 同上 | #163 | |
| `lang/pt_BR/admin.php` | 同上 | #163 | |
| `tests/Feature/AdminAiSourceProvidersPageTest.php` | 401 / 超时提示的回归用例 | #163 | |

> 新增功能请尽量以外挂方式实现（新文件、新 config、新语言包、新路由文件），避免修改核心文件；确实需要改的，登记到上表并注明原因。

## 仅存在于部署环境、不进 git 的配置

`.env.prod` 已被 `.gitignore` 忽略，以下为本部署与上游默认值的差异：

| 变量 | 上游默认 | 本部署 | 原因 |
| --- | --- | --- | --- |
| `GEOFLOW_AI_WORKSPACE_RUNTIME_ENABLED` | `false` | `true` | 开启 AI 工作台运行时；关闭时页面一问就返回「AI 服务暂时不可用」 |

部署时如遇到「AI 服务暂时不可用」或「至少需要一个已启用且通过普通文本检测的对话模型」，按顺序检查：

1. `config('ai-workspace.runtime_enabled')` 是否为 `true`；
2. AI 配置器中该管理员的个人 chat 模型 `ai_workspace_readiness_status` 是否为 `ready`（系统级 `system_only` 模型不参与工作台）；
3. 就绪状态是否过期（有效期 7 天）。

## 许可

- 本仓库继续适用 AGPL-3.0，保留 `LICENSE`、`NOTICE`、`docs/licenses/*`。
- 对外提供网络服务时，须向使用者提供完整对应源码的获取方式。
- 品牌名与 Logo 不随代码授权，对外发布前需自行确认商标。
