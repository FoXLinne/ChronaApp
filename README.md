<p align="center">
  <img src="Chrona/Resources/icons/appicon-iOS-Default-1024x1024@1x.png" width="120" alt="Chrona">
</p>

<h1 align="center">Chrona</h1>

<p align="center">
  <a href="https://github.com/FoXLinne/ChronaApp/releases">
    <img src="https://img.shields.io/github/v/release/FoXLinne/ChronaApp?style=flat-square" alt="Latest Release">
  </a>
  <a href="https://github.com/FoXLinne/ChronaApp/stargazers">
    <img src="https://img.shields.io/github/stars/FoXLinne/ChronaApp?style=flat-square" alt="Stars">
  </a>
  <a href="https://github.com/FoXLinne/ChronaApp/blob/dev/1.0.5/LICENSE">
    <img src="https://img.shields.io/github/license/FoXLinne/ChronaApp?style=flat-square" alt="License">
  </a>
</p>

<p align="center">
  一款以 SwiftUI 构建的原生 iOS 专注计时应用
</p>

***

## 功能

### 计时模式

| 模式 | 说明 |
| --- | --- |
| **番茄钟** | 25/5 分钟或 50/10 分钟工作与休息周期 |
| **倒计时** | 为任务设置 1 至 300 分钟的专注时长 |
| **正向计时** | 记录不设时长上限的专注时间 |

### 任务管理

- 创建、编辑、排序和搜索专注任务
- 为任务设置计时模式、时长与背景主题
- 按偏好置顶已完成任务，并为其添加删除线
- 查看每日任务完成次数

### 专注统计

- 按日、周、月查看专注记录
- 查看专注次数、总时长、日均时长与任务分布
- 查看月度趋势和专注热力图
- 自定义统计卡片的顺序、显示状态与展开状态

### 实时活动与通知

- 在灵动岛和锁定屏幕查看进行中的专注状态
- 设置每日专注提醒与提醒时间
- 使用沉浸模式、屏幕常亮和严格专注选项调整计时体验

### 小组件

- 查看今日专注时长
- 查看选定倒数日事件
- 查看月度专注热力图

### 数据管理

- 在设备本地保存任务、专注记录、倒数日与应用设置
- 通过 JSON 备份文件导入和导出数据
- 导入时检查备份版本与完整性
- 在设置中清除应用数据

### 倒数日

- 管理今天、未来和过去的事件
- 为事件设置具体时间与提醒

### 个性化

- 设置头像、昵称与个人签名
- 使用浅色、深色或跟随系统外观
- 每日签到并查看连续签到记录
- 为任务选择不同背景主题

### 多语言

- 简体中文
- 繁體中文
- English
- 日本語

***

## 项目结构

```
ChronaApp/
├── Chrona/              # iOS 应用
│   ├── Models/          # 任务、设置、专注记录与倒数日模型
│   ├── ViewModels/      # 应用状态管理
│   ├── Views/           # SwiftUI 页面与共享组件
│   ├── Services/        # 计时、持久化、通知与系统服务
│   └── Resources/       # 本地化字符串与资源
├── ChronaWidget/        # 小组件与实时活动
├── Chrona.xcodeproj/    # Xcode 项目
├── LICENSE
└── README.md
```

## 技术栈

- **语言**：Swift 5
- **界面框架**：SwiftUI
- **应用与小组件**：WidgetKit、ActivityKit
- **最低系统版本**：iOS 27.0

## 构建要求

- Xcode 27.0 或更新版本
- iOS 27.0 或更新版本的设备

### 构建步骤

1. 使用 Xcode 打开 `Chrona.xcodeproj`
2. 选择 `Chrona` scheme
3. 选择运行设备并使用 `Cmd + R` 构建运行

## 设计原则

- 使用 SwiftUI 与 Apple 平台原生框架构建界面
- 优先采用系统交互与辅助功能规范
- 将任务与专注记录保存在设备本地，并提供用户控制的数据备份

## 许可证

[Apache License 2.0](LICENSE)

***

<p align="center">
  <a href="https://github.com/FoXLinne/ChronaApp">
    <img src="https://img.shields.io/badge/GitHub-181717?style=flat-square&logo=github" alt="GitHub">
  </a>
</p>
