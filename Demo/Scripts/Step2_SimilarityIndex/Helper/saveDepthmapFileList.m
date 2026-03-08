function DepthMapFiles = saveDepthMapFileList(folderPath, outputVarName)

    if nargin < 2 || strlength(string(outputVarName)) == 0
        outputVarName = "DepthMapFiles";
    end

    depthMapFiles = dir(fullfile(folderPath, '*.jpg.geometric.bin'));

    if isempty(depthMapFiles)
        error('No .geometric.bin files found in the specified folder.');
    end

    DepthMapFiles = struct('FileName', {}, 'FilePath', {});

    for i = 1:length(depthMapFiles)
        filePath = fullfile(depthMapFiles(i).folder, depthMapFiles(i).name);
        baseName = regexprep(depthMapFiles(i).name, '\.geometric\.bin$', '');

        DepthMapFiles(i).FileName = baseName;
        DepthMapFiles(i).FilePath = filePath;
    end

    assignin('base', outputVarName, DepthMapFiles);
    disp(['Depth map file list saved to "', char(outputVarName), '".']);
end
