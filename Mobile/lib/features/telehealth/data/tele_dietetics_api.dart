import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/shared/config/app_config.dart';

typedef AdviceChatMessage = ({
  int id,
  bool fromUser,
  String body,
  DateTime createdAt,
  DateTime? readAt,
  List<String> attachments,
});

typedef AdviceChatDelta = ({
  List<AdviceChatMessage> messages,
  bool peerTyping,
  DateTime serverNow,
});

typedef AdviceChatFetch = ({
  List<AdviceChatMessage> messages,
  DateTime? expiresAt,
  DateTime? startsAt,
  String phase,
  bool active,
  DateTime serverNow,
  bool peerTyping,
  bool hasMore,
  int? oldestId,
});

class DietitianDto {
  final String id;
  final int advisorUserId;
  final String name;
  final String specialty;
  final String category;
  final double rating;
  final int hourlyRate;
  final String imageUrl;

  DietitianDto({
    required this.id,
    required this.advisorUserId,
    required this.name,
    required this.specialty,
    required this.category,
    required this.rating,
    required this.hourlyRate,
    required this.imageUrl,
  });

  factory DietitianDto.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic v) {
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is num) return v.toDouble();
      return double.tryParse((v ?? '').toString()) ?? 0.0;
    }

    int asInt(dynamic v) {
      if (v is int) return v;
      if (v is double) return v.round();
      if (v is num) return v.toInt();
      return int.tryParse((v ?? '').toString()) ?? 0;
    }

    return DietitianDto(
      id: (json['id'] ?? '').toString(),
      advisorUserId: asInt(json['advisorUserId'] ?? json['advisor_user_id']),
      name: (json['name'] ?? '').toString(),
      specialty: (json['specialty'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      rating: asDouble(json['rating']),
      hourlyRate: asInt(json['hourlyRate'] ?? json['hourly_rate']),
      imageUrl: AppConfig.normalizeUrlForDevice((json['imageUrl'] ?? json['image_url'] ?? '').toString()),
    );
  }
}

class DietitianApplicationDto {
  DietitianApplicationDto({
    required this.id,
    required this.fullName,
    required this.status,
    this.dateOfBirth,
    this.age,
    this.phone,
    this.altPhone,
    this.professionalEmail,
    this.ghanaCardNumber,
    this.residentialAddress,
    this.city,
    this.region,
    this.highestQualification,
    this.institution,
    this.yearsExperience,
    this.licenseNumber,
    this.bio,
    this.specialty,
    this.category,
    this.hourlyRate,
    this.reviewNotes,
    this.hasCertificate = false,
    this.hasGhanaCard = false,
    this.hasCv = false,
    this.hasProfilePhoto = false,
    this.imageUrl,
  });

  final int id;
  final String fullName;
  final String status;
  final String? dateOfBirth;
  final int? age;
  final String? phone;
  final String? altPhone;
  final String? professionalEmail;
  final String? ghanaCardNumber;
  final String? residentialAddress;
  final String? city;
  final String? region;
  final String? highestQualification;
  final String? institution;
  final int? yearsExperience;
  final String? licenseNumber;
  final String? bio;
  final String? specialty;
  final String? category;
  final int? hourlyRate;
  final String? reviewNotes;
  final bool hasCertificate;
  final bool hasGhanaCard;
  final bool hasCv;
  final bool hasProfilePhoto;
  final String? imageUrl;

  factory DietitianApplicationDto.fromJson(Map<String, dynamic> json) {
    int? asIntOpt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      return int.tryParse(v.toString());
    }

