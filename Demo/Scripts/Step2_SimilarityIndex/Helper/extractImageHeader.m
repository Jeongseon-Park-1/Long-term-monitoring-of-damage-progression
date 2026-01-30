function extractImageHeader(inputFilePath, outputFilePath)
    % extractImageHeader - Extracts lines containing image names and sorts by IMAGE_ID
    % 
    % Inputs:
    %   inputFilePath - Path to the input text file
    %   outputFilePath - Path to the output text file

    fid = fopen(inputFilePath, 'r');
    if fid == -1
        error('Unable to open input file: %s', inputFilePath);
    end

    fileLines = textscan(fid, '%s', 'Delimiter', '\n');
    fclose(fid);

    fileLines = fileLines{1};

    fileLines(1:4) = [];

    filteredData = {}; 

    for i = 1:length(fileLines)
        line = fileLines{i};

        if contains(line, '.jpg', 'IgnoreCase', true)
            parts = strsplit(line, ' ');
            IMAGE_ID = str2double(parts{1});
            filteredData(end + 1, :) = [{IMAGE_ID}, parts(2:end)]; %#ok<AGROW>
        end
    end

    filteredTable = cell2table(filteredData, ...
        'VariableNames', {'IMAGE_ID', 'QW', 'QX', 'QY', 'QZ', 'TX', 'TY', 'TZ', 'CAMERA_ID', 'NAME'});

    sortedTable = sortrows(filteredTable, 'IMAGE_ID');

    fid = fopen(outputFilePath, 'w');
    if fid == -1
        error('Unable to open output file: %s', outputFilePath);
    end

    for i = 1:height(sortedTable)
        fprintf(fid, '%d %s %s %s %s %s %s %s %s %s\n', ...
            sortedTable.IMAGE_ID(i), ...
            sortedTable.QW{i}, ...
            sortedTable.QX{i}, ...
            sortedTable.QY{i}, ...
            sortedTable.QZ{i}, ...
            sortedTable.TX{i}, ...
            sortedTable.TY{i}, ...
            sortedTable.TZ{i}, ...
            sortedTable.CAMERA_ID{i}, ...
            sortedTable.NAME{i});
    end

    fclose(fid);
    disp('Filtered and sorted data saved to output file.');
end
