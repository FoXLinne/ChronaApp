# Chrona 项目本地化键审计报告

**审计日期**: 2026年4月18日  
**项目路径**: `/Users/kaedekr/ChronaProject/Chrona`  
**扫描范围**: 21 个 Swift 文件 + 3 个本地化文件

---

## 📊 审计概览

| 指标 | 数值 |
|------|------|
| **本地化文件总数** | 3 个 (en, zh-Hans, zh-Hant) |
| **English 键数** | 152 |
| **Simplified Chinese 键数** | 148 |
| **Traditional Chinese 键数** | 143 |
| **代码中使用的唯一键数** | 164 |
| **缺失的键数** | 31 |
| **未使用的键数** | 8 |

---

## ✗ 第一部分：代码中使用但本地化文件中缺失的键（31 个）

### 🔴 1.1 最严重：所有三个语言都缺失（12 个键）

这些键会导致 UI 显示键名而不是翻译内容。

| 序号 | 键名 | 分类 | 影响文件 |
|------|------|------|---------|
| 1 | `about.localization.builtin` | 关于 | AboutView.swift |
| 2 | `common.done` | 通用 | TaskEditorView.swift |
| 3 | `common.edit` | 通用 | CountdownView, ProfileView, TaskEditorView, TaskListView |
| 4 | `common.resume` | 通用 | ActiveSessionView.swift |
| 5 | `countdown.future` | 倒数日 | CountdownView.swift |
| 6 | `countdown.past` | 倒数日 | CountdownView.swift |
| 7 | `stats.dailyAverage` | 统计 | StatisticsView.swift |
| 8 | `stats.todayFocus` | 统计 | StatisticsView.swift |
| 9 | `stats.totalCount` | 统计 | StatisticsView.swift |
| 10 | `stats.totalDuration` | 统计 | StatisticsView.swift |
| 11 | `task.filter` | 任务 | TaskListView.swift |
| 12 | `task.running` | 任务 | TaskListView.swift |

### 🟠 1.2 高优先级：部分语言缺失（19 个键）

#### English 缺失（1 个）
- `profile.about` — 关于页面标题

#### Simplified Chinese (zh-Hans) 缺失（5 个）
- `countdown.days.suffix` — 倒数日后缀
- `settings.category.notification` — 设置分类
- `task.countdown.advanced.message` — 倒计时高级提示
- `task.countdown.advanced.placeholder` — 倒计时占位符
- `task.countdown.advanced.title` — 倒计时标题

#### Traditional Chinese (zh-Hant) 缺失（13 个）
- `about.contributor.role1` — 贡献者角色
- `about.contributor.role2` — 贡献者角色
- `countdown.days.suffix` — 倒数日后缀
- `countdown.inDays.prefix` — 倒数日前缀（将来）
- `countdown.pastDays.prefix` — 倒数日前缀（过去）
- `notification.focus.body` — 通知内容
- `profile.avatar.crop` — 头像裁剪
- `profile.avatar.crop.hint` — 头像裁剪提示
- `profile.avatar.photo.pick` — 选择照片头像
- `profile.avatar.photo.remove` — 移除照片头像
- `session.alreadyRunning` — 会话已运行
- `settings.restAfterTask` — 任务后休息
- `settings.restTime.subtitle` — 休息时长说明

---

## ✓ 第二部分：本地化文件中存在但代码未使用的键（8 个）

### 2.1 所有三个语言都有但未使用（2 个）

| 键名 | 所在文件 |
|------|---------|
| `about.app` | en, zh-Hans, zh-Hant |
| `task.form.basic` | en, zh-Hans, zh-Hant |

### 2.2 仅 Traditional Chinese 有但未使用（4 个）

- `duration.hms` — 时间格式（可能已被其他键替代）
- `session.showControls` — 显示控制（可能被其他键替代）
- 另外 2 个键在所有文件中

---

## 📁 第三部分：文件影响范围

共 **12 个文件** 涉及本地化键的使用：

### 涉及缺失键的文件
- **AboutView.swift** — 3 个缺失键（贡献者、本地化标签）
- **ActiveSessionView.swift** — 1 个缺失键（恢复按钮）
- **AppViewModel.swift** — 1 个缺失键（会话已运行）
- **CountdownView.swift** — 4 个缺失键（倒数日文本、后缀）
- **NotificationService.swift** — 1 个缺失键（通知内容）
- **ProfileView.swift** — 6 个缺失键（关于、头像相关）
- **SettingsView.swift** — 3 个缺失键（通知分类、休息设置）
- **StatisticsView.swift** — 4 个缺失键（统计指标）
- **TaskEditorView.swift** — 4 个缺失键（按钮、倒计时）
- **TaskListView.swift** — 3 个缺失键（筛选、编辑、运行状态）

