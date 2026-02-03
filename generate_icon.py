from PIL import Image, ImageDraw

def create_paw_icon(size=1024):
    # Colors
    bg_color = (255, 171, 145) # #FFAB91 (kPrimaryColor)
    fg_color = (255, 255, 255) # White

    # Create image
    img = Image.new('RGB', (size, size), bg_color)
    draw = ImageDraw.Draw(img)

    # Calculate dimensions
    center_x = size // 2
    center_y = size // 2
    
    # Main pad (large circle)
    pad_radius = size * 0.25
    pad_y = center_y + size * 0.1
    draw.ellipse([
        center_x - pad_radius, pad_y - pad_radius * 0.85, # slightly flattened
        center_x + pad_radius, pad_y + pad_radius * 0.85
    ], fill=fg_color)

    # Toes (4 smaller circles)
    toe_radius = size * 0.1
    toe_y_base = center_y - size * 0.2
    
    # Toe positions (angles roughly: -45, -15, 15, 45 degrees relative to vertical)
    # But simplified with coordinates
    
    # Inner toes
    draw.ellipse([
        center_x - size * 0.15 - toe_radius, toe_y_base - size * 0.05 - toe_radius,
        center_x - size * 0.15 + toe_radius, toe_y_base - size * 0.05 + toe_radius
    ], fill=fg_color)
    
    draw.ellipse([
        center_x + size * 0.15 - toe_radius, toe_y_base - size * 0.05 - toe_radius,
        center_x + size * 0.15 + toe_radius, toe_y_base - size * 0.05 + toe_radius
    ], fill=fg_color)

    # Outer toes
    outer_toe_y = toe_y_base + size * 0.1
    draw.ellipse([
        center_x - size * 0.38 - toe_radius, outer_toe_y - toe_radius,
        center_x - size * 0.38 + toe_radius, outer_toe_y + toe_radius
    ], fill=fg_color)
    
    draw.ellipse([
        center_x + size * 0.38 - toe_radius, outer_toe_y - toe_radius,
        center_x + size * 0.38 + toe_radius, outer_toe_y + toe_radius
    ], fill=fg_color)

    # Save
    img.save('assets/icon/app_icon.png')
    print("Icon created at assets/icon/app_icon.png")

if __name__ == "__main__":
    create_paw_icon()
