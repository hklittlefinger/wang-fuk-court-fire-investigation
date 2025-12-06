# Wang Fuk Fire - Parametric Study

<p align="center">
  <em>"He would see this country burn if he could be king of the ashes"</em>
  <br>
  — Lord Varys
</p>

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
| 4 | tier1_4_steel_FR_styro.fds | **Steel** | **FR-HDPE (compliant)** | Yes | Full compliance with styrofoam |
| 5 | tier1_5_bamboo_FR_no_styro.fds | Bamboo | **FR-HDPE (compliant)** | **No** | Styrofoam effect with FR net |

### TIER 2: Extended Analysis (3 simulations)

| # | File | Scaffolding | Safety Net | Styrofoam | Purpose |
|---|------|-------------|------------|-----------|---------|
| 6 | tier2_1_bamboo_none_styro.fds | Bamboo | **None** | Yes | Total net effect |
| 7 | tier2_2_bamboo_HDPE_styro.fds | Bamboo | **HDPE (cheap)** | Yes | PP vs HDPE |
| 8 | tier2_3_steel_FR_nostyro.fds | Steel | FR-HDPE | **No** | Styrofoam effect with full compliance |

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

## Running on AWS

### Custom AMI

Simulations use a pre-built AMI with:
- **FDS 6.10.1** with HYPRE v2.32.0 and Sundials v6.7.0 (statically linked)
- **Intel oneAPI** (MPI, compilers, math libraries)
- FDS binary: `/opt/fds/bin/fds`
- Environment setup: `source /opt/intel/oneapi/setvars.sh`

The AMI is available in multiple regions (eu-north-1, eu-south-1, eu-south-2, ap-northeast-1, ap-southeast-3).

### Launch Script

```bash
# Basic launch
./launch_aws.sh --key-path ~/.ssh/fds-key-pair tier1_*.fds tier2_*.fds

# Fresh start (delete existing S3 output)
./launch_aws.sh --key-path ~/.ssh/fds-key-pair --clean tier1_1.fds

# Larger disk for big simulations
./launch_aws.sh --key-path ~/.ssh/fds-key-pair --volume-size 200 tier1_1.fds
```

The script will:
1. Find cheapest region with available spot capacity
2. Auto-detect custom FDS AMI in the selected region
3. Create VPC, security groups, and S3 Gateway endpoint
4. Launch EC2 spot instance (c7i.12xlarge, 48 vCPUs, 100GB disk)
5. Upload FDS file and start simulation in tmux
6. **Resume from checkpoint** if restart files exist in S3 (unless `--clean`)
7. Track instance info in SQLite database (`instances.db`)
8. Sync outputs to S3 bucket (`fds-output-wang-fuk-fire`)

### Monitor Status

```bash
./check_status.sh --key-path ~/.ssh/fds-key-pair --watch --interval 60
```

### Manual Execution (on EC2 instance)

#### SSH into the instance
```bash
ssh -i ~/.ssh/fds-key-pair ubuntu@<INSTANCE_IP>
```

#### Start a fresh simulation
```bash
# Load Intel environment (required once per session)
source /opt/intel/oneapi/setvars.sh

# Navigate to work directory
cd ~/fds-work/<CHID>

# Count meshes in FDS file
NUM_MESHES=$(grep -c '&MESH' <simulation>.fds)

# Run in tmux (persists after SSH disconnect)
tmux new-session -d -s fds_run "source /opt/intel/oneapi/setvars.sh && mpiexec -n $NUM_MESHES /opt/fds/bin/fds <simulation>.fds"
```

#### Resume from a restart file
```bash
# Edit FDS file to enable restart mode
sed -i 's/^&MISC /&MISC RESTART=.TRUE., /' <simulation>.fds

# Start simulation (reads the latest *.restart file automatically)
tmux new-session -d -s fds_run "source /opt/intel/oneapi/setvars.sh && mpiexec -n $NUM_MESHES /opt/fds/bin/fds <simulation>.fds"
```

#### Monitor progress
```bash
# Attach to running tmux session (Ctrl+B, D to detach)
tmux attach -t fds_run

# Check simulation progress
tail -f ~/fds-work/<CHID>/<CHID>.out

# Check current simulation time
grep "Time Step" ~/fds-work/<CHID>/<CHID>.out | tail -5

# Check for errors
grep -i "error\|warning\|instability" ~/fds-work/<CHID>/<CHID>.out
```

## Output Files

Each simulation produces:

### Core Files
- `*.out` - Text output log (solver diagnostics, timing, errors)
- `*.smv` - Smokeview visualization metadata
- `*.restart` - Checkpoint files for resuming simulations (every 300s)

