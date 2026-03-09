clc;

thisDir  = fileparts(mfilename("fullpath"));
demoRoot = fileparts(fileparts(thisDir));

imgFolder = fullfile(demoRoot, ...
    "Scripts","Step1_CameraPoseEstimation","Data","Images");

maskFolder = fullfile(demoRoot, ...
    "Scripts","Step2_SimilarityIndex","Segmentation_mask");

saveMaskCoords(maskFolder);
globalMasks = evalin('base', 'Masks');

if ~evalin('base','exist(''BestPairs'',''var'')')
    error("base workspace에 BestPairs none");
end
if ~evalin('base','exist(''CameraIntParams'',''var'')')
    error("base workspace에 CameraIntParams none");
end
if ~evalin('base','exist(''CameraExtParams'',''var'')')
    error("base workspace에 CameraExtParams none");
end
if evalin('base','exist(''Depthmaps'',''var'')')
    Depthmaps = evalin('base','Depthmaps');
elseif evalin('base','exist(''DepthMapFiles'',''var'')')
    Depthmaps = evalin('base','DepthMapFiles');
else
    error("Depthmaps or DepthMapFiles none");
end

BestPairs       = evalin('base','BestPairs');
CameraIntParams = evalin('base','CameraIntParams');

if evalin('base','exist(''ExtCameraParams'',''var'')')
    ExtCameraParams = evalin('base','ExtCameraParams');
else
    ExtCameraParams = evalin('base','CameraExtParams');
    fprintf("Using CameraExtParams for visualization.\n");
end

if evalin('base','exist(''Depthmaps'',''var'')')
    Depthmaps = evalin('base','Depthmaps');
else
    Depthmaps = evalin('base','DepthMapFiles');
end

queryNames = string(BestPairs(:,1));
refNames   = string(BestPairs(:,2));

colorMap = [0.5, 1.0, 0.0;
            1.0, 1.0, 0.0;
            1.0, 0.0, 0.0;
            1.0, 0.0, 0.8];

refColor = [0.40, 0.85, 1.00];

uniqueRefs = unique(refNames(refNames ~= "None"));
screen = get(0, 'ScreenSize');

K_names   = lower(strtrim(string({CameraIntParams.image_name})));
Evis_names = lower(strtrim(string({ExtCameraParams.ImageName})));
dm_names  = lower(strtrim(string({Depthmaps.FileName})));

