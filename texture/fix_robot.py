python3 << 'EOF'
from PIL import Image

Image.MAX_IMAGE_PIXELS = None

# step 1: open cursed png
img = Image.open('robot_wtf.png')
print("loaded the cursed file ✅")

# step 2: convert to RGBA clean
img = img.convert('RGBA')
print("converted to RGBA ✅")

# step 3: save as TIFF (nukes ALL png-specific metadata)
img.save('robot_temp.tiff', 'TIFF')
print("saved as TIFF (metadata NUKED) ✅")

# step 4: reload from TIFF (fresh start no bs)
img_clean = Image.open('robot_temp.tiff')
print("reloaded from TIFF ✅")

# step 5: save as clean PNG
img_clean.save('robot_godot_final.png', 'PNG', compress_level=6, optimize=False)
print("saved as clean PNG ✅✅✅")

# cleanup
import os
os.remove('robot_temp.tiff')
print("COOKED AND CLEANED FR FR 💯")
EOF
