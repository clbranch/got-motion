from PIL import Image, ImageOps
import os

img_path = "/Users/cbranch/Downloads/motion_icon_1024_final.png"
if not os.path.exists(img_path):
    print(f"File not found: {img_path}")
else:
    img = Image.open(img_path).convert("RGBA")
    print("Original size:", img.size)
    
    # Get bounding box of the non-black/non-transparent content
    # First, let's find the most common color (likely background)
    colors = img.getcolors(1024*1024)
    colors.sort(reverse=True, key=lambda x: x[0])
    bg_color = colors[0][1]
    print("Likely background color:", bg_color)
