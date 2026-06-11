class RssItem {
  final String title;
  final String link;
  final String description;
  final DateTime? pubDate;
  final String sourceName;

  RssItem({
    required this.title,
    required this.link,
    required this.description,
    this.pubDate,
    required this.sourceName,
  });

  String toPromptString(int index) {
    final dateStr = pubDate != null
        ? '${pubDate!.year}-${pubDate!.month.toString().padLeft(2, '0')}-${pubDate!.day.toString().padLeft(2, '0')}'
        : '未知日期';
    return '[$index] $title\n'
        '   来源: $sourceName | 日期: $dateStr\n'
        '   链接: $link\n'
        '   摘要: ${_stripHtml(description)}\n';
  }

  String _stripHtml(String html) {
    var text = html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>'), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text.length > 200 ? '${text.substring(0, 200)}…' : text;
  }
}
