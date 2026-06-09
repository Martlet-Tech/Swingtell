import 'package:flutter/material.dart';

class ChapterListSheet extends StatefulWidget {
  final List<String> titles;
  final List<int> levels;
  final int currentIndex;
  final void Function(int index) onTap;

  const ChapterListSheet({
    super.key,
    required this.titles,
    required this.levels,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<ChapterListSheet> createState() => _ChapterListSheetState();
}

class _ChapterListSheetState extends State<ChapterListSheet> {
  late final List<int> _parentOf;
  late final List<bool> _isParent;
  final Set<int> _collapsedParents = {};
  final ScrollController _scrollController = ScrollController();
  bool _scrolledToCurrent = false;

  @override
  void initState() {
    super.initState();
    _computeHierarchy();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  void _computeHierarchy() {
    final n = widget.levels.length;
    _parentOf = List.filled(n, -1);
    _isParent = List.filled(n, false);
    final stack = <int>[];
    for (int i = 0; i < n; i++) {
      while (stack.isNotEmpty && widget.levels[stack.last] >= widget.levels[i]) {
        stack.removeLast();
      }
      if (stack.isNotEmpty) _parentOf[i] = stack.last;
      stack.add(i);
    }
    for (int i = 0; i < n - 1; i++) {
      if (widget.levels[i + 1] > widget.levels[i]) {
        _isParent[i] = true;
      }
    }
  }

  bool _isVisible(int index) {
    int p = _parentOf[index];
    while (p != -1) {
      if (_collapsedParents.contains(p)) return false;
      p = _parentOf[p];
    }
    return true;
  }

  void _scrollToCurrent() {
    if (_scrolledToCurrent) return;
    _scrolledToCurrent = true;

    final idx = widget.currentIndex;
    if (idx < 0 || idx >= widget.titles.length) return;

    if (!_scrollController.hasClients) return;
    final listHeight = _scrollController.position.viewportDimension;
    const itemHeight = 48.0;

    // Count visible items up to current
    int visiblePos = 0;
    for (int i = 0; i <= idx; i++) {
      if (_isVisible(i)) visiblePos++;
    }

    final targetScroll = visiblePos * itemHeight - listHeight / 2 + itemHeight / 2;
    _scrollController.jumpTo(
      targetScroll.clamp(0.0, _scrollController.position.maxScrollExtent),
    );
  }

  void _toggleParent(int index) {
    setState(() {
      if (_collapsedParents.contains(index)) {
        _collapsedParents.remove(index);
      } else {
        _collapsedParents.add(index);
      }
    });
  }

  void _expandAll() {
    setState(() => _collapsedParents.clear());
  }

  void _collapseAll() {
    setState(() {
      _collapsedParents.clear();
      for (int i = 0; i < widget.levels.length; i++) {
        if (_isParent[i]) _collapsedParents.add(i);
      }
    });
  }

  bool get _allCollapsed =>
      _isParent.length == _collapsedParents.length &&
      _isParent.where((p) => p).length == _collapsedParents.length;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── 标题栏 ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.black12)),
          ),
          child: Row(
            children: [
              const Text(
                '章节目录',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.unfold_less, size: 20),
                tooltip: '折叠全部',
                onPressed: _allCollapsed ? null : _collapseAll,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.unfold_more, size: 20),
                tooltip: '展开全部',
                onPressed: _collapsedParents.isEmpty ? null : _expandAll,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        // ── 列表 ──
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemCount: widget.titles.length,
            itemBuilder: (context, index) {
              if (!_isVisible(index)) return const SizedBox.shrink();

              final isCurrent = index == widget.currentIndex;
              final indent = widget.levels[index] * 20.0;
              final isParent = _isParent[index];
              final isCollapsed = _collapsedParents.contains(index);

              return Material(
                color: isCurrent
                    ? Colors.blue.withValues(alpha: 0.08)
                    : Colors.transparent,
                child: InkWell(
                  onTap: () => widget.onTap(index),
                  child: Container(
                    padding: EdgeInsets.only(
                      left: 16 + indent,
                      right: 16,
                    ),
                    height: 44,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        // 展开/折叠图标（仅父级）
                        if (isParent)
                          GestureDetector(
                            onTap: () => _toggleParent(index),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                isCollapsed
                                    ? Icons.arrow_right
                                    : Icons.arrow_drop_down,
                                size: 20,
                                color: Colors.grey[600],
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 24),
                        // 标题
                        Expanded(
                          child: Text(
                            widget.titles.isNotEmpty &&
                                    index < widget.titles.length
                                ? widget.titles[index]
                                : '第 ${index + 1} 章',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  isCurrent ? FontWeight.w600 : FontWeight.normal,
                              color: isCurrent ? Colors.blue[700] : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrent)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '当前',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
