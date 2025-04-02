#!/bin/bash

# 使用 AI 優化 PR 描述
function optimize_pr_with_ai {
    # 檢查是否有 curl 命令
    if ! command -v curl > /dev/null; then
        echo "錯誤：使用 AI 功能需要安裝 curl 命令"
        exit 1
    fi

    # 將 PR 內容中的特殊字符轉義，避免破壞 JSON 格式
    # 先過濾所有控制字元，再進行JSON轉義
    PR_CONTENT_FILTERED=$(echo "$PR_CONTENT" | tr -d '\000-\010\013-\037\177')
    
    if command -v jq > /dev/null; then
        # 使用 jq 進行 JSON 安全的轉義
        PR_CONTENT_ESCAPED=$(echo "$PR_CONTENT_FILTERED" | jq -Rs . | sed 's/^"//;s/"$//')
    else
        # 如果沒有 jq，使用 sed 進行基本轉義
        PR_CONTENT_ESCAPED=$(echo "$PR_CONTENT_FILTERED" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/\r/\\r/g' | sed 's/\n/\\n/g' | sed 's/\t/\\t/g' | sed 's/\f/\\f/g')
    fi

    # 如果使用完整差異，則轉義 FULL_DIFF
    if [ "$INCLUDE_FULL_DIFF" = true ]; then
        # 先過濾所有控制字元，再進行JSON轉義
        FULL_DIFF_FILTERED=$(echo "$FULL_DIFF" | tr -d '\000-\010\013-\037\177')
        
        if command -v jq > /dev/null; then
            # 使用 jq 進行 JSON 安全的轉義
            FULL_DIFF_ESCAPED=$(echo "$FULL_DIFF_FILTERED" | jq -Rs . | sed 's/^"//;s/"$//')
        else
            # 如果沒有 jq，使用 sed 進行基本轉義
            FULL_DIFF_ESCAPED=$(echo "$FULL_DIFF_FILTERED" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/\r/\\r/g' | sed 's/\n/\\n/g' | sed 's/\t/\\t/g' | sed 's/\f/\\f/g')
        fi
    fi

    # 根據選擇的 AI 模型進行處理
    echo "正在使用 ${AI_MODEL} 優化 PR 描述..."

    # 檢查 API 密鑰
    check_api_key "$AI_MODEL"

    # 準備 API 請求內容
    prompt_type="pr"
    if [ "$INCLUDE_FULL_DIFF" = true ]; then
        prompt_type="diff"
    fi

    REQUEST_DATA=$(prepare_ai_request_data "$AI_MODEL" "$prompt_type")

    # 檢查請求數據是否有效的JSON
    if command -v jq > /dev/null; then
        # 使用 jq 進行 JSON 有效性檢查
        if ! echo "$REQUEST_DATA" | jq . > /dev/null 2>&1; then
            echo "錯誤：生成的請求數據不是有效的JSON格式"
            if [ "$DEBUG_MODE" = true ]; then
                echo "$REQUEST_DATA" > "${DEBUG_FILE_PREFIX}_invalid_json_request.txt"
                echo "已將無效的請求數據保存到 ${DEBUG_FILE_PREFIX}_invalid_json_request.txt"
            fi
            exit 1
        fi
    else
        # 如果沒有 jq，使用基本檢查（但不夠嚴謹）
        if ! echo "$REQUEST_DATA" | grep -E -q "^[[:space:]]*\{.*\}[[:space:]]*$"; then
            echo "錯誤：生成的請求數據不是有效的JSON格式"
            if [ "$DEBUG_MODE" = true ]; then
                echo "$REQUEST_DATA" > "${DEBUG_FILE_PREFIX}_invalid_json_request.txt"
                echo "已將無效的請求數據保存到 ${DEBUG_FILE_PREFIX}_invalid_json_request.txt"
            fi
            exit 1
        fi
    fi

    # 呼叫 API
    RESPONSE=$(call_ai_api "$AI_MODEL" "$REQUEST_DATA")

    # 檢查是否包含錯誤
    if echo "$RESPONSE" | grep -E -q "\"error\""; then
        echo "警告：API返回錯誤，嘗試使用備份方案..."
        if [ "$DEBUG_MODE" = true ]; then
            echo "$RESPONSE" > "${DEBUG_FILE_PREFIX}_api_error_response.json"
        fi
        
        # 進行一次額外處理，再嘗試一次
        if command -v jq > /dev/null; then
            # 使用最嚴格的方式清理和轉義
            CONTENT_CLEAN=$(echo "$CONTENT" | tr -cd '[:print:][:space:]' | jq -Rs .)
            # 直接使用 jq 構建乾淨的JSON請求
            REQUEST_DATA=$(jq -n \
                --arg model "${!model_var}" \
                --argjson content "$CONTENT_CLEAN" \
                '{
                    model: $model,
                    max_tokens: 2048,
                    system: "Generate PR description",
                    messages: [{role: "user", content: $content}],
                    temperature: 0.7
                }')
            RESPONSE=$(call_ai_api "$AI_MODEL" "$REQUEST_DATA")
        fi
    fi

    # 解析 API 回應
    AI_DESCRIPTION=$(parse_ai_response "$AI_MODEL" "$RESPONSE")

    # 檢查是否成功獲取到 AI 生成的描述
    if [ -z "$AI_DESCRIPTION" ] || [ "$AI_DESCRIPTION" == "null" ]; then
        echo "錯誤：無法從 ${AI_MODEL} AI 獲取優化描述，操作中止"
        echo "API 回應: $RESPONSE"
        # 清理臨時文件並退出
        rm -f "$TEMP_FILE"
        exit 1
    else
        # 使用 AI 生成的描述
        PR_CONTENT="$AI_DESCRIPTION"
        echo "${AI_MODEL} AI 已優化 PR 描述"
    fi
}