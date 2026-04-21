import json
import os

filepath = "/Users/kaedekr/ChronaProject/Chrona/Chrona/Resources/Localizable.xcstrings"

with open(filepath, 'r', encoding='utf-8') as f:
    data = json.load(f)

# Add new category name
data["strings"]["settings.category.system"] = {
    "localizations": {
        "en": {"stringUnit": {"state": "translated", "value": "System Settings"}},
        "zh-Hans": {"stringUnit": {"state": "translated", "value": "系统设置"}},
        "zh-Hant": {"stringUnit": {"state": "translated", "value": "系統設定"}},
        "ja": {"stringUnit": {"state": "translated", "value": "システム設定"}}
    }
}

# Add new action name
data["strings"]["settings.systemSettings.action"] = {
    "localizations": {
        "en": {"stringUnit": {"state": "translated", "value": "Enter System Settings"}},
        "zh-Hans": {"stringUnit": {"state": "translated", "value": "进入系统设置"}},
        "zh-Hant": {"stringUnit": {"state": "translated", "value": "進入系統設定"}},
        "ja": {"stringUnit": {"state": "translated", "value": "システム設定に移動"}}
    }
}

# Add new footer name
data["strings"]["settings.systemSettings.footer"] = {
    "localizations": {
        "en": {"stringUnit": {"state": "translated", "value": "Enter system settings to change options such as language."}},
        "zh-Hans": {"stringUnit": {"state": "translated", "value": "进入系统设置可更改语言等选项"}},
        "zh-Hant": {"stringUnit": {"state": "translated", "value": "進入系統設定可更改語言等選項"}},
        "ja": {"stringUnit": {"state": "translated", "value": "システム設定で言語などのオプションを変更できます"}}
    }
}

with open(filepath, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print("Updated Localizable.xcstrings with final system settings strings")
