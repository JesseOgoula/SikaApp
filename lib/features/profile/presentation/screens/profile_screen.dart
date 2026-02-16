import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sika_app/core/theme/app_theme.dart';
import 'package:sika_app/utils/time_utils.dart';
import 'package:sika_app/features/auth/data/repositories/auth_repository.dart';
import 'package:sika_app/features/auth/presentation/providers/auth_controller.dart';
import 'package:sika_app/features/accounts/presentation/screens/account_setup_screen.dart';
import 'package:sika_app/features/budgets/presentation/screens/budgets_screen.dart';
import 'package:sika_app/features/profile/presentation/screens/notification_settings_screen.dart';

/// Écran de profil avancé avec gestion Cloud
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final fullName =
        user?.userMetadata?['full_name'] as String? ?? 'Utilisateur';
    final email = user?.email ?? '';
    final avatarUrl = user?.userMetadata?['avatar_url'] as String?;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Partie sticky (non-scrollable)
                _buildAppBar(),
                const SizedBox(height: 16),
                _buildProfileHeader(avatarUrl, fullName, email),
                const SizedBox(height: 24),
                // Partie scrollable
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        _buildSettingsSection(),
                        const SizedBox(height: 16),
                        _buildDataSection(),
                        const SizedBox(height: 16),
                        _buildAccountSection(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_isLoading)
              Container(
                color: Colors.black26,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Mon Profil',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(String? avatarUrl, String fullName, String email) {
    final greeting = getGreetingMessage();
    final emoji = getGreetingEmoji();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // Photo de profil
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
                    )
                  : _buildDefaultAvatar(),
            ),
          ),
          const SizedBox(width: 16),
          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting $emoji',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  getFirstName(fullName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: Colors.white.withOpacity(0.2),
      child: const Icon(Icons.person, size: 36, color: Colors.white),
    );
  }

  Widget _buildSettingsSection() {
    return _buildSection(
      title: 'PARAMÈTRES',
      children: [
        _buildActionTile(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Budgets',
          subtitle: 'Gérer les limites de dépenses par catégorie',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BudgetsScreen()),
          ),
        ),
        _buildDivider(),
        _buildActionTile(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          subtitle: 'Paramétrer les rappels et alertes',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const NotificationSettingsScreen(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataSection() {
    return _buildSection(
      title: 'DONNÉES',
      children: [
        // Effacer toutes les données (local + cloud)
        _buildActionTile(
          icon: Icons.delete_sweep_outlined,
          title: 'Effacer toutes mes données',
          subtitle: 'Supprime les données locales et en ligne',
          isDanger: true,
          onTap: () => _confirmDeleteAllData(),
        ),
      ],
    );
  }

  Widget _buildAccountSection() {
    return _buildSection(
      title: 'COMPTE',
      children: [
        _buildActionTile(
          icon: Icons.info_outline,
          title: 'À propos',
          subtitle: 'SIKA v1.0.0',
          onTap: () => _showAboutDialog(),
        ),
        _buildDivider(),
        _buildActionTile(
          icon: Icons.logout_outlined,
          title: 'Déconnexion',
          subtitle: 'Se déconnecter de l\'application',
          onTap: () => _confirmLogout(),
        ),
        _buildDivider(),
        _buildActionTile(
          icon: Icons.person_remove_outlined,
          title: 'Supprimer mon compte',
          subtitle: 'Supprime définitivement votre profil',
          isDanger: true,
          onTap: () => _confirmDeleteAccount(),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                letterSpacing: 1,
              ),
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(
        icon,
        color: isDanger ? AppTheme.error : AppTheme.textSecondary,
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDanger ? AppTheme.error : AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.grey.shade400,
        size: 20,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 56,
      endIndent: 20,
      color: Colors.grey.shade100,
    );
  }

  // ============= DIALOGS =============

  void _confirmDeleteAllData() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.delete_sweep_outlined, color: AppTheme.error),
            const SizedBox(width: 12),
            const Expanded(child: Text('Effacer les données')),
          ],
        ),
        content: const Text(
          '⚠️ Cette action supprimera TOUTES vos données:\n\n'
          '• Comptes financiers\n'
          '• Transactions\n'
          '• Objectifs\n'
          '• Dettes et Factures\n'
          '• Catégories\n\n'
          'Vous devrez reconfigurer vos comptes.\n\n'
          'Votre connexion Google restera active.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _executeDeleteAllData();
            },
            child: const Text('Effacer tout'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeDeleteAllData() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).deleteAllUserData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Toutes les données ont été effacées'),
            backgroundColor: AppTheme.success,
          ),
        );
        // Rediriger vers l'écran de configuration des comptes
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AccountSetupScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.person_remove_outlined, color: AppTheme.error),
            const SizedBox(width: 12),
            const Expanded(child: Text('Supprimer le compte')),
          ],
        ),
        content: SingleChildScrollView(
          child: const Text(
            '🚨 ACTION IRRÉVERSIBLE !\n\n'
            'Cette action supprimera définitivement:\n\n'
            '• Votre profil utilisateur\n'
            '• Toutes vos données\n'
            '• Votre authentification\n\n'
            'Vous ne pourrez plus récupérer ces informations.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          Flexible(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await _executeDeleteAccount();
              },
              child: const Text('Supprimer'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeDeleteAccount() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      if (mounted) {
        Navigator.pop(context);
        ref.read(authControllerProvider.notifier).logout();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.logout_outlined, color: AppTheme.textSecondary),
            const SizedBox(width: 12),
            const Text('Déconnexion'),
          ],
        ),
        content: const Text(
          'Voulez-vous vous déconnecter ?\n\nVos données locales seront conservées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              ref.read(authControllerProvider.notifier).logout();
            },
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: AppTheme.textSecondary),
            const SizedBox(width: 12),
            const Text('À propos'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SIKA - Budget with AI',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 12),
            Text(
              'Gestion financière personnelle avec synchronisation cloud et intelligence artificielle.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            SizedBox(height: 16),
            Text('Version 1.0.0', style: TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Fermer',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}
