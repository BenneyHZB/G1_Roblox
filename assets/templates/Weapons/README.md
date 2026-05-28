# 武器模板 → `ReplicatedStorage.Weapons`

Rojo 同步：`default.project.json` 里 `"Weapons": { "$path": "assets/templates/Weapons" }`

## 正确保存步骤（Studio）

1. 在 **Explorer** 里选中整把武器（必须是 **Tool**，或 Model 里只有一个 Tool）。
2. 确认 **Properties → Name**：
   - 推荐与 `GameConfig.WeaponToolName` 一致：`Sword`、`Ban Hammer`、`Rainbow Sword`
   - 或用文件名：`Sword.rbxm`、`BanHammer.rbxm`（代码会自动匹配 `Ban Hammer`）
3. 右键该 Tool（或顶层 Model）→ **Save to File…**
4. 保存到本目录：
   - `Sword.rbxm`
   - `BanHammer.rbxm`（可加 `BanHammer.rbxm.meta.json` 指定 Studio 名为 `Ban Hammer`）
   - `RainbowSword.rbxm`
   - `Azure.rbxm`（Studio 里 Tool 名须为 `Azure`）
5. **不要**存成放在子文件夹里的路径（Rojo 只同步本目录一层 `.rbxm`）。
6. 保存后：**Rojo → Sync In**，在 **ReplicatedStorage → Weapons** 下应能看到三把。

## 常见错误

| 现象 | 原因 |
|------|------|
| 剑能领、锤子不能 | Studio 里叫 `BanHammer`，配置要 `Ban Hammer` → 已用模糊匹配；若根节点是 **Model 且里面没有 Tool** 仍会失败 |
| 磁盘有、游戏里找不到 | 没 Sync In，或 `.rbxm` 不在 `assets/templates/Weapons` |
| 重开 Rojo 后又坏 | Studio 里 **又手动拖了一份** 到 Weapons，与 Rojo 同步的重复/冲突 → 只保留 Rojo 同步的那三个 |

## 自检

Play 后看 Output：`[WeaponShop]` 应对照三行 **✓**。若 ✗ 会打印当前 Weapons 里**实际名称**。
