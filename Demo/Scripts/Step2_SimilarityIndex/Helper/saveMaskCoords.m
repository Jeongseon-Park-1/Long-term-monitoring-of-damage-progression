function saveMaskCoords(maskFolder)

    files = dir(fullfile(maskFolder, '*.jpg')); 
    n = length(files);

    Masks = struct('filename', [], 'mask', []);

    for i = 1:n
        fname = files(i).name;
        path  = fullfile(maskFolder, fname);

        I = imread(path);

        if ndims(I) == 3
            I = rgb2gray(I);
        end

        BW = double(I > 0); 

        Masks(i).filename = fname;
        Masks(i).mask     = BW;
    end

    assignin('base', 'Masks', Masks);

end
