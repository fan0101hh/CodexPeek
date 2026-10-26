#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"
bash scripts/build-app.sh

stage="$(mktemp -d "$project_root/.build/dmg-staging.XXXXXX")"
cleanup() { rm -rf "$stage"; }
trap cleanup EXIT

ditto "$project_root/dist/CodexPeek.app" "$stage/CodexPeek.app"
ln -s /Applications "$stage/Applications"
cat > "$stage/安装说明.txt" <<'TEXT'
CodexPeek 安装说明

1. 如有旧版正在运行，先从菜单栏退出 CodexPeek。
2. 将本磁盘中的 CodexPeek.app 拖到旁边的 Applications 文件夹。
3. 安装后弹出本磁盘，从 Finder 的“应用程序”打开 CodexPeek。

不要只复制 Contents/MacOS 内的可执行文件，必须复制完整 .app。
应用默认在菜单栏运行，不在 Dock 常驻。
账号别名、窗口尺寸及偏好保存在应用包之外，替换应用不会清除它们。

此版本为本地 ad-hoc 签名构建，尚未使用 Developer ID 签名或公证。
TEXT

codesign --verify --strict "$stage/CodexPeek.app"
hdiutil create -volname CodexPeek -srcfolder "$stage" -fs HFS+ -format UDZO -ov "$project_root/dist/CodexPeek.dmg"
hdiutil verify "$project_root/dist/CodexPeek.dmg"
echo "Built: $project_root/dist/CodexPeek.dmg"
