function saveCameraExtrinsics(varName, filePath)
% saveCameraExtrinsics("CameraExtParams","F:\SHML\Data\Bridge_Naegok\Example\images.txt")
   
    data = readtable(filePath, 'Delimiter', ' ', 'ReadVariableNames', false);

    numImages = size(data, 1);
    cameraExtrinsics = struct('ImageName', [], 'R', [], 't', []);
    
    for i = 1:numImages
        imageName = data{i, 10};  
        qw = data{i, 2};
        qx = data{i, 3};
        qy = data{i, 4};
        qz = data{i, 5};
        tx = data{i, 6};
        ty = data{i, 7};
        tz = data{i, 8};
        
        R = quat2rotm([qw, qx, qy, qz]);
        
        t = [tx; ty; tz];
        
        cameraExtrinsics(i).ImageName = imageName;
        cameraExtrinsics(i).R = R;
        cameraExtrinsics(i).t = t;
    end

    assignin('base', varName, cameraExtrinsics);
end

function R = quat2rotm(quat)
    % quat2rotm - Convert a quaternion to a rotation matrix
    %
    % Input:
    %   quat - Quaternion as [qw, qx, qy, qz]
    %
    % Output:
    %   R - 3x3 rotation matrix

    qw = quat(1);
    qx = quat(2);
    qy = quat(3);
    qz = quat(4);

    % Compute rotation matrix
    R = [1 - 2*qy^2 - 2*qz^2, 2*qx*qy - 2*qz*qw,     2*qx*qz + 2*qy*qw;
         2*qx*qy + 2*qz*qw,     1 - 2*qx^2 - 2*qz^2, 2*qy*qz - 2*qx*qw;
         2*qx*qz - 2*qy*qw,     2*qy*qz + 2*qx*qw,     1 - 2*qx^2 - 2*qy^2];
end
