# Wang Fuk Fire - Parametric Study

## Overview
8 FDS simulations to determine material contributions to fire spread.

### Simulation Scope

This study models **only the scaffold facade** (10m × 5.6m × 90m) to isolate scaffold material contributions. We intentionally exclude:

- **Full building interior**: Not modeling internal compartments, occupants, or building structure. Our focus is scaffold materials, not evacuation or structural failure.
- **Building complex**: Not modeling adjacent buildings or the entire Wang Fuk Court site. The fire behavior on a single facade is sufficient to compare material contributions.
- **Wind effects**: No prevailing wind conditions modeled. Wind would affect overall fire spread but not the relative contribution of each material (bamboo vs steel, PP vs FR-HDPE, styrofoam vs none), which is our research question.

This simplified approach allows us to:
1. Directly compare material contributions without confounding variables
2. Complete simulations in reasonable time (45 hours vs months)
3. Focus computational resources on high-resolution material combustion

## Simulation Matrix

### TIER 1: Critical Validation (5 simulations)

| # | File | Scaffolding | Safety Net | Styrofoam | Purpose |
|---|------|-------------|------------|-----------|---------|
| 1 | tier1_1_bamboo_PP_styro.fds | Bamboo | PP (non-compliant) | Yes | **ACTUAL incident** |
| 2 | tier1_2_steel_PP_styro.fds | **Steel** | PP (non-compliant) | Yes | Isolate bamboo |
| 3 | tier1_3_bamboo_FR_styro.fds | Bamboo | **FR-HDPE (compliant)** | Yes | Isolate netting |
| 4 | tier1_4_steel_FR_styro.fds | **Steel** | **FR-HDPE (compliant)** | Yes | Full compliance |
| 5 | tier1_5_bamboo_FR_no_styro.fds | Bamboo | **FR-HDPE (compliant)** | **No** | Styrofoam effect with FR net |

### TIER 2: Extended Analysis (3 simulations)

| # | File | Scaffolding | Safety Net | Styrofoam | Purpose |
|---|------|-------------|------------|-----------|---------|
| 6 | tier2_5_bamboo_none_styro.fds | Bamboo | **None** | Yes | Total net effect |
| 7 | tier2_6_bamboo_HDPE_styro.fds | Bamboo | **HDPE (cheap)** | Yes | PP vs HDPE |
| 8 | tier2_7_steel_FR_nostyro.fds | Steel | FR-HDPE | **No** | Styrofoam effect with full compliance |

## Fire Source

**Ignition**: Single ignition source at ground level (z=0.0-2.0m)
- HRRPUA: 2500 kW/m²
- Location: 4.0-6.0m (x) × 4.25-5.0m (y)
- Fire spreads naturally through combustible scaffold materials

**No apartment window jets** - Focus is on scaffold material contribution, not apartment fires.

## Material Properties

### Scaffolding Materials
- **Bamboo**: Wet bamboo (40 kg/m³) → Dry (35 kg/m³) → Char (10 kg/m³) + Wood vapor
  - Ignition: 280°C
  - HoC: ~15 MJ/kg
- **Steel**: Inert, non-combustible, high conductivity (heat sink)

### Safety Net Materials
- **PP Tarpaulin** (non-compliant): Ignition 345°C, HoC 46 MJ/kg, burns 12.4 mm/min
- **HDPE** (cheap Chinese std): Ignition 355°C, HoC 43 MJ/kg
- **FR-HDPE** (compliant): Ignition 475°C, burns 0.8 mm/min (15.5× slower!)
- **None**: No netting (baseline)

### Window Sealing
- **Styrofoam**: Polystyrene foam, ignition 350°C, HoC 40 MJ/kg, massive soot
- **No Styrofoam**: Windows closed but not sealed with insulation

## Expected Results

### Material Contributions (Predicted)
Based on forensic analysis and material properties:

| Material | Contribution to Peak HRR | Fire Acceleration |
|----------|-------------------------|-------------------|
| Styrofoam | 45-50% | ~17 min faster |
| PP Tarpaulin | 30-35% | ~13 min faster |
| Bamboo | 20-25% | ~2.5 min faster |

### Key Comparisons

