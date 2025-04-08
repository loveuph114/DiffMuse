#!/bin/bash

# 版本號碼
VERSION="0.2.0"

# 專案路徑配置 (必填項目)
# 指定 git 專案的絕對路徑
# 例如: PROJECT_PATH="/Users/username/projects/my-android-app"
PROJECT_PATH=""

# 預設 AI 設定
DEFAULT_AI_MODEL="claude" 
DEFAULT_LANGUAGE="zh_TW" # en or zh_TW

# 各 AI 服務的 API 金鑰
CLAUDE_API_KEY=""
OPENAI_API_KEY=""
GEMINI_API_KEY="" 

# 各 AI 服務使用的模型設定
CLAUDE_MODEL="claude-3-5-sonnet-20241022"
OPENAI_MODEL="gpt-3.5-turbo-0125"
GEMINI_MODEL="gemini-2.0-flash"
