import 'package:equatable/equatable.dart';

class EmergencyContact extends Equatable {
  final String id;
  final String name;
  final String phoneNumber;
  final String? email;
  final bool notifyBySms;
  final bool notifyByEmail;
  final bool notifyByWhatsapp;

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.email,
    this.notifyBySms = true,
    this.notifyByEmail = false,
    this.notifyByWhatsapp = false,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'] as String,
      name: json['name'] as String,
      phoneNumber: json['phoneNumber'] as String,
      email: json['email'] as String?,
      notifyBySms: json['notifyBySms'] as bool? ?? true,
      notifyByEmail: json['notifyByEmail'] as bool? ?? false,
      notifyByWhatsapp: json['notifyByWhatsapp'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'notifyBySms': notifyBySms,
      'notifyByEmail': notifyByEmail,
      'notifyByWhatsapp': notifyByWhatsapp,
    };
  }

  EmergencyContact copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? email,
    bool? notifyBySms,
    bool? notifyByEmail,
    bool? notifyByWhatsapp,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      notifyBySms: notifyBySms ?? this.notifyBySms,
      notifyByEmail: notifyByEmail ?? this.notifyByEmail,
      notifyByWhatsapp: notifyByWhatsapp ?? this.notifyByWhatsapp,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        phoneNumber,
        email,
        notifyBySms,
        notifyByEmail,
        notifyByWhatsapp,
      ];
}