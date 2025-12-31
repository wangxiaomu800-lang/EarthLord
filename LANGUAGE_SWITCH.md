# App 内语言切换功能

✅ **已完成实现！用户可以在 App 内自由切换语言，无需依赖系统设置。**

## 功能特性

### 🌍 支持的语言
- **跟随系统** - 自动使用设备系统语言
- **简体中文** - zh-Hans
- **English** - en

### ⚡ 核心功能
- ✅ 实时切换，无需重启 App
- ✅ 用户选择持久化存储（UserDefaults）
- ✅ 下次启动自动加载上次选择
- ✅ 支持所有界面文本的本地化

## 实现架构

### 1. LanguageManager（语言管理器）
位置：`EarthLord/Managers/LanguageManager.swift`

**功能**：
- 单例模式管理全局语言设置
- 使用 `@Published` 属性实现响应式更新
- UserDefaults 持久化存储
- 提供 `localizedString()` 方法获取本地化文本

**核心代码**：
```swift
@MainActor
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @Published var currentLanguage: AppLanguage {
        didSet {
            saveLanguage()
        }
    }

    func localizedString(_ key: String) -> String {
        // 根据当前选择的语言返回对应翻译
    }
}
```

### 2. String 扩展
提供便捷的本地化方法：

```swift
// 简单使用
Text("设置".localized)

// 带参数
Text("%lld秒后重发".localized(countdown))
```

### 3. 设置界面更新
位置：`EarthLord/Views/SettingsView.swift`

**新增组件**：
- 语言设置卡片 - 显示当前语言
- 语言选择器弹窗 - 选择语言选项
- 美观的选项列表设计

## 使用方法

### 用户操作步骤
1. 打开 App
2. 进入 "更多" Tab
3. 点击 "设置"
4. 点击 "语言设置" 卡片中的 "当前语言"
5. 在弹窗中选择想要的语言：
   - 跟随系统
   - 简体中文
   - English
6. 选择后立即生效，所有文本自动更新

### 开发者使用

#### 在代码中使用本地化文本：

```swift
// SwiftUI Text
Text("登录".localized)

// 字符串变量
let message = "验证成功！请设置密码完成注册".localized

// 带格式化参数
let countdown = 60
Text("%lld秒后重发".localized(countdown))
```

#### 添加新的本地化文本：

1. 在 `Localizable.xcstrings` 中添加新的 key
2. 同时提供中文和英文翻译：

```json
"新的文本" : {
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "New Text"
      }
    }
  }
}
```

## 技术细节

### 语言切换原理
1. 用户选择语言 → `LanguageManager.currentLanguage` 更新
2. `@Published` 属性触发 → 所有观察者收到通知
3. UI 组件重新渲染 → 调用 `.localized` 获取新语言文本
4. 设置保存到 UserDefaults → 下次启动恢复

### 持久化存储
- 使用 UserDefaults 存储 key: `app_language`
- 存储值：`"system"` | `"zh-Hans"` | `"en"`
- App 启动时自动加载

### 响应式更新
- `LanguageManager` 继承 `ObservableObject`
- `currentLanguage` 使用 `@Published` 包装
- 所有使用 `.localized` 的视图自动更新

## 文件清单

### 新增文件
- `EarthLord/Managers/LanguageManager.swift` - 语言管理核心逻辑

### 修改文件
- `EarthLord/Views/SettingsView.swift` - 添加语言选择界面
- `Localizable.xcstrings` - 添加语言设置相关翻译

### 新增翻译 Keys
- `语言设置` → "Language"
- `当前语言` → "Current Language"
- `选择语言` → "Select Language"
- `完成` → "Done"
- `跟随系统语言设置` → "Follow system language"

## 测试建议

1. **切换测试**
   - 切换到简体中文，检查所有界面文本
   - 切换到 English，检查所有界面文本
   - 切换到跟随系统，验证使用系统语言

2. **持久化测试**
   - 选择一种语言
   - 完全关闭 App
   - 重新打开，验证语言选择被保留

3. **实时更新测试**
   - 在不同页面切换语言
   - 确认所有文本立即更新
   - 检查导航栏、Tab 栏、弹窗等

## 扩展指南

### 添加更多语言

1. 在 `AppLanguage` 枚举中添加新语言：
```swift
enum AppLanguage: String, CaseIterable {
    case system = "system"
    case chinese = "zh-Hans"
    case english = "en"
    case japanese = "ja"  // 新增
    case korean = "ko"    // 新增
}
```

2. 更新 `displayName` 和 `languageCode`
3. 在 `Localizable.xcstrings` 中添加对应翻译

### 特殊格式化需求

对于复杂的本地化需求（复数、性别等），可以扩展 LanguageManager：

```swift
func localizedPlural(_ key: String, count: Int) -> String {
    // 处理复数形式
}
```

## 注意事项

⚠️ **重要提示**：
- 所有用户可见的文本都应该使用 `.localized`
- 日志输出可以保持原语言（方便开发调试）
- 添加新文本时必须同时提供所有语言的翻译
- 格式化字符串（如 `%lld`, `%@`）要保持一致

## 性能考虑

- ✅ 单例模式避免重复创建
- ✅ 本地化文本缓存在 Bundle 中
- ✅ UserDefaults 读取仅在启动时进行一次
- ✅ 语言切换时才触发 UI 更新

## 未来优化方向

- [ ] 添加更多语言支持（日语、韩语等）
- [ ] 支持 RTL（从右到左）语言
- [ ] 添加语言切换动画效果
- [ ] 云端同步用户语言偏好
