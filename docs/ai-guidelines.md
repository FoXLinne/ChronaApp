# AI Guidelines (Chrona)

## Purpose
This document defines mandatory rules for AI-assisted coding in this repository.

## Core UI Rule (Apple-First)
- For any UI/UX design and implementation, always consult and follow Apple official developer documentation first.
- Do not reinvent or replace system-provided interfaces, behaviors, or interaction patterns when native Apple APIs/components already exist.
- Prefer native SwiftUI/UIKit capabilities over custom implementations unless there is a clear product requirement.
- If a custom UI behavior is necessary, document why built-in APIs are insufficient before implementation.

## UI Implementation Principles
- Prioritize Human Interface Guidelines (HIG) consistency: navigation, spacing, typography, feedback, accessibility.
- Use platform-standard controls (e.g., `NavigationStack`, `Form`, `List`, `Sheet`, `PhotosPicker`, SF Symbols) whenever possible.
- Avoid creating custom controls that mimic Apple system controls unless required by business goals.
- Keep visual behavior aligned with system conventions (animations, gestures, modal presentation, safe areas).

## Decision Policy for AI
When generating UI code, AI must:
1. Check whether Apple has an official component/API for the target behavior.
2. Use the official API as the default solution.
3. If proposing a custom implementation, explicitly explain:
   - why native APIs do not satisfy requirements,
   - tradeoffs (maintenance/accessibility/performance),
   - fallback plan.

## References (Authoritative)
- Apple Developer Documentation: https://developer.apple.com/documentation/
- Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines/
- SwiftUI Documentation: https://developer.apple.com/documentation/swiftui
- UIKit Documentation: https://developer.apple.com/documentation/uikit

## Enforcement
- PRs and AI-generated changes that violate the Apple-First UI rule should be revised before merge.
