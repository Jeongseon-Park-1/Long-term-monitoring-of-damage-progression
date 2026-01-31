function [scaleFactor, T] = scalefactor(imageDir)

if ~evalin("base","exist('CameraExtParams','var')")
    error("CameraExtParams not found in base workspace.");
end
P = evalin("base","CameraExtParams");

imageDir = string(imageDir);
if ~isfolder(imageDir)
    error("Image directory not found: %s", imageDir);
end

exts = ["*.jpg","*.jpeg","*.png","*.JPG","*.JPEG","*.PNG"];
files = [];
for k = 1:numel(exts)
    files = [files; dir(fullfile(imageDir, exts(k)))];
end
if isempty(files)
    error("No images found in: %s", imageDir);
end

gpsMap = containers.Map('KeyType','char','ValueType','any');
for i = 1:numel(files)
    fpath = fullfile(files(i).folder, files(i).name);
    try
        info = imfinfo(fpath);
    catch
        continue;
    end
    if ~isfield(info,"GPSInfo"), continue; end
    gps = info.GPSInfo;
    if ~isfield(gps,"GPSLatitude") || ~isfield(gps,"GPSLongitude"), continue; end

    lat = parseGPS(gps,"GPSLatitude","GPSLatitudeRef");
    lon = parseGPS(gps,"GPSLongitude","GPSLongitudeRef");
    if isnan(lat) || isnan(lon), continue; end

    alt = 0;
    if isfield(gps,"GPSAltitude")
        alt = double(gps.GPSAltitude);
        if isfield(gps,"GPSAltitudeRef") && double(gps.GPSAltitudeRef)==1
            alt = -alt;
        end
    end

    gpsMap(char(lower(string(files(i).name)))) = [lat lon alt];
end

[names, Cw] = getCameraCenters(P);
names = lower(strip(names));

idx = [];
llh = [];

for i = 1:numel(names)
    key = char(names(i));
    if isKey(gpsMap, key)
        idx(end+1,1) = i; 
        llh(end+1,:) = gpsMap(key); 
    end
end

if numel(idx) < 3
    error("Need at least 3 images with both CameraExtParams and EXIF GPS.");
end

Cw = Cw(idx,:);
enu = llh2enu(llh(:,1), llh(:,2), llh(:,3));

[res,~,tr] = procrustes(enu, Cw, 'Scaling', true, 'Reflection', false);
scaleFactor = tr.b;

T.scale = tr.b;
T.rotation = tr.T;
T.translation = tr.c(1,:);
T.residual = res;
T.matchedCount = numel(idx);
T.usedImageNames = names(idx);

end

function deg = parseGPS(gps, valField, refField)
v = double(gps.(valField));
if numel(v)==3
    deg = v(1)+v(2)/60+v(3)/3600;
else
    deg = v(1);
end
if isfield(gps,refField)
    r = string(gps.(refField));
    if r=="S" || r=="W"
        deg = -deg;
    end
end
end

function [names, Cw] = getCameraCenters(P)
names = string({P.ImageName});
n = numel(P);
Cw = zeros(n,3);
for i = 1:n
    R = double(P(i).R);
    t = double(P(i).t(:));
    Cw(i,:) = (-R' * t).';
end
end

function enu = llh2enu(lat, lon, h)
lat0 = mean(lat);
lon0 = mean(lon);
h0   = mean(h);

[x,y,z] = llh2ecef(lat,lon,h);
[x0,y0,z0] = llh2ecef(lat0,lon0,h0);

dx=x-x0; dy=y-y0; dz=z-z0;

phi=deg2rad(lat0);
lam=deg2rad(lon0);

R=[-sin(lam) cos(lam) 0;
   -sin(phi)*cos(lam) -sin(phi)*sin(lam) cos(phi);
    cos(phi)*cos(lam)  cos(phi)*sin(lam) sin(phi)];

enu=(R*[dx';dy';dz'])';
end

function [x,y,z] = llh2ecef(lat, lon, h)
a=6378137;
f=1/298.257223563;
e2=f*(2-f);

lat=deg2rad(lat);
lon=deg2rad(lon);

N=a./sqrt(1-e2*(sin(lat).^2));

x=(N+h).*cos(lat).*cos(lon);
y=(N+h).*cos(lat).*sin(lon);
z=(N*(1-e2)+h).*sin(lat);
end
