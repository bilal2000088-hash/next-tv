import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class RemoteImage extends StatelessWidget {
  const RemoteImage({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) => const ColoredBox(
        color: Color(0xFF1B2947),
        child: Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (context, url, error) => const ColoredBox(
        color: Color(0xFF1B2947),
        child: Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}
