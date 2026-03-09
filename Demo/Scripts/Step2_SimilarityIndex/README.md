# Step 2: Similarity Index

# Overview

<p align="justify">

This step identifies the most relevant reference image for each query image containing detected damage.

Only query images with detected damage are considered. For each query image, all pixels are projected onto the coordinate systems of the reference images using the estimated camera parameters and depth maps. The reference image receiving the largest number of valid projected pixels is selected as the most similar viewpoint.

This process establishes a robust association between query and reference images captured from similar viewpoints, even under variations in camera position and inspection time.

</p>

# Dependency

The authors used the following environment:

- MATLAB R2024b

# Method

## (Option 1) Load the pre-saved workspace (recommended for the demo)

1. Add all subfolders under the `Demo` directory to the MATLAB path so that all helper functions can be accessed.

2. Load the pre-saved workspace (recommended for the demo)
Due to repository size limitations, large reconstruction outputs (e.g., depth maps and dense SfM results) are not included in this demo.
Instead, the required variables are provided as a pre-saved MATLAB workspace file.

Load the workspace file as follows:
```matlab
load("Scripts\Step1_CameraPoseEstimation\Data\Workspace\workspace.mat")
```
This file includes the required variables for Step 2, such as:

- Camera intrinsic parameters
- Camera extrinsic parameters
- Depthmaps

3. Run Step2.m to compute the similarity index and generate query–reference pairs.

```matlab
run("Scripts\Step2_SimilarityIndex\Step2.m")
```

What Step2.m does:
- Extracts GNSS metadata from images and computes the physical scale (scale conversion factor, SCF) by aligning camera optical centers with GNSS coordinates using the Procrustes method.
 
* **Note:** The file `out_of_bridge.txt` in the `Step2_SimilarityIndex` folder contains images manually identified during the initial inspection as being captured from the outer boundary of the bridge. Only these images are used for the Procrustes alignment because their GNSS measurements are more reliable.

- Reads damage masks for query images
- Identifies query images listed in `Segmentation_mask/Damage_detected_images.txt` and projects pixels from each of these query images into all reference images
- Counts valid projected pixels per reference image
- Selects the reference image with the maximum count
- Saves the best match as a query–reference pair

---

## (Option 2) Rebuild the workspace from raw reconstruction outputs

The following steps are required only when reproducing the pipeline from scratch using the full reconstruction data from Step 1.

1. replace the images.txt file exported in Step 1 by extracting and reformatting the image header information:

```matlab
extractImageHeader( ...
    "Scripts\Step1_CameraPoseEstimation\Data_option2\Routine_inspection4_data\images.txt", ...
    "Scripts\Step1_CameraPoseEstimation\Data_option2\Routine_inspection4_data\images.txt")
```
2. load camera intrinsic parameters, camera extrinsic parameters, and depth maps into the MATLAB workspace:

```matlab
saveDepthMapFileList("path_to_depthmaps", "Depthmaps")
saveCameraIntrinsics("updated_extrinsics_txt_path","intrinsics_txt_path", "Depthmaps", "CameraIntParams")
saveCameraExtrinsics("CameraExtParams", "updated_extrinsics_txt_path")
```

Example used in this study:

```matlab
saveDepthMapFileList( ...
    "Scripts\Step1_CameraPoseEstimation\Data_option1\Depthmaps", ...
    "Depthmaps")

saveCameraIntrinsics( ...
    "Scripts\Step1_CameraPoseEstimation\Data_option2\Routine_inspection4_data\images.txt", ...
    "Scripts\Step1_CameraPoseEstimation\Data_option2\Routine_inspection4_data\cameras.txt", ...
    "Depthmaps", ...
    "CameraIntParams")

saveCameraExtrinsics( ...
    "CameraExtParams", ...
    "Scripts\Step1_CameraPoseEstimation\Data_option2\Routine_inspection4_data\images.txt")
```
3. After loading these variables into the MATLAB workspace, run Step 2:

```matlab
run("Scripts\Step2_SimilarityIndex\Step2.m")
```

This script computes the similarity index and generates the query–reference image pairs.
