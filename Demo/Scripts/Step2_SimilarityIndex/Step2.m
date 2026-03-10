clc

workspacePath = "Scripts\Step1_CameraPoseEstimation\Data\Workspace\workspace.mat";

if exist(workspacePath, "file")
    load(workspacePath);
end;

thisDir = fileparts(mfilename("fullpath"));
demoRoot = fileparts(fileparts(thisDir));

imageDir = fullfile(demoRoot,"Data","Images");
listPath = fullfile(demoRoot,"Scripts","Step2_SimilarityIndex","out_of_bridge.txt");
depthFolderPath = fullfile(demoRoot, ...
    "Scripts","Step1_CameraPoseEstimation","Data","Depthmaps");

try
    SCF = scalefactor(imageDir,listPath);
    assignin("base","SCF",SCF);
    fprintf("SCF: %.12f\n",SCF);
catch ME
    fprintf("SCF calculation skipped: %s\n", ME.message);
end

fprintf("Updating Depthmaps from: %s\n", depthFolderPath);
Depthmaps = saveDepthMapFileList(depthFolderPath,"Depthmaps");
assignin("base","DepthMapFiles",Depthmaps);

txtInputPath = fullfile(demoRoot, ...
    "Scripts","Step2_SimilarityIndex","Segmentation_mask", ...
    "Damage_detected_images.txt");

if ~evalin("base","exist('CameraIntParams','var')")
    error("CameraIntParams not found in base workspace.");
end
if ~evalin("base","exist('CameraExtParams','var')")
    error("CameraExtParams not found in base workspace.");
end
if ~evalin("base","exist('Depthmaps','var')")
    error("Depthmaps not found in base workspace.");
end

CameraIntParams = evalin("base","CameraIntParams");
CameraExtParams = evalin("base","CameraExtParams");
Depthmaps       = evalin("base","Depthmaps");

K_names  = lower(strtrim(string({CameraIntParams.image_name})));
E_names  = lower(strtrim(string({CameraExtParams.ImageName})));
DM_names = lower(strtrim(string({Depthmaps.FileName})));

refMask = contains(E_names,"ref_");
refFiles = string({CameraExtParams(refMask).ImageName});
refFiles = unique(refFiles);

fid = fopen(txtInputPath,'r');
if fid == -1
    error("File not found: %s", txtInputPath);
end
rawOutput = textscan(fid,'%s');
fclose(fid);

if isempty(rawOutput) || isempty(rawOutput{1})
    error("Damage_detected_images.txt none");
end
queryFiles = string(rawOutput{1});

nQuery = numel(queryFiles);
nRef = numel(refFiles);
updateEvery = 1;
sampleStep = 16;
topN = 5;

BestPairs = strings(0,2);
Top5Pairs = struct("Query",{}, "Refs",{}, "Scores",{});

fprintf("\nMatching queries to references using full-image pixels...\n")