### CSV Data
- `*_hrr.csv` - Heat Release Rate time series
- `*_steps.csv` - Time step statistics (CFL, pressure iterations)
- `*_devc.csv` - Device measurements (AST temperatures, gas temperatures)

### Visualization Files
- `*.sf` - Slice files (temperature, velocity, HRRPUV cross-sections)
- `*.bf` - Boundary files (wall temperature, convective/radiative heat flux)
- `*.prt5` - Particle data (falling debris trajectories)
- `*.s3d` - 3D smoke visualization data

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

## Technical Background

### Incident Facts

The Wang Fuk Court fire occurred on November 26, 2025 at ~14:51 HKT in Tai Po District, Hong Kong. Key factors from news reports:

- **Building:** 8 blocks of 31-storey towers (~90m height), opened 1983
- **Casualties:** 159+ deaths
- **Weather:** Red Fire Danger Warning in effect (issued Nov 24); 23°C, 42% RH, NW wind ~16 km/h ([timeanddate.com](https://www.timeanddate.com/weather/hong-kong/hong-kong/historic?month=11&year=2025))
- **Fire spread:** Rapid vertical spread via chimney effect in scaffold cavity; escalated to 5-alarm fire within 4 hours
- **Investigation:** Seven scaffolding net samples failed fire retardant testing; fire alarms failed to operate properly

Sources: [Al Jazeera](https://www.aljazeera.com/news/2025/11/27/hong-kongs-deadliest-fire-in-63-years-what-we-know-and-how-it-spread), [SCMP](https://multimedia.scmp.com/infographics/news/hong-kong/article/3334304/taipo_wangfuk_fire/index.html), [HK01](https://www.hk01.com/%E7%AA%81%E7%99%BC/60297831), [Wikipedia](https://en.wikipedia.org/wiki/Wang_Fuk_Court_fire)

### Why Model Only the Scaffold Facade?

The scaffold facade modeling approach isolates the **material contribution question** from confounding variables. This follows principles similar to [BS 8414](https://www.designingbuildings.co.uk/wiki/BS_8414_Fire_performance_of_external_cladding_systems) facade fire tests:

- **Chimney effect:** The gap between scaffolding and building exterior creates a vertical channel accelerating upward flame spread (3-6× faster than open fires per [facade fire research](https://www.sciencedirect.com/science/article/abs/pii/S2352710221011153))
- **Isolated variables:** Directly attribute heat release to specific materials (bamboo vs steel, PP vs FR-HDPE, styrofoam vs none)

### Porous Scaffolding Geometry

The model implements a **3D porous scaffolding** approach with discrete structural elements:

| Layer | Y-Position | Thickness | Description |
|-------|-----------|-----------|-------------|
| Safety Net | 4.05-4.25m | 0.2m | Continuous PP tarpaulin layer |
| Outer Bamboo Row | 4.25-4.45m | 0.2m | Discrete vertical poles (5 per 10m span) |
| *Air Cavity* | 4.45-4.65m | 0.2m | Primary chimney channel |
| Inner Bamboo Row | 4.65-4.85m | 0.2m | Discrete vertical poles |
| *Air Gap* | 4.85-5.00m | 0.15m | Secondary convection path |
| Styrofoam | 5.00-5.05m | 0.05m | Window sealant (at window locations only) |
| Building Wall | 5.05-5.25m | 0.2m | Concrete substrate |

Horizontal ledgers connect the bamboo rows every ~3m vertically, creating a realistic scaffold structure.

**Why this geometry matters:**
- **Chimney effect:** The air cavities between layers allow hot gases to accelerate upwards, pre-heating fuel above and driving rapid vertical fire spread
- **Fuel surface area:** Discrete bamboo poles have higher surface-area-to-volume ratio than solid sheets, enabling realistic pyrolysis rates
- **Airflow paths:** Gaps between poles permit horizontal cross-ventilation while maintaining vertical draft

### Mesh Resolution Justification

The 20cm cell size is based on the [characteristic fire diameter (D*)](https://fdstutorial.com/fds-mesh-size-calculator/):

**D* formula:** D* = (Q / (ρ∞ × cp × T∞ × √g))^(2/5)

| Parameter | Value |
|-----------|-------|
| HRRPUA | 2500 kW/m² over 1.5m² = 3.75 MW |
| D* | ≈1.5m |
| Cell size (dx) | 0.2m |
| **D*/dx** | **≈7.5** (medium resolution) |

The [FDS User Guide](https://pages.nist.gov/fds-smv/) recommends D*/dx of 4 (coarse), 10 (medium), or 16 (fine). Our 7.5 ratio provides adequate resolution while maintaining computational feasibility.

### Pressure Solver: UGLMAT HYPRE

The complex porous bamboo geometry requires `SOLVER='UGLMAT HYPRE'`:

- **U (Unstructured):** Solves pressure only in gas phase, eliminating velocity leakage through thin obstructions
- **G (Global):** Solves pressure globally across all meshes, ensuring accurate vertical pressure gradients for chimney flow
- **HYPRE:** Efficient multigrid library managing memory for large problems

### Bamboo Combustion Model

Bamboo pyrolysis uses a two-step reaction scheme based on [lignocellulosic combustion research](https://www.sciencedirect.com/science/article/abs/pii/S0379711220301375):

1. **Drying:** Wet bamboo (40 kg/m³, ~12% moisture) → Dry bamboo (35 kg/m³) + Water vapor
2. **Pyrolysis:** Dry bamboo → Char (10 kg/m³) + Combustible gases (280-400°C)

| Property | Value | Source |
|----------|-------|--------|
| Ignition temperature | 280-386°C | [Pope et al.](https://www.researchgate.net/profile/Ian-Pope-5/publication/356838161_Fire_safety_design_tools_for_laminated_bamboo_buildings/links/627a1ac32f9ccf58eb3c30e8/Fire-safety-design-tools-for-laminated-bamboo-buildings.pdf) |
| Heat of combustion | 15-23 MJ/kg | [Bio-char research](https://www.sciencedirect.com/science/article/abs/pii/S036054422404091X) |
| Pyrolysis range | 257-400°C | [TGA studies](https://www.mdpi.com/2227-9717/12/11/2458) |

Vertical bamboo pole orientation allows fire to spread "without any resistance" ([HK PolyU](https://theconversation.com/why-is-bamboo-used-for-scaffolding-in-hong-kong-a-construction-expert-explains-270780)).

### Safety Net Materials

#### Polypropylene (PP) - Non-Compliant

PP tarpaulins are the primary fire hazard. Properties from [fire hazard research](https://link.springer.com/chapter/10.1007/978-94-011-4421-6_34):

| Property | Value |
|----------|-------|
| Density | 900 kg/m³ |
| Specific heat | 1.9 kJ/kg·K |
| Thermal conductivity | 0.22 W/m·K |
| Ignition | 345°C (melts 130-160°C) |
| Heat of combustion | 46 MJ/kg |
| Burn rate | 12.4 mm/min |

[Melting and dripping behavior](https://www.cuspuk.com/fire-safety/plastic-fire-risks/) spreads fire unpredictably, forming pool fires at base.

#### FR-HDPE - Compliant

[Flame retardant HDPE](https://www.globalplasticsheeting.com/our-blog-resource-library/fire-retardant-woven-hdpe-the-ultimate-guide) incorporates fire-retardant additives:

| Property | Value |
|----------|-------|
| Ignition | ~475°C |
| Burn rate | 0.8 mm/min (**15.5× slower than PP**) |
| Classification | Should meet [EN 13501-1](https://measurlabs.com/blog/en-13501-1-fire-classification-performance-classes-and-criteria/) Class E |

### Polystyrene (EPS) Window Sealing

EPS foam used to seal windows. From [combustion research](https://pmc.ncbi.nlm.nih.gov/articles/PMC10884846/):

| Property | Value |
|----------|-------|
| Density | 25 kg/m³ (98% air) |
| Specific heat | 1.3 kJ/kg·K |
| Thermal conductivity | 0.03 W/m·K |
| Ignition | 346-360°C |
| Peak HRR | 493.9 kW/m² |
| Heat of combustion | 40 MJ/kg |

Combustion products include CO, monostyrene, hydrogen bromide, and aromatic compounds.

### Stability Controls (Strip Model)

| Parameter | Setting | Purpose |
|-----------|---------|---------|
| CFL_MAX | 1.0 | Convective stability (v×Δt/Δx < 1) |
| VN_MAX | 0.5 | Diffusive stability (α×Δt/Δx² < 0.5) |
| CHECK_VN | .TRUE. | Enable Von Neumann checking for pyrolysis |
| Ignition ramp | 0→50%→100% over 60s, then off at 180s | Gradual ignition to prevent pressure spikes |

### Regulatory Context

Hong Kong scaffolding regulations require:
- [Code of Practice for Bamboo Scaffolding Safety](https://www.labour.gov.hk/eng/public/os/B/Bamboo.pdf) (Labour Department)
- [Cap. 59I Construction Sites (Safety) Regulations](https://www.elegislation.gov.hk/hk/cap59I)
- Protective nets must have "appropriate fire retardant properties"

Post-incident: Materials at Wang Fuk Court "burned much more intensely and spread significantly faster than materials that meet safety standards" ([Security Bureau](https://www.cnn.com/2025/11/27/world/bamboo-scaffolding-scrutiny-hong-kong-fire-intl-hnk)).

## Simulation Parameters (Strip Model)

| Parameter | Value | Justification |
|-----------|-------|---------------|
| FDS Version | 6.10.1 | [Official release](https://github.com/firemodels/fds/releases/tag/FDS-6.10.1) (March 2025) |
| Grid cells | 225,000 | 20cm resolution, D*/dx ≈ 7.5 |
| Domain | 10m × 5.6m × 30m | Single facade, 1/3 height validation |
| Pressure solver | UGLMAT HYPRE | Complex porous geometry |
| Turbulence | Deardorff (default) | Standard LES for fire plumes |
| Radiation | 40% radiative fraction | Typical for diffusion flames |
| MPI processes | 15 | One per mesh |

## References

### Fire Dynamics Simulator
- [FDS-SMV Official Site](https://pages.nist.gov/fds-smv/) - NIST
- [FDS GitHub Repository](https://github.com/firemodels/fds)
- [FDS Mesh Size Calculator](https://fdstutorial.com/fds-mesh-size-calculator/)
- [FDS Mesh Resolution Guide](https://cloudhpc.cloud/2022/10/12/fds-mesh-resolution-how-to-properly-calculate-fds-mesh-size/)

### Bamboo Fire Properties
- [Fire growth for bamboo structures](https://www.sciencedirect.com/science/article/abs/pii/S0379711220301375) - Fire Safety Journal
- [Fire safety design for laminated bamboo](https://www.researchgate.net/profile/Ian-Pope-5/publication/356838161_Fire_safety_design_tools_for_laminated_bamboo_buildings/links/627a1ac32f9ccf58eb3c30e8/Fire-safety-design-tools-for-laminated-bamboo-buildings.pdf) - Pope et al.
- [Pyrolysis kinetics of bamboo](https://www.mdpi.com/2227-9717/12/11/2458) - MDPI Processes

### Polymer Combustion
- [Flame Retardant Polypropylenes](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7464193/) - PMC
- [Fire hazard with polypropylene](https://link.springer.com/chapter/10.1007/978-94-011-4421-6_34) - Springer
- [FR-HDPE Guide](https://www.globalplasticsheeting.com/our-blog-resource-library/fire-retardant-woven-hdpe-the-ultimate-guide)

### Polystyrene Fire Hazards
- [Fire exposed EPS insulation](https://pmc.ncbi.nlm.nih.gov/articles/PMC10884846/) - PMC
- [Polystyrene exterior wall insulation combustion](https://onlinelibrary.wiley.com/doi/10.1002/app.53503) - Wiley

### Facade Fire Testing
- [BS 8414 Fire performance](https://www.designingbuildings.co.uk/wiki/BS_8414_Fire_performance_of_external_cladding_systems) - Designing Buildings
- [EN 13501-1 Fire Classification](https://measurlabs.com/blog/en-13501-1-fire-classification-performance-classes-and-criteria/) - Measurlabs

### Hong Kong Regulations
- [Bamboo Scaffolding Safety Code](https://www.labour.gov.hk/eng/public/os/B/Bamboo.pdf) - Labour Department
- [Construction Sites Regulations Cap. 59I](https://www.elegislation.gov.hk/hk/cap59I) - HK e-Legislation
- [Fire Safety at Construction Sites](https://www.cic.hk/files/page/52/Fire%20Safety%20-%20Enhance%20Fire%20Safety%20Measures%20at%20Construction%20Sites%20-%20Safety%20Message%20No.%20024-25%20(Oct%202025).pdf) - CIC

### Wang Fuk Court Incident
- [Al Jazeera: Bamboo scaffolding analysis](https://www.aljazeera.com/news/2025/11/27/what-is-bamboo-scaffolding-and-how-did-it-worsen-the-hong-kong-fire)
- [The Conversation: Expert explains](https://theconversation.com/why-is-bamboo-used-for-scaffolding-in-hong-kong-a-construction-expert-explains-270780)
- [CNN: Scrutiny after fire](https://www.cnn.com/2025/11/27/world/bamboo-scaffolding-scrutiny-hong-kong-fire-intl-hnk)
- [Fire Engineering](https://www.fireengineering.com/fire-safety/hong-kong-fire-raises-questions-about-bamboo-scaffolding/)
