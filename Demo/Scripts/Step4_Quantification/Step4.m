clc;

gamma = 1.0;

if ~evalin("base","exist('globalMasks','var')")
    error("base workspace에 globalMasks none");
end
if ~evalin("base","exist('CameraIntParams','var')")
    error("base workspace에 CameraIntParams none.");
end
if ~evalin("base","exist('DepthMapFiles','var')")
    error("base workspace에 DepthMapFiles none.");
end
if ~evalin("base","exist('BestPairs','var')")
    error("base workspace에 BestPairs none.");
end
if ~evalin("base","exist('SCF','var')")
    error("SCF none.");
end

globalMasks     = evalin("base","globalMasks");
CameraIntParams = evalin("base","CameraIntParams");
DepthMapFiles   = evalin("base","DepthMapFiles");
BestPairs       = evalin("base","BestPairs");
SCF             = double(evalin("base","SCF"));

numMasks = numel(globalMasks);
results = struct('FileName', {}, 'RefName', {}, 'DamageArea_cm2', {}, 'IsReference', {});

pairQ_raw = string(BestPairs(:,1));
pairR_raw = string(BestPairs(:,2));
pairQ_l   = lower(strtrim(pairQ_raw));

K_names  = lower(strtrim(string({CameraIntParams.image_name})));
dm_names = lower(strtrim(string({DepthMapFiles.FileName})));

SCF_cm = SCF * 100;

colorMap = [0.5, 1.0, 0.0;
            1.0, 1.0, 0.0;
            1.0, 0.0, 0.0;
            1.0, 0.0, 0.8];

refColor = [0.40, 0.85, 1.00];

