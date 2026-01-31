clc;

thisDir  = fileparts(mfilename("fullpath"));
demoRoot = fileparts(fileparts(thisDir));

imgFolder  = fullfile(demoRoot, ...
    "Scripts","Step1_CameraPoseEstimation","Data", ...
    "Routine_inspection4_data","SfM","Dense","images");

maskFolder = fullfile(demoRoot, ...
    "Scripts","Step2_SimilarityIndex","Segmentation_mask");

pairPath   = fullfile(demoRoot, ...
    "Scripts","Step2_SimilarityIndex","Best_Match_Pairs.txt");
fid = fopen(pairPath, 'r');
pairs = textscan(fid, '%s %s'); fclose(fid);
queryNames = string(pairs{1}); 
refNames   = string(pairs{2});

saveMaskCoords(maskFolder);
globalMasks = evalin('base', 'Masks');

colorMap = [0.5, 1.0, 0.0;
            1.0, 1.0, 0.0;
            1.0, 0.0, 0.0;
            1.0, 0.0, 0.8];

uniqueRefs = unique(refNames(refNames ~= "None"));
screen = get(0, 'ScreenSize');

for r = 1:numel(uniqueRefs)
    targetRef = uniqueRefs(r);
    qIdxList = find(refNames == targetRef);
    currentQueries = queryNames(qIdxList);
    [~, sIdx] = sort(cellfun(@(x) str2double(regexp(x,'\d+','match','once')), ...
                     cellstr(currentQueries)), 'descend');
    sortedQueries = currentQueries(sIdx);

    K_names  = lower(string({CameraIntParams.image_name}));
    E_names  = lower(string({CameraExtParams.ImageName}));
    dm_names = lower(string({Depthmaps.FileName}));

    Kr = CameraIntParams(K_names == lower(targetRef));
    Er = CameraExtParams(E_names == lower(targetRef));
    Ir = imresize(im2double(imread(fullfile(imgFolder, targetRef))), ...
                  [Kr.height, Kr.width]);

    fig = figure('Name', sprintf("Balanced-Smooth Overlay: %s", targetRef), ...
                 'Color', 'w');
    fig.Position = [screen(3)/4, screen(4)/4, screen(3)/2, screen(4)/2];
    set(fig, 'Renderer', 'opengl');

    legX = 0.02; 
    legY = 0.77; 
    legW = 0.22; 
    legH = 0.20;

    annotation(fig, 'textbox', [legX legY legW legH], ...
        'String', '', 'Units', 'normalized', ...
        'BackgroundColor', [1 1 1], ...
        'EdgeColor', [0 0 0], ...
        'LineWidth', 1.0, ...
        'FitBoxToText', 'off');

    rowN = 4;
    boxPad = 0.012;
    rowH = (legH - 2*boxPad) / rowN;

    barW = legW * 0.38;
    gap  = legW * 0.05;
    txtW = legW - (2*boxPad + barW + gap);

    barH = rowH * 0.70;

    for i = 1:rowN
        y0 = legY + legH - boxPad - i*rowH + (rowH - barH)/2;
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

    for k = 1:numel(sortedQueries)
        qFile = sortedQueries(k);
        qNum = str2double(regexp(qFile,'\d+','match','once'));
        thisContourColor = colorMap(mod(qNum-1, 4)+1, :);

        Kq = CameraIntParams(K_names == lower(qFile));
        Eq = CameraExtParams(E_names == lower(qFile));
        [~, qBase] = fileparts(qFile);
        idxDq = find(contains(dm_names, lower(qBase)), 1);
        if isempty(idxDq), continue; end

        Dq_orig = Depthmaps(idxDq).DepthMap;
        [D_h, D_w] = size(Dq_orig);

        maskIdx = find(strcmpi({globalMasks.filename}, char(qFile)), 1);
        if isempty(maskIdx), continue; end

        currMask = imresize(globalMasks(maskIdx).mask, ...
                            [D_h, D_w], 'nearest') > 0;
        [vM, uM] = find(currMask);
        if isempty(vM), continue; end

        zM_raw = Dq_orig(sub2ind([D_h, D_w], vM, uM));
        validIdx = isfinite(zM_raw) & zM_raw > 0;
        if sum(validIdx) <= 3, continue; end

        pts_c = [(uM(validIdx)-Kq.cx)./Kq.fx.*zM_raw(validIdx), ...
                 (vM(validIdx)-Kq.cy)./Kq.fy.*zM_raw(validIdx), ...
                  zM_raw(validIdx)];

        [model, ~] = ransacfitplane(pts_c', 0.01);
        if isempty(model), continue; end

        n = model(1:3); 
        d = model(4);

        dirX = (uM-Kq.cx)./Kq.fx; 
        dirY = (vM-Kq.cy)./Kq.fy;
        denom = (n(1)*dirX + n(2)*dirY + n(3));

        good = abs(denom) > 1e-9;
        zM_fixed = nan(size(dirX));
        zM_fixed(good) = -d ./ denom(good);
        good2 = good & isfinite(zM_fixed) & zM_fixed > 0;

        Xc_q = [dirX(good2).*zM_fixed(good2), ...
                dirY(good2).*zM_fixed(good2), ...
                zM_fixed(good2)]';

        Xw   = Eq.R' * (Xc_q - Eq.t);
        Xc_r = Er.R * Xw + Er.t;

        Zr = Xc_r(3,:);
        fVal = Zr > 0;

        u2 = Kr.fx .* (Xc_r(1,fVal)./Zr(fVal)) + Kr.cx;
        v2 = Kr.fy .* (Xc_r(2,fVal)./Zr(fVal)) + Kr.cy;

        inImg = u2 >= 1 & u2 <= Kr.width & ...
                v2 >= 1 & v2 <= Kr.height;

        u2_f = double(u2(inImg));
        v2_f = double(v2(inImg));
        if isempty(u2_f), continue; end

        zLevel = (10 - qNum) * 0.5;

        u_min = max(1, floor(min(u2_f)));
        u_max = min(Kr.width, ceil(max(u2_f)));
        v_min = max(1, floor(min(v2_f)));
        v_max = min(Kr.height, ceil(max(v2_f)));

        Iq = imresize(im2double(imread(fullfile(imgFolder, qFile))), ...
                      [D_h, D_w]);

        idxAll = find(good2);
        idxSel = idxAll(fVal);
        idxSel = idxSel(inImg);

        lin = sub2ind([D_h, D_w], vM(idxSel), uM(idxSel));

        F_R = scatteredInterpolant(u2_f(:), v2_f(:), ...
                                   double(Iq(lin)), ...
                                   'linear', 'none');
        F_G = scatteredInterpolant(u2_f(:), v2_f(:), ...
                                   double(Iq(lin + D_h*D_w)), ...
                                   'linear', 'none');
        F_B = scatteredInterpolant(u2_f(:), v2_f(:), ...
                                   double(Iq(lin + 2*D_h*D_w)), ...
                                   'linear', 'none');

        [gridU, gridV] = meshgrid(double(u_min:u_max), ...
                                  double(v_min:v_max));

        inter_Alpha_full = false(Kr.height, Kr.width);
        inter_Alpha_full(sub2ind(size(inter_Alpha_full), ...
            round(v2_f), round(u2_f))) = true;
        inter_Alpha_full = imfill(imclose(inter_Alpha_full, ...
            strel('disk', 10)), 'holes');

        surface(gridU, gridV, zLevel * ones(size(gridU)), ...
            cat(3, F_R(gridU, gridV), ...
                   F_G(gridU, gridV), ...
                   F_B(gridU, gridV)), ...
            'FaceColor', 'texturemap', ...
            'EdgeColor', 'none', ...
            'FaceAlpha', 'texturemap', ...
            'AlphaData', ...
            double(inter_Alpha_full(v_min:v_max, ...
                                   u_min:u_max)) * 0.7);

        cData = contourc(double(inter_Alpha_full(v_min:v_max, ...
                                                 u_min:u_max)), ...
                          [0.5 0.5]);
        idx = 1;
        while idx < size(cData, 2)
            numPts = cData(2, idx);
            if numPts > 30
                cx = double(cData(1, idx+1:idx+numPts))' ...
                     + u_min - 1;
                cy = double(cData(2, idx+1:idx+numPts))' ...
                     + v_min - 1;

                cx = smoothdata(cx(:), 'rlowess', ...
                                round(numPts/24));
                cy = smoothdata(cy(:), 'rlowess', ...
                                round(numPts/24));

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
