function CameraIntParams = saveCameraIntrinsics(imagesTxtPath, camerasTxtPath, depthmapsVarName, outputVarName)

if nargin < 3 || isempty(depthmapsVarName), depthmapsVarName = "Depthmaps"; end
if nargin < 4 || isempty(outputVarName),   outputVarName   = "CameraIntParams"; end

Depthmaps = evalin("base", char(depthmapsVarName));
depthNames = string({Depthmaps.FileName});

%% ---- read cameras.txt ----
camLines = readlines(camerasTxtPath);
camLines = strip(camLines);
camLines = camLines(camLines ~= "" & ~startsWith(camLines, "#"));

camDB = struct();
for i = 1:numel(camLines)
    t = split(camLines(i));
    camId = str2double(t(1));

    model = string(t(2));
    W = str2double(t(3));
    H = str2double(t(4));
    params = str2double(t(5:end));

    camDB.(sprintf("id_%d", camId)) = struct("model", model, "W", W, "H", H, "params", params);
end

%% ---- read images.txt ----
imgLines = readlines(imagesTxtPath);
imgLines = strip(imgLines);
imgLines = imgLines(imgLines ~= "" & ~startsWith(imgLines, "#"));

imgInfo = struct("name", {}, "camera_id", {});
for i = 1:numel(imgLines)
    t = split(imgLines(i));

    if numel(t) >= 10 && ~isnan(str2double(t(2)))
        imgInfo(end+1).camera_id = str2double(t(9)); 
        imgInfo(end).name = string(t(10));
    end
end

%% ---- build CameraIntParams ----
CameraIntParams = struct("image_name", {}, "fx", {}, "fy", {}, "cx", {}, "cy", {}, "width", {}, "height", {});

for i = 1:numel(imgInfo)
    camKey = sprintf("id_%d", imgInfo(i).camera_id);
    if ~isfield(camDB, camKey), continue; end
    cam = camDB.(camKey);

    if cam.model ~= "PINHOLE"
        error("Only PINHOLE cameras are supported. Found: %s", cam.model);
    end
    if numel(cam.params) < 4
        error("PINHOLE params must be [fx fy cx cy]. camera_id=%d", imgInfo(i).camera_id);
    end

    fx0 = cam.params(1);
    fy0 = cam.params(2);
    cx0 = cam.params(3);
    cy0 = cam.params(4);

    imgBase = erase(imgInfo(i).name, ".jpg");
    imgBase = erase(imgBase, ".JPG");
    dIdx = find(contains(lower(depthNames), lower(imgBase)), 1);
    if isempty(dIdx), continue; end

    D = Depthmaps(dIdx).DepthMap;
    Hd = size(D,1);
    Wd = size(D,2);

    sx = Wd / cam.W;
    sy = Hd / cam.H;

    CameraIntParams(end+1) = struct( ...
        "image_name", imgInfo(i).name, ...
        "fx", fx0*sx, ...
        "fy", fy0*sy, ...
        "cx", cx0*sx, ...
        "cy", cy0*sy, ...
        "width",  Wd, ...
        "height", Hd ); 
end

assignin("base", outputVarName, CameraIntParams);
fprintf("Saved %s (%d images)\n", outputVarName, numel(CameraIntParams));
end