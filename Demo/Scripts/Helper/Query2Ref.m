function [bdRef1_xy, bdRef2_xy] = Query2Ref(refImg, refName, q1Img, q1Name, q2Img, q2Name, Masks, Depthmaps, CameraExtParams, CameraIntParams)

% overlayTwoMasksOnRef
% - 1st: green, 2nd: red
% - boundary smoothing included

    if ischar(refImg) || isstring(refImg), IR = imread(refImg); else, IR = refImg; end

    bdRef1_xy = projectOneMaskBoundaryToRef(q1Img, q1Name, refName, Masks, Depthmaps, CameraExtParams, CameraIntParams);
    bdRef2_xy = projectOneMaskBoundaryToRef(q2Img, q2Name, refName, Masks, Depthmaps, CameraExtParams, CameraIntParams);

    figure;
    imshow(IR); hold on;

    if ~isempty(bdRef1_xy)
        plot(bdRef1_xy(:,1), bdRef1_xy(:,2), 'g', 'LineWidth', 2);
    end

    if ~isempty(bdRef2_xy)
        plot(bdRef2_xy(:,1), bdRef2_xy(:,2), 'r', 'LineWidth', 2);
    end

    title('Two projected mask boundaries on Reference');
    hold off;

end



function bdRef_xy = projectOneMaskBoundaryToRef(queryImg, queryName, refName, Masks, Depthmaps, CameraExtParams, CameraIntParams)

    fx = CameraIntParams.fx; fy = CameraIntParams.fy;
    cx = CameraIntParams.cx; cy = CameraIntParams.cy;
    K = [fx 0 cx; 0 fy cy; 0 0 1];

    if ischar(queryImg) || isstring(queryImg)
    end

    qKey = normName(queryName);
    rKey = normName(refName);

    maskKeys = arrayfun(@(s) normName(s.filename), Masks, 'UniformOutput', false);
    idxM = find(strcmp(maskKeys, qKey), 1);
    if isempty(idxM), error('Mask not found: %s', qKey); end
    BW = logical(Masks(idxM).mask);

    BW = smoothMask(BW);

    depthKeys = arrayfun(@(s) normName(s.FileName), Depthmaps, 'UniformOutput', false);
    idxD = find(strcmp(depthKeys, qKey), 1);
    if isempty(idxD), error('DepthMap not found: %s', qKey); end
    D = Depthmaps(idxD).DepthMap;

    extKeys = arrayfun(@(s) normName(s.ImageName), CameraExtParams, 'UniformOutput', false);
    idxEq = find(strcmp(extKeys, qKey), 1);
    idxEr = find(strcmp(extKeys, rKey), 1);
    if isempty(idxEq), error('Extrinsics not found: %s', qKey); end
    if isempty(idxEr), error('Extrinsics not found: %s', rKey); end

    Rq = CameraExtParams(idxEq).R; tq = CameraExtParams(idxEq).t;
    Rr = CameraExtParams(idxEr).R; tr = CameraExtParams(idxEr).t;

    B = bwboundaries(BW, 'noholes');
    if isempty(B)
        bdRef_xy = [];
        return;
    end
    lens = cellfun(@(x) size(x,1), B);
    [~, idb] = max(lens);
    bd_rc = B{idb};                    
    bdQ_xy = [bd_rc(:,2), bd_rc(:,1)]; 

    xq = round(bdQ_xy(:,1));
    yq = round(bdQ_xy(:,2));

    H = size(D,1); W = size(D,2);
    xq = min(max(xq, 1), W);
    yq = min(max(yq, 1), H);

    ind = sub2ind([H, W], yq, xq);
    zq = D(ind);

    valid = isfinite(zq) & (zq > 0);
    xq = xq(valid); yq = yq(valid); zq = zq(valid);

    if isempty(zq)
        bdRef_xy = [];
        return;
    end

    Pq = [xq.'; yq.'; ones(1, numel(xq))];
    rq = K \ Pq;
    Xcq = rq .* zq.';

    % cam->world
    Xw = Rq' * (Xcq - tq);

    % world->ref cam -> pixel
    Xcr = Rr * Xw + tr;
    Pr = K * Xcr;
    ur = (Pr(1,:) ./ Pr(3,:)).';
    vr = (Pr(2,:) ./ Pr(3,:)).';

    bdRef_xy = [ur, vr];
    bdRef_xy = smoothBoundaryXY(bdRef_xy);