### 本地化键完整的文件
- DailyCheckInView.swift ✓
- RootTabView.swift ✓

---

## 🎯 行动计划

### 第 1 阶段：立即修复（高优先级）

**时间估计**: 30-40 分钟

#### 1.1 添加所有语言都缺失的 12 个键

需要在三个本地化文件中添加翻译：

```
en:
"about.localization.builtin" = "Built-in";
"common.done" = "Done";
"common.edit" = "Edit";
"common.resume" = "Resume";
"countdown.future" = "Upcoming";
"countdown.past" = "Past";
"stats.dailyAverage" = "Daily Average";
"stats.todayFocus" = "Today's Focus";
"stats.totalCount" = "Total Count";
"stats.totalDuration" = "Total Duration";
"task.filter" = "Filter";
"task.running" = "Running";

zh-Hans:
"about.localization.builtin" = "内置";
"common.done" = "完成";
"common.edit" = "编辑";
"common.resume" = "继续";
"countdown.future" = "即将到来";
"countdown.past" = "已过去";
"stats.dailyAverage" = "日均";
"stats.todayFocus" = "今日专注";
"stats.totalCount" = "总数";
"stats.totalDuration" = "总时长";
"task.filter" = "筛选";
"task.running" = "运行中";

zh-Hant:
"about.localization.builtin" = "內置";
"common.done" = "完成";
"common.edit" = "編輯";
"common.resume" = "繼續";
"countdown.future" = "即將到來";
"countdown.past" = "已過去";
"stats.dailyAverage" = "日均";
"stats.todayFocus" = "今日專注";
"stats.totalCount" = "總數";
"stats.totalDuration" = "總時長";
"task.filter" = "篩選";
"task.running" = "執行中";
```

#### 1.2 补充部分语言缺失的 19 个键

- **English**: 添加 1 个键 `profile.about`
- **Simplified Chinese**: 添加 5 个键（倒数日、设置、任务倒计时）
- **Traditional Chinese**: 添加 13 个键（最多的语言）

### 第 2 阶段：代码整洁（可选）

**时间估计**: 10-15 分钟

#### 2.1 删除所有语言中的未使用键

从三个本地化文件中删除：
- `about.app`
- `task.form.basic`

#### 2.2 删除 Traditional Chinese 特有的未使用键

从 `zh-Hant.lproj/Localizable.strings` 中删除：
- `duration.hms`
- `session.showControls`

### 第 3 阶段：验证

- [ ] 编译项目，确认没有本地化警告
- [ ] 在各个语言环境下测试相应视图
- [ ] 检查 UI 显示是否正确

---

## 📋 检查清单

### 缺失键补充检查表

- [ ] 12 个共同缺失键已添加到三个文件
- [ ] `profile.about` 已添加到 English
- [ ] 5 个 Simplified Chinese 缺失键已补充
- [ ] 13 个 Traditional Chinese 缺失键已补充

### 未使用键删除检查表

- [ ] `about.app` 已从三个文件删除
- [ ] `task.form.basic` 已从三个文件删除
- [ ] `duration.hms` 已从 zh-Hant 删除
- [ ] `session.showControls` 已从 zh-Hant 删除

### 验证检查表

- [ ] Xcode 编译成功，无警告
- [ ] 所有三个语言的应用能正常运行
- [ ] 随机抽查 5 个页面的本地化显示正确

---

## 📌 关键发现

### 1. Traditional Chinese 本地化不完整
zh-Hant 缺失 13 个键，远多于其他语言，可能需要统一补全。

### 2. 统计页面本地化缺失最多
StatisticsView.swift 涉及 4 个统计相关的缺失键，影响整个统计功能。

### 3. 倒数日功能键不一致
`countdown.days.suffix` 在 zh-Hans 和 zh-Hant 都缺失，但代码已在使用。

### 4. 本地化键编号不一致
某些键在所有文件都有定义，但只有部分代码使用，需要清理。

---

## 💡 建议

1. **立即处理缺失键**：这些缺失会导致用户看到英文键名而不是翻译，影响用户体验。
2. **统一 Traditional Chinese 翻译**：zh-Hant 缺失最多，考虑使用专业翻译服务。
3. **建立翻译验证流程**：在添加代码中新使用的本地化键时，同时添加所有语言的翻译。
4. **定期审计**：建议在每个版本发布前进行本地化审计。

---

**报告生成时间**: 2026-04-18  
**扫描工具**: Python 3 + Regex  
**扫描方法**: 通过 `String(localized:)` 和 `NSLocalizedString()` 正则表达式检测
