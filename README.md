# DiffMuse (diffmuse.sh)

這是一款高效的 Pull Request 描述自動生成工具，使用 Git 差異分析和先進的 AI 技術，幫助開發者快速產生結構清晰、內容完整的 PR 描述。

## 功能特色

- 自動從 Git 分支差異生成結構化 PR 描述
- 支援 OpenAI、Claude 和 Gemini 等多種 AI 模型優化 PR 內容
- 支援繁體中文（臺灣用語）和英文兩種語言
- AI 分析 Git 提交歷史和程式碼差異
- 自動複製結果到剪貼簿，提高工作效率
- 可從任何位置執行並處理任何 Git 專案
- 可選的除錯模式，記錄中間過程
- 模組化結構設計，便於維護與擴展

## 安裝需求

- Bash 環境（macOS、Linux 或 WSL）
- Git 命令行工具
- curl 命令（用於 API 調用）
- jq 命令（推薦安裝，用於更穩定的 JSON 處理）
- pbcopy（macOS）或 xclip（Linux）命令（用於剪貼簿功能）

## 使用方法

基本用法：
```bash
./diffmuse.sh 目標分支 [來源分支] [選項]
```

### 必要參數

- `目標分支`：你要合併到的分支（例如 `main`、`develop`）

### 可選參數

- `來源分支`：你要從哪個分支合併，預設為當前所在分支
- `--no-copy`：禁用自動複製到剪貼簿功能
- `--claude`, `-c`：使用 Claude AI 優化 PR 描述（預設）
- `--openai`, `-o`：使用 OpenAI 優化 PR 描述
- `--gemini`, `-g`：使用 Gemini AI 優化 PR 描述
- `--en`：使用英文生成 PR 描述
- `--zh-tw`：使用繁體中文（臺灣用語）生成 PR 描述（預設）
- `--no-full-diff`：不包含完整的差異內容
- `--debug`：啟用除錯模式，保存中間處理過程到文件

### 使用範例

```bash
# 基本用法：生成當前分支到 main 分支的 PR 描述
./diffmuse.sh main

# 指定來源分支和目標分支
./diffmuse.sh main feature/xyz

# 使用 OpenAI 模型優化描述
./diffmuse.sh main --openai
./diffmuse.sh main -o  # 簡短版

# 使用 Gemini 模型優化描述
./diffmuse.sh main --gemini
./diffmuse.sh main -g  # 簡短版

# 使用英文生成描述
./diffmuse.sh main --en

# 使用繁體中文生成描述
./diffmuse.sh main --zh-tw

# 不包含完整的程式碼差異內容
./diffmuse.sh main --no-full-diff

# 關閉自動複製到剪貼簿功能
./diffmuse.sh main --no-copy

# 啟用除錯模式
./diffmuse.sh main --debug
```

## 配置與自訂

腳本使用模組化設計，主要配置文件位於：

- `ai_configs.sh`：AI 模型配置文件
- `pr_prompts.sh`：PR 描述模板配置文件

### AI API 密鑰配置

在 `ai_configs.sh` 中配置各 AI 服務的 API 密鑰和專案路徑：

```bash
# 專案路徑配置 (必填項目)
# 指定 git 專案的絕對路徑
PROJECT_PATH="/Users/username/projects/my-android-app"

# 各 AI 服務的 API 金鑰
CLAUDE_API_KEY="your-claude-api-key"
OPENAI_API_KEY="your-openai-api-key"
GEMINI_API_KEY="your-gemini-api-key"
```

### 專案路徑設定

從 v0.2.0 版本開始，腳本支援在任何位置執行，並處理不同專案的 Git 儲存庫：

1. 在 `ai_config.sh` 中設定 `PROJECT_PATH` 變數，指向要處理的 Git 專案目錄
2. 腳本會自動切換到該目錄執行所有 Git 操作
3. 必須使用絕對路徑，且該路徑必須為有效的 Git 倉庫

例如：
```bash
# 在 ai_config.sh 中設定
PROJECT_PATH="/Users/username/AndroidStudioProjects/MyApp"

# 然後從任何地方執行腳本
cd ~/Downloads
./path/to/diffmuse.sh main feature/xyz
```

### 測試 Gemini API

使用提供的測試腳本確認 Gemini API 連接是否正常：

```bash
./test_gemini.sh
```

如果成功，將顯示 "✅ Gemini API 測試成功！"

## 工作原理

1. 解析命令行參數並設定相應的配置
2. 獲取目標分支和來源分支的差異資訊
3. 分析 Git 提交記錄和程式碼變更
4. 生成初步的 PR 描述結構
5. 使用選定的 AI 模型優化 PR 描述
6. 輸出結果至控制台並自動複製到剪貼簿

## 模組結構

- `diffmuse.sh`：主入口腳本
- `src/main_wrapper.sh`：主腳本包裝器
- `src/main.sh`：主要流程控制
- `src/utils.sh`：通用工具函數
- `src/git_utils.sh`：Git 相關功能
- `src/ai_utils.sh`：AI API 調用功能
- `src/pr_generator.sh`：PR 描述生成邏輯

## 故障排除

### 常見問題

1. **專案路徑錯誤**
   - 確認 `PROJECT_PATH` 已正確設定為絕對路徑
   - 確認該路徑是有效的 Git 倉庫（包含 .git 目錄）
   - 確認目前使用者有權限存取該路徑

2. **無法調用 AI API**
   - 請確認已正確設定 API 密鑰
   - 確認網絡連接正常
   - 使用 `./test_gemini.sh` 測試 Gemini API 連接
   - 檢查 curl 命令是否可用

3. **無法複製到剪貼簿**
   - 確認系統已安裝 pbcopy（macOS）或 xclip（Linux）命令
   - 使用 `--no-copy` 選項跳過複製功能

4. **找不到分支間差異**
   - 確認分支名稱輸入正確
   - 確認兩個分支之間確實存在程式碼差異
   - 使用 `--debug` 選項查看詳細日誌

5. **JSON 解析錯誤**
   - 建議安裝 jq 命令以提高 JSON 處理的穩定性
   - 使用 `--debug` 選項查看原始 API 請求和回應

## 作者

Reece
~~基本上都是 AI 寫的~~

## 授權

不要說是我寫的
