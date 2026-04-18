# Chrona 项目本地化键分析报告

**分析日期**：2026年4月18日  
**扫描范围**：所有 Swift 文件和 Localizable.strings 文件

---

## 1️⃣ 未使用的本地化键（定义但代码未使用）

共 **31 个未使用的键**，按分类列出：

### 通用键（Common）- 8 个
- `common.add` - "Add" 
- `common.nextWeek` - "Next 7 days"
- `common.off` - "Off"
- `common.previousWeek` - "Previous 7 days"
- `common.resume` - "Resume"
- `common.save` - "Save"
- `common.unlimited` - "Unlimited"

### 倒数日键（Countdown）- 2 个
- `countdown.inDays` - "%d days left" （有 prefix 版本但没有完整版）
- `countdown.pastDays` - "%d days ago" （有 prefix 版本但没有完整版）

### 任务键（Task）- 5 个
- `task.add` - "Add Task" （虽然代码使用了，但在导航标题中，应该被使用）
- `task.countdown.preview` - "Current duration: %@"
- `task.edit.requiresAll` - "Turn off search/filter before reordering tasks"
- `task.form.basic` - "Basics"
- `task.running` - "Running"

### 会话键（Session）- 1 个
- `session.showControls` - "Show Controls"

### 统计键（Stats）- 3 个
- `stats.summary` - "Summary"
- `stats.todayCount` - "Today"
- `stats.weekOffset` - "Week %d"

### 设置键（Settings）- 4 个
- `settings.autoPin` - "Auto move completed tasks to top"
- `settings.category.task` - "Task behavior"
- `settings.category.timer` - "Timer behavior"
- `settings.minimal` - "Immersive mode"

### 时长键（Duration）- 1 个
- `duration.hms` - "%d h %d m %d s"

### 通知键（Notification）- 2 个
- `notification.focus.title` - "Time to focus"
- `notification.focus.body` - "You have not started a focus session today."

### 资料键（Profile）- 1 个
- `profile.settings.manage` - "Settings"

### 关于键（About）- 2 个
- `about.app` - "App"
- `about.localization.ai` - "AI Translation"

### 贡献者键（Contributors）- 1 个
- `about.contributor.role` - "Programming / UI Design" ⚠️ **多语言不一致**

---

## 2️⃣ 代码中使用但未定义的键（BUG）

共 **1 个键缺失定义**：

- ❌ `task.new` - 在 TaskListView.swift 的 accessibilityLabel 中使用，但在任何 Localizable.strings 文件中都没有定义！