for q = 1:nQuery

    qFile_raw_input = string(strtrim(queryFiles(q)));

    if startsWith(lower(qFile_raw_input), "ref_")
        fprintf("\n[%d/%d] %s -> skipped (Ref image)\n", q, nQuery, qFile_raw_input);
        continue
    end

    qFile_raw = normalizeQueryName(qFile_raw_input);
    qFile = lower(qFile_raw);

    [~, qName, ~] = fileparts(qFile_raw);

    fprintf("\n[%d/%d] Query: %s\n", q, nQuery, qFile_raw_input);

    idxKq = find(K_names == qFile,1);
    idxEq = find(E_names == qFile,1);
    idxDq = find(DM_names == qFile,1);

    if isempty(idxKq), idxKq = find(contains(K_names, lower(qName)),1); end
    if isempty(idxEq), idxEq = find(contains(E_names, lower(qName)),1); end
    if isempty(idxDq), idxDq = find(contains(DM_names, lower(qName)),1); end

    if isempty(idxKq) || isempty(idxEq) || isempty(idxDq)
        fprintf("   skipped (missing K/E/Depth)\n");
        continue
    end

    Kq = CameraIntParams(idxKq);
    Eq = CameraExtParams(idxEq);

    try
        Dq = readDepthMapColmap(Depthmaps(idxDq).FilePath);
    catch ME
        fprintf("   skipped (depth read fail: %s)\n", ME.message);
        continue
    end

    if size(Dq,1) ~= Kq.height || size(Dq,2) ~= Kq.width
        Dq = imresize(Dq,[Kq.height,Kq.width],"nearest");
    end

    u = 1:sampleStep:Kq.width;
    v = 1:sampleStep:Kq.height;
    [uG, vG] = meshgrid(u, v);

    uAll = uG(:);
    vAll = vG(:);

    linAll = sub2ind([Kq.height, Kq.width], vAll, uAll);
    z = double(Dq(linAll));

    valid = isfinite(z) & z > 0;
    if ~any(valid)
        fprintf("   skipped (no valid depth in full image)\n");
        continue
    end

    u = double(uAll(valid));
    v = double(vAll(valid));
    z = double(z(valid));

    Xc_q = [ ...
        ((u-Kq.cx)./Kq.fx).*z, ...
        ((v-Kq.cy)./Kq.fy).*z, ...
        z]';

    Xw = Eq.R' * (Xc_q - Eq.t(:));

    allScores = zeros(nRef,1);

    for r = 1:nRef

        if r == 1 || mod(r,updateEvery) == 0 || r == nRef
            fprintf('   refs checked: %4d / %4d', r, nRef);
            if r < nRef
                fprintf('\r');
            else
                fprintf('\n');
            end
        end

        rFile_raw = string(refFiles(r));
        rFile = lower(strtrim(rFile_raw));

        idxKr = find(K_names == rFile,1);
        idxEr = find(E_names == rFile,1);

        if isempty(idxKr) || isempty(idxEr)
            continue
        end

        Kr = CameraIntParams(idxKr);
        Er = CameraExtParams(idxEr);

        Xc_r = Er.R * Xw + Er.t(:);
        Zr = Xc_r(3,:);

        front = Zr > 0;
        if ~any(front)
            continue
        end

        u2 = Kr.fx .* (Xc_r(1,front)./Zr(front)) + Kr.cx;
        v2 = Kr.fy .* (Xc_r(2,front)./Zr(front)) + Kr.cy;

        u2i = round(u2);
        v2i = round(v2);

        inImg = u2i >= 1 & u2i <= Kr.width & v2i >= 1 & v2i <= Kr.height;
        if ~any(inImg)
            continue
        end

        linIdx = sub2ind([Kr.height Kr.width], v2i(inImg), u2i(inImg));
        allScores(r) = numel(unique(linIdx));
    end

    validRefIdx = find(allScores > 0);
    if isempty(validRefIdx)
        fprintf("   done -> no valid ref found\n");
        continue
    end

    validScores = allScores(validRefIdx);
    validRefs = refFiles(validRefIdx);

    [sortedScores, sortIdx] = sort(validScores, "descend");
    sortedRefs = validRefs(sortIdx);

    keepN = min(topN, numel(sortedRefs));
    topRefs = sortedRefs(1:keepN);
    topScores = sortedScores(1:keepN);

    BestPairs(end+1,:) = [qFile_raw_input, topRefs(1)];

    Top5Pairs(end+1).Query = qFile_raw_input;
    Top5Pairs(end).Refs = topRefs;
    Top5Pairs(end).Scores = topScores;

    fprintf("   done -> best ref: %s | overlap: %d\n", topRefs(1), topScores(1));
    fprintf("   Top %d refs:\n", keepN);
    for k = 1:keepN
        fprintf("      %d) %s | %d\n", k, topRefs(k), topScores(k));
    end
end

assignin("base","BestPairs",BestPairs);
assignin("base","Top5Pairs",Top5Pairs);

fprintf("\nFinished.\n");
fprintf("Final BestPairs: %d\n\n", size(BestPairs,1));

disp("Best Matching Pairs:");
disp(BestPairs);

disp("Top5Pairs saved to base workspace.");

function Depthmaps = saveDepthMapFileList(folderPath, outputVarName)
if nargin < 2 || strlength(string(outputVarName)) == 0
    outputVarName = "Depthmaps";
end

folderPath = string(folderPath);
if ~isfolder(folderPath)
    error("Depth map folder not found: %s", folderPath);
end

depthMapFiles = dir(fullfile(folderPath, '*.jpg.geometric.bin'));

if isempty(depthMapFiles)
    error("No .geometric.bin files found in the specified folder.");
end

Depthmaps = struct('FileName', {}, 'FilePath', {});

for i = 1:numel(depthMapFiles)
    filePath = fullfile(depthMapFiles(i).folder, depthMapFiles(i).name);
    baseName = regexprep(depthMapFiles(i).name, '\.geometric\.bin$', '');

    Depthmaps(i).FileName = baseName;
    Depthmaps(i).FilePath = filePath;
end

assignin('base', char(outputVarName), Depthmaps);
fprintf('Depth map file list saved to "%s".\n', char(outputVarName));
end

function outName = normalizeQueryName(inName)
inName = string(strtrim(inName));
tok = regexp(inName, '^(sQuery\d+)_(\d+)(\.jpg)$', 'tokens', 'once', 'ignorecase');
if isempty(tok)
    outName = inName;
    return
end
prefix = string(tok{1});
numStr = string(tok{2});
ext = string(tok{3});
numVal = str2double(numStr);
if isnan(numVal)
    outName = inName;
    return
end
outName = string(sprintf('%s_%03d%s', char(prefix), numVal, char(ext)));
end

function depth = readDepthMapColmap(filePath)
fid = fopen(filePath,'rb');
if fid == -1
    error("Cannot open depth map: %s", filePath);
end

c = onCleanup(@() fclose(fid));

header = '';
numAmp = 0;

while numAmp < 3
    ch = fread(fid,1,'*char');
    if isempty(ch)
        error("Invalid COLMAP depth map header: %s", filePath);
    end
    header(end+1) = ch;
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
