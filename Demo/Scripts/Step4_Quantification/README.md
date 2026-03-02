# Step 4: Quantification

# Overview

This step quantitatively estimates the damage area from each query image using depth information and camera parameters.

For each damage mask, pixel-wise depth values are used to estimate the local surface geometry.
The physical area corresponding to each damaged pixel is computed and summed to obtain the total damage area.


# 📊 Quantitative Results (Water Leakage)
The following table compares the results from this GitHub demo against the original paper's results to demonstrate the pipeline's robustness.

<div align="center">
  
<table>
<p align="center">
  <img src="result2.png" width="600">
</p>


<table>
<thead>
<tr>
<th rowspan="2">Damage type</th>
<th rowspan="2">Image set</th>
<th colspan="3">Damage area (cm²)</th>
</tr>
<tr>
<th>GitHub repository


</th>
<th>Original paper


</th>
<th>Reference</th>
</tr>
</thead>
<tbody>
<tr>
<td rowspan="4" align="center"><b>Water leakage</b></td>
<td align="center">Query #1</td>
<td align="center">942.92


(1.18%)</td>
<td align="center">943.87


(1.29%)</td>
<td align="center">931.89</td>
</tr>
<tr>
<td align="center">Query #2</td>
<td align="center">1321.56


(-3.70%)</td>
<td align="center">1338.35


(-2.47%)</td>
<td align="center">1372.30</td>
</tr>
<tr>
<td align="center">Query #3</td>
<td align="center">4153.62


(-0.58%)</td>
<td align="center">4149.65


(-0.67%)</td>
<td align="center">4177.84</td>
</tr>
<tr>
<td align="center">Query #4</td>
<td align="center">16671.72


(4.12%)</td>
<td align="center">16695.23


(4.26%)</td>
<td align="center">16012.65</td>
</tr>
</tbody>
</table>

</div>

⚠️ Technical Note on RANSAC Variability:
Please note that minor discrepancies (at the decimal level) between the "GitHub repository" and "Original paper" results may occur. This is due to the stochastic nature of the RANSAC (Random Sample Consensus) algorithm used during the Plane Fitting process for damage quantification. While the overall precision remains high, these randomized iterations can lead to slight variations in each run.


# Dependency

The authors used the following environment:

- MATLAB R2024b

# Method

```matlab
run("Scripts\Step4_Quantification\Step4.m")
```

This script performs the following operations:
- reads damage masks for each query image
- estimates a plane of each damage mask using depth values and RANSAC
- converts damaged pixels to physical area using camera intrinsics and scale factors
- computes the total damage area for each image
