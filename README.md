# GoToDo

GoToDo 是一个基于 Flutter 构建的个人专注记录应用，核心目标是把「开始专注」「沉淀记录」「统计回顾」串成一个本地优先的闭环。当前版本聚焦 Android 端，支持项目化专注、正向计时/倒计时、时间线统计、周回顾以及本地数据备份恢复。

## 项目定位

从产品形态上看，GoToDo 不是待办清单工具，而是偏执行记录工具：

- 以“项目”为核心组织专注行为，而不是以单条任务为核心。
- 以“专注 session”作为最小数据单元，保留开始、暂停、恢复、完成、取消等状态变化。
- 以“时间线 + 周回顾”承接统计分析，帮助用户复盘时间投入结构。
- 以本地 SQLite 为主存储，优先保证离线可用和数据可控。

## 技术栈

- Flutter 3 / Dart 3
- 状态管理：Riverpod
- 本地数据库：Drift + SQLite
- 图表：fl_chart
- 本地文件与目录：path_provider
- ID 生成：uuid
- 国际化基础能力：flutter_localizations + intl

## 架构概览

项目采用偏轻量的分层结构，整体可理解为：

- `presentation`：页面与组件，负责交互、渲染和局部状态。
- `application`：页面级业务编排，例如专注计时控制器。
- `core/data`：仓储层，封装数据库读写和领域对象创建。
- `core/database`：Drift 表结构、查询接口、迁移策略。
- `core/stats`：统计计算逻辑，负责时间分摊、连续天数、汇总结果等纯计算能力。
- `core/native`：与平台能力交互的封装层，例如计时器、存储/文件选择。

当前实现偏单体应用结构，但分层已经明确，后续继续演进为更清晰的 feature-first 目录也比较顺滑。

## 目录结构

```text
lib/
  main.dart
  src/
    app/
      gotodo_app.dart
      main_shell.dart
    core/
      data/
      database/
      models/
      native/
      stats/
      theme/
      utils/
    features/
      review/
      settings/
      timeline/
      timer/
    shared/
      widgets/
test/
  stats_calculator_test.dart
```

主要模块职责如下：

- `app/`
  应用入口、主题注入、底部导航壳。
- `features/timer/`
  专注开始页、进行中状态面板、项目创建编辑、倒计时/正向计时交互。
- `features/timeline/`
  按天时间线、日历视图、最近趋势图、项目时长分布。
- `features/review/`
  周维度统计回顾与连续天数计算结果展示。
- `features/settings/`
  主题、通知偏好、备份恢复、清理数据。
- `core/database/`
  SQLite 表定义、查询接口、迁移逻辑。
- `core/data/`
  `ProjectRepository`、`FocusSessionRepository`、`SettingsRepository`、`DataBackupService`。
- `core/stats/`
  统计分析核心逻辑，当前已有单元测试覆盖部分边界行为。

## 数据模型

当前数据库由 3 张表组成：

### `projects`

专注项目表，存储项目名称、颜色、排序、归档状态，以及默认专注模式等配置。

关键字段：

- `id`：项目主键
- `name`：项目名称
- `colorValue`：项目颜色
- `isArchived`：是否归档
- `dailyGoalSeconds`：日目标时长
- `weeklyGoalSeconds`：周目标时长
- `defaultMode`：默认模式，`count_up` / `count_down`
- `defaultCountdownSeconds`：默认倒计时秒数

### `focus_sessions`

专注记录表，保存完整的 session 生命周期信息。

关键字段：

- `projectId`：所属项目
- `mode`：计时模式
- `startAt` / `endAt`：开始与结束时间
- `lastPausedAt`：最近一次暂停时间
- `effectiveSeconds`：有效专注时长
- `plannedSeconds`：计划时长
- `pauseSeconds`：累计暂停时长
- `status`：`running` / `paused` / `completed` / `cancelled`

### `app_settings`

键值型应用设置表，用于保存主题、通知开关等轻量配置。

## 核心业务能力

