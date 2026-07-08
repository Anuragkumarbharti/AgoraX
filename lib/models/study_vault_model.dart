import 'package:flutter/foundation.dart';

class StudyVaultItem {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String coverImage;
  final String category;
  final String course;
  final String semester;
  final String branch;
  final String university;
  final String language;
  final List<String> tags;
  final String authorName;
  final String publisher;
  final String edition;
  final String? isbn;
  final int pages;
  final String fileType; // e.g., 'PDF', 'Notes', 'Books', 'Projects', 'Assignments', 'Question Banks', 'Previous Year Papers', 'Research Paper'
  final String pdfUrl;
  final String thumbnail;
  final int previewPagesCount; // 3, 5, 10, or custom
  final double sellingPrice; // Base price set by seller (0 for free)
  final String license;
  final bool copyrightDeclaration;
  final bool isOfficial;
  final int requiredVipLevel; // 0 = FREE, 1 = VIP1, ..., 5 = VIP5
  final String sellerId;
  final String sellerName;
  final String sellerAvatar;
  final double rating;
  final int reviewsCount;
  final int viewsCount;
  final int downloadsCount;
  final int purchasesCount;
  final DateTime createdAt;
  final String watermarkText;
  final bool isFeatured;
  final String status; // 'Approved', 'Pending', 'Rejected'
  final String? adminComment;

  StudyVaultItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.coverImage,
    required this.category,
    required this.course,
    required this.semester,
    required this.branch,
    required this.university,
    required this.language,
    required this.tags,
    required this.authorName,
    required this.publisher,
    required this.edition,
    this.isbn,
    required this.pages,
    required this.fileType,
    required this.pdfUrl,
    required this.thumbnail,
    required this.previewPagesCount,
    required this.sellingPrice,
    required this.license,
    required this.copyrightDeclaration,
    required this.isOfficial,
    required this.requiredVipLevel,
    required this.sellerId,
    required this.sellerName,
    required this.sellerAvatar,
    this.rating = 0.0,
    this.reviewsCount = 0,
    this.viewsCount = 0,
    this.downloadsCount = 0,
    this.purchasesCount = 0,
    required this.createdAt,
    this.watermarkText = 'AgoraX',
    this.isFeatured = false,
    this.status = 'Pending',
    this.adminComment,
  });

  StudyVaultItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? description,
    String? coverImage,
    String? category,
    String? course,
    String? semester,
    String? branch,
    String? university,
    String? language,
    List<String>? tags,
    String? authorName,
    String? publisher,
    String? edition,
    String? isbn,
    int? pages,
    String? fileType,
    String? pdfUrl,
    String? thumbnail,
    int? previewPagesCount,
    double? sellingPrice,
    String? license,
    bool? copyrightDeclaration,
    bool? isOfficial,
    int? requiredVipLevel,
    String? sellerId,
    String? sellerName,
    String? sellerAvatar,
    double? rating,
    int? reviewsCount,
    int? viewsCount,
    int? downloadsCount,
    int? purchasesCount,
    DateTime? createdAt,
    String? watermarkText,
    bool? isFeatured,
    String? status,
    String? adminComment,
  }) {
    return StudyVaultItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      coverImage: coverImage ?? this.coverImage,
      category: category ?? this.category,
      course: course ?? this.course,
      semester: semester ?? this.semester,
      branch: branch ?? this.branch,
      university: university ?? this.university,
      language: language ?? this.language,
      tags: tags ?? this.tags,
      authorName: authorName ?? this.authorName,
      publisher: publisher ?? this.publisher,
      edition: edition ?? this.edition,
      isbn: isbn ?? this.isbn,
      pages: pages ?? this.pages,
      fileType: fileType ?? this.fileType,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      thumbnail: thumbnail ?? this.thumbnail,
      previewPagesCount: previewPagesCount ?? this.previewPagesCount,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      license: license ?? this.license,
      copyrightDeclaration: copyrightDeclaration ?? this.copyrightDeclaration,
      isOfficial: isOfficial ?? this.isOfficial,
      requiredVipLevel: requiredVipLevel ?? this.requiredVipLevel,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      sellerAvatar: sellerAvatar ?? this.sellerAvatar,
      rating: rating ?? this.rating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      viewsCount: viewsCount ?? this.viewsCount,
      downloadsCount: downloadsCount ?? this.downloadsCount,
      purchasesCount: purchasesCount ?? this.purchasesCount,
      createdAt: createdAt ?? this.createdAt,
      watermarkText: watermarkText ?? this.watermarkText,
      isFeatured: isFeatured ?? this.isFeatured,
      status: status ?? this.status,
      adminComment: adminComment ?? this.adminComment,
    );
  }
}

