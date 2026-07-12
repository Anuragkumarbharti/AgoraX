import os

# Minimal 1x1 transparent PNG bytes
MINIMAL_PNG = b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15c4\x00\x00\x00\rIDATx\x9cc`\x00\x00\x00\x02\x00\x01H\xaf\xa4q\x00\x00\x00\x00IEND\xaeB`\x82'

# Minimal 1x1 JPEG bytes
MINIMAL_JPG = b'\xff\xd8\xff\xdb\x00C\x00\x08\x06\x06\x07\x06\x05\x08\x07\x07\x07\t\t\x08\n\x0c\x14\r\x0c\x0b\x0b\x0c\x19\x12\x13\x0f\x14\x1d\x1a\x1f\x1e\x1d\x1a\x1c\x1c $.\' ",#\x1c\x1c(7),01444\x1f\'9=82<.342\xff\xc0\x00\x0b\x08\x00\x01\x00\x01\x01\x01\x11\x00\xff\xc4\x00\x1f\x00\x00\x01\x05\x01\x01\x01\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x01\x02\x03\x04\x05\x06\x07\x08\t\n\x0b\xff\xda\x00\x08\x01\x01\x00\x00?\x00\x37\xff\xd9'

# Minimal JSON theme
MINIMAL_JSON = b'{\n  "primaryColor": "#FFFFFF",\n  "secondaryColor": "#000000",\n  "accentColor": "#888888"\n}'

base_dir = "assets/images/cosmetics"

# 6 active collections
active_dirs = [
    "vip_1", "vip_2", "vip_3",
    "novel_1", "novel_2", "novel_3"
]

# Coming Soon collections
coming_soon_dirs = [
    "vip_4", "vip_5", "vip_6", "vip_7",
    "novel_4", "novel_5", "novel_6", "novel_7", "novel_8"
]

# Asset list per collection
png_assets = ["frame.png", "bubble.png", "badge.png", "tag.png", "gift.png", "thumb.png"]
webp_assets = ["frame.webp", "bubble_anim.webp", "name_glow.webp", "aura.webp", "badge_anim.webp", "tag_anim.webp", "gift.webp"]
webm_assets = ["entry.webm"]

emojis = ["laugh", "cry", "love", "wow", "angry", "celebrate", "victory", "magic", "royal", "galaxy"]

def create_files():
    print("Starting placeholder asset generation...")
    os.makedirs(base_dir, exist_ok=True)
    
    # 1. Create active collections
    for folder in active_dirs:
        folder_path = os.path.join(base_dir, folder)
        os.makedirs(folder_path, exist_ok=True)
        print(f"Creating files in: {folder_path}")
        
        # PNGs
        for asset in png_assets:
            with open(os.path.join(folder_path, asset), "wb") as f:
                f.write(MINIMAL_PNG)
        # WebPs (empty files or 1x1 PNG mapped)
        for asset in webp_assets:
            with open(os.path.join(folder_path, asset), "wb") as f:
                f.write(MINIMAL_PNG)  # Flutter can often decode PNG renamed to WebP as fallback
        # WebMs
        for asset in webm_assets:
            with open(os.path.join(folder_path, asset), "wb") as f:
                f.write(b"") # Empty webm
        # Theme JSON
        with open(os.path.join(folder_path, "theme.json"), "wb") as f:
            f.write(MINIMAL_JSON)
        # Background JPG
        with open(os.path.join(folder_path, "bg.jpg"), "wb") as f:
            f.write(MINIMAL_JPG)
        # Store Preview Card JPG
        with open(os.path.join(folder_path, "preview.jpg"), "wb") as f:
            f.write(MINIMAL_JPG)
            
        # Create Emojis Subdirectory
        emojis_dir = os.path.join(folder_path, "emojis")
        os.makedirs(emojis_dir, exist_ok=True)
        for emoji in emojis:
            with open(os.path.join(emojis_dir, f"{emoji}.png"), "wb") as f:
                f.write(MINIMAL_PNG)
            with open(os.path.join(emojis_dir, f"{emoji}_anim.webp"), "wb") as f:
                f.write(MINIMAL_PNG)
                
    # 2. Create Coming Soon placeholders
    for folder in coming_soon_dirs:
        folder_path = os.path.join(base_dir, folder)
        os.makedirs(folder_path, exist_ok=True)
        print(f"Creating Coming Soon files in: {folder_path}")
        
        # Basic PNG placeholders so asset loading doesn't throw errors
        all_assets = png_assets + webp_assets + webm_assets + ["theme.json", "bg.jpg", "preview.jpg"]
        for asset in all_assets:
            filepath = os.path.join(folder_path, asset)
            if asset.endswith(".json"):
                with open(filepath, "wb") as f:
                    f.write(MINIMAL_JSON)
            elif asset.endswith(".jpg"):
                with open(filepath, "wb") as f:
                    f.write(MINIMAL_JPG)
            else:
                with open(filepath, "wb") as f:
                    f.write(MINIMAL_PNG)
                    
        # Emoji directory fallback
        emojis_dir = os.path.join(folder_path, "emojis")
        os.makedirs(emojis_dir, exist_ok=True)
        for emoji in emojis:
            with open(os.path.join(emojis_dir, f"{emoji}.png"), "wb") as f:
                f.write(MINIMAL_PNG)
            with open(os.path.join(emojis_dir, f"{emoji}_anim.webp"), "wb") as f:
                f.write(MINIMAL_PNG)

    print("Success: All placeholder asset structures generated successfully!")

if __name__ == "__main__":
    create_files()
