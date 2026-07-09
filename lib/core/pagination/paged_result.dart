class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
  });

  final List<T> items;
  final int page;
  final int pageSize;
  final int totalCount;

  int get totalPages {
    if (totalCount <= 0) return 0;
    return (totalCount / pageSize).ceil();
  }

  bool get hasPrevious => page > 1;

  bool get hasNext => page < totalPages;

  static int normalizePage(int page) {
    return page < 1 ? 1 : page;
  }

  static int normalizePageSize(int pageSize) {
    return pageSize <= 0 ? 10 : pageSize;
  }
}
