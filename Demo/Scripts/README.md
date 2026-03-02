# Demo: Damage Monitoring Pipeline

> [!IMPORTANT]
> ### 🔍 Authenticity & Reproducibility
> * **Direct Subset of Original Data:** The images and `.mat` files in this demo are **not** separate examples; they are a **representative subset directly extracted from the original datasets** used in our paper (curated from actual routine bridge inspections).
> * **Identical Results:** All results generated through this demo are **fully identical** to the specific cases presented in the paper. This confirms that the proposed quantification pipeline maintains its integrity even when running on this lightweight version of the data.
> * **Storage Efficiency:** While the original study utilized **2,509 images**, this folder provides **29 images** to allow for immediate verification without high storage requirements.
---

# ⚠️ Quick Start (Recommended) ⚠️

Before running the demo, clone the repository to your local machine:

```
git clone https://github.com/Jeongseon-Park-1/Long-term-monitoring-of-damage-progression.git
```

After cloning the repository, please follow the step-by-step instructions provided in the README.md file of each stage directory.
Each folder contains detailed guidance required to execute the corresponding step of the pipeline.

This demo already includes all intermediate results required for Step 2 and later.
If the goal is to reproduce the qualitative and quantification results,
           
            
```
you can skip Step 1 and start directly from Step 2.
```

# Environment

The authors performed in the following environments:
- OS: Windows 11
- Python: 3.9.13
- CUDA Toolkit: 12.8
- MATLAB: R2024b

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
- File paths in the scripts are relative to the Demo directory.















