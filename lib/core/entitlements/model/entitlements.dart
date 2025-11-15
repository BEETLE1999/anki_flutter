class Entitlements {
  final bool isPro;
  final String plan; // 'free' or 'pro'
  final DateTime? validUntil;

  const Entitlements({
    required this.isPro,
    required this.plan,
    this.validUntil,
  });

  factory Entitlements.fromMap(Map<String, dynamic> map) {
    return Entitlements(
      isPro: map['isPro'] as bool? ?? false,
      plan: map['plan'] as String? ?? 'free',
      validUntil: map['validUntil'] != null
          ? DateTime.tryParse(map['validUntil'] as String)
          : null,
    );
  }

  static const Entitlements free = Entitlements(isPro: false, plan: 'free');
}