    return DietitianApplicationDto(
      id: asIntOpt(json['id']) ?? 0,
      fullName: (json['full_name'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      dateOfBirth: json['date_of_birth']?.toString(),
      age: asIntOpt(json['age']),
      phone: json['phone']?.toString(),
      altPhone: json['alt_phone']?.toString(),
      professionalEmail: json['professional_email']?.toString(),
      ghanaCardNumber: json['ghana_card_number']?.toString(),
      residentialAddress: json['residential_address']?.toString(),
      city: json['city']?.toString(),
      region: json['region']?.toString(),
      highestQualification: json['highest_qualification']?.toString(),
      institution: json['institution']?.toString(),
      yearsExperience: asIntOpt(json['years_experience']),
      licenseNumber: json['license_number']?.toString(),
      bio: json['bio']?.toString(),
      specialty: json['specialty']?.toString(),
      category: json['category']?.toString(),
      hourlyRate: asIntOpt(json['hourly_rate']),
      reviewNotes: json['review_notes']?.toString(),
      hasCertificate: json['has_certificate'] == true,
      hasGhanaCard: json['has_ghana_card'] == true,
      hasCv: json['has_cv'] == true,
      hasProfilePhoto: json['has_profile_photo'] == true,
      imageUrl: json['image_url'] != null
          ? AppConfig.normalizeUrlForDevice(json['image_url'].toString())
          : null,
    );
  }
}

class ConsultationBookingResult {
  final String status;
  final String message;
  final String? paystackReference;

  ConsultationBookingResult({
    required this.status,
    required this.message,
    required this.paystackReference,
  });

  factory ConsultationBookingResult.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] is Map) ? (json['data'] as Map).map((k, v) => MapEntry(k.toString(), v)) : const <String, dynamic>{};
    return ConsultationBookingResult(
      status: (json['status'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      paystackReference: (data['paystack_reference'] ?? data['paystackReference'])?.toString(),
    );
  }
}

class TeleDieteticsApi {
  TeleDieteticsApi({
    Dio? dio,
    FlutterSecureStorage? storage,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
              ),
            ),
        _storage = storage ?? const FlutterSecureStorage();

