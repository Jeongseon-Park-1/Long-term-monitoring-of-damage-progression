# Demo: Damage Monitoring Pipeline

> [!IMPORTANT]
> ### 🔍 Authenticity & Reproducibility
> * **Full Data Utilization:** This repository utilizes the complete dataset of **2,509 images** curated from actual routine bridge inspections, ensuring the robustness and accuracy of the proposed quantification pipeline.
> * **Direct Access to Processed Data:** To support full reproducibility and immediate verification, we provide the estimated camera parameters and Depthmaps:
> * **Analysis Efficiency:** By providing these pre-computed parameters and depth maps, users can verify the 3D geometry and loosening quantification results without re-running the full reconstruction process.
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
If **Option 1** is selected in **Step 1**, you can proceed directly to **Step 2**.
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

- Extracts GNSS information from images and aligns the scale of the SfM model using the Procrustes method
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

- File paths in the scripts are relative to the Demo directory.



















