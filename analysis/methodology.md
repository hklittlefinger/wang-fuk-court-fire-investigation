# 調查方法論

本項目遵循大型火災調查所建立嘅調查框架，並為獨立社區驅動嘅研究進行調整。

## 參考調查

### NIST 世貿中心調查（2002-2008）

美國國家標準與技術研究院（NIST）喺911襲擊後對世貿中心建築物倒塌進行咗全面調查。主要方法元素：

- **多學科方法**：結構工程、火災動力學、材料科學
- **計算建模**：火災模擬、結構分析
- **證據收集**：實物證據、相片/影片、目擊者訪談
- **同行評審**：外部專家審查研究結果
- **公開記錄**：所有報告公開可用

報告：[NIST NCSTAR 1 系列](https://www.nist.gov/publications/federal-building-and-fire-safety-investigation-world-trade-center-disaster-final-report)

### 格蘭菲塔調查（2017-2025，已完成）

英國對格蘭菲塔火災嘅公開調查為火災調查建立咗嚴格標準：

- **第一階段**：事發當晚嘅事實紀錄（報告：2019年10月）
- **第二階段**：火災點燃同蔓延方式；建築法規；應對措施（報告：2024年9月）
- **證據收集**：文件、證人證詞、專家報告
- **獨立性**：調查獨立於政府
- **透明度**：公開聽證會、公開證據

報告：[格蘭菲塔調查](https://www.grenfelltowerinquiry.org.uk/)

## 我哋嘅方法論

### 第一階段：證據收集

**目標**：喺證據無法取得之前收集並保存所有可用證據。

1. **新聞同媒體**
   - 匯編所有已發表嘅報導
   - 使用 web.archive.org 存檔
   - 提取並核實關鍵事實
   - 追蹤敘述演變

2. **官方文件**
   - 政府聲明
   - 調查公告
   - 監管文件
   - 法庭文件

3. **第一手陳述**
   - 目擊者陳述
   - 倖存者口述
   - 救援人員觀點
   - 住戶證詞

4. **實物證據**
   - 事件相片/影片
   - 建築物文件
   - 材料規格

### 第二階段：時間線重建

**目標**：建立經核實嘅事件時間線。

| 日期 | 時間 | 事件 | 來源 | 可信度 |
|------|------|------|------|--------|
| YYYY-MM-DD | HH:MM | 事件描述 | [來源] | 高/中/低 |

**時間線元素**：
- 起火及發現
- 火勢蔓延進程
- 警報啟動（或失效）
- 疏散行動
- 緊急應對
- 建築物倒塌/失效點

### 第三階段：技術分析

**目標**：了解火災嘅物理機制。

#### 建築物分析
- 建築類型同日期
- 改建同裝修
- 消防系統
- 逃生通道

#### 火災動力學
- 起火源同燃料負荷
- 火勢蔓延路徑
- 棚架空腔嘅煙囪效應
- 外牆火勢蔓延機制

#### 材料分析
- 棚架材料（竹棚對鋼架）
- 安全網成分同防火等級
- 外牆材料
- 隔熱層

#### 計算建模
- FDS 火災動力學模擬
- 與觀察到嘅行為驗證
- 敏感度分析
- 情景比較

### 第四階段：法規分析

**目標**：識別監管失效或漏洞。

1. **適用法規**
   - 建造時嘅建築法規
   - 消防安全法規
   - 棚架/裝修要求
   - 材料防火等級標準

2. **合規評估**
   - 法規係咪有被遵守？
   - 有冇進行檢查？
   - 有冇發現違規？

3. **監管漏洞**
   - 現有法規係咪有處理呢個危險？
   - 法規係咪足夠？
   - 國際比較

### 第五階段：根本原因分析

**目標**：識別系統性原因，而唔只係直接原因。

使用「5個為什麼」同故障樹分析：

```
事件：火勢快速蔓延
├── 點解？可燃棚架材料
│   ├── 點解？使用咗非防火等級安全網
│   │   ├── 點解？法規冇要求 / 冇執行
│   │   └── 點解？成本考慮
│   └── 點解？竹棚架（傳統做法）
├── 點解？棚架空腔嘅煙囪效應
│   └── 點解？棚架同建築物之間有空隙
└── 點解？消防系統失效
    └── 點解？[需要調查]
```

### 第六階段：建議

**目標**：提出防止未來事故嘅改變建議。

類別：
1. **即時行動**：應該立即改變嘅嘢
2. **法規修訂**：新增或修改法規
3. **執法**：改進檢查/合規
4. **技術**：偵測、滅火、材料
5. **教育**：承包商、住戶、救援人員培訓

## 質量標準

### 來源核實

- 優先使用**主要來源**（官方文件、直接目擊者）
- **次要來源**需要佐證
- **未經核實嘅聲稱**清楚標明
- **矛盾資訊**有記錄

### 同行評審

- 技術分析由合資格專家審查
- 模擬參數有記錄且可重現
- 方法論接受批評

### 透明度

- 所有證據公開可用
- 分析方法有記錄
- 局限性有承認
- 所有文件有版本控制

## 分析成果

### 交付物

1. **證據資料庫**：有組織、可搜索嘅收藏
2. **時間線**：經核實嘅事件順序
3. **技術報告**：火災動力學分析
4. **法規審查**：合規同漏洞評估
5. **模擬結果**：FDS 建模輸出
6. **建議**：可行動嘅提案

### 格式

- 文字文件使用 Markdown（版本控制）
- 結構化數據使用 CSV/JSON
- 模擬檔案使用標準格式
- 高解像度媒體連同元數據

## 貢獻分析

見 [CONTRIBUTING.md](../CONTRIBUTING.md) 了解如何貢獻。

**歡迎分析貢獻**：
- 技術部分嘅專家審查
- 法規專業知識（香港建築法規）
- 消防工程分析
- 翻譯（中英對照）
- 數據可視化

---

*目標係真相同預防，而唔係追究責任。嚴謹嘅方法論保護研究結果嘅完整性。*

---

# Investigation Methodology

This project follows investigation frameworks established by major fire investigations, adapted for independent community-driven research.

## Reference Investigations

### NIST World Trade Center Investigation (2002-2008)

The National Institute of Standards and Technology (NIST) conducted a comprehensive investigation of the WTC building failures following the 9/11 attacks. Key methodological elements:

- **Multi-disciplinary approach**: Structural engineering, fire dynamics, materials science
- **Computational modeling**: Fire simulations, structural analysis
- **Evidence collection**: Physical evidence, photos/videos, witness interviews
- **Peer review**: External expert review of findings
- **Public documentation**: All reports publicly available

Reports: [NIST NCSTAR 1 Series](https://www.nist.gov/publications/federal-building-and-fire-safety-investigation-world-trade-center-disaster-final-report)

### Grenfell Tower Inquiry (2017-2025, completed)

The UK public inquiry into the Grenfell Tower fire established rigorous standards for fire investigation:

- **Phase 1**: Factual account of events on the night (report: October 2019)
- **Phase 2**: How the fire started and spread; building regulations; response (report: September 2024)
- **Evidence gathering**: Documents, witness testimony, expert reports
- **Independence**: Inquiry independent of government
- **Transparency**: Public hearings, published evidence

Reports: [Grenfell Tower Inquiry](https://www.grenfelltowerinquiry.org.uk/)

## Our Methodology

### Phase 1: Evidence Collection

**Objective**: Gather and preserve all available evidence before it becomes unavailable.

1. **News and Media**
   - Compile all published reports
   - Archive using web.archive.org
   - Extract and verify key facts
   - Track evolving narratives

2. **Official Documents**
   - Government statements
   - Investigation announcements
   - Regulatory documents
   - Court filings

3. **First-hand Accounts**
   - Witness statements
   - Survivor accounts
   - First responder perspectives
   - Resident testimonies

4. **Physical Evidence**
   - Photos/videos of incident
   - Building documentation
   - Material specifications

### Phase 2: Timeline Reconstruction

**Objective**: Establish a verified timeline of events.

| Date | Time | Event | Source | Confidence |
|------|------|-------|--------|------------|
| YYYY-MM-DD | HH:MM | Event description | [source] | High/Medium/Low |

**Timeline elements**:
- Fire ignition and discovery
- Fire spread progression
- Alarm activation (or failure)
- Evacuation activities
- Emergency response
- Building collapse/failure points

### Phase 3: Technical Analysis

**Objective**: Understand the physical mechanisms of the fire.

#### Building Analysis
- Construction type and date
- Modifications and renovations
- Fire protection systems
- Means of egress

#### Fire Dynamics
- Ignition source and fuel load
- Fire spread pathways
- Chimney effect in scaffolding cavity
- External fire spread mechanisms

#### Materials Analysis
- Scaffolding materials (bamboo vs steel)
- Safety net composition and fire rating
- Facade materials
- Insulation

#### Computational Modeling
- FDS fire dynamics simulation
- Validation against observed behavior
- Sensitivity analysis
- Scenario comparisons

### Phase 4: Regulatory Analysis

**Objective**: Identify regulatory failures or gaps.

1. **Applicable Regulations**
   - Building codes at time of construction
   - Fire safety regulations
   - Scaffolding/renovation requirements
   - Material fire rating standards

2. **Compliance Assessment**
   - Were regulations followed?
   - Were inspections conducted?
   - Were violations identified?

3. **Regulatory Gaps**
   - Did existing regulations address the hazard?
   - Were regulations adequate?
   - International comparisons

### Phase 5: Root Cause Analysis

**Objective**: Identify systemic causes, not just proximate causes.

Using the "5 Whys" and fault tree analysis:

```
Event: Rapid fire spread
├── Why? Combustible scaffolding materials
│   ├── Why? Non-fire-rated safety nets used
│   │   ├── Why? Not required by regulation / Not enforced
│   │   └── Why? Cost considerations
│   └── Why? Bamboo scaffolding (traditional practice)
├── Why? Chimney effect in scaffold cavity
│   └── Why? Gap between scaffold and building
└── Why? Fire protection systems failed
    └── Why? [Investigation needed]
```

### Phase 6: Recommendations

**Objective**: Propose changes to prevent future incidents.

Categories:
1. **Immediate actions**: What should change now
2. **Regulatory changes**: New or modified regulations
3. **Enforcement**: Improved inspection/compliance
4. **Technology**: Detection, suppression, materials
5. **Education**: Training for contractors, residents, responders

## Quality Standards

### Source Verification

- **Primary sources** preferred (official documents, direct witnesses)
- **Secondary sources** require corroboration
- **Unverified claims** clearly labeled
- **Conflicting information** documented

### Peer Review

- Technical analysis reviewed by qualified experts
- Simulation parameters documented and reproducible
- Methodology open to critique

### Transparency

- All evidence publicly accessible
- Analysis methods documented
- Limitations acknowledged
- Version control for all documents

## Analysis Outputs

### Deliverables

1. **Evidence Database**: Organized, searchable collection
2. **Timeline**: Verified sequence of events
3. **Technical Report**: Fire dynamics analysis
4. **Regulatory Review**: Compliance and gaps assessment
5. **Simulation Results**: FDS modeling outputs
6. **Recommendations**: Actionable proposals

### Format

- Markdown for text documents (version controlled)
- CSV/JSON for structured data
- Standard formats for simulation files
- High-resolution media with metadata

## Contributing to Analysis

See [CONTRIBUTING.md](../CONTRIBUTING.md) for how to contribute.

**Analysis contributions welcome**:
- Expert review of technical sections
- Regulatory expertise (HK building codes)
- Fire engineering analysis
- Translation (Chinese ↔ English)
- Data visualization

---

*The goal is truth and prevention, not blame. Rigorous methodology protects the integrity of findings.*
