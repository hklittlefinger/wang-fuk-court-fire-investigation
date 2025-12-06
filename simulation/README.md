# 火災動力學模擬 / Fire Dynamics Simulation

本目錄包含使用 Fire Dynamics Simulator (FDS) 進行嘅火災動力學模擬。

This directory contains fire dynamics simulations using the Fire Dynamics Simulator (FDS).

---

## 模擬狀態 / Simulation Status

**目前階段：模型驗證**

我哋正運行模擬以驗證FDS模型係咪準確反映觀察到嘅火災行為。喺驗證完成之前，模擬結果應視為初步數據，唔係最終結論。

**Current Phase: Model Validation**

We are running simulations to validate whether the FDS model accurately reflects observed fire behavior. Until validation is complete, simulation results should be considered preliminary data, not final conclusions.

---

## 模擬範圍 / Simulation Scope

本研究**僅模擬棚架外牆**（10米×5.6米×90米）以隔離棚架材料嘅影響。我哋刻意排除：

- **完整建築物內部**：唔模擬內部間隔、住戶或建築結構。重點係棚架材料，唔係疏散或結構倒塌。
- **建築群**：唔模擬相鄰建築物或整個宏福苑。單一外牆嘅火災行為已足以比較材料影響。
- **風力影響**：無模擬盛行風向。風力會影響整體火勢蔓延，但唔會影響每種材料嘅相對貢獻。

This study models **only the scaffold facade** (10m × 5.6m × 90m) to isolate scaffold material contributions. We intentionally exclude:

- **Full building interior**: Not modeling internal compartments, occupants, or building structure. Focus is scaffold materials, not evacuation or structural failure.
- **Building complex**: Not modeling adjacent buildings or the entire Wang Fuk Court site.
- **Wind effects**: No prevailing wind conditions modeled.

---

## 模擬矩陣 / Simulation Matrix

### 第一層：關鍵驗證（5個模擬）/ TIER 1: Critical Validation (5 simulations)

| # | 檔案 / File | 棚架 / Scaffolding | 安全網 / Safety Net | 發泡膠 / Styrofoam | 目的 / Purpose |
|---|-------------|---------------------|---------------------|---------------------|----------------|
| 1 | tier1_1_bamboo_PP_styro.fds | 竹 / Bamboo | PP（不合規）| 有 / Yes | **實際事件 / ACTUAL incident** |
| 2 | tier1_2_steel_PP_styro.fds | **鋼 / Steel** | PP（不合規）| 有 / Yes | 隔離竹嘅影響 / Isolate bamboo |
| 3 | tier1_3_bamboo_FR_styro.fds | 竹 / Bamboo | **FR-HDPE（合規）** | 有 / Yes | 隔離網嘅影響 / Isolate netting |
| 4 | tier1_4_steel_FR_styro.fds | **鋼 / Steel** | **FR-HDPE（合規）** | 有 / Yes | 完全合規連發泡膠 / Full compliance with styrofoam |
| 5 | tier1_5_bamboo_FR_no_styro.fds | 竹 / Bamboo | **FR-HDPE（合規）** | **無 / No** | FR網下發泡膠影響 / Styrofoam effect with FR net |

### 第二層：延伸分析（3個模擬）/ TIER 2: Extended Analysis (3 simulations)

| # | 檔案 / File | 棚架 / Scaffolding | 安全網 / Safety Net | 發泡膠 / Styrofoam | 目的 / Purpose |
|---|-------------|---------------------|---------------------|---------------------|----------------|
| 6 | tier2_1_bamboo_none_styro.fds | 竹 / Bamboo | **無 / None** | 有 / Yes | 網嘅總體影響 / Total net effect |
| 7 | tier2_2_bamboo_HDPE_styro.fds | 竹 / Bamboo | **HDPE（廉價）** | 有 / Yes | PP vs HDPE |
| 8 | tier2_3_steel_FR_nostyro.fds | 鋼 / Steel | FR-HDPE | **無 / No** | 完全合規下發泡膠影響 / Styrofoam effect with full compliance |

---

## 火源 / Fire Source

**點火 / Ignition**：地面單一點火源（z=0.0-2.0米）/ Single ignition source at ground level (z=0.0-2.0m)
- HRRPUA：2500 kW/m²
- 位置 / Location：4.0-6.0米（x）× 4.25-5.0米（y）
- 火勢經可燃棚架材料自然蔓延 / Fire spreads naturally through combustible scaffold materials

**無單位窗口噴火 / No apartment window jets** — 重點係棚架材料貢獻 / Focus is on scaffold material contribution