**Bamboo Contribution:**
```
Sim 1 (Bamboo+PP) vs Sim 2 (Steel+PP)
Expected: 15 MW difference, 150s time difference
```

**Netting Compliance:**
```
Sim 1 (PP) vs Sim 3 (FR-HDPE)
Expected: 20 MW difference, 800s time difference (13 minutes!)
```

**Full Compliance:**
```
Sim 1 (Actual) vs Sim 4 (Best case with styrofoam)
Expected: 30 MW difference, 1300s time difference (22 minutes!)
```

**Styrofoam Effect:**
```
Sim 3 (Bamboo+FR+Styro) vs Sim 5 (Bamboo+FR+No Styro)
Sim 4 (Steel+FR+Styro) vs Sim 8 (Steel+FR+No Styro)
Expected: Styrofoam adds 40-50% to peak HRR
```

## Compute Requirements

- **Per simulation**: 45 hours @ 45 cores (c7i.12xlarge)
- **Total sequential**: 8 × 45 = 360 hours = 15 days
- **Parallel (8 instances)**: ~48 hours elapsed time
- **Cost estimate**: $2,300-3,500 USD (spot instances)

## Running on AWS

### Launch Script

```bash
./launch_aws.sh --key-path ~/.ssh/fds-key-pair tier1_*.fds tier2_*.fds
```

The script will:
1. Create VPC and security groups
2. Launch EC2 spot instances (c7i.12xlarge)
3. Install FDS via cloud-init
4. Upload FDS files
5. Start simulations with 45 MPI processes

### Manual Execution

Instance 1: `mpiexec -n 45 fds tier1_1_bamboo_PP_styro.fds`
Instance 2: `mpiexec -n 45 fds tier1_2_steel_PP_styro.fds`
Instance 3: `mpiexec -n 45 fds tier1_3_bamboo_FR_styro.fds`
Instance 4: `mpiexec -n 45 fds tier1_4_steel_FR_styro.fds`
Instance 5: `mpiexec -n 45 fds tier1_5_bamboo_FR_no_styro.fds`
Instance 6: `mpiexec -n 45 fds tier2_5_bamboo_none_styro.fds`
Instance 7: `mpiexec -n 45 fds tier2_6_bamboo_HDPE_styro.fds`
Instance 8: `mpiexec -n 45 fds tier2_7_steel_FR_nostyro.fds`

## Output Files

Each simulation produces:
- `*.out` - Text output log
- `*.smv` - Smokeview metadata
- `*_hrr.csv` - Heat Release Rate data
- `*_steps.csv` - Time step data
- `*.s3d` - 3D slice visualization
- `*.sf` - Surface data

## Analysis

### Primary Metrics
1. **Peak HRR** (MW) - Fire intensity
2. **Time to Floor 30** (s) - Spread rate
3. **Total heat released** (GJ) - Fuel contribution

### Comparison Method
```python
bamboo_contribution = (Sim1_HRR - Sim2_HRR) / Sim1_HRR * 100
netting_compliance = (Sim1_time - Sim3_time)  # Extra evacuation time
styrofoam_effect = (Sim3_HRR - Sim5_HRR) / Sim3_HRR * 100
```

## Policy Implications

### Question 1: Should Hong Kong ban bamboo scaffolding?
**Analysis**: Compare Sim 1 vs Sim 2

### Question 2: Was non-compliant netting the main problem?
**Analysis**: Compare Sim 1 vs Sim 3

### Question 3: Could compliance have prevented deaths?
**Analysis**: Compare Sim 1 vs Sim 4

### Question 4: Was styrofoam the biggest culprit?
**Analysis**: Compare Sim 3 vs Sim 5, and Sim 4 vs Sim 8

## References

- FDS Version: 6.10.1
- Grid: 630,000 cells (20cm resolution)
- Domain: 10m × 5.6m × 90m (31 floors)
- Turbulence: VLES (Deardorff + WALE)
- Radiation: 35% radiative fraction
- MPI processes: 45

## Misc

For questions about this parametric study, refer to:
- FDS User Guide: https://pages.nist.gov/fds-smv/
- [Wang Fuk Court incident reports](https://github.com/Hong-Kong-Emergency-Coordination-Hub/Hong-Kong-Fire-Documentary) (November 2025)
