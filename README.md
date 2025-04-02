# PR 描述產生器 (pr_desc_generator_v2.sh)

這是一款高效的 Pull Request 描述自動生成工具，使用 Git 差異分析和先進的 AI 技術，幫助開發者快速產生結構清晰、內容完整的 PR 描述。

## 功能特色

- 自動從 Git 分支差異生成結構化 PR 描述
- 支援 OpenAI、Claude 和 Gemini 等多種 AI 模型優化 PR 內容
- 支援繁體中文（臺灣用語）和英文兩種語言
- AI 分析 Git 提交歷史和程式碼差異
- 自動複製結果到剪貼簿，提高工作效率
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
./pr_desc_generator_v2.sh 目標分支 [來源分支] [選項]
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
- `-p "自訂提示"`：簡短版設定客製化的 AI 提示
- `-rp "自訂提示"`：簡短版完全替換預設提示
- `--no-full-diff`：不包含完整的差異內容
- `--debug`：啟用除錯模式，保存中間處理過程到文件

### 使用範例

```bash
# 基本用法：生成當前分支到 main 分支的 PR 描述
./pr_desc_generator_v2.sh main

# 指定來源分支和目標分支
./pr_desc_generator_v2.sh main feature/xyz

# 使用 OpenAI 模型優化描述
./pr_desc_generator_v2.sh main --openai
./pr_desc_generator_v2.sh main -o  # 簡短版

# 使用 Gemini 模型優化描述
./pr_desc_generator_v2.sh main --gemini
./pr_desc_generator_v2.sh main -g  # 簡短版

# 使用英文生成描述
./pr_desc_generator_v2.sh main --en

# 使用繁體中文生成描述
./pr_desc_generator_v2.sh main --zh-tw

# 添加自訂 AI 提示
./pr_desc_generator_v2.sh main -p "請突出顯示性能改進"

# 完全替換預設提示
./pr_desc_generator_v2.sh main -rp "只保留標題和摘要"

# 不包含完整的程式碼差異內容
./pr_desc_generator_v2.sh main --no-full-diff

# 關閉自動複製到剪貼簿功能
./pr_desc_generator_v2.sh main --no-copy

# 啟用除錯模式
./pr_desc_generator_v2.sh main --debug
```

## 配置與自訂

腳本使用模組化設計，主要配置文件位於：

- `pr_desc_generator/configs/ai_config.sh`：AI 模型配置文件
- `pr_desc_generator/configs/pr_patterns.sh`：PR 描述模板配置文件

### AI API 密鑰配置

在 `ai_config.sh` 中配置各 AI 服務的 API 密鑰：

```bash
# 各 AI 服務的 API 金鑰
CLAUDE_API_KEY="your-claude-api-key"
OPENAI_API_KEY="your-openai-api-key"
GEMINI_API_KEY="your-gemini-api-key"
```

### PR 模板自訂

在 `pr_patterns.sh` 中可以自訂 PR 描述的風格和格式。

## 工作原理

1. 解析命令行參數並設定相應的配置
2. 獲取目標分支和來源分支的差異資訊
3. 分析 Git 提交記錄和程式碼變更
4. 生成初步的 PR 描述結構
5. 使用選定的 AI 模型優化 PR 描述
6. 輸出結果至控制台並自動複製到剪貼簿

## 模組結構

- `pr_desc_generator_v2.sh`：主入口腳本
- `pr_desc_generator/main_wrapper.sh`：主腳本包裝器
- `pr_desc_generator/main.sh`：主要流程控制
- `pr_desc_generator/utils.sh`：通用工具函數
- `pr_desc_generator/git_utils.sh`：Git 相關功能
- `pr_desc_generator/ai_utils.sh`：AI API 調用功能
- `pr_desc_generator/pr_generator.sh`：PR 描述生成邏輯
- `pr_desc_generator/configs/`：配置文件目錄

## 故障排除

### 常見問題

1. **無法調用 AI API**
   - 請確認已正確設定 API 密鑰
   - 確認網絡連接正常
   - 檢查 curl 命令是否可用

2. **無法複製到剪貼簿**
   - 確認系統已安裝 pbcopy（macOS）或 xclip（Linux）命令
   - 使用 `--no-copy` 選項跳過複製功能

3. **找不到分支間差異**
   - 確認分支名稱輸入正確
   - 確認兩個分支之間確實存在程式碼差異
   - 使用 `--debug` 選項查看詳細日誌

4. **JSON 解析錯誤**
   - 建議安裝 jq 命令以提高 JSON 處理的穩定性
   - 使用 `--debug` 選項查看原始 API 請求和回應

## 作者

- Reece

## 授權

不要說是我寫的