---

## 材料特性 / Material Properties

### 棚架材料 / Scaffolding Materials

**竹 / Bamboo**：
- 濕竹（40 kg/m³）→ 乾竹（35 kg/m³）→ 炭（10 kg/m³）+ 木氣
- Wet bamboo (40 kg/m³) → Dry (35 kg/m³) → Char (10 kg/m³) + Wood vapor
- 著火點 / Ignition：280°C
- 燃燒熱 / HoC：~15 MJ/kg

**鋼 / Steel**：惰性、不可燃、高導熱（散熱）/ Inert, non-combustible, high conductivity (heat sink)

### 安全網材料 / Safety Net Materials

| 材料 / Material | 著火點 / Ignition | 燃燒熱 / HoC | 燃燒速率 / Burn Rate |
|-----------------|-------------------|--------------|---------------------|
| **PP帳篷布**（不合規）/ PP Tarpaulin (non-compliant) | 345°C | 46 MJ/kg | 12.4 mm/min |
| **HDPE**（廉價中國標準）/ HDPE (cheap) | 355°C | 43 MJ/kg | - |
| **FR-HDPE**（合規）/ FR-HDPE (compliant) | 475°C | - | 0.8 mm/min（慢15.5倍！/ 15.5× slower!）|

### 窗口密封 / Window Sealing

**發泡膠 / Styrofoam**：聚苯乙烯泡沫 / Polystyrene foam
- 著火點 / Ignition：350°C
- 燃燒熱 / HoC：40 MJ/kg
- 大量煙霧 / Massive soot

---

## 喺AWS運行 / Running on AWS

### 自訂AMI / Custom AMI

模擬使用預建AMI，包含 / Simulations use a pre-built AMI with：
- **FDS 6.10.1** 配 HYPRE v2.32.0 及 Sundials v6.7.0（靜態鏈接）
- **Intel oneAPI**（MPI、編譯器、數學函式庫）
- FDS執行檔 / FDS binary：`/opt/fds/bin/fds`
- 環境設定 / Environment setup：`source /opt/intel/oneapi/setvars.sh`

AMI喺多個區域可用 / AMI available in multiple regions：eu-north-1, eu-south-1, eu-south-2, ap-northeast-1, ap-southeast-3

### 啟動腳本 / Launch Script

```bash
cd simulation

# 基本啟動 / Basic launch
./scripts/launch_aws.sh --key-path ~/.ssh/fds-key-pair tier1_*.fds tier2_*.fds

# 全新開始（刪除現有S3輸出）/ Fresh start (delete existing S3 output)
./scripts/launch_aws.sh --key-path ~/.ssh/fds-key-pair --clean tier1_1.fds

# 大型模擬用更大硬碟 / Larger disk for big simulations
./scripts/launch_aws.sh --key-path ~/.ssh/fds-key-pair --volume-size 200 tier1_1.fds
```

腳本會 / The script will：
1. 搵最平且有spot容量嘅區域 / Find cheapest region with available spot capacity
2. 自動偵測所選區域嘅自訂FDS AMI / Auto-detect custom FDS AMI in the selected region
3. 建立VPC、安全群組及S3 Gateway端點 / Create VPC, security groups, and S3 Gateway endpoint
4. 啟動EC2 spot實例（c7i.12xlarge，48 vCPU，100GB硬碟）/ Launch EC2 spot instance
5. 上載FDS檔案並喺tmux啟動模擬 / Upload FDS file and start simulation in tmux
6. **從檢查點恢復**如果S3有restart檔案 / **Resume from checkpoint** if restart files exist in S3
7. 喺SQLite資料庫追蹤實例資訊（`instances.db`）/ Track instance info in SQLite database
8. 同步輸出到S3儲存桶 / Sync outputs to S3 bucket

### 監控狀態 / Monitor Status

```bash
./scripts/check_status.sh --key-path ~/.ssh/fds-key-pair --watch --interval 60
```

### 手動執行 / Manual Execution

#### SSH登入實例 / SSH into the instance
```bash
ssh -i ~/.ssh/fds-key-pair ubuntu@<INSTANCE_IP>
```

#### 開始新模擬 / Start a fresh simulation
```bash
# 載入Intel環境 / Load Intel environment
source /opt/intel/oneapi/setvars.sh

# 進入工作目錄 / Navigate to work directory
cd ~/fds-work/<CHID>

# 計算mesh數量 / Count meshes
NUM_MESHES=$(grep -c '&MESH' <simulation>.fds)

# 喺tmux運行 / Run in tmux
tmux new-session -d -s fds_run "source /opt/intel/oneapi/setvars.sh && mpiexec -n $NUM_MESHES /opt/fds/bin/fds <simulation>.fds"
```

