from PIL import Image, ImageDraw, ImageChops

def fix_icon():
    img_path = "/Users/cbranch/.cursor/projects/Users-cbranch-dev-got-motion/assets/motion-255c8a8e-7c1c-4146-8a0f-36ec206f3805.png"
    img = Image.open(img_path).convert("RGBA")
    
    print(f"Shape: {img.size}")
    
    # Let's create a thresholded black & white version to find the outline
    # The glowing M has bright colors. The background and interior are dark.
    bw = img.convert("L")
    # Threshold: anything brighter than 30 becomes white, else black
    bw = bw.point(lambda p: 255 if p > 50 else 0, mode="1")
    
    # We want to fill the inside of the M. The inside is currently black in `bw`.
    # Let's do a floodfill from the outside corners with white.
    # What's left as black will be the inside of the M.
    bw_fill = bw.copy().convert("RGB")
    ImageDraw.floodfill(bw_fill, (0, 0), (255, 255, 255), thresh=0)
    
    # Check what's left as black
    # The inside of the M should be the only black region (maybe some other tiny artifacts).
    # Let's invert bw_fill.
    # What was black (inside) becomes white. What was white (outside and outline) becomes black.
    inside_mask = ImageChops.invert(bw_fill).convert("L")
    
    # Count pixels inside
    inside_pixels = sum(1 for p in inside_mask.getdata() if p > 128)
    print(f"Inside pixels: {inside_pixels}")
    
    # If the M outline has gaps, floodfill might have filled the inside too!
    # Let's test by saving the mask.
    inside_mask.save("/Users/cbranch/dev/got-motion/test_mask.png")

fix_icon()
