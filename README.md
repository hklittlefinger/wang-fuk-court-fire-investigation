# 宏福苑火災獨立調查

<p align="center">
  <strong>獨立社區驅動嘅調查</strong>
  <br>
  <em>「就算要燒毀呢個國家，佢都想做灰燼嘅王」</em>
  <br>
  — 瓦里斯大人
</p>

> **📢 徵集證據**
>
> 我哋正積極收集以下證據用於火災模擬驗證：
>
> - **帶時間戳嘅影片/相片** — 顯示火勢發展嘅多角度片段（如有需要請保留 EXIF 元數據）
> - **火災前相片** — 棚架、安全網、發泡膠窗罩嘅配置
> - **目擊者陳述** — 你見到乜嘢？幾點？喺邊度？
> - **火警系統證據** — 火警鐘有冇響？幾時響？
>
> 如果你有任何相關資料，請參閱 [CONTRIBUTING.md](CONTRIBUTING.md) 或 [匿名提交指引](ANONYMOUS-CONTRIBUTIONS.md)。

## 調查狀態

| 階段 | 描述 | 狀態 |
|------|------|------|
| 1. 證據收集 | 收集並保存新聞報導、相片、影片及第一手陳述 | 進行中 |
| 2. 火災動力學模擬 | FDS建模及**模型驗證** | **進行中** |
| 3. 技術分析 | 建築系統、材料、火勢蔓延分析 | 待開始 |
| 4. 法規審查 | 合規評估、監管漏洞 | 待開始 |
| 5. 調查報告 | 調查結果及建議 | 計劃中 |

**目前狀態**：我哋正處於**模型驗證階段**——運行模擬以確認FDS模型係咪準確反映觀察到嘅火災行為，然後先可以得出任何結論。

## 概覽

呢係一個**獨立、社區驅動嘅調查**，記錄及分析2025年11月26日發生於香港大埔宏福苑嘅火災慘劇，事件造成159人以上死亡。

### 我哋嘅目標

1. **保存證據** — 趁證據消失之前
2. **實現獨立分析** — 透過火災動力學模擬
3. **支持消防安全改進** — 透過嚴謹嘅技術調查
4. **發表調查報告** — 記錄調查結果並提出建議

### 呢個唔係乜嘢

- 呢個**唔係**官方政府調查
- 呢個**唔係**任何政治組織嘅一部分
- 呢個**唔係**商業項目

我哋係一個獨立團隊，運用公開證據及科學方法了解發生咗乜嘢同點解。

## 項目結構

```
├── evidence/              # 證據收集
├── analysis/              # 技術分析
├── simulation/            # FDS火災動力學模擬
├── reports/               # 調查報告
└── resources/             # 工具及參考資料
```

## 事件事實

宏福苑火災發生於2025年11月26日約下午2時51分，地點係香港大埔區。關鍵事實：

- **建築物**：8座31層大廈（約90米高），1983年落成
- **傷亡**：159人以上死亡
- **天氣**：紅色火災危險警告生效；23°C，42%相對濕度，西北風約16公里/小時
- **火勢蔓延**：經棚架空隙煙囪效應快速垂直蔓延；4小時內升至五級火
- **初步發現**：七個棚架網樣本未能通過阻燃測試；火警鐘未能正常運作

