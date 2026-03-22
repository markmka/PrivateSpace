# Vault — 安全私密内容存储 App 设计文档

**日期：** 2026-03-22
**状态：** 已批准

---

## 1. 概述

### 1.1 App 定位

**Vault** 是一款离线优先的安全私密内容存储 app，支持存储用户账号密码、私钥及其他敏感信息。不联网但通过 iCloud 在用户设备间同步内容。

核心定位：**混合型设计** — 密码管理 + 通用加密保险箱

### 1.2 核心特性

| 特性 | 说明 |
|------|------|
| 离线存储 | 所有数据本地加密存储，不上传第三方服务器 |
| iCloud 同步 | 通过 CloudKit 在用户 Apple 设备间自动同步 |
| 生物识别解锁 | Face ID / Touch ID 解锁为主 |
| Master Password | 可选主密码作为备份或强制使用 |
| 自定义字段 | 每种类型支持自由添加任意字段 |
| 自定义类型 | 用户可创建新的条目类型 |
| 剪贴板安全 | 复制敏感内容后 30 秒自动清除 |
| 密码自动填充 | 集成 iOS 密码自动填充 API |

---

## 2. 用户体验设计

### 2.1 界面结构

App 分为以下主要界面：

1. **解锁页** — Face ID / Master Password 解锁
2. **主列表页** — 条目列表 + 搜索 + 筛选
3. **条目详情页** — 查看条目字段内容
4. **条目编辑页** — 创建/编辑条目
5. **设置页** — 安全设置 + 自定义类型管理
6. **自定义类型编辑页** — 创建/编辑自定义类型

### 2.2 解锁页

- 深色安全风格背景
- App Logo + 名称居中显示
- Face ID 按钮（主解锁方式）
- Master Password 输入框（备选方式）
- 首次使用引导链接

**解锁流程：**
1. App 启动 → 检测生物识别可用性
2. 默认显示 Face ID 按钮，点击触发识别
3. 识别成功 → 进入主列表页
4. 识别失败 / 用户跳过 → 显示 Master Password 输入
5. Master Password 验证成功 → 进入主列表页

### 2.3 主列表页

**顶部导航栏：**
- App Logo（左侧）
- 搜索按钮（右侧）
- 设置按钮（右侧）

**类型筛选条：**
- 横向滚动的筛选标签
- 选项：全部 / 密码 / 私钥 / 安全笔记 / 其他 / [用户自定义类型]
- 默认选中"全部"

**条目列表：**
- 紧凑列表式布局（List Style B）
- 每行显示：类型图标 + 标题 + 字段摘要
- 按类型用不同颜色区分图标背景
- 点击进入详情页

**右下角 FAB：**
- 圆形蓝色按钮，点击展开创建选项
- 展开显示：密码、🔐私钥、📝安全笔记、📎其他
- 用户自定义类型也显示在展开菜单中
- 点击背景或再次点击 FAB 关闭

### 2.4 条目详情页

**导航栏：**
- 返回按钮（左侧）
- 编辑按钮
- 删除按钮（右侧）

**头部卡片：**
- 类型图标（大尺寸）
- 条目标题
- 类型名称 + 字段数量

**字段列表：**
- 每行显示：字段名 + 字段值 + 操作按钮
- 敏感字段（密码、私钥）默认隐藏值，点击眼睛图标显示
- 复制按钮：点击复制字段值，显示"已复制，30秒后清除"提示

### 2.5 条目编辑页

**标题输入框**
- 单行文本输入

**类型选择器：**
- 水平滚动类型卡片
- 预设类型 + 用户自定义类型

**字段列表：**
- 每字段：字段名输入框 + 字段值输入框 + 删除按钮
- 敏感字段可标记为"敏感"（隐藏值、加密存储）

**添加字段按钮：**
- 在字段列表底部
- 点击添加新的空白字段行

**保存/取消按钮**

### 2.6 设置页

**iCloud 同步卡片：**
- 同步状态（已连接 / 未连接）
- 上次同步时间
- 开关控制

**安全设置分组：**
- Face ID / Touch ID 开关
- Master Password 管理（设置/修改/删除）
- 自动锁定策略（立即 / 1分钟 / 5分钟）

**自定义类型分组：**
- 管理已有自定义类型（列表）
- 创建新类型按钮

**关于分组：**
- 版本号
- 隐私政策链接

