clc;
gamma = 1.0; 
numMasks = numel(globalMasks);
results = struct('FileName', {}, 'DamageArea_cm2', {});

for k = 1:numMasks
    qFile = globalMasks(k).filename;
    [~, qBase] = fileparts(qFile);
    
    K_names = lower(string({CameraIntParams.image_name}));
    dm_names = lower(string({Depthmaps.FileName}));
    
    Kq = CameraIntParams(K_names == lower(qFile));
    idxDq = find(contains(dm_names, lower(qBase)), 1);
    
    if isempty(idxDq) || isempty(Kq)
        continue; 
    end
    
    Dq_orig = Depthmaps(idxDq).DepthMap;
    [D_h, D_w] = size(Dq_orig);
    currMask = imresize(globalMasks(k).mask, [D_h, D_w], 'nearest') > 0;
    
    [vM, uM] = find(currMask);
    if isempty(vM), continue; end
    
    zM_raw = Dq_orig(sub2ind([D_h, D_w], vM, uM));
    validIdx = isfinite(zM_raw) & zM_raw > 0;
    
    if sum(validIdx) > 3
        pts_c = [uM(validIdx), vM(validIdx), zM_raw(validIdx)];
        [model, ~] = ransacfitplane_step4(pts_c', 0.05);
        
        if ~isempty(model)
            a = model(1); b = model(2); c = model(3); d = model(4);
            s_hat = (-a*uM - b*vM - d) / c;
            
            delta_X = (gamma * s_hat / Kq.fx);
            delta_Y = (gamma * s_hat / Kq.fy);
            SCF = 292.0689; 
            area_multiplier = (SCF / 10)^2;
            
            pixel_areas = abs(delta_X .* delta_Y);
            total_area_m2 = sum(pixel_areas) * area_multiplier;
            
            total_area_cm2 = total_area_m2 * 100;
        else
            total_area_cm2 = 0;
        end
    else
        total_area_cm2 = 0;
    end
    
    results(k).FileName = qFile;
    results(k).DamageArea_cm2 = total_area_cm2;
    
    fprintf('[%d/%d] %s: %.6f (cm^2)\n', k, numMasks, qFile, total_area_cm2);
end

areaValues = [results.DamageArea_cm2];
fileLabels = {results.FileName};

figure('Color', 'w', 'Name', 'Damage Area Quantification (cm^2)');
b = bar(areaValues, 'FaceColor', [0.75 0.15 0.15]);
grid on;
ylabel('Damage Area (cm^2)', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Image Index', 'FontSize', 12, 'FontWeight', 'bold');
title('Quantified Damage Area in cm^2', 'FontSize', 14);

xtips = b.XEndPoints;
ytips = b.YEndPoints;
labels = compose("%.6f", areaValues);
text(xtips, ytips, labels, 'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'bottom', 'FontSize', 9, 'FontWeight', 'bold');

set(gca, 'XTick', 1:numMasks, 'XTickLabel', fileLabels, 'XTickLabelRotation', 45);

function [model, inliers] = ransacfitplane_step4(pts, threshold)
    numPts = size(pts, 2);
    bestInliers = [];
    model = [];
    for i = 1:200
        idx = randperm(numPts, 3);
        p1 = pts(:,idx(1)); p2 = pts(:,idx(2)); p3 = pts(:,idx(3));
        n = cross(p2-p1, p3-p1);
        if norm(n) < eps, continue; end
        n = n / norm(n);
        d = -dot(n, p1);
        dist = abs(n' * pts + d);
        inliers = find(dist < threshold);
        if length(inliers) > length(bestInliers)
            bestInliers = inliers;
            model = [n; d];
        end
    end
end