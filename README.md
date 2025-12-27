# Long-term Monitoring of Damage Progression

This repository provides a research-oriented implementation for long-term monitoring of surface damage progression on bridges using temporal UAV images.
The workflow integrates hierarchical localization, structure-from-motion (SfM), and YOLOv8-based damage segmentation to enable consistent damage identification and tracking across different inspection times.


## Overview

The proposed framework aims to localize and quantify surface damage progression by aligning UAV images captured at different times into a common spatial reference.
The key components of the pipeline are:

1. YOLOv8-based damage segmentation for identifying surface damage regions such as cracks, spalling, and water leakage
2. COLMAP-based SfM for geometric reconstruction and spatial consistency
3. Hierarchical localization (hloc) for robust camera pose estimation under appearance changes

This repository focuses on providing code, configuration files, and representative sample images.

## Repository Structure

```
Long-term-monitoring-of-damage-progression/
│
├─ Images/
│   ├─ Query_1/
│   ├─ Query_2/
│   ├─ Query_3/
│   ├─ Query_4/
│   └─ Reference/
│
├─ Instance_segmentation/
│   ├─ train_seg.py
│   └─ data/data.yaml
│
└─ README.md
```

- **Images/**: Representative UAV images acquired from routine inspections  
- **Instance_segmentation/**: YOLOv8-based damage segmentation scripts  

Due to repository size limitations, only representative sample images are included.  
The full dataset will be provided after further discussion.




Damage Segmentation (YOLOv8)

Damage regions are identified using a YOLOv8-based segmentation model, trained to detect multiple damage types commonly observed on concrete bridge surfaces.

Model: YOLOv8-seg

Damage types: crack, spalling, water leakage

Output: pixel-wise segmentation masks

🔗 YOLOv8 (Ultralytics)
https://github.com/ultralytics/ultralytics

Hierarchical Localization

To achieve robust camera pose estimation across long-term inspections with significant appearance changes, hierarchical localization (hloc) is employed.

The pipeline combines:

Global image retrieval

Local feature matching

Geometric verification

This enables reliable localization even under varying illumination, viewpoint, and surface conditions.

🔗 Hierarchical Localization (hloc)
https://github.com/cvg/Hierarchical-Localization

Structure-from-Motion (COLMAP)

COLMAP is used to reconstruct the 3D geometry of the bridge and to maintain spatial consistency between images captured at different times.

The reconstructed SfM model provides:

Camera poses

Sparse point clouds

A shared reference frame for damage comparison

🔗 COLMAP
https://github.com/colmap/colmap

Dataset Availability

The UAV images used in this study were captured from an operational prestressed concrete girder bridge at multiple inspection times.
Only representative samples are included in this repository.