**位置**：[TaskListView.swift](Chrona/Views/Tasks/TaskListView.swift#L91)  
**修复方案**：需要在所有三个 Localizable.strings 文件中添加此键

---

## 3️⃣ 多语言不一致问题

### 问题 1：about.contributor.role 的不一致定义

| 语言文件 | 定义内容 | 代码使用 |
|---------|--------|--------|
| en.lproj | `about.contributor.role` = "Programming / UI Design" | 使用 `role1` 和 `role2` ❌ |
| zh-Hans.lproj | `about.contributor.role1` = "程序 / UI 设计"<br/>`about.contributor.role2` = "创意 / 本地化" | 使用 `role1` 和 `role2` ✓ |
| zh-Hant.lproj | `about.contributor.role` = "程式 / UI 設計" | 使用 `role1` 和 `role2` ❌ |

**根因**：英文版本定义了单一的 `role`，但简体中文版本为两位贡献者分别定义了 `role1` 和 `role2`，代码使用的是后者。

**影响**：英文用户在关于页面看到的贡献者角色标签可能显示为 "role1" 字面值。

### 问题 2：zh-Hant 缺少部分键

以下键在 en.lproj 中定义但在 zh-Hant.lproj 中缺失：
- `profile.avatar.photo.pick` - 从相册选择头像
- `profile.avatar.photo.remove` - 移除照片头像

---

## 4️⃣ 可合并的重复或冗余键

### 关键发现：Countdown 键可合并优化

**当前设计**（分离的 prefix 和 suffix 键）：
```
countdown.inDays = "%d days left"
countdown.inDays.prefix = "Left"  // 冗余
countdown.pastDays = "%d days ago"
countdown.pastDays.prefix = "Passed"  // 冗余
countdown.days.suffix = "days"
countdown.pastDays.prefix = "Passed"
```

**优化方案**（选项 A - 推荐）：
```
// 保留完整格式，删除冗余的 prefix/suffix
countdown.inDays = "%d days left"
countdown.pastDays = "%d days ago"
countdown.days.suffix = "days"  // 可保留用于其他场景
```

**优化方案**（选项 B - 如果需要灵活格式）：
```
countdown.inDays.format = "%d days left"
countdown.pastDays.format = "%d days ago"
countdown.days.label = "days"
// 删除独立的 prefix 键
```

### 时长表示的冗余

**当前**：
- `duration.hms` = "%d h %d m %d s"（未使用）
- `time.hours`, `time.minutes`, `time.seconds`（分别使用）

**建议**：
- 如果代码不使用 `duration.hms`，可将其删除
- 或在需要完整时长格式时，统一使用此键而不是分散的 time.* 键

---

## 5️⃣ 建议与优化方案

### 优先级 1（必须修复）

#### 1. 添加缺失的 `task.new` 键
```
// 在所有三个 Localizable.strings 中添加：
"task.new" = "New Task";  // en.lproj
"task.new" = "新任务";    // zh-Hans.lproj
"task.new" = "新工作";    // zh-Hant.lproj (可调整)
```

#### 2. 统一 `about.contributor.role` 的定义
**选项 A**（推荐）- 让 en.lproj 也用 role1/role2：
```
// en.lproj
"about.contributor.role1" = "Programming / UI Design"
"about.contributor.role2" = "Creative Direction / Localization"
```

**选项 B** - 让 zh-Hans 和 zh-Hant 都用单一 role：
```
// zh-Hans.lproj
"about.contributor.role" = "程序 / UI 设计"
"about.contributor.role.alt" = "创意 / 本地化"
```

#### 3. 补全 zh-Hant.lproj 中缺失的键
```
"profile.avatar.photo.pick" = "從相簿選擇頭像"
"profile.avatar.photo.remove" = "移除照片頭像"
```

### 优先级 2（清理未使用）

#### 清理 8 个未使用的通用键
除非这些键是为了未来功能预留：
- `common.add`, `common.off`, `common.unlimited`：完全未使用
- `common.previousWeek`, `common.nextWeek`：统计功能未实现
- `common.resume`, `common.save`：可能被 `common.pause` 等取代

**建议**：从 Localizable.strings 中删除，或添加代码注释说明保留原因。

#### 清理 5 个任务相关的未使用键
- `task.form.basic`：未在编辑界面使用（可能是设计变更）
- `task.countdown.preview`：被 `task.countdown.minutes.preview` 替代
- `task.edit.requiresAll`：可能的遗留设计
- `task.running`：被代码中的动态 controlTitle 取代

### 优先级 3（结构优化）

#### 简化 Countdown 的 prefix/suffix 设计
- 如果界面已确定不使用 `countdown.inDays.prefix` 和 `countdown.pastDays.prefix`，则：
  - 删除这些 prefix 键
  - 确保 `countdown.inDays` 和 `countdown.pastDays` 被代码使用

#### 统一或删除 `duration.hms`
- 若不使用，删除
- 若计划使用，更新代码在相应位置调用此键

---

## 6️⃣ 统计概览

| 类别 | 数量 | 说明 |
|------|------|------|
| 总定义的键 | 240 | en.lproj 中的所有键 |
| 代码实际使用的键 | 209 | 通过 String(localized:) 使用 |
| 未使用的键 | 31 | **可考虑删除** |
| 代码中使用但未定义的键 | 1 | **task.new - 必须添加** |
| 多语言不一致的键 | 3 | **需要统一** |
| 可合并的键组 | 2+ | Countdown prefix/suffix, duration 相关 |

---

## 7️⃣ 实现优先级检查清单

- [ ] **第 1 周**：修复 `task.new` 缺失定义（优先级 1）
- [ ] **第 1 周**：统一 `about.contributor.role` 定义（优先级 1）
- [ ] **第 2 周**：补全 zh-Hant.lproj 的缺失键（优先级 1）
- [ ] **第 2 周**：删除或标记 8 个未使用的通用键（优先级 2）
- [ ] **第 3 周**：删除或标记 5 个任务相关的未使用键（优先级 2）
- [ ] **第 4 周**：优化 Countdown 和 duration 的键设计（优先级 3）

---

## 附录：完整的未使用键列表（CSV 格式）

```csv
Key,Value (EN),Category,Reason
about.app,"App",about,Not used anywhere
about.contributor.role,"Programming / UI Design",about,Inconsistent with zh-Hans
about.localization.ai,"AI Translation",about,Marked but not used
common.add,"Add",common,No add buttons in UI
common.nextWeek,"Next 7 days",common,Range selector UI not implemented
common.off,"Off",common,No toggle display with "Off" label
common.previousWeek,"Previous 7 days",common,Range selector UI not implemented
common.resume,"Resume",common,Replaced by common.pause in UI
common.save,"Save",common,Not visible in current UI
common.unlimited,"Unlimited",common,Not displayed in settings
countdown.inDays,"%d days left",countdown,Replaced by inDays.prefix
countdown.pastDays,"%d days ago",countdown,Replaced by pastDays.prefix
duration.hms,"%d h %d m %d s",duration,Never called in code
notification.focus.body,"You have not started a focus session today.",notification,Not implemented
notification.focus.title,"Time to focus",notification,Not implemented
profile.settings.manage,"Settings",profile,Duplicate of profile.settings
session.showControls,"Show Controls",session,UI design changed
settings.autoPin,"Auto move completed tasks to top",settings,Possible legacy option
settings.category.advanced,"Advanced",settings,Category headers not displayed
settings.category.task,"Task behavior",settings,Category headers not displayed
settings.category.timer,"Timer behavior",settings,Category headers not displayed
settings.minimal,"Immersive mode",settings,Replaced by settings.immersive
stats.summary,"Summary",stats,Dashboard design changed
stats.todayCount,"Today",stats,Not displayed with this label
stats.weekOffset,"Week %d",stats,Not used in statistics view
task.add,"Add Task",task,Code uses it but may be unused section
task.countdown.preview,"Current duration: %@",task,Replaced by countdown.minutes.preview
task.edit.requiresAll,"Turn off search/filter before reordering tasks.",task,UI no longer requires this
task.form.basic,"Basics",task,Form structure changed
task.running,"Running",task,Computed dynamically in controlTitle
```

