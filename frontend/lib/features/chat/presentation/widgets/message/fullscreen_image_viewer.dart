import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:my_chat_app/core/theme/app_colors.dart';

class FullscreenImageViewer extends StatefulWidget {
  final String url;
  final String? title;

  const FullscreenImageViewer({
    super.key,
    required this.url,
    this.title,
  });

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  bool _isDownloading = false;

  Future<void> _downloadImageToPhotos() async {
    setState(() => _isDownloading = true);
    try {
      final response = await http.get(Uri.parse(widget.url));
      await Gal.putImageBytes(response.bodyBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved to Photos'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
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
          widget.title ?? 'Image',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          _isDownloading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.download_rounded, color: Colors.white),
                  onPressed: _downloadImageToPhotos,
                ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(widget.url),
        ),
      ),
    );
  }
}