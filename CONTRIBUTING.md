# 參與貢獻宏福苑火災紀錄

本項目紀錄宏福苑火災慘劇（2025年11月26日），以保存證據、實現獨立分析及支持消防安全改進。我哋歡迎任何擁有相關資料嘅人士參與貢獻。

## 點解呢件事重要

159條生命逝去。透過證據保存、技術分析及火災動力學模擬，了解發生咗乜嘢可以幫助防止未來嘅悲劇並支持問責。

## 我哋需要乜嘢

### 證據收集
- **新聞報導**：文章連結（我哋會存檔）、截圖、PDF
- **第一手資料**：目擊者陳述、倖存者口述（可匿名處理）
- **相片/影片**：事件片段、建築物狀況、棚架詳情
- **官方文件**：政府聲明、調查報告、法規
- **建築物記錄**：建築文件、裝修許可、檢查報告

### 技術分析
- 火勢蔓延時間線重建
- 建築系統分析
- 法規合規審查
- 棚架材料測試結果

### 模擬
- FDS模型改進
- 與觀察到嘅火災行為進行驗證
- 替代情景模擬

## 如何貢獻

### 標準貢獻（GitHub）

1. 安裝 [Git LFS](https://git-lfs.com/)（見下面嘅說明）
2. Fork呢個儲存庫
3. 將你嘅貢獻加到適當嘅目錄
4. 提交pull request並描述你所添加嘅內容

#### Git LFS

Git LFS（Large File Storage）係 Git 嘅擴展，用嚟處理大型檔案。由於 GitHub 對檔案大細有限制，我哋用 Git LFS 嚟儲存大型影片檔案（例如 `.webm`）。

**請喺 clone 之前安裝 Git LFS。** 如果冇安裝就 clone，大型檔案會變成細小嘅指標檔案（pointer files），影片將無法播放。如果已經 clone 咗，可以安裝 Git LFS 之後運行 `git lfs pull` 嚟下載實際檔案。

如果檔案大過 2GB，請將檔案上載到公開只讀嘅儲存空間（例如 S3 bucket），然後喺 PR 中提供連結。

### 匿名貢獻

**如果你對安全或私隱有顧慮，請閱讀[ANONYMOUS-CONTRIBUTIONS.md](ANONYMOUS-CONTRIBUTIONS.md)了解安全貢獻嘅詳細說明。**

快速選項：
- **電郵**：發送到ProtonMail地址（詳見ANONYMOUS-CONTRIBUTIONS.md）
- **檔案分享**：透過Tor使用OnionShare
- **匿名GitHub**：透過Tor建立帳戶（指南中有說明）

## 貢獻指引

### 所有貢獻

1. **準確性**：只提交你相信係真實嘅資訊
2. **來源**：盡可能提供來源/背景
3. **無臆測**：清楚標明不確定嘅資訊
4. **尊重私隱**：遮蓋私人人士嘅個人資料
5. **無誹謗**：堅持有記錄嘅事實

### 證據

- 盡可能保留原始檔案
- 註明日期、時間、地點（如已知）
- 註明來源（新聞媒體、個人、官方）
- 使用archive.org或archive.today存檔網頁連結
- 如果網頁大過 100MB，請使用 `wget` 遞歸下載所有資源成獨立檔案，而唔係用 monolith 打包成單一檔案

#### 網頁存檔工具

**Monolith**（適合 < 100MB 嘅網頁）- 將網頁打包成單一 HTML 檔案：
```bash
monolith https://example.com/article -o article.html

# 如果需要登入，使用 cookies：
monolith -c cookies.txt https://example.com/article -o article.html
```

**wget**（適合 > 100MB 嘅網頁）- 遞歸下載所有資源成獨立檔案：
```bash
wget --mirror --convert-links --adjust-extension --page-requisites --no-parent https://example.com/article/

# 如果需要登入，使用 cookies：
wget --load-cookies cookies.txt --mirror --convert-links --adjust-extension --page-requisites --no-parent https://example.com/article/
```

你可以用瀏覽器擴展（例如 "Get cookies.txt"）匯出 cookies.txt 檔案。

**yt-dlp** - 下載社交媒體同影片網站嘅影片：
```bash
yt-dlp https://www.youtube.com/watch?v=VIDEO_ID

# 如果需要登入，使用 cookies：
yt-dlp --cookies cookies.txt https://www.youtube.com/watch?v=VIDEO_ID
```

yt-dlp 支援大部分影片平台，包括 YouTube、Facebook、Twitter/X、Instagram 等。

### 相片/影片

- 提交前移除元數據（詳見ANONYMOUS-CONTRIBUTIONS.md）
- 描述圖像顯示嘅內容
- 註明大約日期/時間/地點
- 如適當，遮蓋私人人士嘅面部

## 證據處理

所有提交嘅證據將會：
1. 盡可能驗證真實性
2. 連同校驗碼存檔以確保完整性
3. 按貢獻者偏好標明來源（或標記為匿名）
4. 存放喺適當嘅目錄結構中

## 行為守則

- 專注於事實同證據
- 尊重所有死傷者及家屬
- 無與消防安全無關嘅政治評論
- 只作建設性批評
- 保護貢獻者安全

## 有問題？

開issue或參閱ANONYMOUS-CONTRIBUTIONS.md了解安全聯絡方式。

---

*本項目不隸屬於任何政府、政治組織或商業實體。呢係一個獨立努力，旨在紀錄及分析重大消防安全事件。*

---

# Contributing to Wang Fuk Court Fire Documentation

This project documents the Wang Fuk Court fire tragedy (November 26, 2025) to preserve evidence, enable independent analysis, and support fire safety improvements. We welcome contributions from anyone with relevant information.

## Why This Matters

159 lives were lost. Understanding what happened—through evidence preservation, technical analysis, and fire dynamics simulation—can help prevent future tragedies and support accountability.

## What We Need

### Evidence Collection
- **News reports**: Links to articles (we archive them), screenshots, PDFs
- **First-hand accounts**: Witness statements, survivor accounts (can be anonymized)
- **Photos/Videos**: Incident footage, building conditions, scaffolding details
- **Official documents**: Government statements, investigation reports, regulations
- **Building records**: Construction documents, renovation permits, inspection reports

### Technical Analysis
- Fire spread timeline reconstruction
- Building systems analysis
- Regulatory compliance review
- Scaffolding material testing results

### Simulation
- FDS model improvements
- Validation against observed fire behavior
- Alternative scenario modeling

## How to Contribute

### Standard Contribution (GitHub)

1. Install [Git LFS](https://git-lfs.com/) (see note below)
2. Fork this repository
3. Add your contribution to the appropriate directory
4. Submit a pull request with description of what you're adding

#### Git LFS

Git LFS (Large File Storage) is an extension for Git that handles large files. Since GitHub has file size limits, we use Git LFS to store large video files (e.g., `.webm`).

**Please install Git LFS before cloning.** If you clone without it, large files will be replaced with small pointer files and videos won't play. If you've already cloned, install Git LFS and run `git lfs pull` to download the actual files.

For files larger than 2GB, please upload them to public readonly storage (e.g., S3 bucket) and provide the link in your PR.

### Anonymous Contribution

**If you have concerns about your safety or privacy, please read [ANONYMOUS-CONTRIBUTIONS.md](ANONYMOUS-CONTRIBUTIONS.md) for detailed instructions on contributing safely.**

Quick options:
- **Email**: Send to a ProtonMail address (see ANONYMOUS-CONTRIBUTIONS.md)
- **File sharing**: Use OnionShare via Tor
- **Anonymous GitHub**: Create account via Tor (instructions in guide)

## Contribution Guidelines

### For All Contributions

1. **Accuracy**: Only submit information you believe to be true
2. **Sources**: Provide source/context when possible
3. **No speculation**: Label uncertain information clearly
4. **Respect privacy**: Redact personal information of private individuals
5. **No defamation**: Stick to documented facts

### For Evidence

- Preserve original files when possible
- Include date, time, location if known
- Note the source (news outlet, personal, official)
- Archive web links using archive.org or archive.today
- For web pages larger than 100MB, use `wget` to recursively download all resources as individual files instead of using monolith to bundle into a single file

#### Web Archiving Tools

**Monolith** (for pages < 100MB) - bundles a web page into a single HTML file:
```bash
monolith https://example.com/article -o article.html

# If login is required, use cookies:
monolith -c cookies.txt https://example.com/article -o article.html
```

**wget** (for pages > 100MB) - recursively downloads all resources as individual files:
```bash
wget --mirror --convert-links --adjust-extension --page-requisites --no-parent https://example.com/article/

# If login is required, use cookies:
wget --load-cookies cookies.txt --mirror --convert-links --adjust-extension --page-requisites --no-parent https://example.com/article/
```

You can export a cookies.txt file using browser extensions (e.g., "Get cookies.txt").

**yt-dlp** - downloads videos from social media and video platforms:
```bash
yt-dlp https://www.youtube.com/watch?v=VIDEO_ID

# If login is required, use cookies:
yt-dlp --cookies cookies.txt https://www.youtube.com/watch?v=VIDEO_ID
```

yt-dlp supports most video platforms including YouTube, Facebook, Twitter/X, Instagram, etc.

### For Photos/Videos

- Strip metadata before submission (see ANONYMOUS-CONTRIBUTIONS.md)
- Describe what the image shows
- Note approximate date/time/location
- Redact faces of private individuals if appropriate

## Evidence Handling

All submitted evidence will be:
1. Verified for authenticity where possible
2. Archived with checksums for integrity
3. Attributed (or marked anonymous) per contributor preference
4. Stored in appropriate directory structure

## Code of Conduct

- Focus on facts and evidence
- Respect all victims and families
- No political commentary unrelated to fire safety
- Constructive criticism only
- Protect contributor safety

## Questions?

Open an issue or see ANONYMOUS-CONTRIBUTIONS.md for secure contact methods.

---

*This project is not affiliated with any government, political organization, or commercial entity. It is an independent effort to document and analyze a significant fire safety incident.*
