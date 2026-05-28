# roblox-starter

最小 Rojo + mise 项目，可在 Roblox Studio 里立刻跑起来。

## 前置

- [Roblox Studio](https://create.roblox.com)
- [mise](https://mise.jdx.dev)（`winget install jdx.mise`）
- Git（可选，推荐）

## 今天就能跑起来

```powershell
cd <你的项目路径>\roblox-starter
mise trust
mise install
mise run plugin
mise run serve
```

详细搭建记录见 [docs/2026-05-27-环境搭建记录.md](docs/2026-05-27-环境搭建记录.md)。

1. 打开 **Roblox Studio** → 新建 **Baseplate**（或空地方）
2. 插件栏 **Rojo** → **Connect**
3. 点 **Play**，在 Output 里应看到 server/client 的 print

## 常用命令

| 命令 | 说明 |
|------|------|
| `mise run serve` | 启动同步服务（保持终端开着） |
| `mise run plugin` | 把 Rojo 插件装进 Studio |
| `mise run build` | 导出 `build/place.rbxlx` |
# G1_Roblox
