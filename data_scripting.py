import os
import cloudscraper
from bs4 import BeautifulSoup
from urllib.parse import urljoin, urlparse
from tqdm import tqdm
import time

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,/;q=0.8",
    "Accept-Language": "en-US,en;q=0.5",
    "Accept-Encoding": "gzip, deflate, br",
    "Connection": "keep-alive",
    "Upgrade-Insecure-Requests": "1"
}

BASE_DIR = os.path.join("dataset", "images")

SITES = [
    "Kapoeta_East",
    "Central_Equatoria",
    "Yei_River"
]

MINERALS = [
    "gold",
    "chalcopyrite",
    "hematite"
]


def create_folder_structure():
    for site in SITES:
        for mineral in MINERALS:
            path = os.path.join(BASE_DIR, site, mineral)
            os.makedirs(path, exist_ok=True)

    print("\n✔ Dataset folder structure created.\n")


def download_mindat_images(gallery_url, output_folder):

    os.makedirs(output_folder, exist_ok=True)

    # Use cloudscraper to bypass Cloudflare protection
    scraper = cloudscraper.create_scraper(
        browser={
            'browser': 'chrome',
            'platform': 'windows',
            'desktop': True
        }
    )
    
    # Add a small delay to appear more natural
    time.sleep(2)

    response = scraper.get(gallery_url, timeout=30)
    response.raise_for_status()

    soup = BeautifulSoup(response.text, "html.parser")

    # Find links to images - they might be direct image links or photo page links
    links = soup.select("a[href*='photo']")

    print(f"\nFound {len(links)} photo links.\n")

    image_count = 0
    skipped_no_img = 0
    skipped_too_small = 0
    failed_downloads = 0

    for link in tqdm(links):
        href = link.get("href")
        if not href:
            continue
            
        full_url = urljoin(gallery_url, href)
        
        # Add delay between requests
        time.sleep(1)

        # Check if this is a direct image link
        if full_url.lower().endswith(('.jpg', '.jpeg', '.png', '.gif', '.bmp')):
            # Direct image link
            img_url = full_url
        else:
            # It's a photo page, need to extract image from it
            try:
                photo_page = scraper.get(full_url, timeout=30)
                photo_page.raise_for_status()
            except:
                continue

            photo_soup = BeautifulSoup(photo_page.text, "html.parser")

            # Try multiple methods to find the FULL-SIZE image
            img_url = None
            
            # Method 1: Look for direct link to full-size image
            # Mindat often has <a href="...full.jpg"> or similar
            for a_tag in photo_soup.find_all("a", href=True):
                href = a_tag.get("href", "")
                # Look for direct image links
                if href.endswith(('.jpg', '.jpeg', '.png', '.gif')):
                    if "full" in href.lower() or "/photos/" in href:
                        img_url = urljoin(full_url, href)
                        break
            
            # Method 2: Look for the largest image on the page
            if not img_url:
                all_imgs = photo_soup.find_all("img")
                for img in all_imgs:
                    src = img.get("src", "")
                    
                    # Skip obvious non-photo images
                    if any(x in src.lower() for x in ["logo", "icon", "button", "banner", "avatar", "ad", "spacer", "blank", "sprite"]):
                        continue
                    
                    # Get the parent <a> tag which might link to full size
                    parent_a = img.find_parent("a")
                    if parent_a and parent_a.get("href", "").endswith(('.jpg', '.jpeg', '.png', '.gif')):
                        img_url = urljoin(full_url, parent_a["href"])
                        break
                    
                    # Otherwise use the img src itself
                    if "/photos/" in src and "thumb" not in src.lower():
                        img_url = urljoin(full_url, src)
                        break
            
            # Method 3: Try to find any reasonable-looking image
            if not img_url:
                for img in photo_soup.find_all("img"):
                    src = img.get("src", "")
                    if src and src.endswith(('.jpg', '.jpeg', '.png')):
                        # Skip very small ones based on URL patterns
                        if not any(x in src.lower() for x in ["logo", "icon", "button", "banner", "thumb_", "_t.", "_s."]):
                            img_url = urljoin(full_url, src)
                            break

            if not img_url:
                # Debug: print that no image was found on this page
                skipped_no_img += 1
                continue

            if not img_url:
                continue
            
            # Skip data URIs and very small images
            if img_url.startswith("data:") or "spacer" in img_url.lower():
                continue

            img_url = urljoin(full_url, img_url)

        base_name = os.path.basename(urlparse(img_url).path)
        filename = f"{image_count:05d}_{base_name}"
        save_path = os.path.join(output_folder, filename)

        try:
            img_data = scraper.get(img_url, timeout=30).content
            
            # Skip if image is too small (likely not the actual photo)
            # Removed strict size check - let's get all images
            if len(img_data) < 1000:  # Only skip really tiny ones (< 1KB)
                skipped_too_small += 1
                continue
                
            with open(save_path, "wb") as f:
                f.write(img_data)

            image_count += 1
        except Exception as e:
            # Print errors to see what's failing
            failed_downloads += 1
            continue

    print(f"\n✔ Downloaded {image_count} images into:")
    print(output_folder)
    print(f"\nDebug stats:")
    print(f"  - No image found: {skipped_no_img}")
    print(f"  - Too small (< 1KB): {skipped_too_small}")
    print(f"  - Failed downloads: {failed_downloads}")


if __name__ == "__main__":

    print("\n--- Creating dataset folder structure ---")
    create_folder_structure()

    print("Available sites:")
    for s in SITES:
        print(" -", s)

    site = input("\nType site exactly as shown above: ").strip()

    print("\nAvailable minerals:")
    for m in MINERALS:
        print(" -", m)

    mineral = input("\nType mineral exactly as shown above: ").strip()

    if site not in SITES or mineral not in MINERALS:
        print("\n Invalid site or mineral name. Please run again.")
        exit()

    gallery_url = input("\nPaste Mindat photo gallery URL: ").strip()

    output_folder = os.path.join(BASE_DIR, site, mineral)

    print("\nDownloading images...")
    download_mindat_images(gallery_url, output_folder)