來源：[半島電視台](https://www.aljazeera.com/news/2025/11/27/hong-kongs-deadliest-fire-in-63-years-what-we-know-and-how-it-spread)、[南華早報](https://multimedia.scmp.com/infographics/news/hong-kong/article/3334304/taipo_wangfuk_fire/index.html)、[HK01](https://www.hk01.com/%E7%AA%81%E7%99%BC/60297831)、[維基百科](https://en.wikipedia.org/wiki/Wang_Fuk_Court_fire)

## 調查問題

我哋嘅調查旨在回答：

1. **棚架材料對火勢蔓延嘅貢獻有幾大？** 竹棚 vs 鋼棚
2. **不合規嘅安全網係咪主要問題？** PP帳篷布 vs 阻燃HDPE
3. **如果完全合規，能否防止死亡？**
4. **發泡膠窗口密封係咪關鍵因素？**

## 參與貢獻

我哋歡迎任何擁有相關資料嘅人士參與貢獻：

- **證據**：相片、影片、新聞報導、目擊者陳述
- **技術專長**：消防工程、建築法規、FDS模擬
- **翻譯**：中英對照

請參閱 [CONTRIBUTING.md](CONTRIBUTING.md) 了解如何幫忙。

### 安全顧慮

如果你有安全或私隱顧慮，請參閱 [ANONYMOUS-CONTRIBUTIONS.md](ANONYMOUS-CONTRIBUTIONS.md) 了解匿名貢獻嘅方法。

## 詳細文檔

- [調查方法論](analysis/methodology.md) — 我哋嘅調查框架
- [火災動力學模擬](simulation/README.md) — FDS模擬技術詳情
- [證據收集指引](evidence/README.md) — 如何提交證據

## 聯絡

- **問題**：[GitHub Discussions](https://github.com/hklittlefinger/wang-fuk-court-fire-investigation/discussions)
- **安全聯絡**：見 [ANONYMOUS-CONTRIBUTIONS.md](ANONYMOUS-CONTRIBUTIONS.md)

---

*本項目不隸屬於任何政府、政治組織或商業實體。呢係一個獨立努力，旨在紀錄及分析重大消防安全事件。目標係真相同預防，而唔係追究責任。*

---

# Wang Fuk Court Fire Independent Investigation

<p align="center">
  <strong>Independent Community-Driven Investigation</strong>
  <br>
  <em>"He would see this country burn if he could be king of the ashes"</em>
  <br>
  — Lord Varys
</p>

> **📢 Call for Evidence**
>
> We are actively collecting evidence for fire simulation validation:
>
> - **Timestamped videos/photos** — footage showing fire progression from multiple angles (preserve EXIF metadata if possible and necessary)
> - **Pre-fire photos** — scaffolding, safety nets, styrofoam window covers configuration
> - **Witness statements** — what did you see? when? where?
> - **Fire alarm evidence** — did the fire alarm sound? when?
>
> If you have any relevant information, see [CONTRIBUTING.md](CONTRIBUTING.md) or [anonymous submission guide](ANONYMOUS-CONTRIBUTIONS.md).

## Investigation Status

| Phase | Description | Status |
|-------|-------------|--------|
| 1. Evidence Collection | Gather and preserve news reports, photos, videos, first-hand accounts | In Progress |
| 2. Fire Dynamics Simulation | FDS modeling and **model validation** | **In Progress** |
| 3. Technical Analysis | Building systems, materials, fire spread analysis | Pending |
| 4. Regulatory Review | Compliance assessment, regulatory gaps | Pending |
| 5. Investigation Report | Findings and recommendations | Planned |

**Current Status**: We are in the **model validation stage**—running simulations to confirm the FDS model accurately reflects observed fire behavior before drawing any conclusions.

## Overview

This is an **independent, community-driven investigation** documenting and analyzing the Wang Fuk Court fire tragedy (November 26, 2025, Tai Po, Hong Kong) that claimed 159+ lives.

### Our Goals

1. **Preserve evidence** before it disappears
2. **Enable independent analysis** through fire dynamics simulation
3. **Support fire safety improvements** through rigorous technical investigation
4. **Publish an investigation report** documenting findings and recommendations

### What This Is NOT

- This is **NOT** an official government investigation
- This is **NOT** affiliated with any political organization
- This is **NOT** a commercial project

We are an independent team using publicly available evidence and scientific methods to understand what happened and why.

## Project Structure

```
├── evidence/              # Evidence collection
├── analysis/              # Technical analysis
├── simulation/            # FDS fire dynamics simulation
├── reports/               # Investigation reports
└── resources/             # Tools and references
```

## Incident Facts

The Wang Fuk Court fire occurred on November 26, 2025 at ~14:51 HKT in Tai Po District, Hong Kong. Key facts:

- **Building:** 8 blocks of 31-storey towers (~90m height), opened 1983
- **Casualties:** 159+ deaths
- **Weather:** Red Fire Danger Warning in effect; 23°C, 42% RH, NW wind ~16 km/h
- **Fire spread:** Rapid vertical spread via chimney effect in scaffold cavity; escalated to 5-alarm fire within 4 hours
- **Initial findings:** Seven scaffolding net samples failed fire retardant testing; fire alarms failed to operate properly

Sources: [Al Jazeera](https://www.aljazeera.com/news/2025/11/27/hong-kongs-deadliest-fire-in-63-years-what-we-know-and-how-it-spread), [SCMP](https://multimedia.scmp.com/infographics/news/hong-kong/article/3334304/taipo_wangfuk_fire/index.html), [HK01](https://www.hk01.com/%E7%AA%81%E7%99%BC/60297831), [Wikipedia](https://en.wikipedia.org/wiki/Wang_Fuk_Court_fire)

## Investigation Questions

Our investigation aims to answer:

1. **How much did scaffolding materials contribute to fire spread?** Bamboo vs steel
2. **Was non-compliant safety netting the main problem?** PP tarpaulin vs FR-HDPE
3. **Could full compliance have prevented deaths?**
4. **Was styrofoam window sealing a critical factor?**

## Contributing

We welcome contributions from anyone with relevant information:

- **Evidence**: Photos, videos, news reports, witness statements
- **Technical expertise**: Fire engineering, building codes, FDS simulation
- **Translation**: Chinese ↔ English

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to help.

### Safety Concerns

If you have safety or privacy concerns, see [ANONYMOUS-CONTRIBUTIONS.md](ANONYMOUS-CONTRIBUTIONS.md) for methods to contribute anonymously.

## Detailed Documentation

- [Investigation Methodology](analysis/methodology.md) — Our investigation framework
- [Fire Dynamics Simulation](simulation/README.md) — FDS simulation technical details
- [Evidence Collection Guidelines](evidence/README.md) — How to submit evidence

## Contact

- **Questions**: [GitHub Discussions](https://github.com/hklittlefinger/wang-fuk-court-fire-investigation/discussions)
- **Secure contact**: See [ANONYMOUS-CONTRIBUTIONS.md](ANONYMOUS-CONTRIBUTIONS.md)

---

*This project is not affiliated with any government, political organization, or commercial entity. It is an independent effort to document and analyze a significant fire safety incident. The goal is truth and prevention, not blame.*
