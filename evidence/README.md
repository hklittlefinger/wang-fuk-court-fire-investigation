# 證據收集

呢個目錄包含宏福苑火災相關嘅記錄證據。

## 目錄結構

```
evidence/
├── news/                 # 新聞報導
├── social-media/         # 社交媒體、相片及影片
├── firsthand/            # 第一手陳述
├── official/             # 政府及官方文件
└── renovation/           # 裝修工程文件
```

## 證據類別

### 新聞報導 (`news/`)

各媒體嘅報導。每篇文章應包括：
- 原始網址
- Archive.org/archive.today 備份網址
- 發佈日期
- 簡短摘要
- 報導嘅關鍵事實

**存檔新聞**：
```bash
# 存檔網址
curl -s "https://web.archive.org/save/[URL]"

# 或者使用 archive.today
# 瀏覽：https://archive.today/?run=1&url=[URL]
```

### 第一手陳述 (`firsthand/`)

目擊者陳述、倖存者口述及證詞。

**提交格式**：
```markdown
## 陳述編號：[自動生成]
提交日期：YYYY-MM-DD
與事件關係：[目擊者/倖存者/住戶/救援人員/其他]
已核實：[是/否/待定]

### 陳述內容
[敘述]

### 關鍵細節
- 時間觀察：
- 地點觀察：
- 提及嘅其他目擊者：

### 提交嘅材料
- [任何相片/影片/文件列表]
```

### 社交媒體 (`social-media/`)

Twitter/X、Facebook、Instagram、Threads 等平台嘅帖文。

**目錄結構**：
```
social-media/
└── 2025-11-26-twitter-username-fire-video/
    ├── metadata.yaml      # 元數據
    ├── screenshot.png     # 截圖備份
    ├── video.mp4          # 媒體檔案（如適用）
    └── archive.html       # archive.today 存檔
```

**存檔社交媒體**：
```bash
# 使用 archive.today（比 archive.org 更適合 JS 渲染內容）
# 瀏覽：https://archive.today/?run=1&url=[URL]

# 下載影片
yt-dlp [URL]
```

**metadata.yaml 格式**：
```yaml
title: 帖文標題或描述
platform: twitter  # twitter/facebook/instagram/threads/etc.
author: "@username"
url: https://...
archive_url: https://archive.today/...
post_date: 2025-11-26
capture_date: 2025-11-27
content_type: video  # video/image/text/thread
```

**要求**：
- 優先使用 archive.today 存檔（處理動態內容更可靠）
- 截圖作為備份（以防存檔失敗）
- 使用 yt-dlp 下載影片/圖片
- 記錄擷取時嘅互動數據（可選）

**儲存**：大型檔案應使用 Git LFS 或外部託管（首選 IPFS）

### 官方文件 (`official/`)

政府聲明、調查報告、法規、許可證。

- 法庭文件
- 政府新聞稿
- 屋宇署記錄
- 消防處聲明
- 立法會討論

### 裝修工程文件 (`renovation/`)

裝修工程相關嘅主要來源文件。

- 業主立案法團網站存檔
- 承建商通告
- 工程進度報告
- 棚架安排文件
- 工程問卷及簡報

## 證據處理原則

### 保管鏈

1. **記錄來源**：呢份證據嚟自邊度？
2. **保存原件**：盡可能保留未修改嘅副本
3. **記錄修改**：註明任何遮蔽、格式轉換
4. **時間戳記**：幾時取得/提交？

### 核實

證據分為：
- **已核實**：已從多個來源獨立確認
- **未核實**：單一來源，待確認
- **有爭議**：存在矛盾資訊

### 完整性

每份證據應具備：
- 原始檔案嘅 SHA-256 校驗碼
- 提交日期
- 來源標註（或「匿名」）

生成校驗碼：
```bash
sha256sum filename > filename.sha256
```

### 私隱

- 遮蔽與事件無關嘅私人人士個人資料
- 模糊人群相片中嘅面部，除非相關
- 移除聯絡資料，除非當事人係公眾人物或已同意

