<p align="center">
  <img src="Chrona/Resources/icons/appicon-iOS-Default-1024x1024@1x.png" width="128" alt="Chrona App Icon">
</p>

<h1 align="center">Chrona</h1>

<p align="center">
  <a href="https://github.com/FoXLinne/ChronaApp/releases">
    <img src="https://img.shields.io/github/v/release/FoXLinne/ChronaApp?style=flat-square" alt="Latest Release">
  </a>
  <a href="https://github.com/FoXLinne/ChronaApp/stargazers">
    <img src="https://img.shields.io/github/stars/FoXLinne/ChronaApp?style=flat-square" alt="Stars">
  </a>
  <a href="https://github.com/FoXLinne/ChronaApp/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/FoXLinne/ChronaApp?style=flat-square" alt="License">
  </a>
  <a href="https://github.com/FoXLinne/ChronaApp/issues">
    <img src="https://img.shields.io/github/issues/FoXLinne/ChronaApp?style=flat-square" alt="Issues">
  </a>
</p>

---

一个简洁的 iOS 专注计时应用，采用 SwiftUI 原生开发。
部分代码借助 AI 开发工具辅助构建。

## 功能

- **多种计时模式**：番茄钟、倒计时和正向计时
- **任务管理**：创建和组织专注任务，支持自定义背景
- **计时记录**：追踪专注历史，查看详细统计数据
- **沉浸模式**：专注时支持黑屏沉浸显示
- **专注行为设置**：暂停时间限制、任务后休息、禁止提前完成
- **显示偏好**：主题选择、屏幕常亮、界面自定义
- **倒数日**：追踪即将到来和已发生的事件
- **每日签到**：记录每日专注参与
- **多语言支持**：内置中文和英文

## 项目结构

```
Chrona/
├── Models/          - 数据模型（任务、记录、设置）
├── ViewModels/      - 应用状态管理（AppViewModel）
├── Views/           - UI 界面（按功能分类）
├── Services/        - 数据持久化、通知、计时引擎
└── Resources/       - 本地化字符串和资源
```

## 开发环境要求

- iOS 26.0+
- Xcode 26.0+

## 构建运行

1. 用 Xcode 打开 `Chrona.xcodeproj`
2. 选择 Chrona scheme
3. 构建并运行到模拟器或真机

## 设计原则

本项目遵循 [Apple 人机交互指南](https://developer.apple.com/design/human-interface-guidelines/)，优先使用 SwiftUI 原生组件而非自定义实现。

---

<p align="center">
  <a href="https://github.com">
    <img src="https://img.shields.io/badge/GitHub-181717?style=flat-square&logo=github" alt="GitHub">
  </a>
</p>