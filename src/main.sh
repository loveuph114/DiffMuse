#!/bin/bash

# 確保腳本在出錯時停止執行
set -e

# 獲取腳本所在目錄
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# 導入模組
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/git_utils.sh"
source "$SCRIPT_DIR/ai_utils.sh"
source "$SCRIPT_DIR/pr_generator.sh"
source "$PARENT_DIR/ai_config.sh"
source "$PARENT_DIR/pr_patterns.sh"

# 獲取當前分支
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# 設定預設參數
TARGET_BRANCH=""
SOURCE_BRANCH="$CURRENT_BRANCH"
COPY_TO_CLIPBOARD=true
USE_AI=true # 預設使用 AI
AI_MODEL="$DEFAULT_AI_MODEL" # 使用配置檔案中的預設 AI 模型
LANGUAGE="$DEFAULT_LANGUAGE" # 使用配置檔案中的預設語言
INCLUDE_FULL_DIFF=true # 預設包含完整的差異內容
DEBUG_MODE=false # 是否啟用 debug 模式
USE_FORMAT=false # 是否啟用格式化功能
TEMP_FILE=$(mktemp)

# 解析參數
i=1
while [ $i -le $# ]; do
    arg="${!i}"
    next=$((i+1))
    next_arg=""
    if [ $next -le $# ]; then
        next_arg="${!next}"
    fi

    if [[ "$arg" == "--no-copy" ]]; then
        COPY_TO_CLIPBOARD=false
    elif [[ "$arg" == "--openai" ]] || [[ "$arg" == "-o" ]]; then
        AI_MODEL="OPENAI"
    elif [[ "$arg" == "--claude" ]] || [[ "$arg" == "-c" ]]; then
        AI_MODEL="CLAUDE"
    elif [[ "$arg" == "--gemini" ]] || [[ "$arg" == "-g" ]]; then
        AI_MODEL="GEMINI"
    # 支援舊格式以保持向下兼容
    elif [[ "$arg" == "--ai=openai" ]] || [[ "$arg" == "--ai-openai" ]]; then
        AI_MODEL="OPENAI"
    elif [[ "$arg" == "--ai=claude" ]] || [[ "$arg" == "--ai-claude" ]]; then
        AI_MODEL="CLAUDE"
    elif [[ "$arg" == "--ai=gemini" ]] || [[ "$arg" == "--ai-gemini" ]]; then
        AI_MODEL="GEMINI"
    elif [[ "$arg" == "--no-full-diff" ]]; then
        INCLUDE_FULL_DIFF=false
    elif [[ "$arg" == "--debug" ]]; then
        DEBUG_MODE=true
    elif [[ "$arg" == "--en" ]]; then
        LANGUAGE="en"
    elif [[ "$arg" == "--zh-tw" ]]; then
        LANGUAGE="zh_TW"
    elif [[ "$arg" == "--help" ]] || [[ "$arg" == "-h" ]]; then
        show_usage
    else
        if [ -z "$PARAM1" ]; then
            PARAM1="$arg"
        elif [ -z "$PARAM2" ]; then
            PARAM2="$arg"
        fi
    fi
    i=$((i+1))
done

# 根據提供的參數設定變數
if [ ! -z "$PARAM1" ]; then
    TARGET_BRANCH="$PARAM1"
else
    # 如果沒有提供目標分支，顯示使用說明並退出
    echo "錯誤：必須指定目標分支"
    show_usage
fi

if [ ! -z "$PARAM2" ]; then
    SOURCE_BRANCH="$PARAM2"
fi

# 顯示執行資訊
echo "正在比較分支："
echo "目標分支: $TARGET_BRANCH"
echo "來源分支: $SOURCE_BRANCH"
if [ "$COPY_TO_CLIPBOARD" = true ]; then
    echo "自動複製: 啟用"
fi
if [ "$LANGUAGE" = "en" ]; then
    echo "使用語言: 英文"
else
    echo "使用語言: 繁體中文 (台灣用語)"
fi
if [ "$INCLUDE_FULL_DIFF" = true ]; then
    echo "使用完整差異內容: 啟用"
else
    echo "使用完整差異內容: 停用"
fi

# 檢查分支是否存在
if ! git rev-parse --verify "$TARGET_BRANCH" &>/dev/null; then
    echo "錯誤：目標分支 '$TARGET_BRANCH' 不存在或不可訪問。"
    exit 1
fi

if ! git rev-parse --verify "$SOURCE_BRANCH" &>/dev/null; then
    echo "錯誤：來源分支 '$SOURCE_BRANCH' 不存在或不可訪問。"
    exit 1
fi

# 使用雙破折號避免歧義
echo "正在獲取分支之間的差異資訊..."

# 主要流程函數
function main {
    # 啟用 Debug 模式
    setup_debug_files
    
    # 獲取分支差異資訊
    get_branch_diff
    
    # 檢查分支差異
    check_branches_diff
    
    # 生成 PR 內容
    PR_CONTENT=$(generate_pr_content)
    
    # 如果啟用了 AI 處理，則優化描述
    if [ "$USE_AI" = true ]; then
        optimize_pr_with_ai
    fi
    
    # 如果啟用了 format 功能，則進一步格式化 PR 描述
    if [ "$USE_FORMAT" = true ]; then
        format_pr_description
    fi
    
    # 輸出 PR 描述到控制台
    echo "===== PR 描述 ====="
    echo "$PR_CONTENT"
    echo "=================="
    
    # 複製到剪貼簿
    copy_to_clipboard
    
    # 保存到 debug 文件
    save_pr_to_debug_file
    
    # 清理臨時文件
    rm -f "$TEMP_FILE"
}

# 執行主要流程
main