for k = 1:numMasks
    qFile = string(globalMasks(k).filename);
    qFile_l = lower(strtrim(qFile));
    [~, qBase, ~] = fileparts(qFile);

    isReferenceMask = startsWith(qFile_l, "ref_");

    if ~isReferenceMask
        hit = find(pairQ_l == qFile_l, 1);
        if isempty(hit)
            [~, qBase2, ~] = fileparts(qFile_l);
            pairBases = strings(size(pairQ_l));
            for ii = 1:numel(pairQ_l)
                [~, bb, ~] = fileparts(pairQ_l(ii));
                pairBases(ii) = lower(string(bb));
            end
            hit = find(pairBases == lower(string(qBase2)), 1);
        end
        if isempty(hit)
            continue;
        end
        refForThis = pairR_raw(hit);
    else
        refForThis = qFile;
    end

    idxKq = find(K_names == lower(qFile), 1);
    if isempty(idxKq)
        idxKq = find(contains(K_names, lower(qBase)), 1);
    end

    idxDq = find(contains(dm_names, lower(qBase)), 1);

    if isempty(idxDq) || isempty(idxKq)
        continue;
    end

    Kq = CameraIntParams(idxKq);
    depthPath = string(DepthMapFiles(idxDq).FilePath);

    if ~isfile(depthPath)
        continue;
    end

    try
        Dq_orig = readDepthMap_COLMAP(depthPath);
    catch
        continue;
    end

    [D_h, D_w] = size(Dq_orig);

    currMask = imresize(globalMasks(k).mask, [D_h, D_w], 'nearest') > 0;
    [vM, uM] = find(currMask);
    if isempty(vM)
        continue;
    end

    zM_raw = Dq_orig(sub2ind([D_h, D_w], vM, uM));
    validIdx = isfinite(zM_raw) & zM_raw > 0;

    if nnz(validIdx) > 3
        u_valid = double(uM(validIdx));
        v_valid = double(vM(validIdx));
        z_valid = double(zM_raw(validIdx));

        pts_c = [u_valid, v_valid, z_valid];
        [model, ~] = ransacfitplane_step4(pts_c', 0.05);

        if ~isempty(model) && abs(model(3)) > 1e-12
            a = model(1);
            b = model(2);
            c = model(3);
            d = model(4);

            u_all = double(uM);
            v_all = double(vM);
            s_hat = (-a*u_all - b*v_all - d) / c;

            validPlane = isfinite(s_hat) & s_hat > 0;
            if any(validPlane)
                delta_X = gamma * s_hat(validPlane) / double(Kq.fx);
                delta_Y = gamma * s_hat(validPlane) / double(Kq.fy);

                pixel_areas = abs(delta_X .* delta_Y);
                total_area_cm2 = sum(pixel_areas) * (SCF_cm^2);
            else
                total_area_cm2 = 0;
            end
        else
            total_area_cm2 = 0;
        end
    else
        total_area_cm2 = 0;
    end

    results(end+1).FileName = qFile; 
    results(end).RefName = refForThis;
    results(end).DamageArea_cm2 = total_area_cm2;
    results(end).IsReference = isReferenceMask;

    fprintf('[%d/%d] %s: %.6f (cm^2)\n', k, numMasks, qFile, total_area_cm2);
end

if isempty(results)
    error("No results generated.");
end

refList = string({results.RefName});
uniqR = unique(refList);

for rr = 1:numel(uniqR)
    tr = uniqR(rr);
    idx = find(refList == tr);

    areaValues_all = [results(idx).DamageArea_cm2];
    fileLabels_all = string({results(idx).FileName});
    isRef_all      = [results(idx).IsReference];

    qset = [];
    for ii = 1:numel(fileLabels_all)
        tok = regexp(fileLabels_all(ii), 'squery(\d+)', 'tokens', 'once', 'ignorecase');
        if ~isempty(tok)
            qn = str2double(tok{1});
            if isfinite(qn)
                qset(end+1) = qn; 
            end
        end
    end
    qset = unique(qset);

    if ~isequal(qset, [1 2 3 4])
        continue;
    end

    refIdx = find(isRef_all, 1);

    queryOrder = nan(1, numel(fileLabels_all));
    for ii = 1:numel(fileLabels_all)
        tok = regexp(fileLabels_all(ii), 'squery(\d+)', 'tokens', 'once', 'ignorecase');
        if ~isempty(tok)
            queryOrder(ii) = str2double(tok{1});
        end
    end

    qIdx = find(~isnan(queryOrder));
    [~, ord] = sort(queryOrder(qIdx), 'ascend');
    qIdx = qIdx(ord);

    if ~isempty(refIdx)
        finalIdx = [refIdx, qIdx];
    else
        finalIdx = qIdx;
    end

    areaValues = areaValues_all(finalIdx);
    fileLabels = fileLabels_all(finalIdx);
    isRef      = isRef_all(finalIdx);

    barColors = zeros(numel(fileLabels), 3);
    legendHandles = [];
    legendLabels = {};

    for i = 1:numel(fileLabels)
        if isRef(i)
            barColors(i,:) = refColor;
        else
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
    end

    figure('Color','w','Name', sprintf("Damage Area (cm^2) | Ref: %s", tr));
    b = bar(areaValues);
    b.FaceColor = 'flat';
    b.CData = barColors;

    grid on;
    ylabel('Damage Area (cm^2)', 'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'none');
    xlabel('Image', 'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'none');
    title(sprintf('Quantified Damage Area (Ref: %s)', tr), 'FontSize', 14, 'Interpreter', 'none');

    xticks(1:numel(areaValues));

    xLabels = strings(size(fileLabels));
    for i = 1:numel(fileLabels)
        if isRef(i)
            xLabels(i) = "Reference";
        else
            xLabels(i) = fileLabels(i);
        end
    end
    xticklabels(xLabels);
    set(gca, 'XTickLabelRotation', 45, 'TickLabelInterpreter', 'none');

    xtips = b.XEndPoints;
    ytips = b.YEndPoints;
    labels = compose("%.6f", areaValues);
    text(xtips, ytips, labels, ...
        'HorizontalAlignment','center', ...
        'VerticalAlignment','bottom', ...
        'FontSize', 9, ...
        'FontWeight','bold', ...
        'Interpreter', 'none');

    hold on;

    if any(isRef)
        legendHandles(end+1) = patch(nan, nan, refColor, 'EdgeColor', 'none'); %#ok<SAGROW>
        legendLabels{end+1} = 'Reference'; %#ok<SAGROW>
    end

    for qn = 1:4
        legendHandles(end+1) = patch(nan, nan, colorMap(qn,:), 'EdgeColor', 'none'); %#ok<SAGROW>
        legendLabels{end+1} = sprintf('Query%d', qn); %#ok<SAGROW>
    end

    legend(legendHandles, legendLabels, ...
        'Location', 'best', ...
        'Interpreter', 'none');
end


function [model, inliers] = ransacfitplane_step4(pts, threshold)
numPts = size(pts, 2);
bestInliers = [];
model = [];

if numPts < 3
    inliers = [];
    return;
end

for i = 1:200
    idx = randperm(numPts, 3);
    p1 = pts(:,idx(1));
    p2 = pts(:,idx(2));
    p3 = pts(:,idx(3));

    n = cross(p2-p1, p3-p1);
    if norm(n) < eps
        continue;
    end

    n = n / norm(n);
    d = -dot(n, p1);

    dist = abs(n' * pts + d);
    inliers = find(dist < threshold);

    if numel(inliers) > numel(bestInliers)
        bestInliers = inliers;
        model = [n; d];
    end
end

inliers = bestInliers;
end


function D = readDepthMap_COLMAP(binPath)
fid = fopen(binPath, 'rb');
if fid == -1
    error("파일 열기 실패: %s", binPath);
end

cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>

headerChars = '';
ampCount = 0;

while ampCount < 3
    c = fread(fid, 1, '*char');
    if isempty(c)
        error("COLMAP depth header 읽기 실패: %s", binPath);
    end
    headerChars(end+1) = c; %#ok<AGROW>
    if c == '&'
        ampCount = ampCount + 1;
    end
end

parts = split(string(headerChars), '&');
parts = parts(parts ~= "");

if numel(parts) < 3
    error("COLMAP depth header 파싱 실패: %s", binPath);
end

W = str2double(parts(1));
H = str2double(parts(2));
C = str2double(parts(3));

if any(isnan([W H C])) || C < 1
    error("COLMAP depth header 값이 올바르지 않습니다: %s", binPath);
end

raw = fread(fid, W * H * C, 'single=>single');

if numel(raw) ~= W * H * C
    error("Depth payload 크기가 예상과 다릅니다: %s", binPath);
end

raw = reshape(raw, [C, W, H]);
raw = permute(raw, [3 2 1]);

if C == 1
    D = raw(:,:,1);
else
    D = raw;
end

D = double(D);
end