import Foundation

extension String {
    /// 将包含 `{count}` 占位符的本地化模板拆分为前后两段。
    /// 用于在数字两侧分别设置不同样式。
    func localizedTemplateParts() -> (prefix: String, suffix: String) {
        let parts = components(separatedBy: "{count}")
        guard parts.count == 2 else {
            return ("", self)
        }
        return (
            parts[0].trimmingCharacters(in: .whitespacesAndNewlines),
            parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
