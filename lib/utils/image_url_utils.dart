String buildOptimizedImageUrl(
  String url, {
  int? width,
  int? height,
  int quality = 80,
  bool contain = true,
}) {
  if (!url.contains('/storage/v1/object/public/')) {
    return url;
  }

  final params = <String>[];
  if (width != null) params.add('width=$width');
  if (height != null) params.add('height=$height');
  if (quality != 100) params.add('quality=$quality');
  if (contain) params.add('resize=contain');

  if (params.isEmpty) return url;
  final separator = url.contains('?') ? '&' : '?';
  return '$url$separator${params.join('&')}';
}
