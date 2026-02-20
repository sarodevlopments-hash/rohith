# 💰 AWS S3 Pricing Components Guide

## 📊 Pricing Components You Need to Consider

### 1. **Storage Costs** (GB per month)
- **What it is**: Cost for storing your images in S3
- **How it's charged**: Per GB stored per month
- **Pricing example** (Standard Storage, ap-south-1 Mumbai):
  - First 50 TB/month: ₹2.30 per GB/month (~$0.023/GB)
  - Next 450 TB/month: ₹2.20 per GB/month
  - Over 500 TB/month: ₹2.10 per GB/month

**Calculation Example:**
- 1,000 product images
- Average image size: 500 KB (0.5 MB)
- Total storage: 1,000 × 0.5 MB = 500 MB = 0.5 GB
- Monthly cost: 0.5 GB × ₹2.30 = **₹1.15/month** (~$0.01/month)

### 2. **PUT Requests** (Uploads) 💾
- **What it is**: Cost per image upload
- **How it's charged**: Per 1,000 PUT requests
- **Pricing example** (ap-south-1):
  - ₹0.005 per 1,000 PUT requests (~$0.00005 per request)

**Calculation Example:**
- 100 new product images uploaded per month
- Cost: 100 ÷ 1,000 × ₹0.005 = **₹0.0005/month** (negligible)

### 3. **GET Requests** (Downloads/Views) 📥
- **What it is**: Cost each time an image is viewed/downloaded
- **How it's charged**: Per 1,000 GET requests
- **Pricing example** (ap-south-1):
  - First 1 million requests/month: ₹0.004 per 1,000 requests
  - Next 9 million requests/month: ₹0.003 per 1,000 requests
  - Over 10 million requests/month: ₹0.002 per 1,000 requests

**Calculation Example:**
- 10,000 image views per month
- Cost: 10,000 ÷ 1,000 × ₹0.004 = **₹0.04/month**

### 4. **Data Transfer OUT** (Egress) 🌐
- **What it is**: Cost for data downloaded from S3
- **How it's charged**: Per GB transferred out
- **Pricing example** (ap-south-1):
  - First 1 GB/month: **FREE**
  - Next 9.999 TB/month: ₹0.09 per GB (~$0.09/GB)
  - Next 40 TB/month: ₹0.085 per GB
  - Over 50 TB/month: ₹0.07 per GB

**Calculation Example:**
- 10,000 image views per month
- Average image size: 500 KB (0.5 MB)
- Total data transfer: 10,000 × 0.5 MB = 5,000 MB = 5 GB
- Cost: (5 GB - 1 GB free) × ₹0.09 = **₹0.36/month**

### 5. **Data Transfer IN** (Ingress) ⬇️
- **What it is**: Cost for uploading data to S3
- **How it's charged**: Usually **FREE** ✅
- **Pricing**: ₹0.00 per GB (no charge for uploads)

### 6. **CloudFront CDN** (Optional but Recommended) 🚀
- **What it is**: Content Delivery Network for faster image loading
- **Benefits**: 
  - Faster image loading worldwide
  - Reduced S3 data transfer costs
  - Better user experience
- **Pricing** (separate from S3):
  - Data transfer OUT: ₹0.085 per GB (first 10 TB)
  - Requests: ₹0.006 per 10,000 HTTPS requests

## 📈 Real-World Cost Estimate

### Scenario: Small Marketplace (1,000 products, 10,000 views/month)

| Component | Usage | Monthly Cost |
|-----------|-------|--------------|
| **Storage** | 500 MB (1,000 images × 0.5 MB) | ₹1.15 |
| **PUT Requests** | 100 uploads | ₹0.0005 |
| **GET Requests** | 10,000 views | ₹0.04 |
| **Data Transfer OUT** | 5 GB | ₹0.36 |
| **Data Transfer IN** | 50 MB uploads | FREE |
| **TOTAL** | | **~₹1.55/month** (~$0.02/month) |

### Scenario: Medium Marketplace (10,000 products, 100,000 views/month)

| Component | Usage | Monthly Cost |
|-----------|-------|--------------|
| **Storage** | 5 GB (10,000 images × 0.5 MB) | ₹11.50 |
| **PUT Requests** | 1,000 uploads | ₹0.005 |
| **GET Requests** | 100,000 views | ₹0.40 |
| **Data Transfer OUT** | 50 GB | ₹4.41 |
| **TOTAL** | | **~₹16.32/month** (~$0.20/month) |

### Scenario: Large Marketplace (100,000 products, 1M views/month)

| Component | Usage | Monthly Cost |
|-----------|-------|--------------|
| **Storage** | 50 GB | ₹115.00 |
| **PUT Requests** | 10,000 uploads | ₹0.05 |
| **GET Requests** | 1,000,000 views | ₹4.00 |
| **Data Transfer OUT** | 500 GB | ₹44.91 |
| **TOTAL** | | **~₹163.96/month** (~$2/month) |

## 💡 Cost Optimization Tips

### 1. **Use CloudFront CDN** (Recommended)
- **Benefit**: Reduces S3 data transfer costs
- **How**: CloudFront caches images at edge locations
- **Cost**: Similar to S3 but better performance
- **Savings**: Can reduce data transfer costs by 50-70%

