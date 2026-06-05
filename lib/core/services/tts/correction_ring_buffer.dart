import 'dart:async';

class CorrectedChunk {
  final String original;
  final String corrected;
  const CorrectedChunk(this.original, this.corrected);
}

class CorrectionRingBuffer {
  final int _maxChunks;
  final List<CorrectedChunk> _queue = [];
  Completer<void>? _waiter;
  bool _closed = false;
  String? _error;

  CorrectionRingBuffer({int maxChunks = 6}) : _maxChunks = maxChunks;

  bool get isClosed => _closed;
  bool get isFull => _queue.length >= _maxChunks;
  String? get error => _error;
  int get length => _queue.length;

  void add(CorrectedChunk entry) {
    _queue.add(entry);
    _waiter?.complete();
    _waiter = null;
  }

  void setError(String msg) {
    _error = msg;
    _closed = true;
    _waiter?.complete();
    _waiter = null;
  }

  void close() {
    _closed = true;
    _waiter?.complete();
    _waiter = null;
  }

  Future<CorrectedChunk?> take() async {
    while (_queue.isEmpty && !_closed) {
      _waiter = Completer<void>();
      await _waiter!.future;
      if (_error != null) return null;
    }
    if (_queue.isEmpty) return null;
    return _queue.removeAt(0);
  }

  void reset() {
    _queue.clear();
    _waiter = null;
    _closed = false;
    _error = null;
  }
}
