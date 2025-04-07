#!/bin/bash

# 檢查 AI API 密鑰是否存在
function check_api_key {
    local model=$1
    local key_var="${model}_API_KEY"
    
    if [ -z "${!key_var}" ]; then
        echo "錯誤：使用 ${model} 功能需要提供 ${model} API 密鑰"
        echo "請在 ai_config.sh 中設定 ${key_var} 變數"
        exit 1
    fi
}

# 準備 AI 請求數據
function prepare_ai_request_data {
    local model=$1
    local prompt_type=$2  # "diff" 或 "pr"
    local model_var="${model}_MODEL"
    
    # 獲取版本號
    local version="$VERSION"
    
    # 根據選擇的語言設定添加語言提示和模板
    if [ "$LANGUAGE" = "en" ]; then
        LANG_PROMPT="$EN_PROMPT"
        STYLE_TEMPLATE="$EN_PR_STYLE_TEMPLATE"
        if [ "$prompt_type" = "diff" ]; then
            USER_PROMPT="Please generate a PR description based on the following code diff"
        else
            USER_PROMPT="Please optimize the following PR description"
        fi
    else
        LANG_PROMPT="$ZH_TW_PROMPT"
        STYLE_TEMPLATE="$ZH_TW_PR_STYLE_TEMPLATE"
        if [ "$prompt_type" = "diff" ]; then
            USER_PROMPT="請根據以下代碼差異內容生成 PR 描述"
        else
            USER_PROMPT="請優化以下 PR 描述"
        fi
    fi
    
    # 替換模板中的版本號
    STYLE_TEMPLATE="${STYLE_TEMPLATE/\{VERSION\}/$version}"
    
    # 使用預設提示
    if [ "$prompt_type" = "diff" ]; then
        # 使用完整差異時的提示
        SYSTEM_PROMPT="$LANG_PROMPT $STYLE_TEMPLATE"
        CONTENT="$FULL_DIFF_ESCAPED"
    else
        # 使用 PR 內容時的提示
        SYSTEM_PROMPT="$LANG_PROMPT $STYLE_TEMPLATE"
        CONTENT="$PR_CONTENT_ESCAPED"
    fi
    
    # 根據不同 AI 模型生成請求數據
    case "$model" in
        "CLAUDE")
            if command -v jq > /dev/null; then
                # 使用 jq 構建 JSON (更安全的方法)
                # 將內容轉換為 JSON 字串，確保特殊字符被正確處理
                CONTENT_JSON=$(echo "$CONTENT" | jq -Rs .)
                SYSTEM_JSON=$(echo "$SYSTEM_PROMPT" | jq -Rs .)
                
                # 使用 jq 構建 JSON 結構
                REQUEST_DATA=$(jq -n \
                    --arg model "${!model_var}" \
                    --argjson system "$SYSTEM_JSON" \
                    --argjson content "$CONTENT_JSON" \
                    '{
                        model: $model,
                        max_tokens: 2048,
                        system: $system,
                        messages: [{role: "user", content: $content}],
                        temperature: 0.7
                    }')
            else
                # 使用更安全的方式處理特殊字符
                # 先過濾所有控制字元，然後進行轉義
                CONTENT_FILTERED=$(echo "$CONTENT" | tr -d '\000-\010\013-\037\177')
                SYSTEM_FILTERED=$(echo "$SYSTEM_PROMPT" | tr -d '\000-\010\013-\037\177')
                
                # 轉義特殊字符
                CONTENT_ESCAPED=$(echo "$CONTENT_FILTERED" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g; s/\n/\\n/g; s/\f/\\f/g')
                SYSTEM_ESCAPED=$(echo "$SYSTEM_FILTERED" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g; s/\n/\\n/g; s/\f/\\f/g')
                
                # 手動構建 JSON
                REQUEST_DATA="{\"model\":\"${!model_var}\",\"max_tokens\":2048,\"system\":\"$SYSTEM_ESCAPED\",\"messages\":[{\"role\":\"user\",\"content\":\"$CONTENT_ESCAPED\"}],\"temperature\":0.7}"
            fi
            ;;
        "OPENAI")
            if command -v jq > /dev/null; then
                # 使用 jq 構建 JSON (更安全的方法)
                # 將內容轉換為 JSON 字串，確保特殊字符被正確處理
                SYSTEM_JSON=$(echo "$SYSTEM_PROMPT" | jq -Rs .)
                
                # 構建用戶訊息內容（包含提示和內容）
                USER_CONTENT="$USER_PROMPT\n\n$CONTENT"
                USER_CONTENT_JSON=$(echo "$USER_CONTENT" | jq -Rs .)
                
                # 使用 jq 構建 JSON 結構
                REQUEST_DATA=$(jq -n \
                    --arg model "${!model_var}" \
                    --argjson system "$SYSTEM_JSON" \
                    --argjson user_content "$USER_CONTENT_JSON" \
                    '{
                        model: $model,
                        messages: [
                            {role: "system", content: $system},
                            {role: "user", content: $user_content}
                        ],
                        temperature: 0.7,
                        max_tokens: 2048
                    }')
            else
                # 使用更安全的方式處理特殊字符
                # 先過濾所有控制字元，然後進行轉義
                SYSTEM_FILTERED=$(echo "$SYSTEM_PROMPT" | tr -d '\000-\010\013-\037\177')
                USER_PROMPT_FILTERED=$(echo "$USER_PROMPT" | tr -d '\000-\010\013-\037\177')
                CONTENT_FILTERED=$(echo "$CONTENT" | tr -d '\000-\010\013-\037\177')
                
                # 轉義特殊字符
                SYSTEM_ESCAPED=$(echo "$SYSTEM_FILTERED" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g; s/\n/\\n/g; s/\f/\\f/g')
                USER_PROMPT_ESCAPED=$(echo "$USER_PROMPT_FILTERED" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g; s/\n/\\n/g; s/\f/\\f/g')
                CONTENT_ESCAPED=$(echo "$CONTENT_FILTERED" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g; s/\n/\\n/g; s/\f/\\f/g')
                
                # 手動構建 JSON
                REQUEST_DATA="{\"model\":\"${!model_var}\",\"messages\":[{\"role\":\"system\",\"content\":\"$SYSTEM_ESCAPED\"},{\"role\":\"user\",\"content\":\"$USER_PROMPT_ESCAPED\\n\\n$CONTENT_ESCAPED\"}],\"temperature\":0.7,\"max_tokens\":2048}"
            fi
            ;;
        "GEMINI")
            # 如果是 Gemini，需要特別處理系統提示
            FINAL_PROMPT="$LANG_PROMPT: $STYLE_TEMPLATE"
            
            if command -v jq > /dev/null; then
                # 使用 jq 構建 JSON (更安全的方法)
                # 構建完整文本內容
                FULL_TEXT="$FINAL_PROMPT\n\n$USER_PROMPT\n\n$CONTENT"
                FULL_TEXT_JSON=$(echo "$FULL_TEXT" | jq -Rs .)
                
                # 使用 jq 構建 JSON 結構
                REQUEST_DATA=$(jq -n \
                    --argjson full_text "$FULL_TEXT_JSON" \
                    '{
                        contents: [{
                            role: "user",
                            parts: [{
                                text: $full_text
                            }]
                        }],
                        generationConfig: {
                            temperature: 0.7,
                            maxOutputTokens: 2048
                        }
                    }')
            else
                # 使用更安全的方式處理特殊字符
                # 先過濾所有控制字元，然後進行轉義
                PROMPT_FILTERED=$(echo "$FINAL_PROMPT" | tr -d '\000-\010\013-\037\177')
                USER_PROMPT_FILTERED=$(echo "$USER_PROMPT" | tr -d '\000-\010\013-\037\177')
                CONTENT_FILTERED=$(echo "$CONTENT" | tr -d '\000-\010\013-\037\177')
                
                # 轉義特殊字符
                PROMPT_ESCAPED=$(echo "$PROMPT_FILTERED" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g; s/\n/\\n/g; s/\f/\\f/g')
                USER_PROMPT_ESCAPED=$(echo "$USER_PROMPT_FILTERED" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g; s/\n/\\n/g; s/\f/\\f/g')
                CONTENT_ESCAPED=$(echo "$CONTENT_FILTERED" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g; s/\n/\\n/g; s/\f/\\f/g')
                
                # 手動構建 JSON
                REQUEST_DATA="{\"contents\":[{\"role\":\"user\",\"parts\":[{\"text\":\"$PROMPT_ESCAPED\\n\\n$USER_PROMPT_ESCAPED\\n\\n$CONTENT_ESCAPED\"}]}],\"generationConfig\":{\"temperature\":0.7,\"maxOutputTokens\":2048}}"
            fi
            ;;
    esac
    
    echo "$REQUEST_DATA"
}

# 呼叫 AI API
function call_ai_api {
    local model=$1
    local request_data=$2
    local key_var="${model}_API_KEY"
    local model_var="${model}_MODEL"
    local response
    
    # 根據不同 AI 模型呼叫 API
    case "$model" in
        "CLAUDE")
            if [ "$DEBUG_MODE" = true ]; then
                echo "curl -X POST \"https://api.anthropic.com/v1/messages\" \\
                -H \"Content-Type: application/json\" \\
                -H \"x-api-key: ${!key_var}\" \\
                -H \"anthropic-version: 2023-06-01\" \\
                -d '$request_data'" > "${DEBUG_FILE_PREFIX}_claude_request.sh"
            fi
            
            response=$(curl -s -X POST "https://api.anthropic.com/v1/messages" \
                -H "Content-Type: application/json" \
                -H "x-api-key: ${!key_var}" \
                -H "anthropic-version: 2023-06-01" \
                -d "$request_data")
            
            if [ "$DEBUG_MODE" = true ]; then
                echo "$response" > "${DEBUG_FILE_PREFIX}_claude_response.json"
            fi
            ;;
        
        "OPENAI")
            if [ "$DEBUG_MODE" = true ]; then
                echo "curl -X POST \"https://api.openai.com/v1/chat/completions\" \\
                -H \"Content-Type: application/json\" \\
                -H \"Authorization: Bearer ${!key_var}\" \\
                -d '$request_data'" > "${DEBUG_FILE_PREFIX}_openai_request.sh"
            fi
            
            response=$(curl -s -X POST "https://api.openai.com/v1/chat/completions" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer ${!key_var}" \
                -d "$request_data")
            
            if [ "$DEBUG_MODE" = true ]; then
                echo "$response" > "${DEBUG_FILE_PREFIX}_openai_response.json"
            fi
            ;;
        
        "GEMINI")
            if [ "$DEBUG_MODE" = true ]; then
                echo "curl -X POST \"https://generativelanguage.googleapis.com/v1/models/${!model_var}:generateContent?key=${!key_var}\" \\
                -H \"Content-Type: application/json\" \\
                -d '$request_data'" > "${DEBUG_FILE_PREFIX}_gemini_request.sh"
            fi
            
            response=$(curl -s -X POST "https://generativelanguage.googleapis.com/v1/models/${!model_var}:generateContent?key=${!key_var}" \
                -H "Content-Type: application/json" \
                -d "$request_data")
            
            if [ "$DEBUG_MODE" = true ]; then
                echo "$response" > "${DEBUG_FILE_PREFIX}_gemini_response.json"
            fi
            ;;
    esac
    
    echo "$response"
}

# 解析 AI API 回應
function parse_ai_response {
    local model=$1
    local response=$2
    local result
    
    # 根據不同 AI 模型解析回應
    case "$model" in
        "CLAUDE")
            if command -v jq > /dev/null; then
                # 使用 jq 解析 JSON（如果安裝了 jq）
                result=$(echo "$response" | jq -r '.content[0].text')
            else
                # 使用簡單的文本處理（如果沒有安裝 jq）
                result=$(echo "$response" | grep -E -o '"text":"[^"]*"' | head -1 | sed 's/"text":"//;s/"$//')
            fi
            ;;
        
        "OPENAI")
            if command -v jq > /dev/null; then
                # 使用 jq 解析 JSON（如果安裝了 jq）
                result=$(echo "$response" | jq -r '.choices[0].message.content')
            else
                # 使用簡單的文本處理（如果沒有安裝 jq）
                result=$(echo "$response" | grep -E -o '"content":"[^"]*"' | head -1 | sed 's/"content":"//;s/"$//')
            fi
            ;;
        
        "GEMINI")
            if command -v jq > /dev/null; then
                # 使用 jq 解析 JSON（如果安裝了 jq）
                result=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text')
            else
                # 使用簡單的文本處理（如果沒有安裝 jq）
                result=$(echo "$response" | grep -E -o '"text":"[^"]*"' | head -1 | sed 's/"text":"//;s/"$//')
            fi
            ;;
    esac
    
    echo "$result"
}
