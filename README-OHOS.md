# Bun for HarmonyOS (OHOS)

[Bun](https://github.com/oven-sh/bun) 的 [HarmonyOS (OHOS)](https://www.harmonyos.com/) aarch64 移植版本。

基于 [springmin/bun](https://github.com/springmin/bun) 的 OHOS 适配工作，提供自动化 CI 构建和一键安装。

## 快速安装

在 OHOS 设备上执行：

```bash
curl -fsSL https://ghfast.top/https://github.com/sb-fy-sb/bun/releases/download/ohos-latest/install-bun-ohos.sh | sh
```

安装到 `~/usr/bin/bun`，自动签名，自动配置 PATH。

## 分支说明

| 分支 | 说明 | 来源 |
|------|------|------|
| `main` | Bun 上游主线，与 [oven-sh/bun](https://github.com/oven-sh/bun) 同步 | oven-sh/bun main |
| `ohos-aarch64` | OHOS 移植版，包含平台适配补丁和 CI 工作流 | springmin/bun ohos-aarch64 |

## CI 流水线

所有流水线运行在 **self-hosted ARM64 Linux runner**（鸿蒙 PC + openEuler）上。

查看运行状态：https://github.com/sb-fy-sb/bun/actions

### OHOS Rust Build（主力构建）

| 项目 | 说明 |
|------|------|
| 文件 | `.github/workflows/ohos-build-rust.yml` |
| 用途 | 完整编译 Bun for OHOS aarch64 |
| 触发 | push 到 `ohos-aarch64` / `claude/ohos-*`，PR 到 `ohos-aarch64`，手动触发 |
| 耗时 | ~30 分钟（有缓存更快） |
| 产物 | GitHub Actions Artifacts（bun 二进制 + tar.gz） |

### OHOS Release（发版构建）

| 项目 | 说明 |
|------|------|
| 文件 | `.github/workflows/ohos-release.yml` |
| 用途 | 构建 + 签名 + 创建 GitHub Release |
| 触发 | push tag `ohos-v*`（如 `ohos-v1.4.0`），手动触发 |
| 产物 | [GitHub Releases](https://github.com/sb-fy-sb/bun/releases)，含安装脚本 |

Release 产物：
- `bun-ohos-aarch64` — 原始二进制（供 curl 安装）
- `bun-ohos-aarch64-*.tar.gz` — 版本化压缩包
- `install-bun-ohos.sh` — 安装脚本

### OHOS Build Incremental（增量构建）

| 项目 | 说明 |
|------|------|
| 文件 | `.github/workflows/ohos-build-incremental.yml` |
| 用途 | 快速增量编译（ccache + 持久工作区） |
| 触发 | push 到 `ohos-aarch64`（排除 docs/test），手动触发 |
| 耗时 | 1-5 分钟 |
| 产物 | GitHub Actions Artifacts |

## 如何触发构建

### 自动触发

推送到 `ohos-aarch64` 分支即可自动触发主力构建和增量构建：

```bash
git checkout ohos-aarch64
# 修改代码...
git commit -m "your change"
git push origin ohos-aarch64
```

### 手动触发

在 GitHub Actions 页面点击 **Run workflow**：

- [OHOS Rust Build](https://github.com/sb-fy-sb/bun/actions/workflows/ohos-build-rust.yml)
- [OHOS Release](https://github.com/sb-fy-sb/bun/actions/workflows/ohos-release.yml)
- [OHOS Build Incremental](https://github.com/sb-fy-sb/bun/actions/workflows/ohos-build-incremental.yml)

### 创建 Release

打 tag 并推送，自动触发发版流程：

```bash
git tag ohos-v1.4.0
git push origin ohos-v1.4.0
```

构建完成后自动创建 [GitHub Release](https://github.com/sb-fy-sb/bun/releases) 并更新 `ohos-latest` 标签。

## 在 OHOS 设备上运行

```bash
# 安装
curl -fsSL https://ghfast.top/https://github.com/sb-fy-sb/bun/releases/download/ohos-latest/install-bun-ohos.sh | sh

# 验证
bun --version

# 运行测试
bun test test/cli/install/bun-run.test.ts
```

> OHOS 设备上的二进制必须经过签名才能执行。安装脚本会自动签名（如果 `binary-sign-tool` 可用）。

## 构建环境

Runner 运行在鸿蒙 PC 的 openEuler Linux 终端上：

| 组件 | 版本/路径 |
|------|----------|
| 操作系统 | openEuler 24.03 LTS-SP1 aarch64 |
| OHOS SDK | `/home/user/setup-ohos-sdk/` |
| LLVM 22 | `/home/user/setup-ohos-sdk/llvm-22/` (clang 22.1.0) |
| Rust | nightly-2026-06-06 + `aarch64-unknown-linux-ohos` target |
| Bun | 1.3.14（用于运行构建脚本） |
| Node.js | v24.16.0 |

详细的 Runner 部署步骤见 [`ohos/RUNNER-DEPLOYMENT-MANUAL.md`](ohos/RUNNER-DEPLOYMENT-MANUAL.md)。

## 已知问题

| 问题 | 说明 |
|------|------|
| DNS 解析失败 | Bun 内置 c-ares DNS 在 OHOS 上不稳定，`bun install` 可能需要配置国内镜像 |
| Unix 域套接字 EPERM | OHOS 安全策略限制 `AF_UNIX` 套接字 |
| NAPI 原生模块 | `.node` 文件未针对 OHOS 编译，NAPI 测试全部失败 |
| 编译目标检测 | `bun build --compile` 将 OHOS 误识别为 `linux-aarch64-musl` |

## 相关链接

- [oven-sh/bun](https://github.com/oven-sh/bun) — Bun 上游仓库
- [springmin/bun](https://github.com/springmin/bun) — OHOS 移植源
- [springmin/WebKit](https://github.com/springmin/WebKit) — WebKit OHOS fork
- [Bun 官方文档](https://bun.sh/docs)
- [OHOS 测试报告](ohos/REPORT.md)

## License

与上游 Bun 一致，见 [LICENSE](LICENSE)。
