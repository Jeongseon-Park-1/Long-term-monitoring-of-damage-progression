 function EstimatePlane(imagePath, binaryMaskPath)

    Depthmaps = evalin('base', 'Depthmaps');
    CameraIntParams = evalin('base', 'CameraIntParams');
    CameraExtParams = evalin('base', 'CameraExtParams');

    [~, baseFileName, ext] = fileparts(imagePath);
    fullFileName = [baseFileName, ext];

    allFileNames = {Depthmaps.FileName};
    allFileNames = cellfun(@char, allFileNames, 'UniformOutput', false);
    depthMapIdx = find(contains(lower(allFileNames), lower(baseFileName)), 1);
    if isempty(depthMapIdx)
        error('Depth map not found for image: %s', baseFileName);
    end
    depthMap = Depthmaps(depthMapIdx).DepthMap;

    allImageNames = {CameraExtParams.ImageName};
    allImageNames = cellfun(@char, allImageNames, 'UniformOutput', false);
    extIdx = find(contains(lower(allImageNames), lower(baseFileName)), 1);
    if isempty(extIdx)
        error('Camera extrinsics not found for image: %s', baseFileName);
    end
    R = CameraExtParams(extIdx).R;
    t = CameraExtParams(extIdx).t;

    inputImage = imread(imagePath);

    binaryMask = imread(binaryMaskPath);
    if size(binaryMask,3) > 1
        binaryMask = rgb2gray(binaryMask);
    end
    binaryMask = logical(binaryMask);

    [polygonY, polygonX] = find(binaryMask);
    zCamera = depthMap(binaryMask);

    validIdx = ~isnan(zCamera);
    polygonX = polygonX(validIdx);
    polygonY = polygonY(validIdx);
    zCamera = zCamera(validIdx);

    validIdx = ~isnan(zCamera);
    polygonX = polygonX(validIdx);
    polygonY = polygonY(validIdx);
    zCamera = zCamera(validIdx);

    polygonIdx = sub2ind(size(depthMap), polygonY, polygonX);
    rgbColors = reshape(inputImage, [], 3);
    rgbColors = rgbColors(polygonIdx, :);

    xCamera = (polygonX - CameraIntParams.cx) .* zCamera / CameraIntParams.fx;
    yCamera = (polygonY - CameraIntParams.cy) .* zCamera / CameraIntParams.fy;

    pointsCamera = [xCamera'; yCamera'; zCamera'];
    pointsWorld = R * pointsCamera + t;

    if evalin('base','exist("R_ecef","var") && exist("t_ecef","var") && exist("scaleFactor","var")')
        R_ecef      = evalin('base', 'R_ecef');
        t_ecef      = evalin('base', 't_ecef');
        scaleFactor = evalin('base', 'scaleFactor');

        pointsWorld = scaleFactor * pointsWorld' * R_ecef + t_ecef; % Nx3
        pointsWorld = pointsWorld'; 
    % else
    %     warning('Procrustes data none');
    end


    maxIterations = 1000;
    threshold = 0.010;
    bestInliersCount = 0;
    bestPlane = [];

    for i = 1:maxIterations
        idx = randperm(size(pointsWorld, 2), 3);
        samplePoints = pointsWorld(:, idx);
        p1 = samplePoints(:, 1);
        p2 = samplePoints(:, 2);
        p3 = samplePoints(:, 3);
        normal = cross(p2 - p1, p3 - p1);
        normal = normal / norm(normal);
        d = -dot(normal, p1);
        plane = [normal; d];

        distances = abs(plane(1) * pointsWorld(1, :) + ...
                        plane(2) * pointsWorld(2, :) + ...
                        plane(3) * pointsWorld(3, :) + plane(4));
        distances = distances / norm(plane(1:3));

        inliers = find(distances < threshold);
        numInliers = length(inliers);

        if numInliers > bestInliersCount
            bestInliersCount = numInliers;
            bestPlane = plane;
            bestInliers = inliers;
        end
    end

    A = bestPlane(1); B = bestPlane(2); C = bestPlane(3); D = bestPlane(4);
    inliersPoints = pointsWorld(:, bestInliers);
    
    centroid = mean(inliersPoints, 2); 

     
     [xGrid, yGrid] = meshgrid(linspace(min(inliersPoints(1,:)), max(inliersPoints(1,:)), 100), ...
                               linspace(min(inliersPoints(2,:)), max(inliersPoints(2,:)), 100));
      zGrid = (-D - A*xGrid - B*yGrid) / C;

    % xMin = min(inliersPoints(1,:));
    % xMax = max(inliersPoints(1,:));
    % yMin = min(inliersPoints(2,:));
    % yMax = max(inliersPoints(2,:));
    % 
    % Xcorners = [xMin xMax xMax xMin];
    % Ycorners = [yMin yMin yMax yMax];
    % Zcorners = (-D - A * Xcorners - B * Ycorners) / C;
    % 
    % Xcorners = Xcorners - centroid(1);
    % Ycorners = Ycorners - centroid(2);
    % Zcorners = Zcorners - centroid(3);
    % 
    % fill3(Xcorners, Ycorners, Zcorners, [0.6 0.6 1], ...
    %       'FaceAlpha', 0.3, 'EdgeColor', 'k', 'LineWidth', 1.2);
    % 
    % figure('Color','w');
    % 
    % planeCorners = [Xcorners; Ycorners; Zcorners];
    % allPts = [inliersPoints'; planeCorners'];
    % 
    % centroid = mean(allPts, 1);  % [xMid, yMid, zMid]
    % 
    % shiftedInliers = inliersPoints - centroid';
    % shiftedXGrid = xGrid - centroid(1);
    % shiftedYGrid = yGrid - centroid(2);
    % shiftedZGrid = zGrid - centroid(3);

    % scatter3(shiftedInliers(1,:), shiftedInliers(2,:), shiftedInliers(3,:), ...
    %          15, double(rgbColors(bestInliers, :)) / 255, 'filled'); hold on;
    % mesh(shiftedXGrid, shiftedYGrid, shiftedZGrid, ...
    %      'EdgeColor', 'k', 'EdgeAlpha', 0.5, 'FaceColor', 'none');
    % 
    % title('ECEF-based plane estimation');
    % xlabel('X(m)'); ylabel('Y(m)'); zlabel('Z(m)');
    % axis equal; grid on;
    % % legend('Inlier Points','Estimated Plane'); legend boxoff;

    % allX = shiftedInliers(1,:); allY = shiftedInliers(2,:); allZ = shiftedInliers(3,:);
    % maxRange = max([range(allX), range(allY), range(allZ)]);
    % xMid = mean(allX); yMid = mean(allY); zMid = mean(allZ);
    % xlim([xMid - maxRange/2, xMid + maxRange/2]);
    % ylim([yMid - maxRange/2, yMid + maxRange/2]);
    % zlim([zMid - maxRange/2, zMid + maxRange/2]);

    % if evalin('base','exist("refGPS", "var")')
    %     refGPS = evalin('base', 'refGPS');  % [lat, lon, alt]
    %     [X0, Y0, Z0] = geodetic2ecef(refGPS(1), refGPS(2), refGPS(3));
    %     ax = gca;
    %     xt = ax.XTick; yt = ax.YTick; zt = ax.ZTick;
    %     ax.XTickLabel = compose('%.0f', xt + centroid(1) + X0);
    %     ax.YTickLabel = compose('%.0f', yt + centroid(2) + Y0);
    %     ax.ZTickLabel = compose('%.0f', zt + centroid(3) + Z0);
    % end
    % 
    % xlabel('X'); ylabel('Y'); zlabel('Z');


    assignin('base', 'planeModel', bestPlane);


end