  final Dio _dio;
  final FlutterSecureStorage _storage;

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? 0;
  }

  Future<String?> _token() => _storage.read(key: 'sanctum_token');

  Future<List<DietitianDto>> fetchDietitians() async {
    final token = await _token();
    if (token == null || token.isEmpty) return const [];

    final resp = await _dio.get(
      '/dietitians',
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );
    final raw = resp.data;
    final map = (raw is Map) ? raw.map((k, v) => MapEntry(k.toString(), v)) : const <String, dynamic>{};
    final list = map['dietitians'];
    if (list is! List) return const [];
    return list
        .whereType<dynamic>()
        .map((e) => e is Map ? e.map((k, v) => MapEntry(k.toString(), v)) : const <String, dynamic>{})
        .where((e) => e.isNotEmpty)
        .map(DietitianDto.fromJson)
        .toList();
  }

  Future<ConsultationBookingResult> bookConsultation({
    required String dieticianName,
    DateTime? scheduledTime,
  }) async {
    final token = await _token();
    if (token == null || token.isEmpty) {
      return ConsultationBookingResult(
        status: 'error',
        message: 'Missing auth token. Please login again.',
        paystackReference: null,
      );
    }

    final body = <String, dynamic>{
      'dietician_name': dieticianName,
      if (scheduledTime != null) 'scheduled_time': scheduledTime.toIso8601String(),
    };

    final resp = await _dio.post(
      '/consultations/book',
      data: body,
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final raw = resp.data;
    final map = (raw is Map) ? raw.map((k, v) => MapEntry(k.toString(), v)) : const <String, dynamic>{};
    return ConsultationBookingResult.fromJson(map);
  }

  Future<({String authorizationUrl, String reference, int consultationId})?>
      initiatePayment({
    required String dieticianName,
    required int advisorUserId,
    required String type, // ask_now | schedule
    DateTime? scheduledTime,
    int? consultationId,
  }) async {
    final token = await _token();
    if (token == null || token.isEmpty) return null;

    final body = <String, dynamic>{
      'dietician_name': dieticianName,
      'advisor_user_id': advisorUserId,
      'type': type,
      if (scheduledTime != null) 'scheduled_time': scheduledTime.toIso8601String(),
      'consultation_id': consultationId,
    };

    final resp = await _dio.post(
      '/consultations/initiate',
      data: body..removeWhere((k, v) => v == null),
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final raw = resp.data;
    final map = (raw is Map) ? raw.map((k, v) => MapEntry(k.toString(), v)) : const <String, dynamic>{};
    final url = map['authorization_url']?.toString();
    final reference = map['reference']?.toString();
    final consultationIdRaw = map['consultation_id'];
    final parsedConsultationId = consultationIdRaw is int
        ? consultationIdRaw
        : int.tryParse((consultationIdRaw ?? '').toString());
    if (url == null ||
        url.isEmpty ||
        reference == null ||
        reference.isEmpty ||
        parsedConsultationId == null) {
      return null;
    }
    return (authorizationUrl: url, reference: reference, consultationId: parsedConsultationId);
  }

  Future<bool> verifyPayment({required String reference}) async {
    final token = await _token();
    if (token == null || token.isEmpty) return false;

    final resp = await _dio.get(
      '/consultations/verify',
      queryParameters: {'reference': reference},
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );
    final raw = resp.data;
    final map = (raw is Map) ? raw.map((k, v) => MapEntry(k.toString(), v)) : const <String, dynamic>{};
    final payment = (map['payment'] is Map) ? (map['payment'] as Map).map((k, v) => MapEntry(k.toString(), v)) : const <String, dynamic>{};
    final status = payment['consultation_payment_status']?.toString();
    return status == 'paid';
  }

  Future<List<({int id, int advisorUserId, String professionalName, DateTime? scheduledAt, String paymentStatus})>>
      listMyConsultations() async {
    final token = await _token();
    if (token == null || token.isEmpty) return const [];

    final resp = await _dio.get(
      '/consultations/my',
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );
    final raw = resp.data;
    final map =
        (raw is Map) ? raw.map((k, v) => MapEntry(k.toString(), v)) : const <String, dynamic>{};
    final list = map['consultations'];
    if (list is! List) return const [];

    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return list
        .whereType<dynamic>()
        .map((e) => e is Map ? e.map((k, v) => MapEntry(k.toString(), v)) : const <String, dynamic>{})
        .where((e) => e.isNotEmpty)
        .map((e) {
          final idRaw = e['id'];
          final id = idRaw is int ? idRaw : int.tryParse((idRaw ?? '').toString()) ?? 0;
          return (
            id: id,
            advisorUserId: _asInt(e['advisor_user_id'] ?? e['advisorUserId']),
            professionalName: (e['dietician_name'] ?? e['professionalName'] ?? '').toString(),
            scheduledAt: parseDt(e['scheduled_time'] ?? e['scheduledAt']),
            paymentStatus: (e['payment_status'] ?? e['paymentStatus'] ?? '').toString(),
          );
        })
        .where((e) => e.id > 0)
        .toList();
  }

  Future<List<({int id, int userId, String clientName, String professionalName, String paymentStatus, DateTime? expiresAt})>>
      listAdvisorConsultations() async {
    final token = await _token();
    if (token == null || token.isEmpty) return const [];

    final resp = await _dio.get(
      '/advisor/consultations',
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );
    final raw = resp.data;
    final map = (raw is Map) ? raw.map((k, v) => MapEntry(k.toString(), v)) : const <String, dynamic>{};
    final list = map['consultations'];
    if (list is! List) return const [];

    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return list
        .whereType<dynamic>()
        .map((e) => e is Map ? e.map((k, v) => MapEntry(k.toString(), v)) : const <String, dynamic>{})
        .where((e) => e.isNotEmpty)
        .map((e) {
          final idRaw = e['id'];
          final id = idRaw is int ? idRaw : int.tryParse((idRaw ?? '').toString()) ?? 0;
          final userIdRaw = e['user_id'] ?? e['userId'];
          final userId = userIdRaw is int ? userIdRaw : int.tryParse((userIdRaw ?? '').toString()) ?? 0;
          final rawClient = (e['client_name'] ?? e['clientName'] ?? '').toString().trim();
          final clientName =
              rawClient.isNotEmpty ? rawClient : (userId > 0 ? 'User #$userId' : 'Client');
          return (
            id: id,
            userId: userId,
            clientName: clientName,
            professionalName: (e['dietician_name'] ?? '').toString(),
            paymentStatus: (e['payment_status'] ?? '').toString(),
            expiresAt: parseDt(e['session_expires_at']),
          );
        })
        .where((e) => e.id > 0)
        .toList();
  }

  List<String> _parseAttachmentUrls(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((v) => v?.toString() ?? '')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  AdviceChatMessage _parseAdviceChatRow(Map<String, dynamic> e) {
    DateTime? parseDt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
    final idRaw = e['id'];
    final id = idRaw is int ? idRaw : int.tryParse((idRaw ?? '').toString()) ?? 0;
    final sender = (e['sender'] ?? '').toString();
    return (
      id: id,
      fromUser: sender == 'user',
      body: (e['body'] ?? '').toString(),
      createdAt: parseDt(e['created_at']) ?? DateTime.now(),
      readAt: parseDt(e['read_at']),
      attachments: _parseAttachmentUrls(e['attachments']),
    );
  }

  AdviceChatDelta _parseAdviceChatDelta(Map<String, dynamic> map) {
    final list = map['messages'];
    final session = (map['session'] is Map)
        ? (map['session'] as Map).map((k, v) => MapEntry(k.toString(), v))
        : const <String, dynamic>{};
    DateTime? parseDt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
    final msgs = (list is List ? list : const [])
        .whereType<dynamic>()
        .map((e) => e is Map ? e.map((k, v) => MapEntry(k.toString(), v)) : const <String, dynamic>{})
        .where((e) => e.isNotEmpty)
        .map(_parseAdviceChatRow)
        .where((m) => m.id > 0)
        .toList();
    return (
      messages: msgs,
      peerTyping: map['peer_typing'] == true || map['peer_typing']?.toString() == 'true',
      serverNow: parseDt(session['server_now']) ?? DateTime.now(),
    );
  }

  AdviceChatFetch _parseAdviceChatFetch(Map<String, dynamic> map) {
    final list = map['messages'];
    final session = (map['session'] is Map)
        ? (map['session'] as Map).map((k, v) => MapEntry(k.toString(), v))
        : const <String, dynamic>{};
    final pagination = (map['pagination'] is Map)
        ? (map['pagination'] as Map).map((k, v) => MapEntry(k.toString(), v))
        : const <String, dynamic>{};

    DateTime? parseDt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

    final msgs = (list is List ? list : const [])
        .whereType<dynamic>()
        .map((e) => e is Map ? e.map((k, v) => MapEntry(k.toString(), v)) : const <String, dynamic>{})
        .where((e) => e.isNotEmpty)
        .map(_parseAdviceChatRow)
        .where((m) => m.id > 0)
        .toList();

    final oldestRaw = pagination['oldest_id'];
    int? oldestId;
    if (oldestRaw is int) {
      oldestId = oldestRaw;
    } else if (oldestRaw != null) {
      oldestId = int.tryParse(oldestRaw.toString());
    }

    return (
      messages: msgs,
      expiresAt: parseDt(session['expires_at']),
      startsAt: parseDt(session['starts_at']),
      phase: (session['phase'] ?? 'unpaid').toString(),
      active: session['active'] == true,
      serverNow: parseDt(session['server_now']) ?? DateTime.now(),
      peerTyping: map['peer_typing'] == true || map['peer_typing']?.toString() == 'true',
      hasMore: pagination['has_more'] == true || pagination['has_more']?.toString() == 'true',
      oldestId: oldestId,
    );
  }

  Future<AdviceChatFetch> fetchAdvisorMessages({
    required int consultationId,
    int? beforeId,
    int limit = 100,
  }) async {
    final token = await _token();
    if (token == null || token.isEmpty) {
      return (
        messages: const <AdviceChatMessage>[],
        expiresAt: null,
        startsAt: null,
        phase: 'unpaid',
        active: false,
        serverNow: DateTime.now(),
        peerTyping: false,
        hasMore: false,
        oldestId: null,
      );
    }

    final resp = await _dio.get(
      '/advisor/consultations/$consultationId/messages',
      queryParameters: {
        'limit': limit,
        ...(beforeId != null ? <String, dynamic>{'before_id': beforeId} : const {}),
      },
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );
    final raw = resp.data;
    final map = (raw is Map) ? raw.map((k, v) => MapEntry(k.toString(), v)) : const <String, dynamic>{};

    return _parseAdviceChatFetch(map);
  }

  Future<AdviceChatDelta> fetchAdvisorMessagesDelta({
    required int consultationId,
    required int afterId,
  }) async {
    final token = await _token();
    if (token == null || token.isEmpty) {
      return (
        messages: const <AdviceChatMessage>[],
        peerTyping: false,
        serverNow: DateTime.now(),
      );
    }
    final resp = await _dio.get(
      '/advisor/consultations/$consultationId/messages/delta',
      queryParameters: {'after_id': afterId},
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );
    final raw = resp.data;
    final map = (raw is Map) ? raw.map((k, v) => MapEntry(k.toString(), v)) : const <String, dynamic>{};
    return _parseAdviceChatDelta(map);
  }

  Future<void> sendAdvisorTypingPing({required int consultationId}) async {
    final token = await _token();
    if (token == null || token.isEmpty) return;
    try {
      await _dio.post(
        '/advisor/consultations/$consultationId/typing',
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );
    } catch (_) {}
  }

  Future<bool> sendAdvisorMessage({
    required int consultationId,
    required String body,
  }) async {
    final token = await _token();
    if (token == null || token.isEmpty) return false;

    await _dio.post(
      '/advisor/consultations/$consultationId/messages',
      data: {'body': body},
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );
    return true;
  }

  Future<AdviceChatFetch> fetchMessages({
    required int consultationId,
    int? beforeId,
    int limit = 100,
  }) async {
    final token = await _token();
    if (token == null || token.isEmpty) {
      return (
        messages: const <AdviceChatMessage>[],
        expiresAt: null,
        startsAt: null,
        phase: 'unpaid',
        active: false,
        serverNow: DateTime.now(),
        peerTyping: false,
        hasMore: false,
        oldestId: null,
      );
    }

    final resp = await _dio.get(
      '/consultations/$consultationId/messages',
      queryParameters: {
        'limit': limit,
        ...(beforeId != null ? <String, dynamic>{'before_id': beforeId} : const {}),
      },
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final raw = resp.data;
    final map =
        (raw is Map) ? raw.map((k, v) => MapEntry(k.toString(), v)) : const <String, dynamic>{};

    return _parseAdviceChatFetch(map);
  }

  Future<AdviceChatDelta> fetchMessagesDelta({
    required int consultationId,
    required int afterId,
  }) async {
    final token = await _token();
    if (token == null || token.isEmpty) {
      return (
        messages: const <AdviceChatMessage>[],
        peerTyping: false,
        serverNow: DateTime.now(),
      );
    }
    final resp = await _dio.get(
      '/consultations/$consultationId/messages/delta',
      queryParameters: {'after_id': afterId},
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );
    final raw = resp.data;
    final map =
        (raw is Map) ? raw.map((k, v) => MapEntry(k.toString(), v)) : const <String, dynamic>{};
    return _parseAdviceChatDelta(map);
  }

  Future<void> sendUserTypingPing({required int consultationId}) async {
    final token = await _token();
    if (token == null || token.isEmpty) return;
    try {
      await _dio.post(
        '/consultations/$consultationId/typing',
        options: Options(
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );
    } catch (_) {}
  }

  Future<bool> sendMessage({
    required int consultationId,
    required String body,
  }) async {
    final token = await _token();
    if (token == null || token.isEmpty) return false;

    final resp = await _dio.post(
      '/consultations/$consultationId/messages',
      data: {'body': body},
      options: Options(
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ),
    );
    return resp.statusCode != null && resp.statusCode! >= 200 && resp.statusCode! < 300;
  }

  Future<DietitianApplicationDto?> fetchMyDietitianApplication() async {
    final token = await _token();
    if (token == null || token.isEmpty) return null;

    final resp = await _dio.get(
      '/dietetics/application',
      options: Options(
        headers: {
          ...AppConfig.apiHeaders,
          'Authorization': 'Bearer $token',
        },
      ),
    );
    final raw = resp.data;
    final map = (raw is Map) ? raw.map((k, v) => MapEntry(k.toString(), v)) : const <String, dynamic>{};
    final app = map['application'];
    if (app == null) return null;
    if (app is! Map) return null;
    final parsed = app.map((k, v) => MapEntry(k.toString(), v));
    return DietitianApplicationDto.fromJson(parsed);
  }

  Future<({bool ok, String message, DietitianApplicationDto? application})> submitDietitianApplication({
    required String fullName,
    required DateTime dateOfBirth,
    required int age,
    required String phone,
    required String altPhone,
    required String professionalEmail,
    required String ghanaCardNumber,
    required String residentialAddress,
    required String city,
    required String region,
    required String highestQualification,
    required String institution,
    required int yearsExperience,
    required String licenseNumber,
    required String bio,
    required String specialty,
    required String category,
    required int hourlyRate,
    required File certificate,
    required File ghanaCard,
    required File profilePhoto,
    required File cv,
  }) async {
    final token = await _token();
    if (token == null || token.isEmpty) {
      return (ok: false, message: 'Please sign in again.', application: null);
    }

    final dob = '${dateOfBirth.year.toString().padLeft(4, '0')}-'
        '${dateOfBirth.month.toString().padLeft(2, '0')}-'
        '${dateOfBirth.day.toString().padLeft(2, '0')}';

    final formMap = <String, dynamic>{
      'full_name': fullName,
      'date_of_birth': dob,
      'age': age,
      'phone': phone,
      'alt_phone': altPhone,
      'professional_email': professionalEmail,
      'ghana_card_number': ghanaCardNumber,
      'residential_address': residentialAddress,
      'city': city,
      'region': region,
      'highest_qualification': highestQualification,
      'institution': institution,
      'years_experience': yearsExperience,
      'license_number': licenseNumber,
      'bio': bio,
      'specialty': specialty,
      'category': category,
      'hourly_rate': hourlyRate,
      'certificate': await MultipartFile.fromFile(
        certificate.path,
        filename: certificate.uri.pathSegments.last,
      ),
      'ghana_card': await MultipartFile.fromFile(
        ghanaCard.path,
        filename: ghanaCard.uri.pathSegments.last,
      ),
    };

    formMap['profile_photo'] = await MultipartFile.fromFile(
      profilePhoto.path,
      filename: profilePhoto.uri.pathSegments.last,
    );
    formMap['cv'] = await MultipartFile.fromFile(
      cv.path,
      filename: cv.uri.pathSegments.last,
    );

    try {
      final resp = await _dio.post(
        '/dietetics/application',
        data: FormData.fromMap(formMap),
        options: Options(
          headers: {
            ...AppConfig.apiHeaders,
            'Authorization': 'Bearer $token',
          },
        ),
      );
      final raw = resp.data;
      final map = (raw is Map) ? raw.map((k, v) => MapEntry(k.toString(), v)) : const <String, dynamic>{};
      final appRaw = map['application'];
      DietitianApplicationDto? app;
      if (appRaw is Map) {
        app = DietitianApplicationDto.fromJson(appRaw.map((k, v) => MapEntry(k.toString(), v)));
      }
      return (
        ok: true,
        message: (map['message'] ?? 'Application submitted.').toString(),
        application: app,
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      String msg = 'Could not submit application.';
      if (data is Map) {
        final m = data.map((k, v) => MapEntry(k.toString(), v));
        if (m['message'] != null) {
          msg = m['message'].toString();
        } else if (m['errors'] is Map) {
          final errs = (m['errors'] as Map).values.expand((v) => v is List ? v : [v]).map((e) => e.toString());
          msg = errs.join('\n');
        }
      }
      return (ok: false, message: msg, application: null);
    }
  }
}