## 提交證據

### 透過 GitHub

1. Fork 呢個儲存庫
2. 將證據加到適當嘅目錄
3. 附上元數據檔案
4. 提交 pull request

### 透過安全渠道

見 [ANONYMOUS-CONTRIBUTIONS.md](../ANONYMOUS-CONTRIBUTIONS.md) 了解安全提交方法。

## 存檔工具

### 本地存檔（儲存喺呢個 repo）

**[Monolith](https://github.com/Y2Z/monolith)** - 將網頁保存為單一 HTML 檔案，包含所有資源（圖片、CSS、JS）：

```bash
# 安裝
# macOS
brew install monolith

# Linux (Debian/Ubuntu)
sudo apt install monolith
# 或者用 Cargo
cargo install monolith

# Windows (用 Scoop)
scoop install monolith

# 基本用法
monolith https://example.com/article -o archive.html

# 包含影片/音訊
monolith -v https://example.com/article -o archive.html

# 隔離模式（移除外部連結）
monolith -I https://example.com/article -o archive.html
```

**[yt-dlp](https://github.com/yt-dlp/yt-dlp)** - 下載影片（支援 YouTube、Twitter、Facebook 等）：

```bash
# 安裝
# macOS
brew install yt-dlp

# Linux (Debian/Ubuntu)
sudo apt install yt-dlp
# 或者用 pip
pip install yt-dlp

# Windows (用 Scoop)
scoop install yt-dlp

# 下載影片
yt-dlp [URL]

# 下載最佳畫質
yt-dlp -f "best" [URL]
```

### 外部存檔（第三方時間戳備份）

除咗本地存檔，請順手提交到外部存檔服務。呢啲服務提供獨立嘅時間戳驗證，證明內容喺某個時間存在過。

**[archive.today](https://archive.today)**（推薦，處理動態內容更可靠）：
1. 打開 https://archive.today
2. 貼上網址，撳「Save」
3. 複製存檔網址到 metadata.yaml 嘅 `archive_url` 欄位

**[Wayback Machine](https://web.archive.org)**：
1. 打開 https://web.archive.org
2. 貼上網址，撳「Save Page」
3. 等待完成，複製存檔網址

### 存檔最佳做法

1. **雙重備份**：本地存檔（monolith）+ 外部存檔（archive.today）
2. **記錄網址**：喺 metadata.yaml 記錄原始網址同存檔網址
3. **即刻存檔**：內容可能隨時消失，發現即存檔
4. **驗證存檔**：確保存檔完整可讀

## 證據需求清單

我哋正尋求嘅優先項目：

### 關鍵（模擬驗證）

用於驗證 FDS 火災模擬與觀察到嘅火災行為所需嘅證據：

- [ ] **帶時間戳嘅影片**，顯示多角度嘅火勢發展
- [ ] **帶 EXIF 時間戳嘅相片**（呢啲唔好移除元數據）
- [ ] 火災發生時嘅**天氣數據**（風速/風向、溫度、濕度）
- [ ] 棚架/安全網配置嘅**火災前相片**
- [ ] **建築物尺寸**同棚架測量數據
- [ ] **拍攝位置記錄**——影片/相片嘅拍攝地點

### 高優先（技術分析）

- [ ] 建築物平面圖
- [ ] 棚架配置圖紙同尺寸
- [ ] 安全網材料規格（防火等級、成分、製造商）
- [ ] 火警系統檢查記錄
- [ ] 裝修承包商資料同許可證
- [ ] 附有來源引用嘅事件時間線

### 中等優先

- [ ] 以往消防安全檢查報告
- [ ] 關於裝修嘅住戶通訊
- [ ] 保險文件
- [ ] 物業管理通信

### 持續收集

- [ ] 新聞報導（尤其係本地中文媒體）
- [ ] 附有時間觀察嘅第一手陳述
- [ ] 社交媒體帖文（附存檔連結）

## 法律聲明

此證據收集用於紀錄及消防安全研究目的。貢獻者應：
- 只提交有合法權利分享嘅材料
- 尊重版權（連結到文章，唔好複製全文）
- 唔好提交透過非法途徑取得嘅材料
- 明白提交嘅內容可能用於分析及出版

---

*證據保存至關重要。資訊可能會變得無法取得。存檔一切。*

---

# Evidence Collection

This directory contains documented evidence related to the Wang Fuk Court fire.

## Directory Structure

```
evidence/
├── news/                 # News reports
├── social-media/         # Social media, photos and videos
├── firsthand/            # First-person accounts
├── official/             # Government and official documents
└── renovation/           # Renovation project documents
```

## Evidence Categories

### News Reports (`news/`)

Media coverage from various outlets. Each article should include:
- Original URL
- Archive.org/archive.today backup URL
- Publication date
- Brief summary
- Key facts reported

**Archiving News**:
```bash
# Archive a URL
curl -s "https://web.archive.org/save/[URL]"

# Or use archive.today
# Visit: https://archive.today/?run=1&url=[URL]
```

### First-hand Accounts (`firsthand/`)

Witness statements, survivor accounts, and testimonies.

**Submission format**:
```markdown
## Account ID: [auto-generated]
Date submitted: YYYY-MM-DD
Relation to incident: [witness/survivor/resident/responder/other]
Verified: [yes/no/pending]

### Account
[narrative]

### Key details
- Time observations:
- Location observations:
- Other witnesses mentioned:

### Submitted materials
- [list of any photos/videos/documents]
```

### Social Media (`social-media/`)

Posts from Twitter/X, Facebook, Instagram, Threads, and other platforms.

**Directory Structure**:
```
social-media/
└── 2025-11-26-twitter-username-fire-video/
    ├── metadata.yaml      # Metadata
    ├── screenshot.png     # Screenshot backup
    ├── video.mp4          # Media file (if applicable)
    └── archive.html       # archive.today archive
```

**Archiving Social Media**:
```bash
# Use archive.today (better for JS-rendered content than archive.org)
# Visit: https://archive.today/?run=1&url=[URL]

# Download videos
yt-dlp [URL]
```

**metadata.yaml Format**:
```yaml
title: Post title or description
platform: twitter  # twitter/facebook/instagram/threads/etc.
author: "@username"
url: https://...
archive_url: https://archive.today/...
post_date: 2025-11-26
capture_date: 2025-11-27
content_type: video  # video/image/text/thread
```

**Requirements**:
- Prefer archive.today for archiving (more reliable for dynamic content)
- Take screenshots as backup (in case archive fails)
- Use yt-dlp to download videos/images
- Record engagement metrics at capture time (optional)

**Storage**: Large files should use Git LFS or external hosting (IPFS preferred)

### Official Documents (`official/`)

Government statements, investigation reports, regulations, permits.

- Court documents
- Government press releases
- Building Department records
- Fire Services Department statements
- Legislative Council discussions

### Renovation Documents (`renovation/`)

Primary source documents related to the renovation project.

- Owners' Corporation website archives
- Contractor notices
- Project progress reports
- Scaffolding arrangement documents
- Project questionnaires and briefings

## Evidence Handling Principles

### Chain of Custody

1. **Document source**: Where did this evidence come from?
2. **Preserve original**: Keep unmodified copies when possible
3. **Record modifications**: Note any redactions, format conversions
4. **Timestamp**: When was it obtained/submitted?

### Verification

Evidence is categorized as:
- **Verified**: Independently confirmed from multiple sources
- **Unverified**: Single source, awaiting confirmation
- **Disputed**: Conflicting information exists

### Integrity

Each piece of evidence should have:
- SHA-256 checksum of original file
- Submission date
- Source attribution (or "anonymous")

Generate checksums:
```bash
sha256sum filename > filename.sha256
```

### Privacy

- Redact personal information of uninvolved private individuals
- Blur faces in crowd photos unless relevant
- Remove contact details unless person is a public figure or consents

## Submitting Evidence

### Via GitHub

1. Fork this repository
2. Add evidence to appropriate directory
3. Include metadata file
4. Submit pull request

### Via Secure Channels

See [ANONYMOUS-CONTRIBUTIONS.md](../ANONYMOUS-CONTRIBUTIONS.md) for secure submission methods.

## Archiving Tools

### Local Archiving (stored in this repo)

**[Monolith](https://github.com/Y2Z/monolith)** - Save web pages as single HTML files with all resources (images, CSS, JS) embedded:

```bash
# Install
# macOS
brew install monolith

# Linux (Debian/Ubuntu)
sudo apt install monolith
# Or via Cargo
cargo install monolith

# Windows (via Scoop)
scoop install monolith

# Basic usage
monolith https://example.com/article -o archive.html

# Include video/audio
monolith -v https://example.com/article -o archive.html

# Isolation mode (remove external links)
monolith -I https://example.com/article -o archive.html
```

**[yt-dlp](https://github.com/yt-dlp/yt-dlp)** - Download videos (supports YouTube, Twitter, Facebook, etc.):

```bash
# Install
# macOS
brew install yt-dlp

# Linux (Debian/Ubuntu)
sudo apt install yt-dlp
# Or via pip
pip install yt-dlp

# Windows (via Scoop)
scoop install yt-dlp

# Download video
yt-dlp [URL]

# Download best quality
yt-dlp -f "best" [URL]
```

### External Archiving (third-party timestamped backup)

In addition to local archiving, please also submit to external archive services. These provide independent timestamped verification that content existed at a certain time.

**[archive.today](https://archive.today)** (recommended, more reliable for dynamic content):
1. Go to https://archive.today
2. Paste the URL and click "Save"
3. Copy the archive URL to the `archive_url` field in metadata.yaml

**[Wayback Machine](https://web.archive.org)**:
1. Go to https://web.archive.org
2. Paste the URL and click "Save Page"
3. Wait for completion, copy the archive URL

### Best Practices

1. **Dual backup**: Local archive (monolith) + external archive (archive.today)
2. **Record URLs**: Store original and archive URLs in metadata.yaml
3. **Archive immediately**: Content may disappear at any time
4. **Verify archives**: Ensure archives are complete and readable

## Evidence Wishlist

Priority items we're seeking:

### Critical (Simulation Validation)

Evidence needed to validate FDS fire simulations against observed fire behavior:

- [ ] **Timestamped videos** showing fire progression from multiple angles
- [ ] **Photos with EXIF timestamps** intact (do NOT strip metadata for these)
- [ ] **Weather data** at time of fire (wind speed/direction, temperature, humidity)
- [ ] **Pre-fire photos** of scaffolding/safety net configuration
- [ ] **Building dimensions** and scaffolding measurements
- [ ] **Vantage point documentation** - where videos/photos were taken from

### High Priority (Technical Analysis)

- [ ] Building floor plans
- [ ] Scaffolding configuration drawings and dimensions
- [ ] Safety net material specifications (fire rating, composition, manufacturer)
- [ ] Fire alarm system inspection records
- [ ] Renovation contractor details and permits
- [ ] Timeline of events with source citations

### Medium Priority

- [ ] Previous fire safety inspection reports
- [ ] Resident communications about renovation
- [ ] Insurance documents
- [ ] Building management correspondence

### Ongoing Collection

- [ ] News coverage (especially local Chinese-language media)
- [ ] First-hand accounts with time observations
- [ ] Social media posts (with archive links)

## Legal Notice

This evidence collection is for documentary and fire safety research purposes. Contributors should:
- Only submit materials they have legal right to share
- Respect copyright (link to articles, don't copy full text)
- Not submit materials obtained through illegal means
- Understand that submissions may be used in analysis and publications

---

*Evidence preservation is critical. Information may become unavailable. Archive everything.*
