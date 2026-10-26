"""WaveRep G4 model load and image transforms (no pandas; safe for production inference)."""

import torch  # torch>=2.0.1
import timm  # timm>=1.0.12


def create_transform(cropping):
    import torchvision.transforms as transforms

    t = transforms.Compose(
        [
            transforms.CenterCrop((cropping, cropping)),
            transforms.ToTensor(),
            transforms.Normalize(
                mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]
            ),
        ]
    )
    return t


def create_model(weights, arc, cropping, device):
    model = timm.create_model(
        arc, num_classes=1, pretrained=True, img_size=cropping
    )
    model = model.to(device)

    print("loading the model from %s" % weights)
    dat = torch.load(weights, map_location=device)
    if "state_dict" in dat:
        dat = {
            k[6:]: dat["state_dict"][k]
            for k in dat["state_dict"]
            if k.startswith("model")
        }
    model.load_state_dict(dat)
    del dat

    return model
