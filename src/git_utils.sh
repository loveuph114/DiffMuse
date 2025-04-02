#!/bin/bash

# 獲取分支之間的差異資訊
function get_branch_diff {
    echo "正在更新 Target Branch: [$TARGET_BRANCH]" ...
    git fetch origin $TARGET_BRANCH

    ORIGIN_TARGET_BRANCH="origin/$TARGET_BRANCH"

    # 獲取分支之間的所有 commit
    COMMITS=$(git log "$ORIGIN_TARGET_BRANCH..$SOURCE_BRANCH" --pretty=format:'%h - %s (%an)' --reverse -- 2>/dev/null)
    
    # 獲取分支之間的 diff 統計，處理 tab 字元
    DIFF_STAT=$(git diff "$ORIGIN_TARGET_BRANCH..$SOURCE_BRANCH" --stat -- 2>/dev/null | tr '\t' '    ')
    
    # 檢查是否有差異存在，處理 tab 字元
    DIFF_CHECK=$(git diff --name-only "$ORIGIN_TARGET_BRANCH..$SOURCE_BRANCH" -- 2>/dev/null | tr '\t' '    ')
    
    # 預設或根據選項決定是否包含完整差異
    if [ "$INCLUDE_FULL_DIFF" = true ]; then
        echo "正在獲取完整的程式碼差異內容..."
        # 使用 tr 命令將 tab 字元轉換為空格，解決 iOS 與 Android 環境差異問題
        FULL_DIFF=$(git diff "$ORIGIN_TARGET_BRANCH..$SOURCE_BRANCH" -- 2>/dev/null | tr '\t' '    ')
        
        # 檢查差異是否過大（超過 100KB）
        DIFF_SIZE=${#FULL_DIFF}
        if [ $DIFF_SIZE -gt 102400 ]; then
            echo "警告：差異內容較大（約 $((DIFF_SIZE / 1024)) KB），可能會影響 AI 處理速度或超過 AI 輸入限制"
            read -p "是否繼續？(y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "操作已取消"
                exit 1
            fi
        fi
    fi
}

# 檢查有無差異
function check_branches_diff {
    if [ -z "$DIFF_CHECK" ]; then
        # 如果檢測不到差異，嘗試交換分支順序
        echo "警告：無法檢測到分支之間的差異，嘗試反向檢查..."
        REVERSE_DIFF=$(git diff --name-only "$SOURCE_BRANCH..$TARGET_BRANCH" -- 2>/dev/null | tr '\t' '    ')
        
        if [ -n "$REVERSE_DIFF" ]; then
            echo "提示：找到從 $TARGET_BRANCH 到 $SOURCE_BRANCH 的差異。建議交換分支順序重試。"
        fi
        
        echo "錯誤：無法檢測到 $SOURCE_BRANCH 與 $TARGET_BRANCH 之間的程式碼差異。"
        echo "請確認兩個分支是否正確，以及它們之間是否有差異。"
        exit 1
    fi
}

# 生成基本 PR 內容
function generate_pr_content {
    # 根據是否有 commit 記錄來获取 commit 细节
    if [ -n "$COMMITS" ]; then
        # 獲取 commit 詳細信息
        COMMIT_DETAILS=$(git log "$ORIGIN_TARGET_BRANCH..$SOURCE_BRANCH" --pretty=format:'### %s%n%n%b%n' --reverse -- 2>/dev/null | sed '/^$/d')
    else
        # 如果没有 commit 但有差異，創建假的 commit 詳細信息
        COMMIT_DETAILS="### 程式碼差異\n\n此 PR 包含程式碼差異，但沒有提交記錄。"
    fi
    
    # 生成 PR 描述內容
    if [ "$INCLUDE_FULL_DIFF" = true ]; then
        # 使用完整差異時，創建簡單的 PR 模板，不包含 commit 詳細資訊
        if [ "$LANGUAGE" = "en" ]; then
            PR_CONTENT="# PR: $SOURCE_BRANCH → $TARGET_BRANCH\n\n## Summary of Changes\n\nThis PR contains changes from \`$SOURCE_BRANCH\` to \`$TARGET_BRANCH\`."
        else
            PR_CONTENT="# PR: $SOURCE_BRANCH → $TARGET_BRANCH\n\n## 變更摘要\n\n這個 PR 包含了從 \`$SOURCE_BRANCH\` 到 \`$TARGET_BRANCH\` 的變更。"
        fi
    else
        # 確定使用哪個模板（中文或英文）
        local TEMPLATE_TO_USE=""
        if [ "$LANGUAGE" = "en" ]; then
            TEMPLATE_TO_USE="$EN_PR_STYLE_TEMPLATE"
        else
            TEMPLATE_TO_USE="$ZH_TW_PR_STYLE_TEMPLATE"
        fi
        
        # 使用傳統模板，包含 commit 詳細資訊
        PR_CONTENT="${TEMPLATE_TO_USE/\{SOURCE_BRANCH\}/$SOURCE_BRANCH}"
        PR_CONTENT="${PR_CONTENT/\{TARGET_BRANCH\}/$TARGET_BRANCH}"
        PR_CONTENT="${PR_CONTENT/\{COMMIT_DETAILS\}/$COMMIT_DETAILS}"
    fi
    
    echo "$PR_CONTENT"
}
