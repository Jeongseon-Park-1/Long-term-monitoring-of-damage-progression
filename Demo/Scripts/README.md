# Demo: Reproducible Damage Quantification Pipeline


This folder provides a minimal, reproducible demo of the proposed damage
localization and quantification pipeline used in the paper.

The demo is organized as a step-by-step workflow, from camera pose estimation
to similarity-based image pairing and damage quantification.

---

# ⚠️ Quick Start (Recommended) ⚠️

This demo already includes all intermediate results required for Step 2 and later.
If the goal is to reproduce the qualitative and quantification results,
           
            
```
                                     you can skip Step 1 and start directly from Step 2.
```

# Requirements

- MATLAB R2024b

# Folder Structure

```
Demo/
 ├─ Scripts/
 │   ├─ Step1_CameraPoseEstimation/
 │   ├─ Step2_SimilarityIndex/
 │   ├─ Step3_Visualization/
 │   └─ Step4_Quantification/
```

# Step Overview

Step 1: Camera Pose Estimation

- Registers reference and query images using hloc and COLMAP
- Estimates camera intrinsics, extrinsics, and depth maps

📁 Scripts/Step1_CameraPoseEstimation/

Step 2: Similarity Index

- Projects damaged pixels from query images into all reference images
- Selects the reference image with the largest number of valid projections
- Generates query–reference image pairs

📁 Scripts/Step2_SimilarityIndex/

Step 3: Visualization

- Visualizes projected damage regions on the selected reference images

📁 Scripts/Step3_Visualization/

Step 4: Quantification

- Estimates damage area and geometric metrics in 3D
- Uses depth maps and plane fitting for metric quantification

📁 Scripts/Step4_Quantification/

# Notes

- All image data and large intermediate files are tracked using Git LFS.
- The demo dataset is a representative subset used only for demonstration.
- File paths in the scripts are relative to the Demo directory.



