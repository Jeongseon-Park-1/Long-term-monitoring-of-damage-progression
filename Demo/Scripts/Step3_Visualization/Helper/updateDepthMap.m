function updateDepthMap(imagePath, binaryMaskPath)
    % updateDepthMap - Plane-based depth correction and visualization

    Depthmaps = evalin('base', 'Depthmaps');
    CameraIntParams = evalin('base', 'CameraIntParams');
    CameraExtParams = evalin('base', 'CameraExtParams');
    planeModel = evalin('base', 'planeModel');

    useECEF = false;
    if evalin('base','exist("R_ecef","var") && exist("t_ecef","var") && exist("scaleFactor","var")')
        R_ecef = evalin('base', 'R_ecef');
        t_ecef = evalin('base', 't_ecef');
        scaleFactor = evalin('base', 'scaleFactor');
        useECEF = true;
    % else
    %     disp('※ No ECEF alignment: using world coordinates.');
    end

    % --- Find corresponding depth map ---
    [~, baseFileName, ~] = fileparts(imagePath);
    baseFileName = regexprep(baseFileName, '\.geometric$', '', 'ignorecase');
    baseFileName = strtrim(erase(baseFileName, newline));
    allFileNames = {Depthmaps.FileName};
    allFileNames = cellfun(@(x) strtrim(erase(x, newline)), allFileNames, 'UniformOutput', false);
    depthMapIdx = find(contains(lower(allFileNames), lower(baseFileName)), 1);
    if isempty(depthMapIdx), error(['Depth Map not found for image: ', baseFileName]); end
    depthMap = Depthmaps(depthMapIdx).DepthMap;

    binaryMask = imread(binaryMaskPath);
    if size(binaryMask,3) > 1, binaryMask = rgb2gray(binaryMask); end
    binaryMask = logical(binaryMask);
    inputImage = imread(imagePath);

    fx = CameraIntParams.fx; fy = CameraIntParams.fy;
    cx = CameraIntParams.cx; cy = CameraIntParams.cy;
    R = CameraExtParams(depthMapIdx).R;
    t = CameraExtParams(depthMapIdx).t;

    A = planeModel(1); B = planeModel(2); C = planeModel(3); D = planeModel(4);

    [vY, vX] = find(binaryMask);
    zCamera = depthMap(binaryMask);

    nanMaskInROI = binaryMask & isnan(depthMap);
    [nanY, nanX] = find(nanMaskInROI);

    if ~isempty(nanX)
        validDepthMask = binaryMask & ~isnan(depthMap);
        [validY, validX] = find(validDepthMask);
        validZ = depthMap(validDepthMask);
        F = scatteredInterpolant(double(validX), double(validY), double(validZ), 'linear', 'none');
        interpolatedZ = F(double(nanX), double(nanY));
        for i = 1:length(nanX)
            if ~isnan(interpolatedZ(i))
                depthMap(nanY(i), nanX(i)) = interpolatedZ(i);
            end
        end
        zCamera = depthMap(binaryMask);
    end

    validIdx = ~isnan(zCamera);
    vX = vX(validIdx); vY = vY(validIdx); zCamera = zCamera(validIdx);
    pixelIndices = sub2ind(size(depthMap), vY, vX);
    rgbColors = reshape(inputImage, [], 3);
    rgbColors = double(rgbColors(pixelIndices, :)) / 255;

    projPoints = zeros(length(vX), 3);
    correctedDepths = zeros(length(vX), 1);
    pixelAreas = zeros(length(vX), 1);
    for i = 1:length(vX)
        xCam = (vX(i) - cx) * zCamera(i) / fx;
        yCam = (vY(i) - cy) * zCamera(i) / fy;
        point_cam = [xCam; yCam; zCamera(i)];
        point_world = R * point_cam + t;

        normal = [A, B, C];
        if useECEF
            point_ecef = scaleFactor * (point_world' * R_ecef) + t_ecef;
            d = dot(normal, point_ecef) + D;
            point_proj_ecef = point_ecef - (d / norm(normal)^2) * normal;
            projPoints(i, :) = point_proj_ecef;
            point_proj_world = (point_proj_ecef - t_ecef) / scaleFactor;
            point_proj_world = (point_proj_world * R_ecef')';
            point_proj_cam = R' * (point_proj_world - t);
        else
            d = dot(normal, point_world') + D;
            point_proj = point_world' - (d / norm(normal)^2) * normal;
            projPoints(i, :) = point_proj;
            point_proj_cam = R' * (point_proj' - t);
        end

        z = point_proj_cam(3);
        correctedDepths(i) = z;
        depthMap(vY(i), vX(i)) = z;

        if useECEF
            pixelAreas(i) = (z^2 * scaleFactor^2) / (fx * fy);
        else
            pixelAreas(i) = z^2 / (fx * fy);
        end
    end


    % --- Area result ---
    totalArea = sum(pixelAreas, 'omitnan');
    scaleCorr = (1.1157)^2;
    correctedArea = scaleCorr * totalArea * 10000;
    
    imagePathClean = char(imagePath);
    imagePathClean = regexprep(imagePathClean, '[\r\n\t]', '');  
    [~, imgName, ext] = fileparts(imagePathClean);
    
    imgName = regexprep(char(imgName), '[\r\n\t]', '');
    ext     = regexprep(char(ext),     '[\r\n\t]', '');
    
    fullName = [imgName ext];
    fullName = regexprep(fullName, '[\r\n\t]', '');          
        
    fprintf('\n[%s]\n', fullName);
    % fprintf('Raw area: %.6f \n', totalArea);
    fprintf('GNSS-based physical area: %.2f cm^2', correctedArea);



    % Estimate_Depthmaps = Depthmaps;
    % Estimate_Depthmaps(depthMapIdx).DepthMap = depthMap;
    % fullMask = false(size(depthMap));
    % linearIdx = sub2ind(size(depthMap), vY, vX);
    % fullMask(linearIdx) = true;
    % depthMap(~fullMask) = NaN;
    % assignin('base', 'Estimate_Depthmaps', Estimate_Depthmaps);
    % disp('Updated DepthMap saved to Estimate_Depthmaps.');
    % 
    % figure('Color','w');
    % shiftedPts = projPoints - mean(projPoints, 1);
    % scatter3(shiftedPts(:,1), shiftedPts(:,2), shiftedPts(:,3), ...
    %          15, rgbColors, 'filled');
    % xlabel('X'); ylabel('Y'); zlabel('Z');
    % title('Corrected 3D points (RGB)');
    % axis equal; grid on;
    % center = mean(shiftedPts, 1);
    % maxRange = max(range(shiftedPts, 1:3));
    % xlim([center(1)-maxRange/2, center(1)+maxRange/2]);
    % ylim([center(2)-maxRange/2, center(2)+maxRange/2]);
    % zlim([center(3)-maxRange/2, center(3)+maxRange/2]);
    % 
    % figure('Color','w');
    % scatter3(shiftedPts(:,1), shiftedPts(:,2), shiftedPts(:,3), ...
    %          15, pixelAreas, 'filled');
    % xlabel('X'); ylabel('Y'); zlabel('Z');
    % title('Pixel area distribution');
    % colormap turbo; axis equal; grid on;
    % cb = colorbar; 
    % cb.Label.String = 'Pixel Area (m²)';
    % xlim([center(1)-maxRange/2, center(1)+maxRange/2]);
    % ylim([center(2)-maxRange/2, center(2)+maxRange/2]);
    % zlim([center(3)-maxRange/2, center(3)+maxRange/2]);
    % 
    % figure('Color','w');
    % imshow(inputImage); hold on;
    % N = numel(vX); maxPts = 10000;
    % sampledIdx = 1:min(N, maxPts);
    % scatter(vX(sampledIdx), vY(sampledIdx), ...
    %         8, pixelAreas(sampledIdx), 'filled', ...
    %         'MarkerEdgeColor', 'none', 'MarkerFaceAlpha', 0.6);
    % colormap turbo; axis image;
    % 
    % cb = colorbar;
    % cb.Label.String = 'Pixel Area (m²)';
    % 
    % title('Corrected area on image');

end
