import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../models/buyer_address.dart';
import '../services/user_firestore_service.dart';
import '../services/buyer_address_service.dart';
import '../theme/app_theme.dart';
import 'edit_profile_screen.dart';
import 'manage_addresses_screen.dart';

class BuyerProfileScreen extends StatefulWidget {
  const BuyerProfileScreen({super.key});

  @override
  State<BuyerProfileScreen> createState() => _BuyerProfileScreenState();
}

class _BuyerProfileScreenState extends State<BuyerProfileScreen> {
  AppUser? _user;
  BuyerAddress? _defaultAddress;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      // Load from Firestore
      final user = await UserFirestoreService.getUser(currentUser.uid);
      if (user != null) {
        setState(() => _user = user);
      } else {
        // Fallback to Firebase Auth data
        setState(() {
          _user = AppUser(
            uid: currentUser.uid,
            fullName: currentUser.displayName ?? 'User',
            email: currentUser.email ?? '',
            phoneNumber: currentUser.phoneNumber ?? '',
            createdAt: DateTime.now(),
            isRegistered: true,
          );
        });
      }

      // Load default address
      final defaultAddr = await BuyerAddressService.getDefaultAddress(currentUser.uid);
      setState(() => _defaultAddress = defaultAddr);
    }
    setState(() => _isLoading = false);
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  String _maskPhoneNumber(String phone) {
    if (phone.length <= 4) return phone;
    final visible = phone.substring(phone.length - 4);
    return '******$visible';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.darkText,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
              ? const Center(child: Text('No user data found'))
              : RefreshIndicator(
                  onRefresh: _loadUserData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile Header Card
                        _buildProfileHeader(),
                        const SizedBox(height: 24),

                        // Personal Information Section
                        _buildSectionTitle('Personal Information'),
                        const SizedBox(height: 12),
                        _buildInfoCard(),

                        const SizedBox(height: 24),

                        // Delivery Addresses Section
                        _buildSectionTitle('Delivery Addresses'),
                        const SizedBox(height: 12),
                        _buildAddressCard(),

                        const SizedBox(height: 24),

                        // Actions Section
                        _buildSectionTitle('Account Actions'),
                        const SizedBox(height: 12),
                        _buildActionsCard(),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.getCardDecoration(),
      child: Row(
        children: [
          // Avatar Circle
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _getInitials(_user!.fullName),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _user!.fullName,
                  style: AppTheme.heading3,
                ),
                const SizedBox(height: 4),
                Text(
                  _user!.email,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.lightText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTheme.heading4.copyWith(
        color: AppTheme.darkText,
      ),
    );
  }

  Widget _buildInfoCard() {
    final phoneNumber = _user!.phoneNumber.isNotEmpty
        ? _maskPhoneNumber(_user!.phoneNumber)
        : 'Not provided';
    final isPhoneVerified = _user!.phoneNumber.isNotEmpty;
    final isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.getCardDecoration(),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.person_outline,
            label: 'Full Name',
            value: _user!.fullName,
            showEdit: true,
            onEdit: () => _navigateToEditProfile(),
          ),
          const Divider(height: 24),
          _buildInfoRow(
            icon: Icons.phone_outlined,
            label: 'Mobile Number',
            value: phoneNumber,
            isVerified: isPhoneVerified,
            showEdit: false,
          ),
          const Divider(height: 24),
          _buildInfoRow(
            icon: Icons.email_outlined,
            label: 'Email Address',
            value: _user!.email,
            isVerified: isEmailVerified,
            showEdit: true,
            onEdit: () => _navigateToEditProfile(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isVerified = false,
    bool showEdit = false,
    VoidCallback? onEdit,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.lightText,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (isVerified)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified,
                            size: 14,
                            color: AppTheme.successColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Verified',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.successColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (showEdit && onEdit != null)
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            color: AppTheme.primaryColor,
            onPressed: onEdit,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }

  Widget _buildAddressCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.getCardDecoration(),
      child: Column(
        children: [
          if (_defaultAddress != null && _defaultAddress!.id.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, color: AppTheme.primaryColor, size: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.successColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'DEFAULT',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.successColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _defaultAddress!.label,
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _defaultAddress!.fullAddress,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.lightText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _navigateToManageAddresses(),
                icon: const Icon(Icons.manage_accounts_outlined),
                label: const Text('Manage Addresses'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: AppTheme.primaryColor),
                  foregroundColor: AppTheme.primaryColor,
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Icon(Icons.location_off_outlined, color: AppTheme.lightText, size: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'No delivery address saved',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.lightText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToManageAddresses(),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Add Address'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.getCardDecoration(),
      child: Column(
        children: [
          _buildActionTile(
            icon: Icons.help_outline,
            title: 'Help & Support',
            subtitle: 'Get help with your account',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Help & Support coming soon')),
              );
            },
          ),
          const Divider(height: 24),
          _buildActionTile(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'App version and information',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('About coming soon')),
              );
            },
          ),
          const Divider(height: 24),
          _buildActionTile(
            icon: Icons.logout,
            title: 'Logout',
            subtitle: 'Sign out of your account',
            onTap: _handleLogout,
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? AppTheme.errorColor : AppTheme.primaryColor,
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? AppTheme.errorColor : AppTheme.darkText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.lightText,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppTheme.lightText,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(user: _user!),
      ),
    );
    if (result == true) {
      _loadUserData();
    }
  }

  void _navigateToManageAddresses() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ManageAddressesScreen(),
      ),
    );
    _loadUserData();
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    }
  }
}

