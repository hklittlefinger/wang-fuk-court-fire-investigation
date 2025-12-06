# 未來擴展範圍 / Future Scope

本文件記錄擴展調查範圍嘅後續想法同要求。

This document captures follow-up ideas and requirements for expanding the investigation scope.

---

## 階段概覽 / Phase Overview

| 階段 / Phase | 範圍 / Scope | 複雜度 / Complexity |
|--------------|--------------|---------------------|
| 當前 / Current | 單層棚架段 / Single-floor scaffolding section | 基礎 / Baseline |
| 階段 2 / Phase 2 | 時間線重建 / Timeline reconstruction | 中等 / Moderate |
| 階段 3 / Phase 3 | 整棟建築模擬 / Full building simulation | 高 / High |
| 階段 4 / Phase 4 | 多座大廈蔓延 / Multi-tower spread | 極高 / Very High |

---

## 階段 2：時間線重建 / Phase 2: Timeline Reconstruction

### 目標 / Objective

根據相片、影片同目擊者陳述，建立經驗證嘅火勢蔓延時間線。

Establish a verified fire spread timeline based on photos, videos, and witness accounts.

### 所需輸入 / Required Inputs

1. **帶時間戳嘅媒體 / Timestamped Media**
   - 事件相片同影片（EXIF 元數據） / Incident photos and videos (EXIF metadata)
   - 閉路電視片段（如有） / CCTV footage (if available)
   - 新聞直播片段 / News broadcast footage
   - 居民手機錄影 / Resident mobile phone recordings

2. **目擊者陳述 / Witness Accounts**
   - 火勢進展觀察 / Fire progression observations
   - 煙霧顏色/密度變化 / Smoke color/density changes
   - 可聽見嘅事件（爆炸、玻璃破碎） / Audible events (explosions, glass breaking)
   - 疏散時間線 / Evacuation timeline

3. **官方記錄 / Official Records**
   - 消防處派遣記錄 / Fire Services dispatch records
   - 999 通話記錄 / 999 call logs
   - 消防員抵達時間 / Firefighter arrival times
   - 警報啟動時間 / Alarm activation times

### 交付物 / Deliverables

- 帶來源引用嘅時間線數據庫 / Timeline database with source citations
- 火勢進展可視化 / Fire progression visualization
- 與模擬驗證嘅對比 / Comparison with simulation validation

---

## 階段 3：整棟建築模擬 / Phase 3: Full Building Simulation

### 目標 / Objective

模擬火勢喺整棟建築物（地下至天台）嘅蔓延。

Simulate fire spread across the entire building (ground to roof).

### 參考調查 / Reference Investigations

#### NIST 世貿中心 / NIST World Trade Center (2002-2008)

- 從建築圖則建立詳細 3D 模型 / Detailed 3D models built from architectural plans
- 使用 Fire Dynamics Simulator (FDS) 進行火災模擬 / Fire simulation using Fire Dynamics Simulator (FDS)
- 使用 ANSYS 進行結構分析 / Structural analysis using ANSYS
- 與觀察到嘅倒塌序列驗證 / Validation against observed collapse sequence

