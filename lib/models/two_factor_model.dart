class TwoFactorSetupData {
  final String? secret;
  final String? qrCode;
  final String? otpauthUrl;

  const TwoFactorSetupData({
    this.secret,
    this.qrCode,
    this.otpauthUrl,
  });

  factory TwoFactorSetupData.fromJson(Map<String, dynamic> json) {
    return TwoFactorSetupData(
      secret: json['secret']?.toString() ??
          json['secretKey']?.toString() ??
          json['base32']?.toString(),
      qrCode: json['qrCode']?.toString() ??
          json['qrCodeUrl']?.toString() ??
          json['qr']?.toString() ??
          json['qr_code']?.toString(),
      otpauthUrl: json['qrCodeUri']?.toString() ??
          json['otpauthUrl']?.toString() ??
          json['otpauth_url']?.toString() ??
          json['url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (secret != null) 'secret': secret,
        if (qrCode != null) 'qrCode': qrCode,
        if (otpauthUrl != null) 'otpauthUrl': otpauthUrl,
      };
}
