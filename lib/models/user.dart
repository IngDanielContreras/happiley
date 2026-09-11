class User {
  final int id;
  final String code;
  final String firstName;
  final String lastName;
  final String documentNumber;
  final String email;
  final String role;
  final String? image;
  final String birthDate;
  final String registrationDate;
  final String lastAccessDate;
  final String passwordExpirationDate;

  // Atributos exclusivos para el rol de administrador
  final String? hiringDate;
  final String? entryDate;
  final String? accessExpirationDate;
  final String? terminationDate;

  User({
    required this.id,
    required this.code,
    required this.firstName,
    required this.lastName,
    required this.documentNumber,
    required this.email,
    required this.role,
    this.image,
    required this.birthDate,
    required this.registrationDate,
    required this.lastAccessDate,
    required this.passwordExpirationDate,
    this.hiringDate,
    this.entryDate,
    this.accessExpirationDate,
    this.terminationDate,
  });

  // Mapeo de base de datos a objeto usuario
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int,
      code: map['code'] as String,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String,
      documentNumber: map['document_number'] as String,
      email: map['email'] as String,
      role: map['role'] as String,
      image: map['image'] as String?,
      birthDate: map['birth_date'] as String,
      registrationDate: map['registration_date'] as String,
      lastAccessDate: map['last_access_date'] as String,
      passwordExpirationDate: map['password_expiration_date'] as String,
      hiringDate: map['hiring_date'] as String?,
      entryDate: map['entry_date'] as String?,
      accessExpirationDate: map['access_expiration_date'] as String?,
      terminationDate: map['termination_date'] as String?,
    );
  }

  // Mapeo de objeto usuario a base de datos
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'first_name': firstName,
      'last_name': lastName,
      'document_number': documentNumber,
      'email': email,
      'role': role,
      'image': image,
      'birth_date': birthDate,
      'registration_date': registrationDate,
      'last_access_date': lastAccessDate,
      'password_expiration_date': passwordExpirationDate,
      'hiring_date': hiringDate,
      'entry_date': entryDate,
      'access_expiration_date': accessExpirationDate,
      'termination_date': terminationDate,
    };
  }
}