### 1. 项目化专注

- 支持创建、编辑、归档专注项目
- 支持为项目配置默认计时模式
- 支持按颜色区分不同项目

### 2. 专注计时流程

- 支持正向计时和倒计时两种模式
- 支持进行中暂停、继续、完成、取消
- 专注完成后写入时间线统计数据

### 3. 时间线统计

- 支持按天查看专注记录
- 支持整体视角查看趋势
- 支持按项目聚合时长并用图表展示

### 4. 周回顾

- 支持本周 / 上周视角切换
- 支持统计总时长、项目分布、连续专注天数
- 统计逻辑考虑了跨天 session 的按时间范围分摊

### 5. 数据管理

- 支持 SQLite 数据库备份到本地目录
- 支持从本地文件恢复数据库
- 支持清空用户业务数据

## 状态管理与数据流

项目当前采用 Riverpod 作为依赖注入与状态分发中心：

- `Provider`：注入数据库、仓储、平台服务
- `StreamProvider`：向页面暴露项目列表、完成记录、设置项变化
- 控制器：在 `features/timer/application` 中承接计时业务流程

典型数据流如下：

1. 页面通过 Provider 订阅项目或 session 数据。
2. 用户操作触发控制器或仓储方法。
3. 仓储层调用 Drift 读写 SQLite。
4. 数据流回到 `StreamProvider`，页面自动刷新。

这种模式对于当前单机应用是足够的，简单直接，维护成本低。

## 数据库迁移

数据库 schema 当前版本为 `2`，已包含基础迁移逻辑：

- `v1 -> v2`
  为 `projects` 表新增默认计时模式和默认倒计时字段。

如果后续继续扩展表结构，建议保持以下约束：

- 所有 schema 变更都在 `MigrationStrategy` 中显式处理。
- 避免依赖“删库重建”解决版本升级问题。
- 对统计类字段新增时，优先考虑默认值和旧数据兼容。

## 开发环境

建议环境：

- Flutter SDK 3.x
- Dart SDK 3.x
- Android Studio 或 VS Code + Flutter 插件
- Android SDK / 模拟器或真机

安装依赖：

```bash
flutter pub get
```

如果修改了 Drift 表结构或相关生成代码，执行：

```bash
dart run build_runner build --delete-conflicting-outputs
```

## 运行与调试

本地运行：

```bash
flutter run
```

构建 Android Release APK：

```bash
flutter build apk --release
```

当前仓库最近一次 Release APK 位于：

- `build/app/outputs/flutter-apk/app-release.apk`

## 测试

执行测试：

```bash
flutter test
```

当前已有测试主要覆盖统计逻辑：

- 跨天 session 在区间统计中的时长分摊
- 连续专注天数计算

从工程角度看，后续建议优先补齐：

- `FocusTimerController` 的状态流转测试
- Repository 层的数据库读写测试
- 备份恢复流程测试
- 关键页面的 Widget 测试

## 当前实现特点

这个项目当前有几个比较明确的工程特征：

- 优先本地化：核心能力不依赖服务端即可运行。
- 业务闭环完整：从开始专注到回顾分析链路已经打通。
- 分层已经具备：虽然体量不大，但仓储、数据库、页面、统计逻辑已经分开。
- 可继续扩展：后续可以自然演进出云同步、任务系统、通知增强、跨端同步等能力。

## 后续可演进方向

如果继续按工程化方向推进，建议优先做下面几件事：

- 修正并统一部分中文文案编码问题，避免界面出现乱码。
- 增加更系统的单元测试和 Widget 测试。
- 为计时器与备份恢复补充异常处理和边界状态保护。
- 增加 CI，至少覆盖 `flutter analyze`、`flutter test`、`flutter build apk`。
- 补充正式的 `CHANGELOG.md`、Issue 模板和 PR 模板。
- 如果计划长期维护，可引入更明确的领域模型与 use case 层。

## License

当前仓库未声明 License。如需开源发布，建议补充明确的许可证文件。
