clc;

thisDir = fileparts(mfilename("fullpath"));
demoRoot = fileparts(fileparts(thisDir));      

imgFolder = fullfile(demoRoot, ...
    "Scripts","Step1_CameraPoseEstimation","Data", ...
    "Routine_inspection4_data","SfM","Dense","images");

txtInputPath = fullfile(demoRoot, ...
    "Scripts","Step2_SimilarityIndex","Segmentation_mask", ...
    "Damage_detected_images.txt");

outputFileName = fullfile(thisDir, "Best_Match_Pairs.txt");

alpha = 0.85; 

fid = fopen(txtInputPath, 'r');
if fid == -1, error("File not found: %s", txtInputPath); end
rawOutput = textscan(fid, '%s');
fclose(fid);

if isempty(rawOutput) || isempty(rawOutput{1})
    error("Damage_detected_images.txt none");
end
queryFiles = string(rawOutput{1});

imgFiles = dir(fullfile(imgFolder, "*.jpg"));
refFiles = string({imgFiles(contains({imgFiles.name}, "Ref_")).name});

K_names = lower(string({CameraIntParams.image_name}));
E_names = lower(string({CameraExtParams.ImageName}));
dm_names = lower(string({Depthmaps.FileName}));
Results = struct('Query', {}, 'BestRef', {}, 'MaxPixels', {});

for q = 1:numel(queryFiles)
    qFile_raw = queryFiles(q);
    qFile = lower(qFile_raw);
    [~, qName] = fileparts(qFile);
    
    Kq = CameraIntParams(K_names == qFile);
    Eq = CameraExtParams(E_names == qFile);
    idxDq = find(dm_names == qFile | contains(dm_names, lower(qName)), 1);
    
    if isempty(Kq) || isempty(Eq) || isempty(idxDq)
        Results(q).Query = qFile_raw; Results(q).BestRef = "None"; Results(q).MaxPixels = 0;
        continue; 
    end
    
    Iq = imresize(im2double(imread(fullfile(imgFolder, qFile_raw))), [Kq.height, Kq.width], "nearest");
    Dq = Depthmaps(idxDq).DepthMap;
    [uG, vG] = meshgrid(1:Kq.width, 1:Kq.height);
    u = uG(:); v = vG(:); z = Dq(:); valid = isfinite(z) & z > 0;
    
    Xc_q = [(u(valid) - Kq.cx)./Kq.fx .* z(valid), (v(valid) - Kq.cy)./Kq.fy .* z(valid), z(valid)]';
    Xw = Eq.R' * (Xc_q - Eq.t);
    
    maxPx = -1;
    bestRef = "None";
    
    for r = 1:numel(refFiles)
        rFile_raw = refFiles(r);
        Kr = CameraIntParams(K_names == lower(rFile_raw));
        Er = CameraExtParams(E_names == lower(rFile_raw));
        if isempty(Kr) || isempty(Er), continue; end
        
        Xc_r = Er.R * Xw + Er.t;
        Zr = Xc_r(3,:); front = Zr > 0;
        u2 = Kr.fx .* (Xc_r(1,front)./Zr(front)) + Kr.cx;
        v2 = Kr.fy .* (Xc_r(2,front)./Zr(front)) + Kr.cy;
        u2i = round(u2); v2i = round(v2);
        
        inImg = u2i >= 1 & u2i <= Kr.width & v2i >= 1 & v2i <= Kr.height;
        if ~any(inImg), continue; end
        
        linIdx = sub2ind([Kr.height, Kr.width], v2i(inImg), u2i(inImg));
        numPx = numel(unique(linIdx));
        
        if numPx > maxPx
            maxPx = numPx;
            bestRef = rFile_raw;
        end
    end
    
    Results(q).Query = qFile_raw;
    Results(q).BestRef = bestRef;
    Results(q).MaxPixels = maxPx;
    fprintf("[%d/%d] %s -> %s (%d px)\n", q, numel(queryFiles), qFile_raw, bestRef, maxPx);
end

qGroupNames = strings(numel(Results), 1);
for i = 1:numel(Results)
    token = regexp(Results(i).Query, 'sQuery\d+', 'match', 'once');
    if ~isempty(token), qGroupNames(i) = token; end
end

