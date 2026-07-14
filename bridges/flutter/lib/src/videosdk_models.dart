class VideoSdkItem {
  const VideoSdkItem({
    required this.id,
    required this.url,
    this.title = '',
  });

  final String id;
  final String url;
  final String title;

  Map<String, dynamic> toMap() => {
        'id': id,
        'url': url,
        'title': title,
      };
}