### 2.7 自定义类型创建

**类型名称输入框**
**图标选择器：**
- SF Symbol 图标网格
- 常用图标快速选择

**预设字段列表：**
- 每字段：字段名 + 是否敏感开关
- 添加/删除字段

---

## 3. 数据架构

### 3.1 SwiftData 模型

```swift
@Model
class VaultItem {
    @Attribute(.unique) var id: UUID
    var type: ItemType
    var title: String
    var fields: [CustomField]
    var createdAt: Date
    var modifiedAt: Date
}

@Model
class CustomField {
    var id: UUID
    var name: String
    var encryptedValue: Data  // 敏感内容加密存储
    var isSecret: Bool        // true 时默认隐藏值
}

@Model
class CustomItemType {
    @Attribute(.unique) var id: UUID
    var name: String
    var iconName: String
    var presetFields: [PresetField]
}

struct PresetField {
    var name: String
    var isSecret: Bool
}
```

### 3.2 ItemType 枚举

```swift
enum ItemType: String, Codable, CaseIterable {
    case password = "password"
    case privateKey = "privateKey"
    case note = "note"
    case other = "other"
    case custom = "custom"
}
```

### 3.3 预设类型字段

| 类型 | 预设字段 |
|------|---------|
| password | website (非敏感), username (非敏感), password (敏感) |
| privateKey | privateKey (敏感), name (非敏感), note (非敏感) |
| note | title (非敏感), content (敏感) |
| other | 无预设字段 |

---

## 4. 安全模型

### 4.1 本地加密与密钥管理

- 敏感字段（密码、私钥等）使用 **CryptoKit AES-GCM** 加密后存储
- 加密密钥由 Master Password 派生（PBKDF2），生成 256-bit 对称密钥
- 密钥存储在 **iOS Keychain**，保护级别 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- **Face ID 解锁机制**：Face ID 成功后，从 Keychain 提取已存储的加密密钥到内存。用户必须先设置 Master Password，密钥派生后存入 Keychain（受生物识别保护）。之后 Face ID 解锁无需再次输入 Master Password。
- Master Password 本身不上传，仅用于派生本地存储的密钥

### 4.2 解锁流程

**首次使用设置流程（First-Time Setup）：**
1. 用户首次打开 App，显示欢迎页
2. 引导用户设置 Master Password（必填）
3. 可选：启用 Face ID / Touch ID
4. 设置完成，进入主列表页（空状态）

**常规解锁流程：**
```
App 启动
    ↓
检测生物识别可用性 + 是否已启用
    ↓
可用且已启用 → 显示 Face ID 按钮
不可用或未启用 → 跳过生物识别
    ↓
用户触发解锁（点击 Face ID 或跳过）
    ↓
Face ID 成功 → 从 Keychain 加载加密密钥 → 解锁 App
Face ID 失败或跳过 → 显示 Master Password 输入
    ↓
Master Password 验证成功 → 加载加密密钥 → 解锁 App
Master Password 验证失败 → 显示错误，重试
```

### 4.3 iCloud 同步

- 使用 **SwiftData + CloudKit** 原生集成
- CloudKit 在传输层和服务器端提供加密（AES-256），Apple 作为信任方持有密钥
- SwiftData 将数据序列化后通过 CloudKit 同步，敏感字段已在本地用 AES-GCM 加密（见 4.1），CloudKit 同步的是加密后的数据块
- 同步冲突策略：**最后写入优先**（Last-Write-Wins），基于 `modifiedAt` 时间戳
- 用户登录同一 Apple ID 即可在不同设备间自动同步
- 离线时本地操作，恢复网络后自动合并

### 4.4 剪贴板安全

- 复制敏感字段后，显示"已复制，30秒后清除"提示
- 后台 Timer 30 秒后自动清除剪贴板（`UIPasteboard.general.items = []`）

### 4.5 自动锁定

- 用户离开 app（进入后台）立即锁定
- 可配置：立即 / 1分钟 / 5分钟

---

## 5. 技术实现

### 5.1 技术栈

| 层次 | 技术 |
|------|------|
| UI 框架 | SwiftUI |
| 数据层 | SwiftData |
| 同步 | CloudKit（通过 SwiftData 的 CloudKit 集成） |
| 生物识别 | LocalAuthentication framework |
| 密钥存储 | iOS Keychain |
| 加密 | CryptoKit（AES-GCM） |

