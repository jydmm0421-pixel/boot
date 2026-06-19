# CyberEx - 赛博前任机器人

一个跨平台的聊天机器人，可以模拟前任的说话风格，或从零养成一个独特的 AI 性格。

## 功能

- 💬 **两种模式**：导入真实聊天记录模仿 / 从零养成性格
- 🧠 **持久记忆**：SQLite 本地存储，永不丢失
- 🎭 **去人机感**：十层策略让回复像真人
- 🖥️📱 **双端原生**：Windows .exe + Android .apk

## 运行

```bash
flutter pub get
flutter run -d windows
```

## 打包

```bash
flutter build windows --release
flutter build apk --release
```

## 给朋友使用

1. 准备 DeepSeek API Key (https://platform.deepseek.com)
2. 首次打开 App 按引导设置
3. 选择模式：导入聊天记录 / 从零养成
4. 开始聊天！
