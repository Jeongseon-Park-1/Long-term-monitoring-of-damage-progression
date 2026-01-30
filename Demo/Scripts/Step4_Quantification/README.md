### Step 4: Quantification

## Overview

This step quantitatively estimates the damage area from each query image using depth information and camera parameters.

For each damage mask, pixel-wise depth values are used to estimate the local surface geometry.
The physical area corresponding to each damaged pixel is computed and summed to obtain the total damage area.

## Dependency

The authors used the following environment:

- MATLAB R2024b

## Method

```matlab
run("Scripts\Step4_Quantification\Step4.m")
```

This script performs the following operations:
- reads damage masks for each query image
- estimates a plane of each damage mask using depth values and RANSAC
- converts damaged pixels to physical area using camera intrinsics and scale factors
- computes the total damage area for each image
