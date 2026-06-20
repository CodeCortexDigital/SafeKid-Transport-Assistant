class BillingModel {
  final String id;
  final String parentId;
  final double amount;
  final String status; // paid, unpaid, pending
  final DateTime billingDate;
  final DateTime dueDate;
  final String? paymentMethod; // Card, Bank, Cash, etc.

  BillingModel({
    required this.id,
    required this.parentId,
    required this.amount,
    required this.status,
    required this.billingDate,
    required this.dueDate,
    this.paymentMethod,
  });

  factory BillingModel.fromJson(Map<String, dynamic> json, String docId) {
    return BillingModel(
      id: docId,
      parentId: json['parentId'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'pending',
      billingDate: json['billingDate'] != null
          ? DateTime.tryParse(json['billingDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      dueDate: json['dueDate'] != null
          ? DateTime.tryParse(json['dueDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      paymentMethod: json['paymentMethod'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'parentId': parentId,
      'amount': amount,
      'status': status,
      'billingDate': billingDate.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'paymentMethod': paymentMethod,
    };
  }

  BillingModel copyWith({
    String? id,
    String? parentId,
    double? amount,
    String? status,
    DateTime? billingDate,
    DateTime? dueDate,
    String? paymentMethod,
  }) {
    return BillingModel(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      billingDate: billingDate ?? this.billingDate,
      dueDate: dueDate ?? this.dueDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}
