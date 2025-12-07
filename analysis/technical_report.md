# 技術分析報告 / Technical Analysis Report

## 1. 建築物概覽 / Building Overview

**宏福苑 (Wang Fuk Court):**
*   香港大埔區嘅資助房屋屋苑，建於1983年。<br>Subsidised Home Ownership Scheme housing complex in Tai Po District, Hong Kong, built in 1983.
*   由8座31層高住宅大廈組成，約90米高。<br>Comprised of 8 residential blocks, each 31 storeys high, approximately 90m tall.
*   火災發生時，大廈外牆正進行大型維修工程。<br>Undergoing major exterior wall renovation at the time of the fire.

## 2. 火災蔓延機制 / Fire Spread Mechanisms

### 2.1 棚架與安全網 (Scaffolding & Netting)
*   **材料 (Materials):** 竹棚架包裹住綠色安全網。<br>Bamboo scaffolding encased in green safety netting.
*   **作用 (Role):** 提供大量可燃垂直燃料，成為火勢迅速向上蔓延嘅主要途徑。<br>Provided a significant vertical fuel load, acting as a primary pathway for rapid upward fire spread.
*   **合規性爭議 (Compliance Controversy):** 初步檢測顯示部分棚架安全網未能通過阻燃測試，暗示可能使用咗不合規材料。<br>Initial tests indicated some scaffolding nets failed fire retardant testing, suggesting the use of non-compliant materials.

### 2.2 發泡膠封窗 (Polystyrene Window Sealing)
*   **材料 (Materials):** 易燃發泡膠板。<br>Flammable expanded polystyrene foam boards.
*   **作用 (Role):** 用於密封窗戶，一旦被點燃，釋放大量熱量同濃煙，並導致玻璃爆裂，令火勢蔓延至建築物內部。<br>Used to seal windows, upon ignition, they released significant heat and dense smoke, causing windows to shatter and facilitating fire spread into the building interior.

### 2.3 煙囪效應 (Chimney Effect)
*   **機制 (Mechanism):** 棚架與建築物外牆之間嘅空隙形成垂直通道，極大加速咗火勢向上蔓延。<br>The gap between the scaffolding/netting and the building facade created a vertical channel, greatly accelerating upward fire spread.
*   **影響 (Impact):** 比明火蔓延速度快3至6倍。<br>Accelerated fire spread by 3-6 times compared to open fires.

### 2.4 火警鐘失效 (Fire Alarm System Failure)
*   **狀態 (Status):** 系統運作正常但未發出聲響，導致居民未能及時疏散。<br>The system was functional but failed to sound, leading to delayed evacuation for residents.
*   **影響 (Impact):** 增加咗傷亡人數。<br>Contributed to the high casualty count.

## 3. 環境因素 / Environmental Factors

*   **天氣 (Weather):** 火災發生時香港發出紅色火災危險警告，天氣乾燥，風勢強勁（西北風約16公里/小時），助長火勢。<br>Red Fire Danger Warning in effect, dry conditions with strong winds (~16 km/h NW wind) exacerbated fire spread.
*   **時間 (Time):** 火災發生喺下午，居民可能未有充分時間應變。<br>Afternoon incident may have limited residents' response time.

## 4. FDS 模擬相關性 / FDS Simulation Relevance

上述因素將直接影響FDS火災動力學模擬嘅設置同驗證：<br>The above factors directly influence FDS simulation setup and validation:

*   **幾何模型 (Geometric Model):** 需要精確模擬棚架結構、與外牆嘅距離以及窗戶位置。<br>Accurate modeling of scaffolding structure, facade gap, and window locations.
*   **材料屬性 (Material Properties):** 需輸入竹、安全網（聚丙烯PP）、發泡膠（聚苯乙烯）嘅熱釋放率、燃點等參數。<br>Input parameters for heat release rates, ignition temperatures for bamboo, safety netting (PP), and polystyrene.
*   **通風 (Ventilation):** 需要考慮火災當日嘅風速同風向數據。<br>Inclusion of wind speed and direction data from the day of the fire.
*   **火源 (Fire Source):** 初始點火位置同熱釋放率。<br>Initial ignition location and heat release rate.
*   **驗證 (Validation):** 模擬結果將根據火勢蔓延速度、垂直蔓延至高層嘅時間同總體熱量釋放同實際觀察結果進行比較。<br>Simulation results will be compared against observed fire spread rate, time to reach upper floors, and overall heat release for validation.

## 參考文獻 / References

*   [Fire Dynamics Simulation Methodology / 火災動力學模擬方法](simulation/README.md)
*   [Verified Timeline of Wang Fuk Court Fire / 宏福苑火災經核實時間線](analysis/timeline.md)
*   各已存檔新聞報導 / Various Archived News Reports (參閱 `evidence/news/`)
