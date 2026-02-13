import os
import time
import requests
from bs4 import BeautifulSoup
from urllib.parse import urljoin, urlparse, quote_plus

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/122.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Connection": "keep-alive",
    "DNT": "1",
    "Upgrade-Insecure-Requests": "1",
}

SESSION = requests.Session()
SESSION.headers.update(HEADERS)


def _request_get(
    url,
    *,
    stream=False,
    use_cookie=False,
    block_403=False,
    max_retries=3,
    backoff_base=2,
    params=None,
):
    cookie = os.environ.get("MINDAT_COOKIE") if use_cookie else None
    headers = {"Cookie": cookie} if cookie else None

    for attempt in range(max_retries):
        r = SESSION.get(url, headers=headers, timeout=30, stream=stream, params=params)
        if r.status_code in (429, 503):
            retry_after = r.headers.get("Retry-After")
            if retry_after and retry_after.isdigit():
                sleep_for = int(retry_after)
            else:
                sleep_for = backoff_base * (attempt + 1)
            time.sleep(sleep_for)
            continue
        if block_403 and r.status_code == 403:
            raise RuntimeError(
                "Mindat blocked this request (403). Try again later, or set "
                "MINDAT_COOKIE env var from a valid browser session."
            )
        r.raise_for_status()
        return r

    r.raise_for_status()
    return r


# ------------------------------------------------------
# Step 1: search Mindat and find the mineral page
# ------------------------------------------------------

def find_mineral_page(mineral_name):

    search_url = f"https://www.mindat.org/search.php?search={quote_plus(mineral_name)}"

    r = _request_get(search_url, use_cookie=True, block_403=True)

    soup = BeautifulSoup(r.text, "html.parser")

    # look for the first link that looks like a mineral page
    for a in soup.select("a[href*='min-']"):
        href = a.get("href")
        if href:
            return urljoin(search_url, href)

    return None


# ------------------------------------------------------
# Step 2: get all photo pages from mineral page
# ------------------------------------------------------

def get_photo_pages(mineral_page_url):

    r = _request_get(mineral_page_url, use_cookie=True, block_403=True)

    soup = BeautifulSoup(r.text, "html.parser")

    pages = set()

    for a in soup.select("a[href*='photo']"):
        href = a.get("href")
        if href:
            pages.add(urljoin(mineral_page_url, href))

    return list(pages)


# ------------------------------------------------------
# Step 3: extract the real specimen image
# ------------------------------------------------------

def get_main_image(photo_page_url):

    r = _request_get(photo_page_url, use_cookie=True, block_403=True)

    soup = BeautifulSoup(r.text, "html.parser")

    img = soup.select_one("img#mainphoto")

    if img is None:
        return None

    src = img.get("src")

    if not src:
        return None

    return urljoin(photo_page_url, src)


# ------------------------------------------------------
# Fallback: download from Wikimedia Commons
# ------------------------------------------------------

def _commons_search_images(mineral_name, max_images):
    api_url = "https://commons.wikimedia.org/w/api.php"
    query = f"{mineral_name} mineral"

    params = {
        "action": "query",
        "format": "json",
        "generator": "search",
        "gsrsearch": query,
        "gsrlimit": max_images,
        "gsrnamespace": 6,
        "prop": "imageinfo",
        "iiprop": "url|thumburl",
        "iiurlwidth": 800,
    }

    r = _request_get(api_url, max_retries=5, backoff_base=4, params=params)
    data = r.json()

    pages = data.get("query", {}).get("pages", {})
    results = []
    for page in pages.values():
        info = page.get("imageinfo")
        if not info:
            continue
        url = info[0].get("thumburl") or info[0].get("url")
        if url:
            results.append(url)

    return results[:max_images]


def _download_from_commons(mineral_name, output_folder, max_images=30):
    print("Falling back to Wikimedia Commons...")
    os.makedirs(output_folder, exist_ok=True)

    image_urls = _commons_search_images(mineral_name, max_images * 3)
    if not image_urls:
        print("No images found on Wikimedia Commons.")
        return

    count = 0
    for img_url in image_urls:
        if count >= max_images:
            break

        try:
            time.sleep(1.2)
            filename = os.path.basename(urlparse(img_url).path)
            save_path = os.path.join(output_folder, f"{count:04d}_{filename}")
            data = _request_get(
                img_url,
                stream=True,
                max_retries=6,
                backoff_base=5,
            ).content

            with open(save_path, "wb") as f:
                f.write(data)

            count += 1
            print("Downloaded", count)
        except Exception as e:
            print("Skipped one image:", e)

    print("\nFinished.")
    print("Saved to:", output_folder)


# ------------------------------------------------------
# Step 4: main downloader
# ------------------------------------------------------

def download_by_mineral_name(mineral_name, output_folder, max_images=30):

    print("\nSearching Mindat for mineral:", mineral_name)

    try:
        mineral_page = find_mineral_page(mineral_name)
    except RuntimeError as e:
        print(e)
        _download_from_commons(mineral_name, output_folder, max_images)
        return

    if mineral_page is None:
        print("Could not find mineral page. Trying Wikimedia Commons.")
        _download_from_commons(mineral_name, output_folder, max_images)
        return

    print("Found mineral page:")
    print(mineral_page)

    photo_pages = get_photo_pages(mineral_page)

    if not photo_pages:
        print("No photo pages found on Mindat. Trying Wikimedia Commons.")
        _download_from_commons(mineral_name, output_folder, max_images)
        return

    print(f"Found {len(photo_pages)} photo pages")

    os.makedirs(output_folder, exist_ok=True)

    count = 0

    for page in photo_pages:

        if count >= max_images:
            break

        try:
            time.sleep(1.5)

            img_url = get_main_image(page)

            if img_url is None:
                continue

            if "mindat.org" not in img_url:
                continue

            filename = os.path.basename(urlparse(img_url).path)
            save_path = os.path.join(output_folder, f"{count:04d}_{filename}")

            data = _request_get(img_url, stream=True, use_cookie=True, block_403=True).content

            with open(save_path, "wb") as f:
                f.write(data)

            count += 1
            print("Downloaded", count)

        except Exception as e:
            print("Skipped one image:", e)

    print("\nFinished.")
    print("Saved to:", output_folder)


# ------------------------------------------------------

if __name__ == "__main__":

    mineral = input("Enter mineral name (example: gold, chalcopyrite, hematite): ").strip()

    out_dir = input("Output folder: ").strip()

    max_imgs = input("Maximum number of images [default 30]: ").strip()

    if max_imgs == "":
        max_imgs = 30
    else:
        max_imgs = int(max_imgs)

    download_by_mineral_name(mineral, out_dir, max_imgs)
