function saveDepthMaps(folderPath, outputVarName)
% saveDepthMaps("F:\SHML\Data\Bridge_Naegok\Example\Depthmaps","Depthmaps")

    % List all .geometric.bin files in the folder
    depthMapFiles = dir(fullfile(folderPath, '*.jpg.geometric.bin'));
    
    if isempty(depthMapFiles)
        error('No .geometric.bin files found in the specified folder.');
    end

    depthMapStruct = struct('FileName', {}, 'DepthMap', {});

    for i = 1:length(depthMapFiles)
        filePath = fullfile(depthMapFiles(i).folder, depthMapFiles(i).name);
        
        baseName = regexprep(depthMapFiles(i).name, '\.geometric.bin', '');
        
        [depthMap, ~] = read_depth_map(filePath);
        
        depthMapStruct(i).FileName = baseName;
        depthMapStruct(i).DepthMap = depthMap;

        disp(['Processed file: ', depthMapFiles(i).name]);
    end

    assignin('base', outputVarName, depthMapStruct);

    disp(['All depth maps have been saved to struct variable "', outputVarName, '".']);
end
