class DailySpamStat {
  final String dayName;
  final int count;
  final bool isCurrentDay;

  const DailySpamStat({
    required this.dayName,
    required this.count,
    this.isCurrentDay = false,
  });
}

class SpamTypeStat {
  final String typeName;
  final int count;

  const SpamTypeStat({
    required this.typeName,
    required this.count,
  });
}

class ShieldStats {
  final int totalSpamStopped;
  final String timeRange;
  final List<DailySpamStat> dailyStats;
  final List<SpamTypeStat> topSpamTypes;
  final int protectionBannerCount;

  const ShieldStats({
    required this.totalSpamStopped,
    required this.timeRange,
    required this.dailyStats,
    required this.topSpamTypes,
    required this.protectionBannerCount,
  });
}
