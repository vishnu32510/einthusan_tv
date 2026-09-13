# LG Content Store (LG Seller Lounge) Submission Guide & Metadata

Use this document to copy-paste directly into the **[LG Seller Lounge](https://seller.lgappstv.com)** when registering and submitting **Nungu TV**.

---

## 1. Submission Portal
- **URL:** [https://seller.lgappstv.com](https://seller.lgappstv.com)
- **Account:** LG Developer / Seller Account (Free registration)
- **Action:** Click **"Add New App"** $\rightarrow$ **"TV App"**

---

## 2. General Information & Package Upload

| Field | Value to Enter / Upload |
| :--- | :--- |
| **App Type** | Web App (webOS) |
| **Application Package (.ipk)** | Upload `lg_store_assets/com.nungu.tv_1.0.0_all.ipk` |
| **Application ID** | `com.nungu.tv` *(auto-detected from package)* |
| **Version** | `1.0.0` |
| **App Title** | `Nungu TV` |
| **Category** | **Entertainment** |
| **Pricing** | **Free** |
| **Default Language** | English |
| **Target Countries** | Global / Worldwide (Recommended: United States, India, Canada, United Kingdom, Singapore, Malaysia, Australia, UAE) |
| **Age Rating** | 12+ (Mild violence, general entertainment) |

---

## 3. Store Listing Copy

### 📌 Short Description (Summary)
```
Smart TV media browser & cinema portal optimized for South Asian entertainment and 10-foot remote control navigation.
```

### 📌 Full Description
```
Nungu TV is a specialized Smart TV media browser and entertainment hub designed specifically for LG webOS. Experience seamless navigation of South Asian regional cinema, movie trailers, and independent films directly from the comfort of your couch.

Key Features:
• 10-Foot Living Room Navigation: Full support for LG Magic Remote (pointer cursor) and standard D-Pad directional controls.
• Multi-Language Regional Hub: Quick access to popular South Asian language catalogs including Tamil, Telugu, Hindi, Malayalam, Kannada, and Bengali.
• Ultra HD Playback: Full support for high-definition and 4K media streams with native hardware video acceleration.
• Ad-Filter Architecture: Streamlined interface suppresses aggressive popunders and modal disruptions.
• Lightweight & Fast: Clean webOS app footprint (< 100 KB) ensures instant launch times without slowing down your television.

Note: Nungu TV acts as a web browser and media indexing interface. All video streams originate from publicly available web servers.
```

### 📌 Keywords / Tags
```
nungu, smart tv, cinema, media player, south asian, tamil movies, telugu, bollywood, webos browser, tv streaming, 4k player
```

---

## 4. Graphic Assets & Screenshots

All assets are pre-sized to LG Seller Lounge exact technical specifications in `lg_store_assets/`:

1. **App Icon (80x80):** `lg_store_assets/icon_80x80.png`
2. **Large Icon (130x130):** `lg_store_assets/icon_130x130.png`
3. **Screenshot 1 (1920x1080):** `lg_store_assets/screenshot_1.jpg` (Curated Catalog View)
4. **Screenshot 2 (1920x1080):** `lg_store_assets/screenshot_2.jpg` (4K UHD Player Overlay)
5. **Screenshot 3 (1920x1080):** `lg_store_assets/screenshot_3.jpg` (Regional Language Selector)

---

## 5. Support & Legal URLs

| Field | URL |
| :--- | :--- |
| **Privacy Policy URL** | `https://nungu-tv.web.app/privacy.html` |
| **Terms of Service URL** | `https://nungu-tv.web.app/terms.html` |
| **Support Website** | `https://github.com/vishnu32510/nungu_tv` |

---

## 6. Reviewer Notes (QA Testing Instructions)
Paste this into the **"Note to Reviewer" / "Test Information"** box during submission:

```
Testing Instructions:
1. Launch Nungu TV from the LG webOS launcher.
2. The application opens the cinema portal interface.
3. Use the LG Magic Remote or directional arrow keys on the remote to navigate movie categories and language sections.
4. Press 'Back' on the LG remote to navigate to the previous screen or exit cleanly.
5. All streams utilize standard HTML5 media playback.
```
