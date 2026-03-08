# Step 2: Similarity Index

# Overview

This step identifies the most relevant reference image for each query image that contains detected damage.

Only query images with detected damage regions are considered.  
For each such query image, all damage-mask pixels are projected into the coordinate systems of all reference images using the estimated camera parameters and depth maps.  
The reference image that receives the largest number of valid projected pixels is selected as the most similar viewpoint and paired with the query image.

This process enables robust association between query images and reference images captured from similar viewpoints, even under variations in camera position and inspection time.

# Dependency

The authors used the following environment:

- MATLAB R2024b

# Method

1. Add all subfolders under the `Demo` directory to the MATLAB path so that all helper functions can be accessed.

2. Load the pre-saved workspace (recommended for the demo)
Due to repository size limitations, large reconstruction outputs (e.g., depth maps and dense SfM results) are not included in this demo.
Instead, the required variables are provided as a pre-saved MATLAB workspace file.

Load the workspace file as follows:
```matlab
load("Scripts\Step1_CameraPoseRstimation\Data\Workspace\workspace.mat")
```
This file includes the required variables for Step 2, such as:

- camera intrinsic parameters
- camera extrinsic parameters
- depthmaps

3. Run Step2.m to compute the similarity index and generate query–reference pairs.

```matlab
run("Scripts\Step2_SimilarityIndex\Step2.m")
```

What Step2.m does:
- extracts GNSS metadata from images and computes the physical scale (scale conversion factor, SCF) by aligning camera optical centers with GNSS coordinates using the Procrustes method.
 
* **Note:** The file `out_of_bridge.txt` in the `Step2_SimilarityIndex` folder contains images manually identified during the initial inspection as being captured from the outer boundary of the bridge. Only these images are used for the Procrustes alignment because their GNSS measurements are more reliable.

- reads damage masks for query images
- projects damaged pixels from each query into all reference images
- counts valid projected pixels per reference image
- selects the reference image with the maximum count
- writes the best match as a query–reference pair

---

## (Optional) Rebuild the workspace from raw reconstruction outputs

The following steps are required only when reproducing the pipeline from scratch using the full reconstruction data from Step 1.

First, replace the images.txt file exported in Step 1 by extracting and reformatting the image header information:

```matlab
extractImageHeader( ...
    "Scripts\Step1_CameraPoseEstimation\Data\Routine_inspection4_data\images.txt", ...
    "Scripts\Step1_CameraPoseEstimation\Data\Routine_inspection4_data\images.txt")
```
Then, load camera intrinsic parameters, camera extrinsic parameters, and depth maps into the MATLAB workspace:

```matlab
saveDepthMaps("path_to_depthmaps", "Depthmaps")
saveCameraIntrinsics("updated_extrinsics_txt_path", "Depthmaps", "CameraIntParams")
saveCameraExtrinsics("CameraExtParams", "updated_extrinsics_txt_path")
```

Example used in this study:

```matlab
saveDepthMaps( ...
    "Scripts\Step1_CameraPoseEstimation\Data\Routine_inspection4_data\SfM\Dense\stereo\depth_maps", ...
    "Depthmaps")

saveCameraIntrinsics( ...
    "Scripts\Step1_CameraPoseEstimation\Data\Routine_inspection4_data\images.txt", ...
    "Scripts\Step1_CameraPoseEstimation\Data\Routine_inspection4_data\cameras.txt", ...
    "Depthmaps", ...
    "CameraIntParams")

saveCameraExtrinsics( ...
    "CameraExtParams", ...
    "Scripts\Step1_CameraPoseEstimation\Data\Routine_inspection4_data\images.txt")
```