uniqueGroups = unique(qGroupNames(qGroupNames ~= ""));
for g = 1:numel(uniqueGroups)
    thisGroup = uniqueGroups(g);
    gIdx = find(qGroupNames == thisGroup); 
    groupRefs = [Results(gIdx).BestRef];
    uniqueRefsInG = unique(groupRefs(groupRefs ~= "None"));
    
    for r = 1:numel(uniqueRefsInG)
        targetRef = uniqueRefsInG(r);
        candIdx = gIdx([Results(gIdx).BestRef] == targetRef);
        if numel(candIdx) > 1
            [~, localWinner] = max([Results(candIdx).MaxPixels]);
            winnerIdx = candIdx(localWinner);
            losersIdx = candIdx(candIdx ~= winnerIdx);
            for lIdx = losersIdx
                Results(lIdx).BestRef = "None";
            end
        end
    end
end

fid = fopen(outputFileName, 'w');
for i = 1:numel(Results)
    if Results(i).BestRef ~= "None"
        fprintf(fid, "%s %s\n", Results(i).Query, Results(i).BestRef);
    end
end
fclose(fid);

finalIdx = find([Results.BestRef] ~= "None");
if ~isempty(finalIdx), disp(struct2table(Results(finalIdx))); end

%% 6. VISUALIZE ALL MATCHES
% fprintf("\nVisualizing filtered matches...\n");
% for i = reshape(finalIdx, 1, [])
%     qData = Results(i);
%     Kq = CameraIntParams(K_names == lower(qData.Query));
%     Eq = CameraExtParams(E_names == lower(qData.Query));
%     Kr = CameraIntParams(K_names == lower(qData.BestRef));
%     Er = CameraExtParams(E_names == lower(qData.BestRef));
% 
%     [~, qNameOnly] = fileparts(qData.Query);
%     idxDq = find(contains(dm_names, lower(qNameOnly)), 1);
%     Dq = Depthmaps(idxDq).DepthMap;
%     Iq = imresize(im2double(imread(fullfile(imgFolder, qData.Query))), [Kq.height, Kq.width], "nearest");
%     Ir = imresize(im2double(imread(fullfile(imgFolder, qData.BestRef))), [Kr.height, Kr.width], "nearest");
% 
%     [uG, vG] = meshgrid(1:Kq.width, 1:Kq.height);
%     u = uG(:); v = vG(:); z = Dq(:); valid = isfinite(z) & z > 0;
%     Xc_q = [(u(valid) - Kq.cx)./Kq.fx .* z(valid), (v(valid) - Kq.cy)./Kq.fy .* z(valid), z(valid)]';
%     Xw = Eq.R' * (Xc_q - Eq.t);
% 
%     Xc_r = Er.R * Xw + Er.t;
%     Zr = Xc_r(3,:); front = Zr > 0;
%     u2 = Kr.fx .* (Xc_r(1,front)./Zr(front)) + Kr.cx;
%     v2 = Kr.fy .* (Xc_r(2,front)./Zr(front)) + Kr.cy;
%     u2i = round(u2); v2i = round(v2);
%     inImg = u2i >= 1 & u2i <= Kr.width & v2i >= 1 & v2i <= Kr.height;
% 
%     linIdx = sub2ind([Kr.height, Kr.width], v2i(inImg), u2i(inImg));
%     Zr_f = Zr(front); Zr_f = Zr_f(inImg);
%     [~, ord] = sort(Zr_f, "ascend");
%     [linU, ia] = unique(linIdx(ord), "stable");
% 
%     Cq_full = reshape(Iq, [], 3); Cq_valid = Cq_full(valid,:);
%     Cq_loop = Cq_valid(front,:); Cq_loop = Cq_loop(inImg,:);
%     selC = Cq_loop(ord,:); selC = selC(ia,:);
% 
%     overlay = Ir;
%     projMask = false(Kr.height, Kr.width); projMask(linU) = true;
%     for c = 1:3
%         ch = overlay(:,:,c); pj = zeros(Kr.height, Kr.width);
%         pj(linU) = selC(:,c);
%         ch(projMask) = (1-alpha) * ch(projMask) + alpha * pj(projMask);
%         overlay(:,:,c) = ch;
%     end
% 
%     figure('Name', sprintf("Match: %s", qNameOnly), 'Color', 'w');
%     imshow(overlay);
%     title(sprintf("Query: %s \\rightarrow Ref: %s (%d px)", ...
%           qData.Query, qData.BestRef, qData.MaxPixels), 'Interpreter', 'tex');
%     drawnow;
% end
