function saveCameraIntrinsics(varName, fx, fy, cx, cy, width, height)
    % saveCameraIntrinsics("CameraIntParams",2936.7185,2936.7185,1979,1113,3958,2226)

    cameraParams.fx = fx;
    cameraParams.fy = fy;
    cameraParams.cx = cx;
    cameraParams.cy = cy;
    cameraParams.width = width;
    cameraParams.height = height;
    
    assignin('base', varName, cameraParams);
end

