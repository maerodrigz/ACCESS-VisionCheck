UniversalFakeDetect (UnivFD) weights for ACCESS VisionCheck
===========================================================

Place official UnivFD files here (do NOT rename fc_weights.pth):

1. fc_weights.pth
   Official classifier checkpoint from:
   https://github.com/WisconsinAIVision/UniversalFakeDetect
   (pretrained_weights/fc_weights.pth)

2. ViT-L-14.pt
   OpenAI CLIP ViT-L/14 backbone used by UnivFD (CLIP:ViT-L/14).
   This is NOT included in the UnivFD fc_weights.pth file.
   Obtain from the OpenAI CLIP release (same file clip.load("ViT-L/14") downloads).

Both files must exist before dedicated_ai_probability() runs inference.
The backend does NOT auto-download these files.
