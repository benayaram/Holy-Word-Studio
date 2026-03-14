import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_text_styles.dart';

class ViewerScreen extends StatelessWidget {
  final File imageFile;

  const ViewerScreen({super.key, required this.imageFile});

  void _shareImage(BuildContext context, double aspectRatio) async {
    try {
      final xFile = XFile(imageFile.path);
      // ignore: deprecated_member_use
      await Share.shareXFiles([xFile], text: 'Daily Verse');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to share: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'IMAGE VIEWER',
          style: AppTextStyles.heading2.copyWith(
            color: Colors.white,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _shareImage(context, 1.0),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(tag: imageFile.path, child: Image.file(imageFile)),
        ),
      ),
    );
  }
}
