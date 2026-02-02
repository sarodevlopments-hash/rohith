# How to Add Category Images

## Step 1: Prepare Your Images

You need 4 image files with these exact names:
- `food.jpg` - Food category image
- `groceries.jpg` - Groceries category image  
- `vegetables_fruits.jpg` - Vegetables & Fruits category image
- `clothing.jpg` - Clothing category image

## Step 2: Copy Images to This Folder

1. Copy your 4 image files to this exact folder:
   ```
   assets/images/categories/
   ```

2. Make sure the file names match exactly (case-sensitive):
   - food.jpg
   - groceries.jpg
   - vegetables_fruits.jpg
   - clothing.jpg

## Step 3: Restart the App

After adding the images:
1. Stop the app completely
2. Run `flutter clean` (optional but recommended)
3. Run `flutter pub get`
4. Restart the app with `flutter run`

## Troubleshooting

If images still don't show:
- Check file names match exactly (including .jpg extension)
- Verify files are in `assets/images/categories/` folder
- Make sure `pubspec.yaml` has: `assets: - assets/images/categories/`
- Try a full app restart (not just hot reload)

