/// 로그인 API 응답 모델
class LoginResponseModel {
  final String message;
  final String? accessToken;
  final String? refreshToken;
  final int? expiresIn; // 초 단위
  final ProfileModel? profile;

  LoginResponseModel({
    required this.message,
    this.accessToken,
    this.refreshToken,
    this.expiresIn,
    this.profile,
  });

  factory LoginResponseModel.fromMap(Map<String, dynamic> map) {
    return LoginResponseModel(
      message: map['message']?.toString() ?? '로그인 실패',
      accessToken: map['accessToken']?.toString(),
      refreshToken: map['refreshToken']?.toString(),
      expiresIn: map['expiresIn'] as int?,
      profile: map['profile'] != null
          ? ProfileModel.fromMap(Map<String, dynamic>.from(map['profile']))
          : null,
    );
  }

  bool get isSuccess => accessToken != null && accessToken!.isNotEmpty;
}

/// 프로필 모델
class ProfileModel {
  final String userId;
  ProfileModel({required this.userId});

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(userId: map['userId']?.toString() ?? '');
  }
}