### 2. **Image Compression**
- **Benefit**: Reduces storage and transfer costs
- **How**: Compress images before upload
- **Savings**: 50-80% reduction in file size
- **Example**: 1 MB image → 200 KB = 80% savings

### 3. **Use S3 Intelligent-Tiering**
- **Benefit**: Automatically moves unused images to cheaper storage
- **Cost**: ₹0.0025 per 1,000 objects monitored
- **Savings**: 40-68% on storage for rarely accessed images

### 4. **Set Up Lifecycle Policies**
- **Benefit**: Automatically delete old/unused images
- **How**: Delete images older than X days
- **Savings**: Prevents storage bloat

### 5. **Optimize Image Sizes**
- **Benefit**: Smaller images = lower costs
- **How**: 
  - Resize images to appropriate dimensions
  - Use WebP format (smaller than JPEG)
  - Compress before upload

### 6. **Use S3 Standard-IA for Old Images**
- **Benefit**: Cheaper storage for rarely accessed images
- **Cost**: ₹1.20 per GB/month (vs ₹2.30 for Standard)
- **Use case**: Images older than 90 days

## 🎯 Cost Comparison: S3 vs Firebase Storage

### Firebase Storage Pricing (for comparison):
- **Storage**: $0.026 per GB/month (~₹2.16/GB)
- **Downloads**: $0.12 per GB (~₹10/GB)
- **Uploads**: FREE

### S3 Advantages:
- ✅ **Cheaper storage**: ₹2.30/GB vs ₹2.16/GB (similar)
- ✅ **Much cheaper downloads**: ₹0.09/GB vs ₹10/GB (90% cheaper!)
- ✅ **More flexible**: Multiple storage classes
- ✅ **Better for scale**: Lower costs at higher volumes

### S3 Disadvantages:
- ❌ **More complex setup**: Requires AWS account, IAM, etc.
- ❌ **No built-in CDN**: Need CloudFront separately
- ❌ **More configuration**: Bucket policies, CORS, etc.

## 📊 Monthly Cost Calculator

Use this formula to estimate your costs:

```
Total Monthly Cost = 
  (Storage GB × ₹2.30) +
  (PUT Requests ÷ 1,000 × ₹0.005) +
  (GET Requests ÷ 1,000 × ₹0.004) +
  ((Data Transfer GB - 1) × ₹0.09)
```

### Example Calculation:
- Storage: 2 GB
- Uploads: 500 images
- Views: 50,000 views
- Data transfer: 25 GB

```
Cost = 
  (2 × ₹2.30) +                    // Storage
  (500 ÷ 1,000 × ₹0.005) +         // PUT
  (50,000 ÷ 1,000 × ₹0.004) +      // GET
  ((25 - 1) × ₹0.09)               // Transfer

Cost = ₹4.60 + ₹0.0025 + ₹0.20 + ₹2.16
Cost = ₹6.96/month (~$0.08/month)
```

## 🚨 Important Notes

1. **Free Tier**: AWS offers 5 GB storage + 20,000 GET requests free for 12 months (new accounts)
2. **Regional Pricing**: Prices vary by region (ap-south-1 Mumbai is usually cheaper)
3. **Billing**: AWS bills monthly, pay-as-you-go
4. **Monitoring**: Use AWS Cost Explorer to track spending
5. **Alerts**: Set up billing alerts to avoid surprises

## 📝 Recommended Setup for Your App

1. **Start with S3 Standard** (most common)
2. **Enable CloudFront** for better performance and lower costs
3. **Compress images** before upload (target: 200-300 KB per image)
4. **Set up lifecycle policies** to delete old images
5. **Monitor costs** with AWS Cost Explorer
6. **Set billing alerts** at ₹500, ₹1,000, ₹5,000 thresholds

## 💰 Estimated Monthly Costs for Your App

Based on typical marketplace usage:

| Scale | Products | Views/Month | Estimated Cost |
|-------|----------|-------------|----------------|
| **Small** | 1,000 | 10,000 | ₹1-2/month |
| **Medium** | 10,000 | 100,000 | ₹15-20/month |
| **Large** | 100,000 | 1,000,000 | ₹150-200/month |

**Note**: These are estimates. Actual costs depend on:
- Image sizes
- Compression
- CDN usage
- Regional pricing

## ✅ Summary

**S3 Pricing Components:**
1. ✅ **Storage** - Per GB/month
2. ✅ **PUT Requests** - Per upload
3. ✅ **GET Requests** - Per view/download
4. ✅ **Data Transfer OUT** - Per GB downloaded
5. ✅ **Data Transfer IN** - FREE
6. ⚠️ **CloudFront** - Optional but recommended

**For a typical marketplace app:**
- **Storage**: ~₹2-10/month (depending on scale)
- **Requests**: ~₹0.05-5/month
- **Data Transfer**: ~₹0.50-50/month
- **Total**: ~₹2-65/month for most apps

**Bottom Line**: S3 is very cost-effective for image storage, especially compared to Firebase Storage for downloads!

