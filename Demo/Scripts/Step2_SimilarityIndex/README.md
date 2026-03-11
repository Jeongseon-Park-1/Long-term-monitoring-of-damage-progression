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

1. Add all subfolders under the `Demo` directory to the MATLAB path so that all helper functions can be accessed.

2. Run Step2.m to compute the similarity index and generate query–reference pairs.

```matlab
run("Scripts\Step2_SimilarityIndex\Step2.m")
```

What Step2.m does:
- Extracts GNSS metadata from images and computes the physical scale (scale conversion factor, SCF) by aligning camera optical centers with GNSS coordinates using the Procrustes method.

  **Note:** The file `out_of_bridge.txt` in the `Step2_SimilarityIndex` folder contains images manually identified during the initial inspection as being captured from the outer boundary of the bridge. Only these images are used for the Procrustes alignment because their GNSS measurements are more reliable.

- Reads damage masks for query images
- Identifies query images listed in `Segmentation_mask/Damage_detected_images.txt` and projects pixels from each of these query images into all reference images
- Counts valid projected pixels per reference image
- Selects the reference image with the maximum count
- Saves the best match as a query–reference pair


This script computes the scale conversion factor. Afterwards, similarity index and generates the query–reference image pairs.