資源 / Resource: [NIST NCSTAR 1 系列 / NIST NCSTAR 1 Series](https://www.nist.gov/publications/federal-building-and-fire-safety-investigation-world-trade-center-disaster-final-report)

#### 格蘭菲塔調查 / Grenfell Tower Inquiry (2017-2025)

- 從倖存結構同圖則重建 3D 模型 / 3D model reconstructed from surviving structure and plans
- 詳細嘅外牆系統建模 / Detailed facade system modeling
- 火勢蔓延路徑分析 / Fire spread pathway analysis
- 與影片證據驗證 / Validation against video evidence

資源 / Resource: [格蘭菲塔調查 / Grenfell Tower Inquiry](https://www.grenfelltowerinquiry.org.uk/)

### 所需輸入 / Required Inputs

#### 建築幾何 / Building Geometry

1. **建築圖則 / Architectural Plans**
   - 平面圖（每層） / Floor plans (each level)
   - 立面圖 / Elevation drawings
   - 剖面圖 / Section drawings
   - 結構圖則 / Structural drawings

2. **3D 重建 / 3D Reconstruction**
   - 攝影測量法（從相片重建） / Photogrammetry (reconstruction from photos)
   - 激光掃描（LiDAR）如有 / Laser scanning (LiDAR) if available
   - 無人機航拍 / Drone aerial photography

3. **材料規格 / Material Specifications**
   - 外牆材料同厚度 / Facade materials and thickness
   - 窗戶類型同尺寸 / Window types and dimensions
   - 隔熱材料 / Insulation materials
   - 棚架配置 / Scaffolding configuration

#### 棚架配置 / Scaffolding Configuration

- 竹棚架佈局（層數、間距） / Bamboo scaffold layout (levels, spacing)
- 安全網位置同材料 / Safety net positions and materials
- 與建築物嘅間隙尺寸 / Gap dimensions from building
- 發泡膠窗罩位置 / Styrofoam window cover positions

#### 環境條件 / Environmental Conditions

- 事發時嘅天氣數據（風速、風向、濕度） / Weather data at time of incident (wind speed, direction, humidity)
- 環境溫度 / Ambient temperature
- 日照條件 / Solar conditions

### 軟件流程 / Software Pipeline

```
Photos/Videos                Architectural Plans
相片/影片                    建築圖則
    │                           │
    ▼                           ▼
┌─────────────┐          ┌─────────────┐
│Photogrammetry│          │ CAD Software│
│ 攝影測量法   │          │  CAD 軟件   │
│ Meshroom    │          │  AutoCAD    │
│ Reality     │          │  SketchUp   │
│ Capture     │          │             │
└─────────────┘          └─────────────┘
        │                       │
        └───────────┬───────────┘
                    ▼
            ┌─────────────┐
            │  3D Mesh    │
            │  3D 網格    │
            │  Blender    │
            └─────────────┘
                    │
                    ▼
            ┌─────────────┐
            │  FDS Model  │
            │  FDS 模型   │
            │  PyroSim    │
            └─────────────┘
                    │
                    ▼
            ┌─────────────┐
            │FDS Simulation│
            │  FDS 模擬   │
            │  Smokeview  │
            └─────────────┘
```

### 軟件詳情 / Software Details

| 軟件 / Software | 用途 / Purpose | 開源 / Open Source |
|-----------------|----------------|-------------------|
| Meshroom | 攝影測量 3D 重建 / Photogrammetric 3D reconstruction | 是 / Yes |
| Reality Capture | 攝影測量（商業） / Photogrammetry (commercial) | 否 / No |
| Blender | 3D 建模同網格處理 / 3D modeling and mesh processing | 是 / Yes |
| PyroSim | FDS 前處理器（GUI） / FDS preprocessor (GUI) | 否 / No |
| FDS | 火災動力學模擬 / Fire dynamics simulation | 是 / Yes |
| Smokeview | FDS 結果可視化 / FDS results visualization | 是 / Yes |

### 計算規模估計 / Computational Scale Estimates

| 範圍 / Scope | 網格單元 / Cells | 估計運行時間 / Est. Runtime | 估計成本 / Est. Cost |
|--------------|------------------|----------------------------|---------------------|
| 單層（當前） / Single floor (current) | ~1M | 數小時 / Hours | ~$10-50 |
| 整棟建築 / Full building | ~100M | 數日至數週 / Days to weeks | ~$500-2000 |
| 多座大廈 / Multi-tower | ~1B+ | 數週至數月 / Weeks to months | ~$5000-20000+ |

*成本基於 AWS 按需 HPC 實例定價估計 / Cost estimates based on AWS on-demand HPC instance pricing*

### 驗證要求 / Validation Requirements

- 與觀察到嘅火勢蔓延模式對比 / Comparison against observed fire spread patterns
- 與時間線（階段 2）對比 / Comparison with timeline (Phase 2)
- 敏感度分析（網格解析度、材料屬性） / Sensitivity analysis (mesh resolution, material properties)
- 與已知火災測試數據對比 / Comparison with known fire test data

---

## 階段 4：多座大廈蔓延 / Phase 4: Multi-Tower Spread

### 目標 / Objective

模擬火勢從旺福中心蔓延至鄰近大廈嘅可能性。

Model the potential for fire spread from Wang Fuk Centre to adjacent towers.

### 額外要求 / Additional Requirements

1. **周邊建築幾何 / Surrounding Building Geometry**
   - 所有 6 座大廈嘅平面圖 / Floor plans for all 6 towers
   - 建築物間距 / Building separation distances
   - 外牆材料 / Facade materials

2. **飛火建模 / Firebrand Modeling**
   - 飛火傳播模擬 / Flying ember transport simulation
   - 風場建模 / Wind field modeling
   - 接收材料易燃性 / Receiving material ignitability

3. **輻射熱傳遞 / Radiative Heat Transfer**
   - 建築物之間嘅視角因子 / View factors between buildings
   - 外牆臨界熱通量 / Critical heat flux for facades

### 研究差距 / Research Gaps

- 竹棚架飛火產生率嘅數據有限 / Limited data on firebrand generation rates from bamboo scaffolding
- 香港高密度環境嘅具體研究缺乏 / Lack of specific research for Hong Kong high-density environments

---

## 所需專業知識 / Required Expertise

### 攝影測量 / Photogrammetry

**問：攝影測量專家會有幫助嗎？ / Q: Would a photogrammetry expert help?**

**答：會，對整棟建築模擬非常有價值。 / A: Yes, very valuable for full building simulation.**

攝影測量專家可以 / A photogrammetry expert can:

1. **處理非理想圖像 / Process Non-Ideal Images**
   - 從新聞片段、手機影片提取幀 / Extract frames from news footage, mobile videos
   - 處理運動模糊、低解析度 / Handle motion blur, low resolution
   - 合併多個來源 / Combine multiple sources

2. **優化重建質量 / Optimize Reconstruction Quality**
   - 選擇最佳圖像子集 / Select optimal image subsets
   - 調整算法參數 / Tune algorithm parameters
   - 識別同填補缺口 / Identify and fill gaps

3. **與 FDS 整合 / Integrate with FDS**
   - 將攝影測量輸出轉換為 FDS 幾何 / Convert photogrammetry output to FDS geometry
   - 確保正確嘅比例同對齊 / Ensure correct scale and alignment
   - 簡化網格以供 CFD 使用 / Simplify mesh for CFD use

### 其他所需專業知識 / Other Required Expertise

| 專業 / Expertise | 貢獻 / Contribution |
|------------------|---------------------|
| 火災工程 / Fire Engineering | FDS 建模、火災動力學分析 / FDS modeling, fire dynamics analysis |
| 結構工程 / Structural Engineering | 建築物同棚架幾何 / Building and scaffolding geometry |
| 材料科學 / Materials Science | 燃燒特性數據 / Combustion property data |
| 氣象學 / Meteorology | 風場建模 / Wind field modeling |
| 數據可視化 / Data Visualization | 結果呈現 / Results presentation |

---

## 數據收集優先級 / Data Collection Priorities

### 高優先級 / High Priority

- [ ] 建築圖則（如可獲得） / Building plans (if obtainable)
- [ ] 帶時間戳嘅事件相片/影片 / Timestamped incident photos/videos
- [ ] 天氣數據（事發時） / Weather data (at time of incident)
- [ ] 棚架配置記錄 / Scaffolding configuration records

### 中優先級 / Medium Priority

- [ ] 目擊者陳述 / Witness statements
- [ ] 消防處記錄 / Fire Services records
- [ ] 相鄰建築物資料 / Adjacent building information

### 低優先級 / Lower Priority

- [ ] 歷史翻新記錄 / Historical renovation records
- [ ] 類似建築物案例研究 / Similar building case studies

---

## 資源同限制 / Resources and Constraints

### 計算資源 / Computational Resources

- 當前：AWS 競價實例，按需擴展 / Current: AWS spot instances, scale on demand
- 階段 3+：可能需要 HPC 集群或雲端 HPC 服務 / Phase 3+: May require HPC cluster or cloud HPC services

### 資金來源 / Potential Funding Sources

- 社區眾籌 / Community crowdfunding
- 學術機構合作 / Academic institution partnership
- 消防安全研究基金 / Fire safety research grants
- 新聞調查基金 / Investigative journalism funds

### 時間限制 / Timeline Constraints

- 證據可能隨時間流失 / Evidence may be lost over time
- 目擊者記憶會褪色 / Witness memories will fade
- 建築物可能被翻新或拆除 / Building may be renovated or demolished

---

## 下一步行動 / Next Steps

1. **即時 / Immediate**
   - 完成當前 16 個情景模擬 / Complete current 16 scenario simulations
   - 收集同存檔可用嘅相片/影片 / Collect and archive available photos/videos
   - 嘗試獲取建築圖則 / Attempt to obtain building plans

2. **短期 / Short-term**
   - 建立時間線數據庫 / Build timeline database
   - 評估攝影測量可行性 / Assess photogrammetry feasibility
   - 識別潛在合作者 / Identify potential collaborators

3. **長期 / Long-term**
   - 尋求資金支持 / Seek funding support
   - 建立專家網絡 / Build expert network
   - 規劃整棟建築模擬 / Plan full building simulation

---

*本文件為工作文件，會隨調查進展更新。*

*This is a working document that will be updated as the investigation progresses.*