for r = 1:numel(uniqueRefs)
    targetRef = uniqueRefs(r);
    qIdxList = find(refNames == targetRef);
    currentQueries = queryNames(qIdxList);

    required = ["sQuery1","sQuery2","sQuery3","sQuery4"];
    present = false(1,4);

    for i = 1:numel(currentQueries)
        name = currentQueries(i);
        token = regexp(name,'squery(\d)','tokens','once','ignorecase');
        if ~isempty(token)
            idx = str2double(token{1});
            if idx >= 1 && idx <= 4
                present(idx) = true;
            end
        end
    end

    if ~all(present)
        continue
    end

    qTypeList = nan(numel(currentQueries),1);
    for i = 1:numel(currentQueries)
        token = regexp(currentQueries(i),'squery(\d)','tokens','once','ignorecase');
        if ~isempty(token)
            qTypeList(i) = str2double(token{1});
        end
    end
    [~, sIdx] = sort(qTypeList, 'descend');
    sortedQueries = currentQueries(sIdx);

    idxKr = find(K_names == lower(targetRef), 1);
    idxEr = find(Evis_names == lower(targetRef), 1);

    if isempty(idxKr)
        idxKr = findByBaseName(K_names, targetRef);
    end
    if isempty(idxEr)
        idxEr = findByBaseName(Evis_names, targetRef);
    end

    if isempty(idxKr) || isempty(idxEr)
        continue
    end

    Kr = CameraIntParams(idxKr);
    Er = ExtCameraParams(idxEr);

    refImgPath = fullfile(imgFolder, targetRef);
    if ~isfile(refImgPath)
        continue
    end

    Ir = imresize(im2double(imread(refImgPath)), [Kr.height, Kr.width]);

    fig = figure('Name', sprintf("Balanced-Smooth Overlay: %s", targetRef), ...
                 'Color', 'w');
    fig.Position = [screen(3)/4, screen(4)/4, screen(3)/2, screen(4)/2];
    set(fig, 'Renderer', 'opengl');

    refMaskIdx = find(strcmpi({globalMasks.filename}, char(targetRef)), 1);
    hasRefMask = ~isempty(refMaskIdx);

    legX = 0.02;
    legY = 0.73;
    legW = 0.25;
    legH = 0.24;

    if hasRefMask
        rowN = 5;
    else
        rowN = 4;
    end

    annotation(fig, 'textbox', [legX legY legW legH], ...
        'String', '', 'Units', 'normalized', ...
        'BackgroundColor', [1 1 1], ...
        'EdgeColor', [0 0 0], ...
        'LineWidth', 1.0, ...
        'FitBoxToText', 'off');

    boxPad = 0.012;
    rowH = (legH - 2*boxPad) / rowN;

    barW = legW * 0.38;
    gap  = legW * 0.05;
    txtW = legW - (2*boxPad + barW + gap);
    barH = rowH * 0.70;

    rowStart = 1;

    if hasRefMask
        y0 = legY + legH - boxPad - rowStart*rowH + (rowH - barH)/2;
        xBar = legX + boxPad;
        xTxt = xBar + barW + gap;

        annotation(fig, 'rectangle', ...
            [xBar, y0, barW, barH], ...
            'Units', 'normalized', ...
            'FaceColor', refColor, ...
            'EdgeColor', [0 0 0], ...
            'LineWidth', 0.8);

        annotation(fig, 'textbox', ...
            [xTxt, y0, txtW, barH], ...
            'Units', 'normalized', ...
            'String', 'Reference', ...
            'EdgeColor', 'none', ...
            'Color', [0 0 0], ...
            'FontSize', 11, ...
            'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'middle');

        rowStart = 2;
    end

    for i = 1:4
        y0 = legY + legH - boxPad - (i + rowStart - 1)*rowH + (rowH - barH)/2;
        xBar = legX + boxPad;
        xTxt = xBar + barW + gap;

        annotation(fig, 'rectangle', ...
            [xBar, y0, barW, barH], ...
            'Units', 'normalized', ...
            'FaceColor', colorMap(i,:), ...
            'EdgeColor', [0 0 0], ...
            'LineWidth', 0.8);

        annotation(fig, 'textbox', ...
            [xTxt, y0, txtW, barH], ...
            'Units', 'normalized', ...
            'String', sprintf("Query%d", i), ...
            'EdgeColor', 'none', ...
            'Color', [0 0 0], ...
            'FontSize', 11, ...
            'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'middle');
    end

    [Xb, Yb] = meshgrid(1:double(Kr.width), 1:double(Kr.height));
    surface(Xb, Yb, zeros(size(Xb)), Ir, ...
        'FaceColor', 'texturemap', 'EdgeColor', 'none');
    hold on;

    if hasRefMask
        refMask = globalMasks(refMaskIdx).mask;
        refMask = imresize(refMask, [Kr.height, Kr.width], 'nearest') > 0;

        cDataRef = contourc(double(refMask), [0.5 0.5]);
        idxC = 1;
        while idxC < size(cDataRef, 2)
            numPts = cDataRef(2, idxC);
            if numPts > 20
                cx = double(cDataRef(1, idxC+1:idxC+numPts))';
                cy = double(cDataRef(2, idxC+1:idxC+numPts))';

                cx = smoothdata(cx(:), 'rlowess', max(5, round(numPts/24)));
                cy = smoothdata(cy(:), 'rlowess', max(5, round(numPts/24)));

                t  = (1:numel(cx))';
                tt = linspace(1, t(end), numPts * 2)';

                cx_f = interp1(t, cx, tt, 'pchip');
                cy_f = interp1(t, cy, tt, 'pchip');

                line(cx_f, cy_f, ...
                    0.25 * ones(size(cx_f)), ...
                    'Color', [refColor, 0.4], ...
                    'LineWidth', 1.6);
            end
            idxC = idxC + numPts + 1;
        end
    end

    for k = 1:numel(sortedQueries)
        qFile = sortedQueries(k);

        tokenType = regexp(qFile,'squery(\d)','tokens','once','ignorecase');
        if isempty(tokenType)
            continue
        end

        qNum = str2double(tokenType{1});
        thisContourColor = colorMap(mod(qNum-1, 4)+1, :);

        idxKq = find(K_names == lower(qFile), 1);
        idxEq = find(Evis_names == lower(qFile), 1);

        if isempty(idxKq)
            idxKq = findByBaseName(K_names, qFile);
        end
        if isempty(idxEq)
            idxEq = findByBaseName(Evis_names, qFile);
        end

        if isempty(idxKq) || isempty(idxEq)
            continue
        end

        Kq = CameraIntParams(idxKq);
        Eq = ExtCameraParams(idxEq);

        [~, qBase] = fileparts(qFile);
        idxDq = find(contains(dm_names, lower(qBase)), 1);
        if isempty(idxDq)
            continue
        end

        try
            Dq_orig = readDepthMapColmap(Depthmaps(idxDq).FilePath);
        catch
            continue
        end

        [D_h, D_w] = size(Dq_orig);

        maskIdx = find(strcmpi({globalMasks.filename}, char(qFile)), 1);
        if isempty(maskIdx)
            continue
        end

        currMask = imresize(globalMasks(maskIdx).mask, [D_h, D_w], 'nearest') > 0;
        [vM, uM] = find(currMask);
        if isempty(vM)
            continue
        end

        zM_raw = Dq_orig(sub2ind([D_h, D_w], vM, uM));
        validIdx = isfinite(zM_raw) & zM_raw > 0;
        if sum(validIdx) <= 3
            continue
        end

        pts_c = [((uM(validIdx)-Kq.cx)./Kq.fx).*zM_raw(validIdx), ...
                 ((vM(validIdx)-Kq.cy)./Kq.fy).*zM_raw(validIdx), ...
                  zM_raw(validIdx)];

        [model, ~] = ransacfitplane(pts_c', 0.01);
        if isempty(model)
            continue
        end

        n = model(1:3);
        d = model(4);

        dirX = (uM-Kq.cx)./Kq.fx;
        dirY = (vM-Kq.cy)./Kq.fy;
        denom = (n(1)*dirX + n(2)*dirY + n(3));

        good = abs(denom) > 1e-9;
        zM_fixed = nan(size(dirX));
        zM_fixed(good) = -d ./ denom(good);
        good2 = good & isfinite(zM_fixed) & zM_fixed > 0;

        if nnz(good2) < 3
            continue
        end

        Xc_q = [dirX(good2).*zM_fixed(good2), ...
                dirY(good2).*zM_fixed(good2), ...
                zM_fixed(good2)]';

        Xw   = Eq.R' * (Xc_q - Eq.t(:));
        Xc_r = Er.R * Xw + Er.t(:);

        Zr = Xc_r(3,:);
        fVal = Zr > 0;
        if nnz(fVal) < 3
            continue
        end

        u2 = Kr.fx .* (Xc_r(1,fVal)./Zr(fVal)) + Kr.cx;
        v2 = Kr.fy .* (Xc_r(2,fVal)./Zr(fVal)) + Kr.cy;

        inImg = u2 >= 1 & u2 <= Kr.width & ...
                v2 >= 1 & v2 <= Kr.height;

        u2_f = double(u2(inImg));
        v2_f = double(v2(inImg));
        if isempty(u2_f)
            continue
        end

        zLevel = (10 - qNum) * 0.5;

        u_min = max(1, floor(min(u2_f)));
        u_max = min(Kr.width, ceil(max(u2_f)));
        v_min = max(1, floor(min(v2_f)));
        v_max = min(Kr.height, ceil(max(v2_f)));

        qImgPath = fullfile(imgFolder, qFile);
        if ~isfile(qImgPath)
            continue
        end
        Iq = imresize(im2double(imread(qImgPath)), [D_h, D_w]);

        idxAll = find(good2);
        idxSel = idxAll(fVal);
        idxSel = idxSel(inImg);

        if isempty(idxSel)
            continue
        end

        IqR = Iq(:,:,1);
        IqG = Iq(:,:,2);
        IqB = Iq(:,:,3);

        lin = sub2ind([D_h, D_w], vM(idxSel), uM(idxSel));

        if numel(u2_f) < 3 || numel(v2_f) < 3 || numel(lin) < 3
            continue
        end

        F_R = scatteredInterpolant(u2_f(:), v2_f(:), double(IqR(lin)), 'linear', 'none');
        F_G = scatteredInterpolant(u2_f(:), v2_f(:), double(IqG(lin)), 'linear', 'none');
        F_B = scatteredInterpolant(u2_f(:), v2_f(:), double(IqB(lin)), 'linear', 'none');

        [gridU, gridV] = meshgrid(double(u_min:u_max), double(v_min:v_max));

        inter_Alpha_full = false(Kr.height, Kr.width);
        vv = round(v2_f);
        uu = round(u2_f);
        keepPix = uu >= 1 & uu <= Kr.width & vv >= 1 & vv <= Kr.height;
        inter_Alpha_full(sub2ind(size(inter_Alpha_full), vv(keepPix), uu(keepPix))) = true;
        inter_Alpha_full = imfill(imclose(inter_Alpha_full, strel('disk', 10)), 'holes');

        surface(gridU, gridV, zLevel * ones(size(gridU)), ...
            cat(3, F_R(gridU, gridV), ...
                   F_G(gridU, gridV), ...
                   F_B(gridU, gridV)), ...
            'FaceColor', 'texturemap', ...
            'EdgeColor', 'none', ...
            'FaceAlpha', 'texturemap', ...
            'AlphaData', double(inter_Alpha_full(v_min:v_max, u_min:u_max)) * 0.7);

        cData = contourc(double(inter_Alpha_full(v_min:v_max, u_min:u_max)), [0.5 0.5]);
        idx = 1;
        while idx < size(cData, 2)
            numPts = cData(2, idx);
            if numPts > 30
                cx = double(cData(1, idx+1:idx+numPts))' + u_min - 1;
                cy = double(cData(2, idx+1:idx+numPts))' + v_min - 1;

                cx = smoothdata(cx(:), 'rlowess', max(5, round(numPts/24)));
                cy = smoothdata(cy(:), 'rlowess', max(5, round(numPts/24)));

                t  = (1:numel(cx))';
                tt = linspace(1, t(end), numPts * 2)';

                cx_f = interp1(t, cx, tt, 'pchip');
                cy_f = interp1(t, cy, tt, 'pchip');

                line(cx_f, cy_f, ...
                    (zLevel + 0.1) * ones(size(cx_f)), ...
                    'Color', [thisContourColor, 0.4], ...
                    'LineWidth', 1.6);
            end
            idx = idx + numPts + 1;
        end
    end

    view(2);
    axis ij;
    axis equal;
    axis off;
    drawnow;
end

function idx = findByBaseName(nameList, imageName)
imageName = lower(string(imageName));
[~, ib, ~] = fileparts(imageName);

bases = strings(size(nameList));
for i = 1:numel(nameList)
    [~, b, ~] = fileparts(nameList(i));
    bases(i) = lower(string(b));
end

idx = find(bases == lower(string(ib)), 1);
end

function [model, inliers] = ransacfitplane(pts, threshold)
numPts = size(pts, 2);
bestInliers = [];
model = [];
for k = 1:100
    idx = randperm(numPts, 3);
    p1 = pts(:,idx(1));
    p2 = pts(:,idx(2));
    p3 = pts(:,idx(3));
    n = cross(p2-p1, p3-p1);
    n = n / (norm(n)+eps);
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

function depth = readDepthMapColmap(filePath)
fid = fopen(filePath,'rb');
if fid == -1
    error("Cannot open depth map: %s", filePath);
end

c = onCleanup(@() fclose(fid)); %#ok<NASGU>

header = '';
numAmp = 0;

while numAmp < 3
    ch = fread(fid,1,'*char');
    if isempty(ch)
        error("Invalid COLMAP depth map header: %s", filePath);
    end
    header(end+1) = ch; %#ok<AGROW>
    if ch == '&'
        numAmp = numAmp + 1;
    end
end

vals = sscanf(header,'%d&%d&%d&');
if numel(vals) < 3
    error("Failed to parse depth map header: %s", filePath);
end

width = vals(1);
height = vals(2);
channels = vals(3);

raw = fread(fid,inf,'*single');
expected = width * height * channels;

if numel(raw) < expected
    error("Depth data size mismatch: %s", filePath);
end

raw = raw(1:expected);

if channels == 1
    depth = reshape(raw,[width,height])';
else
    raw = reshape(raw,[channels,width,height]);
    depth = squeeze(raw(1,:,:))';
end

depth = double(depth);
end