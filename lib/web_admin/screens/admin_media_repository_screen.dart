import 'package:flutter/material.dart';
import 'package:access_mobile/web_admin/features/media_repository/media_repository_page.dart';

/// Thin wrapper — routes to the modern DAM interface.
class AdminMediaRepositoryScreen extends StatelessWidget {
  const AdminMediaRepositoryScreen({super.key});

  @override
  Widget build(BuildContext context) => const MediaRepositoryPage();
}
