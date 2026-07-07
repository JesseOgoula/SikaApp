import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sika_app/features/notification_sync/data/providers/pending_transaction_providers.dart';
import 'package:sika_app/core/theme/app_theme.dart';

/// Écran d'onboarding pour la fonctionnalité de détection automatique
///
/// Guide l'utilisateur pour activer l'accès aux notifications
/// et/ou aux SMS dans les paramètres Android.
class NotificationSyncOnboardingScreen extends ConsumerStatefulWidget {
  const NotificationSyncOnboardingScreen({super.key});

  @override
  ConsumerState<NotificationSyncOnboardingScreen> createState() =>
      _NotificationSyncOnboardingScreenState();
}

class _NotificationSyncOnboardingScreenState
    extends ConsumerState<NotificationSyncOnboardingScreen>
    with WidgetsBindingObserver {
  bool _isLoading = false;
  bool _isListenerEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-vérifier quand l'utilisateur revient des paramètres
      _checkStatus();
    }
  }

  Future<void> _checkStatus() async {
    if (!Platform.isAndroid) return;
    
    final service = ref.read(notificationSyncServiceProvider);
    final enabled = await service.isNotificationListenerEnabled();
    
    if (mounted && _isListenerEnabled != enabled) {
      setState(() {
        _isListenerEnabled = enabled;
      });
      
      // Si activé avec succès, activer la fonctionnalité globalement
      if (enabled) {
        await service.setEnabled(true);
      }
    }
  }

  Future<void> _handleActivate() async {
    final service = ref.read(notificationSyncServiceProvider);
    
    setState(() => _isLoading = true);
    
    // 1. Demander la permission SMS en premier
    // Le SmsListenerService demandera la permission au système
    await service.requestSmsPermission();

    // 2. Ouvrir les paramètres de Notification Listener
    await service.openNotificationListenerSettings();
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return Scaffold(
        appBar: AppBar(title: const Text('Détection Automatique')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Cette fonctionnalité n\'est pas disponible sur iOS en raison '
              'des restrictions du système Apple.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                
                // ── Illustration / Icône ──
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade200, width: 1),
                    ),
                    child: const Icon(
                      Icons.sync,
                      size: 40,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // ── Titre ──
                const Text(
                  'Saisie Automatique',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // ── Description ──
                const Text(
                  'SIKA peut détecter automatiquement vos transactions Airtel Money, '
                  'Moov et bancaires pour vous éviter de les saisir manuellement.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // ── Étapes ──
                _buildFeatureRow(
                  icon: Icons.notifications_active_outlined,
                  title: 'Intercepte les notifications',
                  description: 'Lecture sécurisée des messages de vos apps financières.',
                ),
                const SizedBox(height: 24),
                _buildFeatureRow(
                  icon: Icons.sms_outlined,
                  title: 'Lit les SMS de confirmation',
                  description: 'Si l\'application de votre opérateur n\'est pas installée.',
                ),
                const SizedBox(height: 24),
                _buildFeatureRow(
                  icon: Icons.privacy_tip_outlined,
                  title: '100% Privé',
                  description: 'L\'analyse se fait sur votre téléphone. SIKA ne lit que les messages financiers.',
                ),
                
                const SizedBox(height: 40),
                
                // ── Status & Bouton ──
                if (_isListenerEnabled) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppTheme.success, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.check_circle, color: AppTheme.success),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Service activé avec succès',
                            style: TextStyle(
                              color: AppTheme.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Continuer',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ] else ...[
                  const Text(
                    'Vous serez redirigé vers les paramètres de votre téléphone. '
                    'Cherchez "SIKA" et activez l\'accès.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleActivate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Activer l\'accès',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
                
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: AppTheme.primaryColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
