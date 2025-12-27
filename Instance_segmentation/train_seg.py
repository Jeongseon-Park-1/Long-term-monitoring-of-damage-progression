from ultralytics import YOLO
import torch

if __name__ == '__main__':
    import torch
    print("CUDA is available:", torch.cuda.is_available())
    print("Number of CUDA devices:", torch.cuda.device_count())
    print("CUDA device name:", torch.cuda.get_device_name(0) if torch.cuda.is_available() else "No CUDA device found")
    print("CUDA version:", torch.version.cuda)
    print("PyTorch version:", torch.__version__)
    model = YOLO("yolov8m-seg.yaml")
    ## model.train(data= [data route] , epochs=150, imgsz=640, batch=16)
