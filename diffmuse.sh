#!/bin/bash

# DiffMuse - Git 差異分析與 AI 強化的 PR 描述生成工具
# 確保腳本在出錯時停止執行
set -e

# 獲取腳本所在目錄
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 引入配置文件
source "$SCRIPT_DIR/src/ai_configs.sh"
source "$SCRIPT_DIR/src/ai_prompts.sh"

# 確保腳本可執行
chmod +x "$SCRIPT_DIR/src/main_wrapper.sh" 2>/dev/null || true
chmod +x "$SCRIPT_DIR/src/main.sh" 2>/dev/null || true
chmod +x "$SCRIPT_DIR/src/utils.sh" 2>/dev/null || true
chmod +x "$SCRIPT_DIR/src/git_utils.sh" 2>/dev/null || true
chmod +x "$SCRIPT_DIR/src/ai_utils.sh" 2>/dev/null || true
chmod +x "$SCRIPT_DIR/src/pr_generator.sh" 2>/dev/null || true

# 執行拆分後的腳本
"$SCRIPT_DIR/src/main_wrapper.sh" "$@"
