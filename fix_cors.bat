@echo off
echo ================================================
echo Firebase Storage CORS Configuration Fix
echo ================================================
echo.

echo Step 1: Authenticating with Google Cloud...
call gcloud auth login

echo.
echo Step 2: Setting Firebase project...
call gcloud config set project resqfood-66b5f

echo.
echo Step 3: Applying CORS configuration...
call gsutil cors set cors.json gs://resqfood-66b5f.firebasestorage.app

echo.
echo Step 4: Verifying CORS configuration...
call gsutil cors get gs://resqfood-66b5f.firebasestorage.app

echo.
echo ================================================
echo CORS configuration applied successfully!
echo ================================================
echo.
echo Please restart your Flutter app and try uploading again.
echo.
pause

