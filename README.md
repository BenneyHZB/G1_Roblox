# G1_Roblox

Rojo + mise 最小项目：在 Cursor 写代码，在 Roblox Studio 里运行。

**说明：** 仓库里没有「场景文件」。地图/Part 在 Studio 的 Place 里；脚本在 `src/`，通过 Rojo 同步进去。

## 第一次（新机 / 刚克隆）

1. 安装 [Roblox Studio](https://create.roblox.com)
2. 安装 mise：`winget install jdx.mise`
3. 新开 PowerShell，进入项目根目录（含 `mise.toml` 的那一层）：

```powershell
cd C:\Roblox_PJ\G1_Roblox
mise trust
mise install
```

4. 在 Studio **插件市场**搜索并安装 **Rojo**（`mise run plugin` 在部分 Windows 上会失败，手动装即可）

## 每次开发（打开工程）

### 1. Cursor 打开代码

**文件 → 打开文件夹** → 选 `G1_Roblox` 根目录

### 2. 终端启动同步（窗口保持打开）

```powershell
cd C:\Roblox_PJ\G1_Roblox
mise run serve
```

看到 `Rojo server listening` 即成功。

### 3. Studio 连接并运行

1. 打开 Roblox Studio → **New → Baseplate**（或继续用已有 Place）
2. **插件 → Rojo → Connect**
3. 点 **Play**，在 **Output** 查看日志

### 4. 写代码

改 `src/**/*.luau` 并保存；已 Connect 时 Studio 会自动同步。

## 跑通标志

| 位置 | 应看到 |
|------|--------|
| 终端 | `Rojo server listening` |
| Studio | Rojo 已 **Connect** |
| Output | `[roblox-starter] Server started ...` 与 `Client started ...` |

Explorer 中应有：`ServerScriptService.Server`、`StarterPlayerScripts.Client`、`ReplicatedStorage.Shared`，以及 `Workspace.Map`（城堡、刷怪点等）。

## 同步模型 / 场景物体

**不用每次手动拖。** 模型放进 `assets/`，Rojo Connect 后会自动进 Studio。

| 磁盘路径 | Studio 位置 | 用途 |
|----------|-------------|------|
| `assets/map/` | `Workspace.Map` | 关卡物体（城堡 City、刷怪点 EnemySpawn…） |
| `assets/templates/` | `ReplicatedStorage` | 可 Clone 的模板（如 EnemyTemplate） |

### 新增模型的两种方式

**简单物体**（Part、空 Model）：在 `assets/` 里新建 `.model.json`，保存即同步。

**复杂模型**（Toolbox 人物、Mesh、Union 等）：

1. 在 Studio 里摆好模型
2. Explorer 里右键 → **Save to File…** → 存成 `.rbxmx`
3. 放进对应目录，例如 `assets/templates/EnemyTemplate.rbxmx`
4. 在 `default.project.json` 里把 `$path` 指向该文件（替换占位 `.model.json`）
5. 保存后 Rojo 自动更新，**不用再拖**

> 日常开发用 Baseplate + Connect 即可；`assets/` 里的物体会同步进来，不必在 Studio 里重复摆放。

## 常用命令

| 命令 | 说明 |
|------|------|
| `mise run serve` | 启动同步（开发时保持运行） |
| `mise run build` | 导出 `build/place.rbxlx` |
| `mise exec -- rojo --version` | 查看 Rojo 版本 |

## 常见问题

- **`mise` 找不到**：重开 PowerShell；仍不行则把 `%LOCALAPPDATA%\Microsoft\WinGet\Links` 加入用户 PATH
- **`mise trust` 报错**：必须在项目根目录执行，不要在上级目录
- **`no tasks defined`**：当前目录不对，先 `cd` 到含 `mise.toml` 的根目录
- **找不到场景**：日常不用打开 `.rbxl`；Studio 新建 Baseplate + Rojo Connect 即可

更多说明见 [docs/2026-05-27-环境搭建记录.md](docs/2026-05-27-环境搭建记录.md)。
