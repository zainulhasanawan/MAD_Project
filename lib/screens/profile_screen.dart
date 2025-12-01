import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'public_journal_screen.dart';
import './auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isPublic = false;
  String? _shareToken;
  String? _fullName;
  String? _username;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profile = await supabase
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null) {
        setState(() {
          _isPublic = profile['profile_is_public'] ?? false;
          _shareToken = profile['share_token'];
          _fullName = profile['full_name'];
          _username = profile['username'];
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePublicProfile(bool value) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase
          .from('user_profiles')
          .update({'profile_is_public': value})
          .eq('id', user.id);

      setState(() => _isPublic = value);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? '✅ Profile is now public!'
                : '🔒 Profile is now private',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: value ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update profile: $e',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _copyShareLink() {
    if (_shareToken != null) {
      final shareUrl = 'https://yourapp.com/journal/$_shareToken';
      Clipboard.setData(ClipboardData(text: shareUrl));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '📋 Link copied to clipboard!',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _viewPublicProfile() {
    final user = supabase.auth.currentUser;
    if (user != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PublicJournalScreen(userId: user.id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F8FC),
        appBar: _buildAppBar(),
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF3D8BFF),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header Section
            _buildProfileHeader(context, user),

            const SizedBox(height: 32),

            // Main Content Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Public Profile Card
                  _buildPublicProfileCard(),

                  const SizedBox(height: 24),

                  // Account Info Card
                  _buildAccountInfoCard(context, user),

                  const SizedBox(height: 24),

                  // Logout Button
                  _buildLogoutButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, User? user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar with gradient background
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3D8BFF), Color(0xFF6A5AF9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(50),
            ),
            child: CircleAvatar(
              radius: 48,
              backgroundColor: Colors.transparent,
              child: Text(
                user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                style: GoogleFonts.poppins(
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Name
          if (_fullName != null && _fullName!.isNotEmpty)
            Text(
              _fullName!,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1A2E),
              ),
            ),

          const SizedBox(height: 4),

          // Email
          Text(
            user?.email ?? 'No email',
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: const Color(0xFF666687),
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 8),

          // Username if available
          if (_username != null && _username!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F5FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '@$_username',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF3D8BFF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPublicProfileCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isPublic
                          ? [const Color(0xFF3D8BFF), const Color(0xFF6A5AF9)]
                          : [const Color(0xFF666687).withOpacity(0.1), const Color(0xFF666687).withOpacity(0.1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
                    color: _isPublic ? Colors.white : const Color(0xFF666687),
                    size: 24,
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Public Profile',
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isPublic
                            ? 'Your journal is visible to others'
                            : 'Your journal is private',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF666687),
                        ),
                      ),
                    ],
                  ),
                ),

                Transform.scale(
                  scale: 1.2,
                  child: Switch(
                    value: _isPublic,
                    onChanged: _togglePublicProfile,
                    activeColor: const Color(0xFF3D8BFF),
                    activeTrackColor: const Color(0xFF3D8BFF).withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),

          // Public Profile Actions
          if (_isPublic) ...[
            Divider(
              height: 1,
              color: Colors.grey.shade200,
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F4FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF3D8BFF).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: const Color(0xFF3D8BFF),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Profile is public and shareable',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: const Color(0xFF3D8BFF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _viewPublicProfile,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF3D8BFF),
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(
                              color: Color(0xFF3D8BFF),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.visibility_rounded, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Preview',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: ElevatedButton(
                          onPressed: _copyShareLink,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3D8BFF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            shadowColor: const Color(0xFF3D8BFF).withOpacity(0.3),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.share_rounded, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Share Link',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Share Link Info
                  if (_shareToken != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F8FC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.link_rounded,
                            color: Color(0xFF666687),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'https://yourapp.com/journal/$_shareToken',
                              overflow: TextOverflow.ellipsis,  // MOVED HERE - Fixes the error
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFF666687),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountInfoCard(BuildContext context, User? user) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account Information',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A2E),
              ),
            ),

            const SizedBox(height: 16),

            _buildInfoRow(
              icon: Icons.email_rounded,
              title: 'Email Address',
              value: user?.email ?? 'Not available',
            ),

            const SizedBox(height: 12),

            _buildInfoRow(
              icon: Icons.person_rounded,
              title: 'Account ID',
              value: user?.id.substring(0, 8) ?? 'Unknown',
            ),

            const SizedBox(height: 12),

            if (_username != null)
              _buildInfoRow(
                icon: Icons.alternate_email_rounded,
                title: 'Username',
                value: '@$_username',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F5FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF3D8BFF),
            size: 20,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF666687),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return ElevatedButton(
      onPressed: () async {
        final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Logout', style: GoogleFonts.poppins()),
            content: Text('Are you sure you want to logout?', style: GoogleFonts.poppins()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel', style: GoogleFonts.poppins()),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Logout', style: GoogleFonts.poppins()),
              ),
            ],
          ),
        );

        if (shouldLogout != true) return;

        try {
          await supabase.auth.signOut();

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Signed out', style: GoogleFonts.poppins()),
              backgroundColor: Colors.green,
            ),
          );

          // Replace the navigation stack so user can't press back into the app
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthScreen()),
                (route) => false,
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Logout failed: $e', style: GoogleFonts.poppins()),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFF44336),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.red.shade200,
            width: 1,
          ),
        ),
        shadowColor: Colors.transparent,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.logout_rounded, size: 22),
          const SizedBox(width: 12),
          Text(
            'Logout',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      centerTitle: false,
      title: Text(
        'Profile Settings',
        style: GoogleFonts.poppins(
          color: const Color(0xFF1A1A2E),
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
      ),
      iconTheme: const IconThemeData(color: Color(0xFF1A1A2E)),
      actions: [
        IconButton(
          onPressed: _loadProfile,
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh Profile',
        ),
      ],
    );
  }
}