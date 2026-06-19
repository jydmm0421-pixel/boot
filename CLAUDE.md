# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

CyberEx（赛博前任机器人）— 跨平台 Flutter 聊天机器人应用。核心功能：通过 DeepSeek API 驱动的 AI 对话，支持两种模式：(A) 导入真实聊天记录模仿说话风格，(B) 从零养成可演化的 AI 性格。

## 常用命令

```bash
# 安装依赖
flutter pub get

# 代码静态分析
flutter analyze

# 运行测试
flutter test

# 运行单个测试文件
flutter test test/widget_test.dart

# Windows 开发运行
flutter run -d windows

# 打包
flutter build windows --release    # → build/windows/x64/runner/Release/
flutter build apk --release        # → build/app/outputs/flutter-apk/app-release.apk
```

## 架构

### 依赖注入

`main.dart` 使用 `MultiProvider`（provider 包）将所有 Service 注入 widget 树。各 Screen 通过 `context.read<T>()` 获取服务实例。没有使用路由框架，直接 `Navigator.pushReplacement` 切换 SetupScreen → HomeScreen。

### 分层结构

```
lib/
├── main.dart          # 入口：Provider 注册
├── app.dart           # MaterialApp + StartupGate（检查是否完成初始化）
├── models/            # 数据模型，均带 fromMap/toMap（SQLite 序列化）
│   ├── message.dart   # 聊天消息
│   ├── memory.dart    # AI 提取的记忆点
│   └── personality.dart # 人格档案（含 traits 特征评分）
├── services/
│   ├── config_service.dart      # API Key（加密存储）+ SharedPreferences
│   ├── database_service.dart    # SQLite 封装（3 张表 + 索引）
│   ├── llm_service.dart         # DeepSeek API（流式/非流式 + system prompt 构建）
│   ├── memory_service.dart      # 记忆提取触发、关键词召回
│   ├── personality_service.dart # 人格创建/分析/演化
│   └── humanizer_service.dart   # 后处理引擎：去 AI 味 + 情绪参数 + 打字延迟
├── screens/
│   ├── setup_screen.dart    # 首次引导：API Key + 模式选择 + 人设
│   ├── home_screen.dart     # 底部三栏导航（聊天/记忆/设置）
│   ├── chat_screen.dart     # 核心聊天界面 + 流式输出 + 记忆自动提取
│   ├── memory_screen.dart   # 记忆列表管理
│   └── settings_screen.dart # 设置页
└── widgets/
    ├── chat_bubble.dart     # 聊天气泡（微信风格，支持亮/暗）
    ├── chat_input.dart      # 输入栏
    └── typing_indicator.dart # 正在输入动画
```

### 数据流（核心链路）

1. 用户输入 → `ChatScreen._sendMessage()`
2. `HumanizerService.rollMoodParams()` 生成随机情绪参数
3. `MemoryService.getRelevantMemories()` 关键词匹配召回记忆
4. `LlmService.chatStream()` 构建 system prompt（注入人格 + 情绪 + 记忆 + 去人机感规则），流式调用 DeepSeek API
5. 流式输出实时渲染到 `ChatBubble`
6. `HumanizerService.postProcess()` 后处理（删禁用词、去 markdown、打断完美句子）
7. 保存 Message 到 SQLite
8. 每 8 轮 `MemoryService.autoExtractMemories()` 调用 LLM 提取新记忆

### LLM 集成

- **API**: DeepSeek (`api.deepseek.com/v1/chat/completions`)，模型 `deepseek-chat`
- **两种调用方式**: `LlmService.chat()` 非流式，`LlmService.chatStream()` 流式（生产使用）
- **System Prompt 构建**: `LlmService._buildSystemPrompt()` 组合人格定义 + 当前情绪 + 去人机感禁止规则 + 相关记忆 + 回复长度随机控制
- **额外 LLM 用途**: `analyzeChatHistory()` 分析聊天记录输出 JSON 人格档案；`extractMemory()` 从对话中提取记忆点

### 数据库

SQLite（sqflite），单文件 `cyber_ex.db`，3 张表：
- `messages` — 按 session_id + created_at 索引
- `memories` — 按 importance 降序排列，支持 source_msg_ids 溯源
- `personality` — 每个 session 一行，traits 以 JSON 字符串存储

### 两种模式

| | 模式 A（import） | 模式 B（cultivate） |
|---|---|---|
| 触发 | 用户上传聊天记录文件 | 用户选择性格底色 |
| 人格来源 | LLM 分析聊天记录生成 | 预设默认值 + 背景故事 |
| 后续变化 | 固定 | `PersonalityService.evolvePersonality()` 随时间微调 |

## CI / CD

`.github/workflows/build.yml` 在 push main/master 时自动构建：
- **Android APK** (`ubuntu-latest`) — 需要 Java 17 + Flutter stable
- **Windows EXE** (`windows-latest`) — 产物为整个 Release 目录

产物保留 30 天，手动触发也支持（`workflow_dispatch`）。APK 当前使用 debug 签名。

## 注意事项

- **API Key 存储**: `FlutterSecureStorage`（加密），不落地明文。首次启动走 `SetupScreen` 引导设置。
- **网络**: `http` 包直连 DeepSeek API，没有中间代理。国内网络下 `pub get` 可能需要镜像源。
- **平台差异**: `sqflite` 使用 `path_provider` 获取数据库路径；`file_picker` 用于导入聊天记录。Windows 打包需开启开发者模式。
- **Provider 而非 Riverpod/Bloc**: 项目使用简单的 Provider 模式，不要引入其他状态管理方案。
- **测试**: 仅有基础 widget test，测试时 CyberExApp 内嵌的 StartupGate 会触发 ConfigService 调用，可能因缺少 secure storage 而失败，需要用 mock。
