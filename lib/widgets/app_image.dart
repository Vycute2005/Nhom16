import 'package:flutter/material.dart';

import '../config/api_config.dart';

class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.source,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    required this.fallbackIcon,
    this.fallbackIconSize = 40,
  });

  final String source;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData fallbackIcon;
  final double fallbackIconSize;

  @override
  Widget build(BuildContext context) {
    final imageSource = source.trim();
    if (imageSource.isEmpty) {
      return _placeholder(context);
    }

    final uri = Uri.tryParse(imageSource);
    final isRemoteUrl =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    final isAsset = imageSource.startsWith('assets/');
    final isApiImage = imageSource.startsWith('/api/images/');

    if (isAsset) {
      return Image.asset(
        imageSource,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _placeholder(context),
      );
    }

    final imageUrl = isRemoteUrl
        ? Uri.parse('${ApiConfig.baseUrl}/api/image-proxy')
            .replace(queryParameters: {'url': imageSource})
            .toString()
        : isApiImage
            ? '${ApiConfig.baseUrl}$imageSource'
            : '${ApiConfig.baseUrl}/api/images/${imageSource.split('/').map(Uri.encodeComponent).join('/')}';

    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        if (!isRemoteUrl || uri.scheme != 'https') {
          return _placeholder(context);
        }

        return Image.network(
          imageSource,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _placeholder(context),
        );
      },
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(fallbackIcon, size: fallbackIconSize),
    );
  }
}
