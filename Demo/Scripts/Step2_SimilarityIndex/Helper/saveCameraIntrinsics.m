function CameraIntParams = saveCameraIntrinsics2( ...
    imagesTxtPath, camerasTxtPath, depthmapsVarName, outputVarName)

% buildPinholeIntrinsicsFromCOLMAP
% - SIMPLE_RADIAL camera model -> PINHOLE 근사
% - depth map 해상도에 맞게 intrinsics 스케일 조정
% - 이미지별 intrinsics를 CameraIntParams 구조체 배열로 저장
%
% Output:
%   CameraIntParams(i).fx, fy, cx, cy, width, height, image_name

    if nargin < 3 || isempty(depthmapsVarName)
        depthmapsVarName = "Depthmaps";
    end
    if nargin < 4 || isempty(outputVarName)
        outputVarName = "CameraIntParams";
    end

    Depthmaps = evalin('base', char(depthmapsVarName));

    %% ---------- Read cameras.txt ----------
    camLines = readlines(camerasTxtPath);
    camLines = strip(camLines);
    camLines = camLines(camLines ~= "" & ~startsWith(camLines, "#"));

    camDB = struct();
    for i = 1:numel(camLines)
        t = split(camLines(i));
        camId = str2double(t(1));
        camDB.(sprintf("id_%d",camId)) = struct( ...
            'model', t(2), ...
            'W', str2double(t(3)), ...
            'H', str2double(t(4)), ...
            'params', str2double(t(5:end)) );
    end

    %% ---------- Read images.txt ----------
    imgLines = readlines(imagesTxtPath);
    imgLines = strip(imgLines);
    imgLines = imgLines(imgLines ~= "" & ~startsWith(imgLines, "#"));

    imgInfo = struct('name',{},'camera_id',{});
    for i = 1:numel(imgLines)
        t = split(imgLines(i));
        if numel(t) >= 10 && ~isnan(str2double(t(2)))
            imgInfo(end+1).camera_id = str2double(t(9));
            imgInfo(end).name = string(t(10));
        end
    end

    depthNames = string({Depthmaps.FileName});

    %% ---------- Build CameraIntParams ----------
    CameraIntParams = struct( ...
        'image_name',{}, ...
        'fx',{}, 'fy',{}, ...
        'cx',{}, 'cy',{}, ...
        'width',{}, 'height',{} );

    for i = 1:numel(imgInfo)

        cam = camDB.(sprintf("id_%d", imgInfo(i).camera_id));

        if cam.model ~= "SIMPLE_RADIAL"
            error("Only SIMPLE_RADIAL cameras are supported.");
        end

        % SIMPLE_RADIAL params: [f, cx, cy, k1]
        f  = cam.params(1);
        cx = cam.params(2);
        cy = cam.params(3);

        imgBase = erase(imgInfo(i).name, ".jpg");
        dIdx = find(contains(lower(depthNames), lower(imgBase)), 1);
        if isempty(dIdx)
            continue;
        end

        D = Depthmaps(dIdx).DepthMap;
        Hd = size(D,1);
        Wd = size(D,2);

        sx = Wd / cam.W;
        sy = Hd / cam.H;

        CameraIntParams(end+1) = struct( ...
            'image_name', imgInfo(i).name, ...
            'fx', f*sx, ...
            'fy', f*sy, ...
            'cx', cx*sx, ...
            'cy', cy*sy, ...
            'width',  Wd, ...
            'height', Hd );
    end

    assignin('base', outputVarName, CameraIntParams);

    fprintf("Saved CameraIntParams (%d images)\n", numel(CameraIntParams));
end