#### 從restart檔案恢復 / Resume from a restart file
```bash
# 編輯FDS檔案啟用restart模式 / Edit FDS file to enable restart mode
sed -i 's/^&MISC /&MISC RESTART=.TRUE., /' <simulation>.fds

# 開始模擬 / Start simulation
tmux new-session -d -s fds_run "source /opt/intel/oneapi/setvars.sh && mpiexec -n $NUM_MESHES /opt/fds/bin/fds <simulation>.fds"
```

#### 監控進度 / Monitor progress
```bash
# 連接tmux session / Attach to tmux session
tmux attach -t fds_run

# 檢查進度 / Check progress
tail -f ~/fds-work/<CHID>/<CHID>.out

# 檢查當前模擬時間 / Check current simulation time
grep "Time Step" ~/fds-work/<CHID>/<CHID>.out | tail -5
```

---

## 輸出檔案 / Output Files

### 核心檔案 / Core Files
- `*.out` - 文字輸出日誌 / Text output log
- `*.smv` - Smokeview可視化元數據 / Smokeview visualization metadata
- `*.restart` - 檢查點檔案 / Checkpoint files (每300秒 / every 300s)

### CSV數據 / CSV Data
- `*_hrr.csv` - 熱釋放率時間序列 / Heat Release Rate time series
- `*_steps.csv` - 時間步統計 / Time step statistics
- `*_devc.csv` - 設備測量 / Device measurements

### 可視化檔案 / Visualization Files
- `*.sf` - 切片檔案 / Slice files
- `*.bf` - 邊界檔案 / Boundary files
- `*.prt5` - 粒子數據 / Particle data
- `*.s3d` - 3D煙霧可視化 / 3D smoke visualization

---

## 分析方法 / Analysis Method

### 主要指標 / Primary Metrics
1. **峰值HRR**（MW）— 火災強度 / Peak HRR (MW) - Fire intensity
2. **到達30樓時間**（秒）— 蔓延速率 / Time to Floor 30 (s) - Spread rate
3. **總釋放熱量**（GJ）— 燃料貢獻 / Total heat released (GJ) - Fuel contribution

### 比較方法 / Comparison Method
```python
bamboo_contribution = (Sim1_HRR - Sim2_HRR) / Sim1_HRR * 100
netting_compliance = (Sim1_time - Sim3_time)  # 額外疏散時間 / Extra evacuation time
styrofoam_effect = (Sim3_HRR - Sim5_HRR) / Sim3_HRR * 100
```

---

## 技術背景 / Technical Background

### 點解只模擬棚架外牆？/ Why Model Only the Scaffold Facade?