### 5.2 项目结构

```
Vault/
├── App/
│   ├── VaultApp.swift              # @main 入口
│   └── AppState.swift              # 全局状态管理
├── Features/
│   ├── Unlock/
│   │   ├── UnlockView.swift
│   │   └── UnlockViewModel.swift
│   ├── MainList/
│   │   ├── MainListView.swift
│   │   ├── MainListViewModel.swift
│   │   └── ItemRowView.swift
│   ├── ItemDetail/
│   │   ├── ItemDetailView.swift
│   │   └── ItemDetailViewModel.swift
│   ├── ItemEdit/
│   │   ├── ItemEditView.swift
│   │   └── ItemEditViewModel.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   └── SettingsViewModel.swift
│   └── CustomTypes/
│       ├── CustomTypeListView.swift
│       └── CustomTypeEditView.swift
├── Models/
│   ├── VaultItem.swift             # SwiftData @Model
│   ├── CustomField.swift          # 自定义字段模型
│   ├── ItemType.swift             # 条目类型枚举
│   └── CustomItemType.swift       # 用户自定义类型
├── Services/
│   ├── AuthenticationService.swift  # Face ID / Master Password
│   ├── KeychainService.swift       # 密钥存储
│   ├── EncryptionService.swift     # 加密/解密
│   ├── ClipboardService.swift      # 剪贴板安全
│   └── CloudSyncService.swift      # 同步状态监控
├── Components/
│   ├── SecretFieldView.swift       # 敏感字段显示/隐藏
│   ├── FABMenuView.swift           # FAB 展开菜单
│   └── FilterPillsView.swift      # 类型筛选条
└── Utilities/
    ├── Constants.swift
    └── Extensions.swift
```

### 5.3 CloudKit 配置

SwiftData 的 CloudKit 集成需要：
1. 在 Xcode 项目中启用 CloudKit capability
2. 配置 `ModelConfiguration` 使用 CloudKit container
3. 用户需要在设备设置中登录 Apple ID 并开启 iCloud

---

## 6. UI/UX 设计规范

### 6.1 视觉风格

- **现代简洁**（Modern Simple）— iOS 原生感，微妙渐变和阴影
- 强调安全感和私密性

### 6.2 颜色系统

| 用途 | 颜色 |
|------|------|
| 主色调 | #007AFF (iOS Blue) |
| 成功色 | #34C759 (iOS Green) |
| 警告色 | #FF9500 (iOS Orange) |
| 危险色 | #FF2D55 (iOS Pink/Red) |
| 背景色 | #F2F2F7 (Light Gray) |
| 卡片背景 | #FFFFFF |
| 深色背景（解锁页） | #000000 |

### 6.3 类型图标颜色

| 类型 | 颜色 |
|------|------|
| 密码 (password) | #007AFF20 (蓝色) |
| 私钥 (privateKey) | #34C75920 (绿色) |
| 安全笔记 (note) | #FF950020 (橙色) |
| 其他 (other) | #FF2D5520 (粉色) |

### 6.4 间距与圆角

- 卡片圆角：14px / 16px
- 按钮圆角：12px / 8px
- 列表项内边距：14px-16px
- 图标圆角：10px / 14px
- FAB 尺寸：56px 直径

---

## 7. 实现优先级

### Phase 1 — 核心功能
1. 项目基础搭建（SwiftData + CloudKit）
2. 解锁页（Face ID + Master Password）
3. 主列表页
4. 条目详情页
5. 条目编辑页
6. 基础 CRUD 操作

### Phase 2 — 安全功能
1. 敏感字段加密存储
2. 剪贴板安全清除
3. 自动锁定

### Phase 3 — 高级功能
1. 自定义类型管理
2. iOS 密码自动填充集成
3. 同步状态监控 UI

---

## 8. 验收标准

- [ ] App 可以通过 Face ID 解锁
- [ ] App 可以通过 Master Password 解锁
- [ ] 用户可以创建/编辑/删除条目
- [ ] 用户可以为条目添加自定义字段
- [ ] 敏感字段值默认隐藏，点击可显示
- [ ] 复制敏感字段后 30 秒自动清除剪贴板
- [ ] 数据通过 iCloud 在设备间同步
- [ ] 用户可以创建自定义类型
- [ ] 设置页可以管理安全选项
