clc;

gamma = 1.0;

numMasks = numel(globalMasks);
results = struct('FileName', {}, 'RefName', {}, 'DamageArea_cm2', {});

thisDir  = fileparts(mfilename("fullpath"));
demoRoot = fileparts(fileparts(thisDir));

pairPath = fullfile(demoRoot, "Scripts","Step2_SimilarityIndex","Best_Match_Pairs.txt");
fidp = fopen(pairPath, 'r');
if fidp == -1, error("File not found: %s", pairPath); end
pairs = textscan(fidp, '%s %s'); fclose(fidp);

pairQ_raw = string(pairs{1});
pairR_raw = string(pairs{2});
pairQ_l   = lower(pairQ_raw);

K_names  = lower(string({CameraIntParams.image_name}));
dm_names = lower(string({Depthmaps.FileName}));

colorMap = [0.5, 1.0, 0.0;
            1.0, 1.0, 0.0;
            1.0, 0.0, 0.0;
            1.0, 0.0, 0.8];

for k = 1:numMasks
    qFile = string(globalMasks(k).filename);
    qFile_l = lower(qFile);
    [~, qBase] = fileparts(qFile);

    hit = find(pairQ_l == qFile_l, 1);
    if isempty(hit), continue; end
    refForThis = pairR_raw(hit);

    Kq = CameraIntParams(K_names == lower(qFile));
    idxDq = find(contains(dm_names, lower(qBase)), 1);

    if isempty(idxDq) || isempty(Kq), continue; end

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

    results(end+1).FileName = qFile;
    results(end).RefName = refForThis;
    results(end).DamageArea_cm2 = total_area_cm2;

    fprintf('[%d/%d] %s: %.6f (cm^2)\n', k, numMasks, qFile, total_area_cm2);
end

if isempty(results), error("No results generated."); end

refList = string({results.RefName});
uniqR = unique(refList);

for rr = 1:numel(uniqR)
    tr = uniqR(rr);
    idx = find(refList == tr);

    areaValues = [results(idx).DamageArea_cm2];
    fileLabels = string({results(idx).FileName});

    barColors = zeros(numel(fileLabels), 3);
    for i = 1:numel(fileLabels)
        tok = regexp(fileLabels(i), 'squery(\d+)', 'tokens', 'once', 'ignorecase');
        if isempty(tok)
            barColors(i,:) = [0.75 0.15 0.15];
        else
            qn = str2double(tok{1});
            if isfinite(qn) && qn >= 1
                barColors(i,:) = colorMap(mod(qn-1, size(colorMap,1))+1, :);
            else
                barColors(i,:) = [0.75 0.15 0.15];
            end
        end
    end

    figure('Color','w','Name', sprintf("Damage Area (cm^2) | Ref: %s", tr));
    b = bar(areaValues);
    b.FaceColor = 'flat';
    b.CData = barColors;

    grid on;
    ylabel('Damage Area (cm^2)', 'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'none');
    xlabel('Query Image', 'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'none');
    title(sprintf('Quantified Damage Area (Ref: %s)', tr), 'FontSize', 14, 'Interpreter', 'none');

    xticks(1:numel(areaValues));
    xticklabels(fileLabels);
    set(gca, 'XTickLabelRotation', 45, 'TickLabelInterpreter', 'none');

    xtips = b.XEndPoints;
    ytips = b.YEndPoints;
    labels = compose("%.6f", areaValues);
    text(xtips, ytips, labels, 'HorizontalAlignment','center', ...
        'VerticalAlignment','bottom', 'FontSize', 9, 'FontWeight','bold', 'Interpreter', 'none');
end

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
        if numel(inliers) > numel(bestInliers)
            bestInliers = inliers;
            model = [n; d];
        end
    end
end