end

function BW2 = smoothMask(BW)
    BW = logical(BW);

    BW = bwareaopen(BW, 80);            
    BW = imfill(BW, 'holes');           

    se1 = strel('disk', 4);
    se2 = strel('disk', 2);

    BW = imclose(BW, se1);             
    BW = imopen(BW, se2);            

    BW2 = BW;
end


function xy2 = smoothBoundaryXY(xy)

    if isempty(xy)
        xy2 = xy;
        return;
    end

    xy = double(xy);

    if size(xy,2) ~= 2
        xy = xy(:);
        if mod(numel(xy),2) ~= 0
            error('smoothBoundaryXY: xy must be Nx2.');
        end
        xy = reshape(xy, [], 2);
    end

    x = xy(:,1);  x = x(:);
    y = xy(:,2);  y = y(:);

    n = numel(x);

    if n < 30
        xy2 = [x, y];
        return;
    end

    idx_prev = [n; (1:n-1).'];
    idx_next = [(2:n).'; 1];

    x_prev = x(idx_prev);
    y_prev = y(idx_prev);
    x_next = x(idx_next);
    y_next = y(idx_next);

    d1 = hypot(x - x_prev, y - y_prev);
    d2 = hypot(x_next - x, y_next - y);
    d  = 0.5*(d1 + d2);

    med  = median(d);
    madv = median(abs(d - med)) + eps;

    thr  = med + 3.5*madv;    
    keep = d <= thr;

    x = x(keep);
    y = y(keep);
    n = numel(x);

    if n < 30
        xy2 = [x, y];
        return;
    end

    idx_prev = [n; (1:n-1).'];
    idx_next = [(2:n).'; 1];

    x_prev = x(idx_prev); y_prev = y(idx_prev);
    x_next = x(idx_next); y_next = y(idx_next);

    v1 = [x - x_prev, y - y_prev];
    v2 = [x_next - x, y_next - y];

    nv1 = sqrt(sum(v1.^2,2)) + eps;
    nv2 = sqrt(sum(v2.^2,2)) + eps;

    cosang = sum(v1.*v2,2) ./ (nv1.*nv2);
    cosang = max(min(cosang, 1), -1);
    ang = acos(cosang);

    keep2 = ang < (pi * 0.85);
    x = x(keep2);
    y = y(keep2);
    n = numel(x);

    if n < 30
        xy2 = [x, y];
        return;
    end

    dx = diff([x; x(1)]);
    dy = diff([y; y(1)]);
    s  = [0; cumsum(hypot(dx(1:end-1), dy(1:end-1)))];
    L  = s(end);

    m = min(max(round(n*0.8), 200), 1200);
    s2 = linspace(0, L, m).';

    x_i = interp1(s, x, s2, 'linear', 'extrap');
    y_i = interp1(s, y, s2, 'linear', 'extrap');

    win = 21;
    if win > m, win = 2*floor(m/2)-1; end
    if win < 7
        xy2 = [x_i, y_i];
        return;
    end

    poly = 3;
    x_s = sgolayfilt(double(x_i), poly, win);
    y_s = sgolayfilt(double(y_i), poly, win);

    k = 3;
    x_s = movmedian(x_s, k);
    y_s = movmedian(y_s, k);

    xy2 = [x_s, y_s];

end



function key = normName(x)
    if isstring(x), x = char(x); end
    if iscell(x), x = x{1}; end

    x = strtrim(x);
    if ~isempty(x) && x(1) == '''', x = x(2:end); end
    if ~isempty(x) && x(end) == '''', x = x(1:end-1); end
    x = strtrim(x);

    [~, name, ext] = fileparts(x);
    if ~isempty(ext)
        key = [name ext];
    else
        key = x;
    end
end
