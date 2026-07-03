class LevelConfig {
  // Số lượng câu hỏi cố định cho mỗi chủ đề
  static const Map<String, int> questionCount = {
    'Tiếng Việt': 30,
    'Tiếng Anh': 30,
    'Toán học': 30,
    'Logic': 12,
    'Suy luận': 18,
    'Sử dụng ngôn ngữ': 60,
    'Tư duy khoa học': 30,
  };

  // Tỷ lệ % độ khó theo Level (1 đến 10)
  static const Map<int, Map<String, double>> difficultyRatio = {
    1: {'Dễ': 0.8, 'Trung bình': 0.2, 'Khó': 0.0},
    2: {'Dễ': 0.7, 'Trung bình': 0.3, 'Khó': 0.0},
    3: {'Dễ': 0.6, 'Trung bình': 0.4, 'Khó': 0.0},
    4: {'Dễ': 0.5, 'Trung bình': 0.4, 'Khó': 0.1},
    5: {'Dễ': 0.4, 'Trung bình': 0.4, 'Khó': 0.2},
    6: {'Dễ': 0.3, 'Trung bình': 0.4, 'Khó': 0.3},
    7: {'Dễ': 0.2, 'Trung bình': 0.5, 'Khó': 0.3},
    8: {'Dễ': 0.1, 'Trung bình': 0.5, 'Khó': 0.4},
    9: {'Dễ': 0.0, 'Trung bình': 0.5, 'Khó': 0.5},
    10: {'Dễ': 0.0, 'Trung bình': 0.3, 'Khó': 0.7},
  };

  // Hàm tính số sao dựa trên tỷ lệ % (0.0 -> 1.0)
  static int calculateStars(double percentage) {
    if (percentage < 0.2) return 1;
    if (percentage < 0.4) return 2;
    if (percentage < 0.6) return 3;
    if (percentage < 0.8) return 4;
    return 5; // Từ 80% đến 100% là 5 sao
  }
}