棚架外牆模擬方法將**材料貢獻問題**從干擾變數中隔離。遵循類似[BS 8414](https://www.designingbuildings.co.uk/wiki/BS_8414_Fire_performance_of_external_cladding_systems)外牆火災測試嘅原則。

The scaffold facade modeling approach isolates the **material contribution question** from confounding variables. This follows principles similar to BS 8414 facade fire tests.

- **煙囪效應 / Chimney effect**：棚架同建築物外牆之間嘅空隙形成垂直通道，加速向上火焰蔓延（比明火快3-6倍）/ Gap between scaffolding and building exterior creates vertical channel accelerating upward flame spread (3-6× faster than open fires)

### 多孔棚架幾何 / Porous Scaffolding Geometry

| 層 / Layer | Y位置 / Y-Position | 厚度 / Thickness | 描述 / Description |
|------------|---------------------|------------------|---------------------|
| 安全網 / Safety Net | 4.05-4.25m | 0.2m | 連續PP帳篷布層 / Continuous PP tarpaulin layer |
| 外排竹 / Outer Bamboo Row | 4.25-4.45m | 0.2m | 離散垂直竹竿 / Discrete vertical poles |
| *空氣腔 / Air Cavity* | 4.45-4.65m | 0.2m | 主要煙囪通道 / Primary chimney channel |
| 內排竹 / Inner Bamboo Row | 4.65-4.85m | 0.2m | 離散垂直竹竿 / Discrete vertical poles |
| *空氣間隙 / Air Gap* | 4.85-5.00m | 0.15m | 次要對流路徑 / Secondary convection path |
| 發泡膠 / Styrofoam | 5.00-5.05m | 0.05m | 窗口密封 / Window sealant |
| 建築牆 / Building Wall | 5.05-5.25m | 0.2m | 混凝土基底 / Concrete substrate |

### 網格解像度 / Mesh Resolution

20厘米網格大小基於[特徵火災直徑（D*）](https://fdstutorial.com/fds-mesh-size-calculator/) / 20cm cell size based on characteristic fire diameter (D*):

| 參數 / Parameter | 數值 / Value |
|------------------|--------------|
| HRRPUA | 2500 kW/m²（1.5m²）= 3.75 MW |
| D* | ≈1.5m |
| 網格大小 / Cell size (dx) | 0.2m |
| **D*/dx** | **≈7.5**（中等解像度 / medium resolution）|

### 壓力求解器 / Pressure Solver

複雜嘅多孔竹棚幾何需要 / Complex porous bamboo geometry requires：`SOLVER='UGLMAT HYPRE'`

- **U（非結構化）/ U (Unstructured)**：僅喺氣相求解壓力 / Solves pressure only in gas phase
- **G（全域）/ G (Global)**：跨所有mesh全域求解壓力 / Solves pressure globally across all meshes
- **HYPRE**：高效多重網格庫 / Efficient multigrid library

### 模擬參數 / Simulation Parameters

| 參數 / Parameter | 數值 / Value | 理據 / Justification |
|------------------|--------------|----------------------|
| FDS版本 / FDS Version | 6.10.1 | [官方版本 / Official release](https://github.com/firemodels/fds/releases/tag/FDS-6.10.1) |
| 網格單元 / Grid cells | 225,000 | 20厘米解像度 / 20cm resolution |
| 領域 / Domain | 10m × 5.6m × 30m | 單一外牆 / Single facade |
| 壓力求解器 / Pressure solver | UGLMAT HYPRE | 複雜多孔幾何 / Complex porous geometry |
| 湍流 / Turbulence | Deardorff | 火羽標準LES / Standard LES for fire plumes |
| 輻射 / Radiation | 40%輻射分數 / 40% radiative fraction | 擴散火焰典型值 / Typical for diffusion flames |
| MPI進程 / MPI processes | 15 | 每個mesh一個 / One per mesh |

---

## 參考資料 / References

### Fire Dynamics Simulator
- [FDS-SMV官方網站 / Official Site](https://pages.nist.gov/fds-smv/) - NIST
- [FDS GitHub儲存庫 / Repository](https://github.com/firemodels/fds)
- [FDS網格大小計算器 / Mesh Size Calculator](https://fdstutorial.com/fds-mesh-size-calculator/)

### 竹火災特性 / Bamboo Fire Properties
- [竹結構火災增長 / Fire growth for bamboo structures](https://www.sciencedirect.com/science/article/abs/pii/S0379711220301375) - Fire Safety Journal
- [層壓竹消防安全設計 / Fire safety design for laminated bamboo](https://www.researchgate.net/profile/Ian-Pope-5/publication/356838161_Fire_safety_design_tools_for_laminated_bamboo_buildings/links/627a1ac32f9ccf58eb3c30e8/Fire-safety-design-tools-for-laminated-bamboo-buildings.pdf) - Pope et al.

### 聚合物燃燒 / Polymer Combustion
- [阻燃聚丙烯 / Flame Retardant Polypropylenes](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7464193/) - PMC
- [聚丙烯火災危險 / Fire hazard with polypropylene](https://link.springer.com/chapter/10.1007/978-94-011-4421-6_34) - Springer
- [FR-HDPE指南 / FR-HDPE Guide](https://www.globalplasticsheeting.com/our-blog-resource-library/fire-retardant-woven-hdpe-the-ultimate-guide)

### 外牆火災測試 / Facade Fire Testing
- [BS 8414消防性能 / Fire performance](https://www.designingbuildings.co.uk/wiki/BS_8414_Fire_performance_of_external_cladding_systems) - Designing Buildings
- [EN 13501-1消防分類 / Fire Classification](https://measurlabs.com/blog/en-13501-1-fire-classification-performance-classes-and-criteria/) - Measurlabs

### 香港法規 / Hong Kong Regulations
- [竹棚架安全守則 / Bamboo Scaffolding Safety Code](https://www.labour.gov.hk/eng/public/os/B/Bamboo.pdf) - 勞工處 / Labour Department
- [建築地盤規例第59I章 / Construction Sites Regulations Cap. 59I](https://www.elegislation.gov.hk/hk/cap59I) - 香港電子法例 / HK e-Legislation
