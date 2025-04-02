#!/bin/bash

# 顯示使用說明
function show_usage {
    echo "參數:"
    echo "  目標分支        要合併到的分支（必須指定）"
    echo "  來源分支        要從哪個分支合併，預設為當前分支 '$CURRENT_BRANCH'"
    echo "  --no-copy       禁用自動複製到剪貼簿（預設會自動複製）"
    echo "  --claude, -c    使用 Claude 優化 PR 描述（預設）"
    echo "  --openai, -o    使用 OpenAI 優化 PR 描述"
    echo "  --gemini, -g    使用 Gemini 優化 PR 描述"
    echo "  --en            使用英文生成 PR 描述"
    echo "  --zh-tw         使用繁體中文（台灣用語）生成 PR 描述（預設）"
    echo "  -p              簡短版設定客製化的 AI 提示"
    echo "  -rp             簡短版完全替換預設提示"
    echo "  --no-full-diff  不包含完整的差異內容（預設包含完整差異內容）"
    echo "  --debug         將 diff 資訊存成文件方便除錯（存放在 pr_desc_generator_debug 目錄）"
    echo "範例:"
    echo "  $0 main                      # main <- $CURRENT_BRANCH"
    echo "  $0 develop                   # develop <- $CURRENT_BRANCH"
    echo "  $0 main feature/xyz          # main <- feature/xyz"
    echo "  $0 main --no-copy            # 不複製到剪貼簿"
    echo "  $0 main --openai             # 使用 OpenAI 優化描述"
    echo "  $0 main -o                   # 使用 OpenAI 優化描述 (簡短版)"
    echo "  $0 main --gemini             # 使用 Gemini 優化描述"
    echo "  $0 main -g                   # 使用 Gemini 優化描述 (簡短版)"
    echo "  $0 main --en                 # 使用英文生成描述"
    echo "  $0 main --zh-tw              # 使用繁體中文生成描述"
    echo "  $0 main -p \"請突出顯示性能改進\"     # 追加客製化提示 (簡短版)"
    echo "  $0 main -rp \"只保留標題和摘要\"      # 完全替換預設提示 (簡短版)"
    echo "  $0 main --no-full-diff       # 不包含完整的程式碼差異內容"
    exit 1
}

# 設置 debug 目錄及檔案名稱
function setup_debug_files {
    if [ "$DEBUG_MODE" = true ]; then
        # 創建 debug 目錄（如果不存在）
        DEBUG_DIR="$PARENT_DIR/gen_pr_desc_debug"
        mkdir -p "$DEBUG_DIR"

        # 生成當前時間戳，用於檔名
        TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
        DEBUG_FILE_PREFIX="$DEBUG_DIR/pr_diff_${SOURCE_BRANCH//\//_}_to_${TARGET_BRANCH//\//_}_$TIMESTAMP"

        # 存儲 commit 資訊
        echo "分支 $SOURCE_BRANCH 到 $TARGET_BRANCH 的提交：" > "${DEBUG_FILE_PREFIX}_commits.txt"
        git log "$TARGET_BRANCH..$SOURCE_BRANCH" --pretty=format:'%h - %s (%an) %ad' --date=iso --reverse -- >> "${DEBUG_FILE_PREFIX}_commits.txt"

        # 存儲 diff 統計資訊
        echo "分支 $SOURCE_BRANCH 到 $TARGET_BRANCH 的差異統計：" > "${DEBUG_FILE_PREFIX}_stat.txt"
        echo "$DIFF_STAT" >> "${DEBUG_FILE_PREFIX}_stat.txt"

        # 存儲完整 diff 資訊，同時處理 tab 字元和過濾控制字元
        git diff "$TARGET_BRANCH..$SOURCE_BRANCH" -- | tr '\t' '    ' | tr -d '\000-\010\013-\037\177' > "${DEBUG_FILE_PREFIX}_full.diff"

        # 儲存全域變數，以便稍後在同一文件夾中儲存 PR 內容
        export DEBUG_ENABLED=true
        export DEBUG_FILE_PREFIX="$DEBUG_FILE_PREFIX"

        echo "Debug 資訊已存儲到目錄：$DEBUG_DIR"
    fi
}

# 格式化 PR 描述
function format_pr_description {
    # 檢查 format_pr.sh 是否存在
    FORMAT_SCRIPT="$PARENT_DIR/format_pr.sh"
    if [ ! -f "$FORMAT_SCRIPT" ]; then
        echo "警告：找不到 format_pr.sh 腳本，跳過格式化步驟"
        return 1
    fi

    # 給予執行權限
    chmod +x "$FORMAT_SCRIPT" 2>/dev/null || true

    echo "正在使用 format_pr.sh 標準化格式..."
    # 將 PR 描述寫入臨時文件
    echo "$PR_CONTENT" > "$TEMP_FILE"

    # 根據是否需要複製到剪貼簿設定參數
    FORMAT_ARGS=""
    if [ "$COPY_TO_CLIPBOARD" = false ]; then
        FORMAT_ARGS="--no-copy"
    fi

    # 調用 format_pr.sh 腳本
    FORMATTED_PR=$("$FORMAT_SCRIPT" "$TEMP_FILE" $FORMAT_ARGS)

    # 取得最後一段輸出，即格式化後的 PR 描述
    local formatted_content=$(echo "$FORMATTED_PR" | awk '/=====格式化後的 PR 描述 =====/{flag=1;next}/==================/{flag=0}flag')

    # 如果格式化後的描述為空，保留原始描述
    if [ -z "$formatted_content" ]; then
        echo "警告：格式化後的 PR 描述為空，將使用原始描述"
        return 1
    else
        echo "PR 描述已成功標準化格式"
        PR_CONTENT="$formatted_content"
        return 0
    fi
}

# 複製 PR 描述到剪貼簿
function copy_to_clipboard {
    if [ "$COPY_TO_CLIPBOARD" = true ]; then
        # 檢查是否有 pbcopy（MacOS）或 xclip（Linux）命令
        if command -v pbcopy > /dev/null; then
            echo "$PR_CONTENT" | pbcopy
            echo "PR 描述已複製到剪貼簿"
        elif command -v xclip > /dev/null; then
            echo "$PR_CONTENT" | xclip -selection clipboard
            echo "PR 描述已複製到剪貼簿"
        else
            echo "警告：無法複製到剪貼簿，找不到 pbcopy 或 xclip 命令"
        fi
    fi
}

# 保存 PR 描述到 debug 文件
function save_pr_to_debug_file {
    if [ "$DEBUG_ENABLED" = true ] && [ -n "$DEBUG_FILE_PREFIX" ]; then
        echo "$PR_CONTENT" > "${DEBUG_FILE_PREFIX}_pr_content.md"
        echo "PR 描述已存儲到文件：${DEBUG_FILE_PREFIX}_pr_content.md"
    fi
}