class StudyReview {
  final String id;
  final String bookId;
  final String userName;
  final String userAvatar;
  final int rating; // 1 to 5
  final String reviewText;
  final int helpfulCount;
  final bool isReported;
  final List<String>? reviewImages;
  final DateTime createdAt;

  StudyReview({
    required this.id,
    required this.bookId,
    required this.userName,
    required this.userAvatar,
    required this.rating,
    required this.reviewText,
    this.helpfulCount = 0,
    this.isReported = false,
    this.reviewImages,
    required this.createdAt,
  });

  StudyReview copyWith({
    String? id,
    String? bookId,
    String? userName,
    String? userAvatar,
    int? rating,
    String? reviewText,
    int? helpfulCount,
    bool? isReported,
    List<String>? reviewImages,
    DateTime? createdAt,
  }) {
    return StudyReview(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      rating: rating ?? this.rating,
      reviewText: reviewText ?? this.reviewText,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      isReported: isReported ?? this.isReported,
      reviewImages: reviewImages ?? this.reviewImages,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class VaultWallet {
  final double currentBalance;
  final double pendingBalance;
  final double withdrawableBalance;
  final double totalEarnings;
  final int totalSales;
  final double refunds;

  VaultWallet({
    this.currentBalance = 0.0,
    this.pendingBalance = 0.0,
    this.withdrawableBalance = 0.0,
    this.totalEarnings = 0.0,
    this.totalSales = 0,
    this.refunds = 0.0,
  });

  VaultWallet copyWith({
    double? currentBalance,
    double? pendingBalance,
    double? withdrawableBalance,
    double? totalEarnings,
    int? totalSales,
    double? refunds,
  }) {
    return VaultWallet(
      currentBalance: currentBalance ?? this.currentBalance,
      pendingBalance: pendingBalance ?? this.pendingBalance,
      withdrawableBalance: withdrawableBalance ?? this.withdrawableBalance,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      totalSales: totalSales ?? this.totalSales,
      refunds: refunds ?? this.refunds,
    );
  }
}

class VaultTransaction {
  final String id;
  final String bookId;
  final String bookTitle;
  final String type; // 'Sale', 'Withdrawal', 'Refund'
  final double amount;
  final String status; // 'Completed', 'Pending', 'Failed'
  final DateTime dateTime;
  final String details;

  VaultTransaction({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.type,
    required this.amount,
    required this.status,
    required this.dateTime,
    required this.details,
  });
}

class ReadingHistory {
  final String bookId;
  final int lastPageRead;
  final double readingProgress; // 0.0 to 1.0
  final DateTime lastReadTime;
  final double totalReadingDurationSeconds;
  final Set<int> bookmarkedPages;
  final Map<int, String> highlights; // page -> highlightedText
  final Map<int, String> personalNotes; // page -> custom note text

  ReadingHistory({
    required this.bookId,
    this.lastPageRead = 1,
    this.readingProgress = 0.0,
    required this.lastReadTime,
    this.totalReadingDurationSeconds = 0.0,
    Set<int>? bookmarkedPages,
    Map<int, String>? highlights,
    Map<int, String>? personalNotes,
  })  : bookmarkedPages = bookmarkedPages ?? {},
        highlights = highlights ?? {},
        personalNotes = personalNotes ?? {};

  ReadingHistory copyWith({
    String? bookId,
    int? lastPageRead,
    double? readingProgress,
    DateTime? lastReadTime,
    double? totalReadingDurationSeconds,
    Set<int>? bookmarkedPages,
    Map<int, String>? highlights,
    Map<int, String>? personalNotes,
  }) {
    return ReadingHistory(
      bookId: bookId ?? this.bookId,
      lastPageRead: lastPageRead ?? this.lastPageRead,
      readingProgress: readingProgress ?? this.readingProgress,
      lastReadTime: lastReadTime ?? this.lastReadTime,
      totalReadingDurationSeconds: totalReadingDurationSeconds ?? this.totalReadingDurationSeconds,
      bookmarkedPages: bookmarkedPages ?? this.bookmarkedPages,
      highlights: highlights ?? this.highlights,
      personalNotes: personalNotes ?? this.personalNotes,
    );
  }
}
