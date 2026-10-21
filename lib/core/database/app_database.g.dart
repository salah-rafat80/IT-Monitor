// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $UsersTable extends Users with TableInfo<$UsersTable, User> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 50,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _passwordHashMeta = const VerificationMeta(
    'passwordHash',
  );
  @override
  late final GeneratedColumn<String> passwordHash = GeneratedColumn<String>(
    'password_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('viewer'),
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastLoginAtMeta = const VerificationMeta(
    'lastLoginAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastLoginAt = GeneratedColumn<DateTime>(
    'last_login_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    username,
    passwordHash,
    role,
    isEnabled,
    createdAt,
    updatedAt,
    lastLoginAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(
    Insertable<User> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('password_hash')) {
      context.handle(
        _passwordHashMeta,
        passwordHash.isAcceptableOrUnknown(
          data['password_hash']!,
          _passwordHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_passwordHashMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('last_login_at')) {
      context.handle(
        _lastLoginAtMeta,
        lastLoginAt.isAcceptableOrUnknown(
          data['last_login_at']!,
          _lastLoginAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  User map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return User(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      )!,
      passwordHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}password_hash'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      lastLoginAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_login_at'],
      ),
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }
}

class User extends DataClass implements Insertable<User> {
  final int id;
  final String username;
  final String passwordHash;
  final String role;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;
  const User({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.role,
    required this.isEnabled,
    required this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['username'] = Variable<String>(username);
    map['password_hash'] = Variable<String>(passwordHash);
    map['role'] = Variable<String>(role);
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    if (!nullToAbsent || lastLoginAt != null) {
      map['last_login_at'] = Variable<DateTime>(lastLoginAt);
    }
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      username: Value(username),
      passwordHash: Value(passwordHash),
      role: Value(role),
      isEnabled: Value(isEnabled),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      lastLoginAt: lastLoginAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastLoginAt),
    );
  }

  factory User.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return User(
      id: serializer.fromJson<int>(json['id']),
      username: serializer.fromJson<String>(json['username']),
      passwordHash: serializer.fromJson<String>(json['passwordHash']),
      role: serializer.fromJson<String>(json['role']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      lastLoginAt: serializer.fromJson<DateTime?>(json['lastLoginAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'username': serializer.toJson<String>(username),
      'passwordHash': serializer.toJson<String>(passwordHash),
      'role': serializer.toJson<String>(role),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'lastLoginAt': serializer.toJson<DateTime?>(lastLoginAt),
    };
  }

  User copyWith({
    int? id,
    String? username,
    String? passwordHash,
    String? role,
    bool? isEnabled,
    DateTime? createdAt,
    Value<DateTime?> updatedAt = const Value.absent(),
    Value<DateTime?> lastLoginAt = const Value.absent(),
  }) => User(
    id: id ?? this.id,
    username: username ?? this.username,
    passwordHash: passwordHash ?? this.passwordHash,
    role: role ?? this.role,
    isEnabled: isEnabled ?? this.isEnabled,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    lastLoginAt: lastLoginAt.present ? lastLoginAt.value : this.lastLoginAt,
  );
  User copyWithCompanion(UsersCompanion data) {
    return User(
      id: data.id.present ? data.id.value : this.id,
      username: data.username.present ? data.username.value : this.username,
      passwordHash: data.passwordHash.present
          ? data.passwordHash.value
          : this.passwordHash,
      role: data.role.present ? data.role.value : this.role,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastLoginAt: data.lastLoginAt.present
          ? data.lastLoginAt.value
          : this.lastLoginAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('User(')
          ..write('id: $id, ')
          ..write('username: $username, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('role: $role, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastLoginAt: $lastLoginAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    username,
    passwordHash,
    role,
    isEnabled,
    createdAt,
    updatedAt,
    lastLoginAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == this.id &&
          other.username == this.username &&
          other.passwordHash == this.passwordHash &&
          other.role == this.role &&
          other.isEnabled == this.isEnabled &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastLoginAt == this.lastLoginAt);
}

class UsersCompanion extends UpdateCompanion<User> {
  final Value<int> id;
  final Value<String> username;
  final Value<String> passwordHash;
  final Value<String> role;
  final Value<bool> isEnabled;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<DateTime?> lastLoginAt;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.username = const Value.absent(),
    this.passwordHash = const Value.absent(),
    this.role = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastLoginAt = const Value.absent(),
  });
  UsersCompanion.insert({
    this.id = const Value.absent(),
    required String username,
    required String passwordHash,
    this.role = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastLoginAt = const Value.absent(),
  }) : username = Value(username),
       passwordHash = Value(passwordHash);
  static Insertable<User> custom({
    Expression<int>? id,
    Expression<String>? username,
    Expression<String>? passwordHash,
    Expression<String>? role,
    Expression<bool>? isEnabled,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? lastLoginAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (username != null) 'username': username,
      if (passwordHash != null) 'password_hash': passwordHash,
      if (role != null) 'role': role,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastLoginAt != null) 'last_login_at': lastLoginAt,
    });
  }

  UsersCompanion copyWith({
    Value<int>? id,
    Value<String>? username,
    Value<String>? passwordHash,
    Value<String>? role,
    Value<bool>? isEnabled,
    Value<DateTime>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<DateTime?>? lastLoginAt,
  }) {
    return UsersCompanion(
      id: id ?? this.id,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (passwordHash.present) {
      map['password_hash'] = Variable<String>(passwordHash.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (lastLoginAt.present) {
      map['last_login_at'] = Variable<DateTime>(lastLoginAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('username: $username, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('role: $role, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastLoginAt: $lastLoginAt')
          ..write(')'))
        .toString();
  }
}

class $AuditLogsTable extends AuditLogs
    with TableInfo<$AuditLogsTable, AuditLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AuditLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<int> userId = GeneratedColumn<int>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detailsMeta = const VerificationMeta(
    'details',
  );
  @override
  late final GeneratedColumn<String> details = GeneratedColumn<String>(
    'details',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    username,
    action,
    details,
    timestamp,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'audit_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<AuditLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('details')) {
      context.handle(
        _detailsMeta,
        details.isAcceptableOrUnknown(data['details']!, _detailsMeta),
      );
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AuditLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AuditLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}user_id'],
      ),
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      details: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}details'],
      ),
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
    );
  }

  @override
  $AuditLogsTable createAlias(String alias) {
    return $AuditLogsTable(attachedDatabase, alias);
  }
}

class AuditLog extends DataClass implements Insertable<AuditLog> {
  final int id;
  final int? userId;
  final String username;
  final String action;
  final String? details;
  final DateTime timestamp;
  const AuditLog({
    required this.id,
    this.userId,
    required this.username,
    required this.action,
    this.details,
    required this.timestamp,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<int>(userId);
    }
    map['username'] = Variable<String>(username);
    map['action'] = Variable<String>(action);
    if (!nullToAbsent || details != null) {
      map['details'] = Variable<String>(details);
    }
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  AuditLogsCompanion toCompanion(bool nullToAbsent) {
    return AuditLogsCompanion(
      id: Value(id),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      username: Value(username),
      action: Value(action),
      details: details == null && nullToAbsent
          ? const Value.absent()
          : Value(details),
      timestamp: Value(timestamp),
    );
  }

  factory AuditLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AuditLog(
      id: serializer.fromJson<int>(json['id']),
      userId: serializer.fromJson<int?>(json['userId']),
      username: serializer.fromJson<String>(json['username']),
      action: serializer.fromJson<String>(json['action']),
      details: serializer.fromJson<String?>(json['details']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'userId': serializer.toJson<int?>(userId),
      'username': serializer.toJson<String>(username),
      'action': serializer.toJson<String>(action),
      'details': serializer.toJson<String?>(details),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  AuditLog copyWith({
    int? id,
    Value<int?> userId = const Value.absent(),
    String? username,
    String? action,
    Value<String?> details = const Value.absent(),
    DateTime? timestamp,
  }) => AuditLog(
    id: id ?? this.id,
    userId: userId.present ? userId.value : this.userId,
    username: username ?? this.username,
    action: action ?? this.action,
    details: details.present ? details.value : this.details,
    timestamp: timestamp ?? this.timestamp,
  );
  AuditLog copyWithCompanion(AuditLogsCompanion data) {
    return AuditLog(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      username: data.username.present ? data.username.value : this.username,
      action: data.action.present ? data.action.value : this.action,
      details: data.details.present ? data.details.value : this.details,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AuditLog(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('username: $username, ')
          ..write('action: $action, ')
          ..write('details: $details, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, userId, username, action, details, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AuditLog &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.username == this.username &&
          other.action == this.action &&
          other.details == this.details &&
          other.timestamp == this.timestamp);
}

class AuditLogsCompanion extends UpdateCompanion<AuditLog> {
  final Value<int> id;
  final Value<int?> userId;
  final Value<String> username;
  final Value<String> action;
  final Value<String?> details;
  final Value<DateTime> timestamp;
  const AuditLogsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.username = const Value.absent(),
    this.action = const Value.absent(),
    this.details = const Value.absent(),
    this.timestamp = const Value.absent(),
  });
  AuditLogsCompanion.insert({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    required String username,
    required String action,
    this.details = const Value.absent(),
    this.timestamp = const Value.absent(),
  }) : username = Value(username),
       action = Value(action);
  static Insertable<AuditLog> custom({
    Expression<int>? id,
    Expression<int>? userId,
    Expression<String>? username,
    Expression<String>? action,
    Expression<String>? details,
    Expression<DateTime>? timestamp,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (username != null) 'username': username,
      if (action != null) 'action': action,
      if (details != null) 'details': details,
      if (timestamp != null) 'timestamp': timestamp,
    });
  }

  AuditLogsCompanion copyWith({
    Value<int>? id,
    Value<int?>? userId,
    Value<String>? username,
    Value<String>? action,
    Value<String?>? details,
    Value<DateTime>? timestamp,
  }) {
    return AuditLogsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      action: action ?? this.action,
      details: details ?? this.details,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<int>(userId.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (details.present) {
      map['details'] = Variable<String>(details.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AuditLogsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('username: $username, ')
          ..write('action: $action, ')
          ..write('details: $details, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }
}

class $LocationsTable extends Locations
    with TableInfo<$LocationsTable, Location> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, description];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'locations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Location> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Location map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Location(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
    );
  }

  @override
  $LocationsTable createAlias(String alias) {
    return $LocationsTable(attachedDatabase, alias);
  }
}

class Location extends DataClass implements Insertable<Location> {
  final int id;
  final String name;
  final String? description;
  const Location({required this.id, required this.name, this.description});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    return map;
  }

  LocationsCompanion toCompanion(bool nullToAbsent) {
    return LocationsCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
    );
  }

  factory Location.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Location(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
    };
  }

  Location copyWith({
    int? id,
    String? name,
    Value<String?> description = const Value.absent(),
  }) => Location(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
  );
  Location copyWithCompanion(LocationsCompanion data) {
    return Location(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Location(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, description);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Location &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description);
}

class LocationsCompanion extends UpdateCompanion<Location> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> description;
  const LocationsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
  });
  LocationsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Location> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? description,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
    });
  }

  LocationsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? description,
  }) {
    return LocationsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocationsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description')
          ..write(')'))
        .toString();
  }
}

class $DevicesTable extends Devices with TableInfo<$DevicesTable, Device> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pc'),
  );
  static const VerificationMeta _ipMeta = const VerificationMeta('ip');
  @override
  late final GeneratedColumn<String> ip = GeneratedColumn<String>(
    'ip',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerNameMeta = const VerificationMeta(
    'ownerName',
  );
  @override
  late final GeneratedColumn<String> ownerName = GeneratedColumn<String>(
    'owner_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _departmentMeta = const VerificationMeta(
    'department',
  );
  @override
  late final GeneratedColumn<String> department = GeneratedColumn<String>(
    'department',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _officeLocationMeta = const VerificationMeta(
    'officeLocation',
  );
  @override
  late final GeneratedColumn<String> officeLocation = GeneratedColumn<String>(
    'office_location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentSwitchIdMeta = const VerificationMeta(
    'parentSwitchId',
  );
  @override
  late final GeneratedColumn<int> parentSwitchId = GeneratedColumn<int>(
    'parent_switch_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentSwitchNameMeta = const VerificationMeta(
    'parentSwitchName',
  );
  @override
  late final GeneratedColumn<String> parentSwitchName = GeneratedColumn<String>(
    'parent_switch_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vendorMeta = const VerificationMeta('vendor');
  @override
  late final GeneratedColumn<String> vendor = GeneratedColumn<String>(
    'vendor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _macMeta = const VerificationMeta('mac');
  @override
  late final GeneratedColumn<String> mac = GeneratedColumn<String>(
    'mac',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hostnameMeta = const VerificationMeta(
    'hostname',
  );
  @override
  late final GeneratedColumn<String> hostname = GeneratedColumn<String>(
    'hostname',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _operatingSystemMeta = const VerificationMeta(
    'operatingSystem',
  );
  @override
  late final GeneratedColumn<String> operatingSystem = GeneratedColumn<String>(
    'operating_system',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isMonitoredMeta = const VerificationMeta(
    'isMonitored',
  );
  @override
  late final GeneratedColumn<bool> isMonitored = GeneratedColumn<bool>(
    'is_monitored',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_monitored" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    ip,
    ownerName,
    department,
    officeLocation,
    parentSwitchId,
    parentSwitchName,
    vendor,
    model,
    mac,
    hostname,
    operatingSystem,
    notes,
    isMonitored,
    isEnabled,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'devices';
  @override
  VerificationContext validateIntegrity(
    Insertable<Device> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('ip')) {
      context.handle(_ipMeta, ip.isAcceptableOrUnknown(data['ip']!, _ipMeta));
    } else if (isInserting) {
      context.missing(_ipMeta);
    }
    if (data.containsKey('owner_name')) {
      context.handle(
        _ownerNameMeta,
        ownerName.isAcceptableOrUnknown(data['owner_name']!, _ownerNameMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerNameMeta);
    }
    if (data.containsKey('department')) {
      context.handle(
        _departmentMeta,
        department.isAcceptableOrUnknown(data['department']!, _departmentMeta),
      );
    } else if (isInserting) {
      context.missing(_departmentMeta);
    }
    if (data.containsKey('office_location')) {
      context.handle(
        _officeLocationMeta,
        officeLocation.isAcceptableOrUnknown(
          data['office_location']!,
          _officeLocationMeta,
        ),
      );
    }
    if (data.containsKey('parent_switch_id')) {
      context.handle(
        _parentSwitchIdMeta,
        parentSwitchId.isAcceptableOrUnknown(
          data['parent_switch_id']!,
          _parentSwitchIdMeta,
        ),
      );
    }
    if (data.containsKey('parent_switch_name')) {
      context.handle(
        _parentSwitchNameMeta,
        parentSwitchName.isAcceptableOrUnknown(
          data['parent_switch_name']!,
          _parentSwitchNameMeta,
        ),
      );
    }
    if (data.containsKey('vendor')) {
      context.handle(
        _vendorMeta,
        vendor.isAcceptableOrUnknown(data['vendor']!, _vendorMeta),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('mac')) {
      context.handle(
        _macMeta,
        mac.isAcceptableOrUnknown(data['mac']!, _macMeta),
      );
    }
    if (data.containsKey('hostname')) {
      context.handle(
        _hostnameMeta,
        hostname.isAcceptableOrUnknown(data['hostname']!, _hostnameMeta),
      );
    }
    if (data.containsKey('operating_system')) {
      context.handle(
        _operatingSystemMeta,
        operatingSystem.isAcceptableOrUnknown(
          data['operating_system']!,
          _operatingSystemMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('is_monitored')) {
      context.handle(
        _isMonitoredMeta,
        isMonitored.isAcceptableOrUnknown(
          data['is_monitored']!,
          _isMonitoredMeta,
        ),
      );
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Device map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Device(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      ip: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ip'],
      )!,
      ownerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_name'],
      )!,
      department: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}department'],
      )!,
      officeLocation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}office_location'],
      ),
      parentSwitchId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parent_switch_id'],
      ),
      parentSwitchName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_switch_name'],
      ),
      vendor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vendor'],
      ),
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      ),
      mac: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mac'],
      ),
      hostname: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hostname'],
      ),
      operatingSystem: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operating_system'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      isMonitored: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_monitored'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $DevicesTable createAlias(String alias) {
    return $DevicesTable(attachedDatabase, alias);
  }
}

class Device extends DataClass implements Insertable<Device> {
  final int id;
  final String name;
  final String type;
  final String ip;
  final String ownerName;
  final String department;
  final String? officeLocation;
  final int? parentSwitchId;
  final String? parentSwitchName;
  final String? vendor;
  final String? model;
  final String? mac;
  final String? hostname;
  final String? operatingSystem;
  final String? notes;
  final bool isMonitored;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime? updatedAt;
  const Device({
    required this.id,
    required this.name,
    required this.type,
    required this.ip,
    required this.ownerName,
    required this.department,
    this.officeLocation,
    this.parentSwitchId,
    this.parentSwitchName,
    this.vendor,
    this.model,
    this.mac,
    this.hostname,
    this.operatingSystem,
    this.notes,
    required this.isMonitored,
    required this.isEnabled,
    required this.createdAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['ip'] = Variable<String>(ip);
    map['owner_name'] = Variable<String>(ownerName);
    map['department'] = Variable<String>(department);
    if (!nullToAbsent || officeLocation != null) {
      map['office_location'] = Variable<String>(officeLocation);
    }
    if (!nullToAbsent || parentSwitchId != null) {
      map['parent_switch_id'] = Variable<int>(parentSwitchId);
    }
    if (!nullToAbsent || parentSwitchName != null) {
      map['parent_switch_name'] = Variable<String>(parentSwitchName);
    }
    if (!nullToAbsent || vendor != null) {
      map['vendor'] = Variable<String>(vendor);
    }
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    if (!nullToAbsent || mac != null) {
      map['mac'] = Variable<String>(mac);
    }
    if (!nullToAbsent || hostname != null) {
      map['hostname'] = Variable<String>(hostname);
    }
    if (!nullToAbsent || operatingSystem != null) {
      map['operating_system'] = Variable<String>(operatingSystem);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['is_monitored'] = Variable<bool>(isMonitored);
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  DevicesCompanion toCompanion(bool nullToAbsent) {
    return DevicesCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      ip: Value(ip),
      ownerName: Value(ownerName),
      department: Value(department),
      officeLocation: officeLocation == null && nullToAbsent
          ? const Value.absent()
          : Value(officeLocation),
      parentSwitchId: parentSwitchId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentSwitchId),
      parentSwitchName: parentSwitchName == null && nullToAbsent
          ? const Value.absent()
          : Value(parentSwitchName),
      vendor: vendor == null && nullToAbsent
          ? const Value.absent()
          : Value(vendor),
      model: model == null && nullToAbsent
          ? const Value.absent()
          : Value(model),
      mac: mac == null && nullToAbsent ? const Value.absent() : Value(mac),
      hostname: hostname == null && nullToAbsent
          ? const Value.absent()
          : Value(hostname),
      operatingSystem: operatingSystem == null && nullToAbsent
          ? const Value.absent()
          : Value(operatingSystem),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      isMonitored: Value(isMonitored),
      isEnabled: Value(isEnabled),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory Device.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Device(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      ip: serializer.fromJson<String>(json['ip']),
      ownerName: serializer.fromJson<String>(json['ownerName']),
      department: serializer.fromJson<String>(json['department']),
      officeLocation: serializer.fromJson<String?>(json['officeLocation']),
      parentSwitchId: serializer.fromJson<int?>(json['parentSwitchId']),
      parentSwitchName: serializer.fromJson<String?>(json['parentSwitchName']),
      vendor: serializer.fromJson<String?>(json['vendor']),
      model: serializer.fromJson<String?>(json['model']),
      mac: serializer.fromJson<String?>(json['mac']),
      hostname: serializer.fromJson<String?>(json['hostname']),
      operatingSystem: serializer.fromJson<String?>(json['operatingSystem']),
      notes: serializer.fromJson<String?>(json['notes']),
      isMonitored: serializer.fromJson<bool>(json['isMonitored']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'ip': serializer.toJson<String>(ip),
      'ownerName': serializer.toJson<String>(ownerName),
      'department': serializer.toJson<String>(department),
      'officeLocation': serializer.toJson<String?>(officeLocation),
      'parentSwitchId': serializer.toJson<int?>(parentSwitchId),
      'parentSwitchName': serializer.toJson<String?>(parentSwitchName),
      'vendor': serializer.toJson<String?>(vendor),
      'model': serializer.toJson<String?>(model),
      'mac': serializer.toJson<String?>(mac),
      'hostname': serializer.toJson<String?>(hostname),
      'operatingSystem': serializer.toJson<String?>(operatingSystem),
      'notes': serializer.toJson<String?>(notes),
      'isMonitored': serializer.toJson<bool>(isMonitored),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  Device copyWith({
    int? id,
    String? name,
    String? type,
    String? ip,
    String? ownerName,
    String? department,
    Value<String?> officeLocation = const Value.absent(),
    Value<int?> parentSwitchId = const Value.absent(),
    Value<String?> parentSwitchName = const Value.absent(),
    Value<String?> vendor = const Value.absent(),
    Value<String?> model = const Value.absent(),
    Value<String?> mac = const Value.absent(),
    Value<String?> hostname = const Value.absent(),
    Value<String?> operatingSystem = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    bool? isMonitored,
    bool? isEnabled,
    DateTime? createdAt,
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => Device(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    ip: ip ?? this.ip,
    ownerName: ownerName ?? this.ownerName,
    department: department ?? this.department,
    officeLocation: officeLocation.present
        ? officeLocation.value
        : this.officeLocation,
    parentSwitchId: parentSwitchId.present
        ? parentSwitchId.value
        : this.parentSwitchId,
    parentSwitchName: parentSwitchName.present
        ? parentSwitchName.value
        : this.parentSwitchName,
    vendor: vendor.present ? vendor.value : this.vendor,
    model: model.present ? model.value : this.model,
    mac: mac.present ? mac.value : this.mac,
    hostname: hostname.present ? hostname.value : this.hostname,
    operatingSystem: operatingSystem.present
        ? operatingSystem.value
        : this.operatingSystem,
    notes: notes.present ? notes.value : this.notes,
    isMonitored: isMonitored ?? this.isMonitored,
    isEnabled: isEnabled ?? this.isEnabled,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  Device copyWithCompanion(DevicesCompanion data) {
    return Device(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      ip: data.ip.present ? data.ip.value : this.ip,
      ownerName: data.ownerName.present ? data.ownerName.value : this.ownerName,
      department: data.department.present
          ? data.department.value
          : this.department,
      officeLocation: data.officeLocation.present
          ? data.officeLocation.value
          : this.officeLocation,
      parentSwitchId: data.parentSwitchId.present
          ? data.parentSwitchId.value
          : this.parentSwitchId,
      parentSwitchName: data.parentSwitchName.present
          ? data.parentSwitchName.value
          : this.parentSwitchName,
      vendor: data.vendor.present ? data.vendor.value : this.vendor,
      model: data.model.present ? data.model.value : this.model,
      mac: data.mac.present ? data.mac.value : this.mac,
      hostname: data.hostname.present ? data.hostname.value : this.hostname,
      operatingSystem: data.operatingSystem.present
          ? data.operatingSystem.value
          : this.operatingSystem,
      notes: data.notes.present ? data.notes.value : this.notes,
      isMonitored: data.isMonitored.present
          ? data.isMonitored.value
          : this.isMonitored,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Device(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('ip: $ip, ')
          ..write('ownerName: $ownerName, ')
          ..write('department: $department, ')
          ..write('officeLocation: $officeLocation, ')
          ..write('parentSwitchId: $parentSwitchId, ')
          ..write('parentSwitchName: $parentSwitchName, ')
          ..write('vendor: $vendor, ')
          ..write('model: $model, ')
          ..write('mac: $mac, ')
          ..write('hostname: $hostname, ')
          ..write('operatingSystem: $operatingSystem, ')
          ..write('notes: $notes, ')
          ..write('isMonitored: $isMonitored, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    ip,
    ownerName,
    department,
    officeLocation,
    parentSwitchId,
    parentSwitchName,
    vendor,
    model,
    mac,
    hostname,
    operatingSystem,
    notes,
    isMonitored,
    isEnabled,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Device &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.ip == this.ip &&
          other.ownerName == this.ownerName &&
          other.department == this.department &&
          other.officeLocation == this.officeLocation &&
          other.parentSwitchId == this.parentSwitchId &&
          other.parentSwitchName == this.parentSwitchName &&
          other.vendor == this.vendor &&
          other.model == this.model &&
          other.mac == this.mac &&
          other.hostname == this.hostname &&
          other.operatingSystem == this.operatingSystem &&
          other.notes == this.notes &&
          other.isMonitored == this.isMonitored &&
          other.isEnabled == this.isEnabled &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DevicesCompanion extends UpdateCompanion<Device> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String> ip;
  final Value<String> ownerName;
  final Value<String> department;
  final Value<String?> officeLocation;
  final Value<int?> parentSwitchId;
  final Value<String?> parentSwitchName;
  final Value<String?> vendor;
  final Value<String?> model;
  final Value<String?> mac;
  final Value<String?> hostname;
  final Value<String?> operatingSystem;
  final Value<String?> notes;
  final Value<bool> isMonitored;
  final Value<bool> isEnabled;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  const DevicesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.ip = const Value.absent(),
    this.ownerName = const Value.absent(),
    this.department = const Value.absent(),
    this.officeLocation = const Value.absent(),
    this.parentSwitchId = const Value.absent(),
    this.parentSwitchName = const Value.absent(),
    this.vendor = const Value.absent(),
    this.model = const Value.absent(),
    this.mac = const Value.absent(),
    this.hostname = const Value.absent(),
    this.operatingSystem = const Value.absent(),
    this.notes = const Value.absent(),
    this.isMonitored = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  DevicesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.type = const Value.absent(),
    required String ip,
    required String ownerName,
    required String department,
    this.officeLocation = const Value.absent(),
    this.parentSwitchId = const Value.absent(),
    this.parentSwitchName = const Value.absent(),
    this.vendor = const Value.absent(),
    this.model = const Value.absent(),
    this.mac = const Value.absent(),
    this.hostname = const Value.absent(),
    this.operatingSystem = const Value.absent(),
    this.notes = const Value.absent(),
    this.isMonitored = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name),
       ip = Value(ip),
       ownerName = Value(ownerName),
       department = Value(department);
  static Insertable<Device> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? ip,
    Expression<String>? ownerName,
    Expression<String>? department,
    Expression<String>? officeLocation,
    Expression<int>? parentSwitchId,
    Expression<String>? parentSwitchName,
    Expression<String>? vendor,
    Expression<String>? model,
    Expression<String>? mac,
    Expression<String>? hostname,
    Expression<String>? operatingSystem,
    Expression<String>? notes,
    Expression<bool>? isMonitored,
    Expression<bool>? isEnabled,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (ip != null) 'ip': ip,
      if (ownerName != null) 'owner_name': ownerName,
      if (department != null) 'department': department,
      if (officeLocation != null) 'office_location': officeLocation,
      if (parentSwitchId != null) 'parent_switch_id': parentSwitchId,
      if (parentSwitchName != null) 'parent_switch_name': parentSwitchName,
      if (vendor != null) 'vendor': vendor,
      if (model != null) 'model': model,
      if (mac != null) 'mac': mac,
      if (hostname != null) 'hostname': hostname,
      if (operatingSystem != null) 'operating_system': operatingSystem,
      if (notes != null) 'notes': notes,
      if (isMonitored != null) 'is_monitored': isMonitored,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  DevicesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? type,
    Value<String>? ip,
    Value<String>? ownerName,
    Value<String>? department,
    Value<String?>? officeLocation,
    Value<int?>? parentSwitchId,
    Value<String?>? parentSwitchName,
    Value<String?>? vendor,
    Value<String?>? model,
    Value<String?>? mac,
    Value<String?>? hostname,
    Value<String?>? operatingSystem,
    Value<String?>? notes,
    Value<bool>? isMonitored,
    Value<bool>? isEnabled,
    Value<DateTime>? createdAt,
    Value<DateTime?>? updatedAt,
  }) {
    return DevicesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      ip: ip ?? this.ip,
      ownerName: ownerName ?? this.ownerName,
      department: department ?? this.department,
      officeLocation: officeLocation ?? this.officeLocation,
      parentSwitchId: parentSwitchId ?? this.parentSwitchId,
      parentSwitchName: parentSwitchName ?? this.parentSwitchName,
      vendor: vendor ?? this.vendor,
      model: model ?? this.model,
      mac: mac ?? this.mac,
      hostname: hostname ?? this.hostname,
      operatingSystem: operatingSystem ?? this.operatingSystem,
      notes: notes ?? this.notes,
      isMonitored: isMonitored ?? this.isMonitored,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (ip.present) {
      map['ip'] = Variable<String>(ip.value);
    }
    if (ownerName.present) {
      map['owner_name'] = Variable<String>(ownerName.value);
    }
    if (department.present) {
      map['department'] = Variable<String>(department.value);
    }
    if (officeLocation.present) {
      map['office_location'] = Variable<String>(officeLocation.value);
    }
    if (parentSwitchId.present) {
      map['parent_switch_id'] = Variable<int>(parentSwitchId.value);
    }
    if (parentSwitchName.present) {
      map['parent_switch_name'] = Variable<String>(parentSwitchName.value);
    }
    if (vendor.present) {
      map['vendor'] = Variable<String>(vendor.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (mac.present) {
      map['mac'] = Variable<String>(mac.value);
    }
    if (hostname.present) {
      map['hostname'] = Variable<String>(hostname.value);
    }
    if (operatingSystem.present) {
      map['operating_system'] = Variable<String>(operatingSystem.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (isMonitored.present) {
      map['is_monitored'] = Variable<bool>(isMonitored.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DevicesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('ip: $ip, ')
          ..write('ownerName: $ownerName, ')
          ..write('department: $department, ')
          ..write('officeLocation: $officeLocation, ')
          ..write('parentSwitchId: $parentSwitchId, ')
          ..write('parentSwitchName: $parentSwitchName, ')
          ..write('vendor: $vendor, ')
          ..write('model: $model, ')
          ..write('mac: $mac, ')
          ..write('hostname: $hostname, ')
          ..write('operatingSystem: $operatingSystem, ')
          ..write('notes: $notes, ')
          ..write('isMonitored: $isMonitored, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $CheckResultsTable extends CheckResults
    with TableInfo<$CheckResultsTable, CheckResultData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CheckResultsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<int> deviceId = GeneratedColumn<int>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetIpMeta = const VerificationMeta(
    'targetIp',
  );
  @override
  late final GeneratedColumn<String> targetIp = GeneratedColumn<String>(
    'target_ip',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checkTypeMeta = const VerificationMeta(
    'checkType',
  );
  @override
  late final GeneratedColumn<String> checkType = GeneratedColumn<String>(
    'check_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('icmp'),
  );
  static const VerificationMeta _isSuccessMeta = const VerificationMeta(
    'isSuccess',
  );
  @override
  late final GeneratedColumn<bool> isSuccess = GeneratedColumn<bool>(
    'is_success',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_success" IN (0, 1))',
    ),
  );
  static const VerificationMeta _latencyMsMeta = const VerificationMeta(
    'latencyMs',
  );
  @override
  late final GeneratedColumn<int> latencyMs = GeneratedColumn<int>(
    'latency_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _packetLossPercentMeta = const VerificationMeta(
    'packetLossPercent',
  );
  @override
  late final GeneratedColumn<double> packetLossPercent =
      GeneratedColumn<double>(
        'packet_loss_percent',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deviceId,
    assetId,
    targetIp,
    checkType,
    isSuccess,
    latencyMs,
    packetLossPercent,
    errorMessage,
    timestamp,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'check_results';
  @override
  VerificationContext validateIntegrity(
    Insertable<CheckResultData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    }
    if (data.containsKey('target_ip')) {
      context.handle(
        _targetIpMeta,
        targetIp.isAcceptableOrUnknown(data['target_ip']!, _targetIpMeta),
      );
    } else if (isInserting) {
      context.missing(_targetIpMeta);
    }
    if (data.containsKey('check_type')) {
      context.handle(
        _checkTypeMeta,
        checkType.isAcceptableOrUnknown(data['check_type']!, _checkTypeMeta),
      );
    }
    if (data.containsKey('is_success')) {
      context.handle(
        _isSuccessMeta,
        isSuccess.isAcceptableOrUnknown(data['is_success']!, _isSuccessMeta),
      );
    } else if (isInserting) {
      context.missing(_isSuccessMeta);
    }
    if (data.containsKey('latency_ms')) {
      context.handle(
        _latencyMsMeta,
        latencyMs.isAcceptableOrUnknown(data['latency_ms']!, _latencyMsMeta),
      );
    }
    if (data.containsKey('packet_loss_percent')) {
      context.handle(
        _packetLossPercentMeta,
        packetLossPercent.isAcceptableOrUnknown(
          data['packet_loss_percent']!,
          _packetLossPercentMeta,
        ),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CheckResultData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CheckResultData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}device_id'],
      )!,
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      ),
      targetIp: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_ip'],
      )!,
      checkType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}check_type'],
      )!,
      isSuccess: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_success'],
      )!,
      latencyMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}latency_ms'],
      ),
      packetLossPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}packet_loss_percent'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
    );
  }

  @override
  $CheckResultsTable createAlias(String alias) {
    return $CheckResultsTable(attachedDatabase, alias);
  }
}

class CheckResultData extends DataClass implements Insertable<CheckResultData> {
  final int id;
  final int deviceId;
  final String? assetId;
  final String targetIp;
  final String checkType;
  final bool isSuccess;
  final int? latencyMs;
  final double? packetLossPercent;
  final String? errorMessage;
  final DateTime timestamp;
  const CheckResultData({
    required this.id,
    required this.deviceId,
    this.assetId,
    required this.targetIp,
    required this.checkType,
    required this.isSuccess,
    this.latencyMs,
    this.packetLossPercent,
    this.errorMessage,
    required this.timestamp,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['device_id'] = Variable<int>(deviceId);
    if (!nullToAbsent || assetId != null) {
      map['asset_id'] = Variable<String>(assetId);
    }
    map['target_ip'] = Variable<String>(targetIp);
    map['check_type'] = Variable<String>(checkType);
    map['is_success'] = Variable<bool>(isSuccess);
    if (!nullToAbsent || latencyMs != null) {
      map['latency_ms'] = Variable<int>(latencyMs);
    }
    if (!nullToAbsent || packetLossPercent != null) {
      map['packet_loss_percent'] = Variable<double>(packetLossPercent);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  CheckResultsCompanion toCompanion(bool nullToAbsent) {
    return CheckResultsCompanion(
      id: Value(id),
      deviceId: Value(deviceId),
      assetId: assetId == null && nullToAbsent
          ? const Value.absent()
          : Value(assetId),
      targetIp: Value(targetIp),
      checkType: Value(checkType),
      isSuccess: Value(isSuccess),
      latencyMs: latencyMs == null && nullToAbsent
          ? const Value.absent()
          : Value(latencyMs),
      packetLossPercent: packetLossPercent == null && nullToAbsent
          ? const Value.absent()
          : Value(packetLossPercent),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      timestamp: Value(timestamp),
    );
  }

  factory CheckResultData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CheckResultData(
      id: serializer.fromJson<int>(json['id']),
      deviceId: serializer.fromJson<int>(json['deviceId']),
      assetId: serializer.fromJson<String?>(json['assetId']),
      targetIp: serializer.fromJson<String>(json['targetIp']),
      checkType: serializer.fromJson<String>(json['checkType']),
      isSuccess: serializer.fromJson<bool>(json['isSuccess']),
      latencyMs: serializer.fromJson<int?>(json['latencyMs']),
      packetLossPercent: serializer.fromJson<double?>(
        json['packetLossPercent'],
      ),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'deviceId': serializer.toJson<int>(deviceId),
      'assetId': serializer.toJson<String?>(assetId),
      'targetIp': serializer.toJson<String>(targetIp),
      'checkType': serializer.toJson<String>(checkType),
      'isSuccess': serializer.toJson<bool>(isSuccess),
      'latencyMs': serializer.toJson<int?>(latencyMs),
      'packetLossPercent': serializer.toJson<double?>(packetLossPercent),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  CheckResultData copyWith({
    int? id,
    int? deviceId,
    Value<String?> assetId = const Value.absent(),
    String? targetIp,
    String? checkType,
    bool? isSuccess,
    Value<int?> latencyMs = const Value.absent(),
    Value<double?> packetLossPercent = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
    DateTime? timestamp,
  }) => CheckResultData(
    id: id ?? this.id,
    deviceId: deviceId ?? this.deviceId,
    assetId: assetId.present ? assetId.value : this.assetId,
    targetIp: targetIp ?? this.targetIp,
    checkType: checkType ?? this.checkType,
    isSuccess: isSuccess ?? this.isSuccess,
    latencyMs: latencyMs.present ? latencyMs.value : this.latencyMs,
    packetLossPercent: packetLossPercent.present
        ? packetLossPercent.value
        : this.packetLossPercent,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    timestamp: timestamp ?? this.timestamp,
  );
  CheckResultData copyWithCompanion(CheckResultsCompanion data) {
    return CheckResultData(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      targetIp: data.targetIp.present ? data.targetIp.value : this.targetIp,
      checkType: data.checkType.present ? data.checkType.value : this.checkType,
      isSuccess: data.isSuccess.present ? data.isSuccess.value : this.isSuccess,
      latencyMs: data.latencyMs.present ? data.latencyMs.value : this.latencyMs,
      packetLossPercent: data.packetLossPercent.present
          ? data.packetLossPercent.value
          : this.packetLossPercent,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CheckResultData(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('assetId: $assetId, ')
          ..write('targetIp: $targetIp, ')
          ..write('checkType: $checkType, ')
          ..write('isSuccess: $isSuccess, ')
          ..write('latencyMs: $latencyMs, ')
          ..write('packetLossPercent: $packetLossPercent, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    deviceId,
    assetId,
    targetIp,
    checkType,
    isSuccess,
    latencyMs,
    packetLossPercent,
    errorMessage,
    timestamp,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CheckResultData &&
          other.id == this.id &&
          other.deviceId == this.deviceId &&
          other.assetId == this.assetId &&
          other.targetIp == this.targetIp &&
          other.checkType == this.checkType &&
          other.isSuccess == this.isSuccess &&
          other.latencyMs == this.latencyMs &&
          other.packetLossPercent == this.packetLossPercent &&
          other.errorMessage == this.errorMessage &&
          other.timestamp == this.timestamp);
}

class CheckResultsCompanion extends UpdateCompanion<CheckResultData> {
  final Value<int> id;
  final Value<int> deviceId;
  final Value<String?> assetId;
  final Value<String> targetIp;
  final Value<String> checkType;
  final Value<bool> isSuccess;
  final Value<int?> latencyMs;
  final Value<double?> packetLossPercent;
  final Value<String?> errorMessage;
  final Value<DateTime> timestamp;
  const CheckResultsCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.assetId = const Value.absent(),
    this.targetIp = const Value.absent(),
    this.checkType = const Value.absent(),
    this.isSuccess = const Value.absent(),
    this.latencyMs = const Value.absent(),
    this.packetLossPercent = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.timestamp = const Value.absent(),
  });
  CheckResultsCompanion.insert({
    this.id = const Value.absent(),
    required int deviceId,
    this.assetId = const Value.absent(),
    required String targetIp,
    this.checkType = const Value.absent(),
    required bool isSuccess,
    this.latencyMs = const Value.absent(),
    this.packetLossPercent = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.timestamp = const Value.absent(),
  }) : deviceId = Value(deviceId),
       targetIp = Value(targetIp),
       isSuccess = Value(isSuccess);
  static Insertable<CheckResultData> custom({
    Expression<int>? id,
    Expression<int>? deviceId,
    Expression<String>? assetId,
    Expression<String>? targetIp,
    Expression<String>? checkType,
    Expression<bool>? isSuccess,
    Expression<int>? latencyMs,
    Expression<double>? packetLossPercent,
    Expression<String>? errorMessage,
    Expression<DateTime>? timestamp,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
      if (assetId != null) 'asset_id': assetId,
      if (targetIp != null) 'target_ip': targetIp,
      if (checkType != null) 'check_type': checkType,
      if (isSuccess != null) 'is_success': isSuccess,
      if (latencyMs != null) 'latency_ms': latencyMs,
      if (packetLossPercent != null) 'packet_loss_percent': packetLossPercent,
      if (errorMessage != null) 'error_message': errorMessage,
      if (timestamp != null) 'timestamp': timestamp,
    });
  }

  CheckResultsCompanion copyWith({
    Value<int>? id,
    Value<int>? deviceId,
    Value<String?>? assetId,
    Value<String>? targetIp,
    Value<String>? checkType,
    Value<bool>? isSuccess,
    Value<int?>? latencyMs,
    Value<double?>? packetLossPercent,
    Value<String?>? errorMessage,
    Value<DateTime>? timestamp,
  }) {
    return CheckResultsCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      assetId: assetId ?? this.assetId,
      targetIp: targetIp ?? this.targetIp,
      checkType: checkType ?? this.checkType,
      isSuccess: isSuccess ?? this.isSuccess,
      latencyMs: latencyMs ?? this.latencyMs,
      packetLossPercent: packetLossPercent ?? this.packetLossPercent,
      errorMessage: errorMessage ?? this.errorMessage,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<int>(deviceId.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (targetIp.present) {
      map['target_ip'] = Variable<String>(targetIp.value);
    }
    if (checkType.present) {
      map['check_type'] = Variable<String>(checkType.value);
    }
    if (isSuccess.present) {
      map['is_success'] = Variable<bool>(isSuccess.value);
    }
    if (latencyMs.present) {
      map['latency_ms'] = Variable<int>(latencyMs.value);
    }
    if (packetLossPercent.present) {
      map['packet_loss_percent'] = Variable<double>(packetLossPercent.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CheckResultsCompanion(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('assetId: $assetId, ')
          ..write('targetIp: $targetIp, ')
          ..write('checkType: $checkType, ')
          ..write('isSuccess: $isSuccess, ')
          ..write('latencyMs: $latencyMs, ')
          ..write('packetLossPercent: $packetLossPercent, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }
}

class $DeviceStatusesTable extends DeviceStatuses
    with TableInfo<$DeviceStatusesTable, DeviceStatusData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeviceStatusesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<int> deviceId = GeneratedColumn<int>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unknown'),
  );
  static const VerificationMeta _lastSeenMeta = const VerificationMeta(
    'lastSeen',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeen = GeneratedColumn<DateTime>(
    'last_seen',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastCheckAtMeta = const VerificationMeta(
    'lastCheckAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastCheckAt = GeneratedColumn<DateTime>(
    'last_check_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastLatencyMsMeta = const VerificationMeta(
    'lastLatencyMs',
  );
  @override
  late final GeneratedColumn<int> lastLatencyMs = GeneratedColumn<int>(
    'last_latency_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSuccessfulLatencyMsMeta =
      const VerificationMeta('lastSuccessfulLatencyMs');
  @override
  late final GeneratedColumn<int> lastSuccessfulLatencyMs =
      GeneratedColumn<int>(
        'last_successful_latency_ms',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastFailureReasonMeta = const VerificationMeta(
    'lastFailureReason',
  );
  @override
  late final GeneratedColumn<String> lastFailureReason =
      GeneratedColumn<String>(
        'last_failure_reason',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _consecutiveFailuresMeta =
      const VerificationMeta('consecutiveFailures');
  @override
  late final GeneratedColumn<int> consecutiveFailures = GeneratedColumn<int>(
    'consecutive_failures',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _consecutiveSuccessesMeta =
      const VerificationMeta('consecutiveSuccesses');
  @override
  late final GeneratedColumn<int> consecutiveSuccesses = GeneratedColumn<int>(
    'consecutive_successes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusChangedAtMeta = const VerificationMeta(
    'statusChangedAt',
  );
  @override
  late final GeneratedColumn<DateTime> statusChangedAt =
      GeneratedColumn<DateTime>(
        'status_changed_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
        defaultValue: currentDateAndTime,
      );
  static const VerificationMeta _isMaintenanceMeta = const VerificationMeta(
    'isMaintenance',
  );
  @override
  late final GeneratedColumn<bool> isMaintenance = GeneratedColumn<bool>(
    'is_maintenance',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_maintenance" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    deviceId,
    status,
    lastSeen,
    lastCheckAt,
    lastLatencyMs,
    lastSuccessfulLatencyMs,
    lastFailureReason,
    consecutiveFailures,
    consecutiveSuccesses,
    statusChangedAt,
    isMaintenance,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'device_statuses';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeviceStatusData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('last_seen')) {
      context.handle(
        _lastSeenMeta,
        lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta),
      );
    }
    if (data.containsKey('last_check_at')) {
      context.handle(
        _lastCheckAtMeta,
        lastCheckAt.isAcceptableOrUnknown(
          data['last_check_at']!,
          _lastCheckAtMeta,
        ),
      );
    }
    if (data.containsKey('last_latency_ms')) {
      context.handle(
        _lastLatencyMsMeta,
        lastLatencyMs.isAcceptableOrUnknown(
          data['last_latency_ms']!,
          _lastLatencyMsMeta,
        ),
      );
    }
    if (data.containsKey('last_successful_latency_ms')) {
      context.handle(
        _lastSuccessfulLatencyMsMeta,
        lastSuccessfulLatencyMs.isAcceptableOrUnknown(
          data['last_successful_latency_ms']!,
          _lastSuccessfulLatencyMsMeta,
        ),
      );
    }
    if (data.containsKey('last_failure_reason')) {
      context.handle(
        _lastFailureReasonMeta,
        lastFailureReason.isAcceptableOrUnknown(
          data['last_failure_reason']!,
          _lastFailureReasonMeta,
        ),
      );
    }
    if (data.containsKey('consecutive_failures')) {
      context.handle(
        _consecutiveFailuresMeta,
        consecutiveFailures.isAcceptableOrUnknown(
          data['consecutive_failures']!,
          _consecutiveFailuresMeta,
        ),
      );
    }
    if (data.containsKey('consecutive_successes')) {
      context.handle(
        _consecutiveSuccessesMeta,
        consecutiveSuccesses.isAcceptableOrUnknown(
          data['consecutive_successes']!,
          _consecutiveSuccessesMeta,
        ),
      );
    }
    if (data.containsKey('status_changed_at')) {
      context.handle(
        _statusChangedAtMeta,
        statusChangedAt.isAcceptableOrUnknown(
          data['status_changed_at']!,
          _statusChangedAtMeta,
        ),
      );
    }
    if (data.containsKey('is_maintenance')) {
      context.handle(
        _isMaintenanceMeta,
        isMaintenance.isAcceptableOrUnknown(
          data['is_maintenance']!,
          _isMaintenanceMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deviceId};
  @override
  DeviceStatusData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeviceStatusData(
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}device_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      lastSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen'],
      ),
      lastCheckAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_check_at'],
      ),
      lastLatencyMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_latency_ms'],
      ),
      lastSuccessfulLatencyMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_successful_latency_ms'],
      ),
      lastFailureReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_failure_reason'],
      ),
      consecutiveFailures: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}consecutive_failures'],
      )!,
      consecutiveSuccesses: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}consecutive_successes'],
      )!,
      statusChangedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}status_changed_at'],
      )!,
      isMaintenance: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_maintenance'],
      )!,
    );
  }

  @override
  $DeviceStatusesTable createAlias(String alias) {
    return $DeviceStatusesTable(attachedDatabase, alias);
  }
}

class DeviceStatusData extends DataClass
    implements Insertable<DeviceStatusData> {
  final int deviceId;
  final String status;
  final DateTime? lastSeen;
  final DateTime? lastCheckAt;
  final int? lastLatencyMs;
  final int? lastSuccessfulLatencyMs;
  final String? lastFailureReason;
  final int consecutiveFailures;
  final int consecutiveSuccesses;
  final DateTime statusChangedAt;
  final bool isMaintenance;
  const DeviceStatusData({
    required this.deviceId,
    required this.status,
    this.lastSeen,
    this.lastCheckAt,
    this.lastLatencyMs,
    this.lastSuccessfulLatencyMs,
    this.lastFailureReason,
    required this.consecutiveFailures,
    required this.consecutiveSuccesses,
    required this.statusChangedAt,
    required this.isMaintenance,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['device_id'] = Variable<int>(deviceId);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || lastSeen != null) {
      map['last_seen'] = Variable<DateTime>(lastSeen);
    }
    if (!nullToAbsent || lastCheckAt != null) {
      map['last_check_at'] = Variable<DateTime>(lastCheckAt);
    }
    if (!nullToAbsent || lastLatencyMs != null) {
      map['last_latency_ms'] = Variable<int>(lastLatencyMs);
    }
    if (!nullToAbsent || lastSuccessfulLatencyMs != null) {
      map['last_successful_latency_ms'] = Variable<int>(
        lastSuccessfulLatencyMs,
      );
    }
    if (!nullToAbsent || lastFailureReason != null) {
      map['last_failure_reason'] = Variable<String>(lastFailureReason);
    }
    map['consecutive_failures'] = Variable<int>(consecutiveFailures);
    map['consecutive_successes'] = Variable<int>(consecutiveSuccesses);
    map['status_changed_at'] = Variable<DateTime>(statusChangedAt);
    map['is_maintenance'] = Variable<bool>(isMaintenance);
    return map;
  }

  DeviceStatusesCompanion toCompanion(bool nullToAbsent) {
    return DeviceStatusesCompanion(
      deviceId: Value(deviceId),
      status: Value(status),
      lastSeen: lastSeen == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeen),
      lastCheckAt: lastCheckAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCheckAt),
      lastLatencyMs: lastLatencyMs == null && nullToAbsent
          ? const Value.absent()
          : Value(lastLatencyMs),
      lastSuccessfulLatencyMs: lastSuccessfulLatencyMs == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSuccessfulLatencyMs),
      lastFailureReason: lastFailureReason == null && nullToAbsent
          ? const Value.absent()
          : Value(lastFailureReason),
      consecutiveFailures: Value(consecutiveFailures),
      consecutiveSuccesses: Value(consecutiveSuccesses),
      statusChangedAt: Value(statusChangedAt),
      isMaintenance: Value(isMaintenance),
    );
  }

  factory DeviceStatusData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeviceStatusData(
      deviceId: serializer.fromJson<int>(json['deviceId']),
      status: serializer.fromJson<String>(json['status']),
      lastSeen: serializer.fromJson<DateTime?>(json['lastSeen']),
      lastCheckAt: serializer.fromJson<DateTime?>(json['lastCheckAt']),
      lastLatencyMs: serializer.fromJson<int?>(json['lastLatencyMs']),
      lastSuccessfulLatencyMs: serializer.fromJson<int?>(
        json['lastSuccessfulLatencyMs'],
      ),
      lastFailureReason: serializer.fromJson<String?>(
        json['lastFailureReason'],
      ),
      consecutiveFailures: serializer.fromJson<int>(
        json['consecutiveFailures'],
      ),
      consecutiveSuccesses: serializer.fromJson<int>(
        json['consecutiveSuccesses'],
      ),
      statusChangedAt: serializer.fromJson<DateTime>(json['statusChangedAt']),
      isMaintenance: serializer.fromJson<bool>(json['isMaintenance']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deviceId': serializer.toJson<int>(deviceId),
      'status': serializer.toJson<String>(status),
      'lastSeen': serializer.toJson<DateTime?>(lastSeen),
      'lastCheckAt': serializer.toJson<DateTime?>(lastCheckAt),
      'lastLatencyMs': serializer.toJson<int?>(lastLatencyMs),
      'lastSuccessfulLatencyMs': serializer.toJson<int?>(
        lastSuccessfulLatencyMs,
      ),
      'lastFailureReason': serializer.toJson<String?>(lastFailureReason),
      'consecutiveFailures': serializer.toJson<int>(consecutiveFailures),
      'consecutiveSuccesses': serializer.toJson<int>(consecutiveSuccesses),
      'statusChangedAt': serializer.toJson<DateTime>(statusChangedAt),
      'isMaintenance': serializer.toJson<bool>(isMaintenance),
    };
  }

  DeviceStatusData copyWith({
    int? deviceId,
    String? status,
    Value<DateTime?> lastSeen = const Value.absent(),
    Value<DateTime?> lastCheckAt = const Value.absent(),
    Value<int?> lastLatencyMs = const Value.absent(),
    Value<int?> lastSuccessfulLatencyMs = const Value.absent(),
    Value<String?> lastFailureReason = const Value.absent(),
    int? consecutiveFailures,
    int? consecutiveSuccesses,
    DateTime? statusChangedAt,
    bool? isMaintenance,
  }) => DeviceStatusData(
    deviceId: deviceId ?? this.deviceId,
    status: status ?? this.status,
    lastSeen: lastSeen.present ? lastSeen.value : this.lastSeen,
    lastCheckAt: lastCheckAt.present ? lastCheckAt.value : this.lastCheckAt,
    lastLatencyMs: lastLatencyMs.present
        ? lastLatencyMs.value
        : this.lastLatencyMs,
    lastSuccessfulLatencyMs: lastSuccessfulLatencyMs.present
        ? lastSuccessfulLatencyMs.value
        : this.lastSuccessfulLatencyMs,
    lastFailureReason: lastFailureReason.present
        ? lastFailureReason.value
        : this.lastFailureReason,
    consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
    consecutiveSuccesses: consecutiveSuccesses ?? this.consecutiveSuccesses,
    statusChangedAt: statusChangedAt ?? this.statusChangedAt,
    isMaintenance: isMaintenance ?? this.isMaintenance,
  );
  DeviceStatusData copyWithCompanion(DeviceStatusesCompanion data) {
    return DeviceStatusData(
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      status: data.status.present ? data.status.value : this.status,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
      lastCheckAt: data.lastCheckAt.present
          ? data.lastCheckAt.value
          : this.lastCheckAt,
      lastLatencyMs: data.lastLatencyMs.present
          ? data.lastLatencyMs.value
          : this.lastLatencyMs,
      lastSuccessfulLatencyMs: data.lastSuccessfulLatencyMs.present
          ? data.lastSuccessfulLatencyMs.value
          : this.lastSuccessfulLatencyMs,
      lastFailureReason: data.lastFailureReason.present
          ? data.lastFailureReason.value
          : this.lastFailureReason,
      consecutiveFailures: data.consecutiveFailures.present
          ? data.consecutiveFailures.value
          : this.consecutiveFailures,
      consecutiveSuccesses: data.consecutiveSuccesses.present
          ? data.consecutiveSuccesses.value
          : this.consecutiveSuccesses,
      statusChangedAt: data.statusChangedAt.present
          ? data.statusChangedAt.value
          : this.statusChangedAt,
      isMaintenance: data.isMaintenance.present
          ? data.isMaintenance.value
          : this.isMaintenance,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeviceStatusData(')
          ..write('deviceId: $deviceId, ')
          ..write('status: $status, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('lastCheckAt: $lastCheckAt, ')
          ..write('lastLatencyMs: $lastLatencyMs, ')
          ..write('lastSuccessfulLatencyMs: $lastSuccessfulLatencyMs, ')
          ..write('lastFailureReason: $lastFailureReason, ')
          ..write('consecutiveFailures: $consecutiveFailures, ')
          ..write('consecutiveSuccesses: $consecutiveSuccesses, ')
          ..write('statusChangedAt: $statusChangedAt, ')
          ..write('isMaintenance: $isMaintenance')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    deviceId,
    status,
    lastSeen,
    lastCheckAt,
    lastLatencyMs,
    lastSuccessfulLatencyMs,
    lastFailureReason,
    consecutiveFailures,
    consecutiveSuccesses,
    statusChangedAt,
    isMaintenance,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeviceStatusData &&
          other.deviceId == this.deviceId &&
          other.status == this.status &&
          other.lastSeen == this.lastSeen &&
          other.lastCheckAt == this.lastCheckAt &&
          other.lastLatencyMs == this.lastLatencyMs &&
          other.lastSuccessfulLatencyMs == this.lastSuccessfulLatencyMs &&
          other.lastFailureReason == this.lastFailureReason &&
          other.consecutiveFailures == this.consecutiveFailures &&
          other.consecutiveSuccesses == this.consecutiveSuccesses &&
          other.statusChangedAt == this.statusChangedAt &&
          other.isMaintenance == this.isMaintenance);
}

class DeviceStatusesCompanion extends UpdateCompanion<DeviceStatusData> {
  final Value<int> deviceId;
  final Value<String> status;
  final Value<DateTime?> lastSeen;
  final Value<DateTime?> lastCheckAt;
  final Value<int?> lastLatencyMs;
  final Value<int?> lastSuccessfulLatencyMs;
  final Value<String?> lastFailureReason;
  final Value<int> consecutiveFailures;
  final Value<int> consecutiveSuccesses;
  final Value<DateTime> statusChangedAt;
  final Value<bool> isMaintenance;
  const DeviceStatusesCompanion({
    this.deviceId = const Value.absent(),
    this.status = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.lastCheckAt = const Value.absent(),
    this.lastLatencyMs = const Value.absent(),
    this.lastSuccessfulLatencyMs = const Value.absent(),
    this.lastFailureReason = const Value.absent(),
    this.consecutiveFailures = const Value.absent(),
    this.consecutiveSuccesses = const Value.absent(),
    this.statusChangedAt = const Value.absent(),
    this.isMaintenance = const Value.absent(),
  });
  DeviceStatusesCompanion.insert({
    this.deviceId = const Value.absent(),
    this.status = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.lastCheckAt = const Value.absent(),
    this.lastLatencyMs = const Value.absent(),
    this.lastSuccessfulLatencyMs = const Value.absent(),
    this.lastFailureReason = const Value.absent(),
    this.consecutiveFailures = const Value.absent(),
    this.consecutiveSuccesses = const Value.absent(),
    this.statusChangedAt = const Value.absent(),
    this.isMaintenance = const Value.absent(),
  });
  static Insertable<DeviceStatusData> custom({
    Expression<int>? deviceId,
    Expression<String>? status,
    Expression<DateTime>? lastSeen,
    Expression<DateTime>? lastCheckAt,
    Expression<int>? lastLatencyMs,
    Expression<int>? lastSuccessfulLatencyMs,
    Expression<String>? lastFailureReason,
    Expression<int>? consecutiveFailures,
    Expression<int>? consecutiveSuccesses,
    Expression<DateTime>? statusChangedAt,
    Expression<bool>? isMaintenance,
  }) {
    return RawValuesInsertable({
      if (deviceId != null) 'device_id': deviceId,
      if (status != null) 'status': status,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (lastCheckAt != null) 'last_check_at': lastCheckAt,
      if (lastLatencyMs != null) 'last_latency_ms': lastLatencyMs,
      if (lastSuccessfulLatencyMs != null)
        'last_successful_latency_ms': lastSuccessfulLatencyMs,
      if (lastFailureReason != null) 'last_failure_reason': lastFailureReason,
      if (consecutiveFailures != null)
        'consecutive_failures': consecutiveFailures,
      if (consecutiveSuccesses != null)
        'consecutive_successes': consecutiveSuccesses,
      if (statusChangedAt != null) 'status_changed_at': statusChangedAt,
      if (isMaintenance != null) 'is_maintenance': isMaintenance,
    });
  }

  DeviceStatusesCompanion copyWith({
    Value<int>? deviceId,
    Value<String>? status,
    Value<DateTime?>? lastSeen,
    Value<DateTime?>? lastCheckAt,
    Value<int?>? lastLatencyMs,
    Value<int?>? lastSuccessfulLatencyMs,
    Value<String?>? lastFailureReason,
    Value<int>? consecutiveFailures,
    Value<int>? consecutiveSuccesses,
    Value<DateTime>? statusChangedAt,
    Value<bool>? isMaintenance,
  }) {
    return DeviceStatusesCompanion(
      deviceId: deviceId ?? this.deviceId,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      lastCheckAt: lastCheckAt ?? this.lastCheckAt,
      lastLatencyMs: lastLatencyMs ?? this.lastLatencyMs,
      lastSuccessfulLatencyMs:
          lastSuccessfulLatencyMs ?? this.lastSuccessfulLatencyMs,
      lastFailureReason: lastFailureReason ?? this.lastFailureReason,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      consecutiveSuccesses: consecutiveSuccesses ?? this.consecutiveSuccesses,
      statusChangedAt: statusChangedAt ?? this.statusChangedAt,
      isMaintenance: isMaintenance ?? this.isMaintenance,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deviceId.present) {
      map['device_id'] = Variable<int>(deviceId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<DateTime>(lastSeen.value);
    }
    if (lastCheckAt.present) {
      map['last_check_at'] = Variable<DateTime>(lastCheckAt.value);
    }
    if (lastLatencyMs.present) {
      map['last_latency_ms'] = Variable<int>(lastLatencyMs.value);
    }
    if (lastSuccessfulLatencyMs.present) {
      map['last_successful_latency_ms'] = Variable<int>(
        lastSuccessfulLatencyMs.value,
      );
    }
    if (lastFailureReason.present) {
      map['last_failure_reason'] = Variable<String>(lastFailureReason.value);
    }
    if (consecutiveFailures.present) {
      map['consecutive_failures'] = Variable<int>(consecutiveFailures.value);
    }
    if (consecutiveSuccesses.present) {
      map['consecutive_successes'] = Variable<int>(consecutiveSuccesses.value);
    }
    if (statusChangedAt.present) {
      map['status_changed_at'] = Variable<DateTime>(statusChangedAt.value);
    }
    if (isMaintenance.present) {
      map['is_maintenance'] = Variable<bool>(isMaintenance.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeviceStatusesCompanion(')
          ..write('deviceId: $deviceId, ')
          ..write('status: $status, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('lastCheckAt: $lastCheckAt, ')
          ..write('lastLatencyMs: $lastLatencyMs, ')
          ..write('lastSuccessfulLatencyMs: $lastSuccessfulLatencyMs, ')
          ..write('lastFailureReason: $lastFailureReason, ')
          ..write('consecutiveFailures: $consecutiveFailures, ')
          ..write('consecutiveSuccesses: $consecutiveSuccesses, ')
          ..write('statusChangedAt: $statusChangedAt, ')
          ..write('isMaintenance: $isMaintenance')
          ..write(')'))
        .toString();
  }
}

class $IncidentsTable extends Incidents
    with TableInfo<$IncidentsTable, IncidentData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IncidentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<int> deviceId = GeneratedColumn<int>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceNameMeta = const VerificationMeta(
    'deviceName',
  );
  @override
  late final GeneratedColumn<String> deviceName = GeneratedColumn<String>(
    'device_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerNameMeta = const VerificationMeta(
    'ownerName',
  );
  @override
  late final GeneratedColumn<String> ownerName = GeneratedColumn<String>(
    'owner_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _departmentMeta = const VerificationMeta(
    'department',
  );
  @override
  late final GeneratedColumn<String> department = GeneratedColumn<String>(
    'department',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIpMeta = const VerificationMeta(
    'deviceIp',
  );
  @override
  late final GeneratedColumn<String> deviceIp = GeneratedColumn<String>(
    'device_ip',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _incidentTypeMeta = const VerificationMeta(
    'incidentType',
  );
  @override
  late final GeneratedColumn<String> incidentType = GeneratedColumn<String>(
    'incident_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _severityMeta = const VerificationMeta(
    'severity',
  );
  @override
  late final GeneratedColumn<String> severity = GeneratedColumn<String>(
    'severity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('critical'),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _acknowledgedAtMeta = const VerificationMeta(
    'acknowledgedAt',
  );
  @override
  late final GeneratedColumn<DateTime> acknowledgedAt =
      GeneratedColumn<DateTime>(
        'acknowledged_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _acknowledgedByMeta = const VerificationMeta(
    'acknowledgedBy',
  );
  @override
  late final GeneratedColumn<String> acknowledgedBy = GeneratedColumn<String>(
    'acknowledged_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _correlationMessageMeta =
      const VerificationMeta('correlationMessage');
  @override
  late final GeneratedColumn<String> correlationMessage =
      GeneratedColumn<String>(
        'correlation_message',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deviceId,
    deviceName,
    ownerName,
    department,
    location,
    deviceIp,
    incidentType,
    severity,
    status,
    startedAt,
    resolvedAt,
    acknowledgedAt,
    acknowledgedBy,
    notes,
    correlationMessage,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'incidents';
  @override
  VerificationContext validateIntegrity(
    Insertable<IncidentData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('device_name')) {
      context.handle(
        _deviceNameMeta,
        deviceName.isAcceptableOrUnknown(data['device_name']!, _deviceNameMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceNameMeta);
    }
    if (data.containsKey('owner_name')) {
      context.handle(
        _ownerNameMeta,
        ownerName.isAcceptableOrUnknown(data['owner_name']!, _ownerNameMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerNameMeta);
    }
    if (data.containsKey('department')) {
      context.handle(
        _departmentMeta,
        department.isAcceptableOrUnknown(data['department']!, _departmentMeta),
      );
    } else if (isInserting) {
      context.missing(_departmentMeta);
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('device_ip')) {
      context.handle(
        _deviceIpMeta,
        deviceIp.isAcceptableOrUnknown(data['device_ip']!, _deviceIpMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIpMeta);
    }
    if (data.containsKey('incident_type')) {
      context.handle(
        _incidentTypeMeta,
        incidentType.isAcceptableOrUnknown(
          data['incident_type']!,
          _incidentTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_incidentTypeMeta);
    }
    if (data.containsKey('severity')) {
      context.handle(
        _severityMeta,
        severity.isAcceptableOrUnknown(data['severity']!, _severityMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    }
    if (data.containsKey('acknowledged_at')) {
      context.handle(
        _acknowledgedAtMeta,
        acknowledgedAt.isAcceptableOrUnknown(
          data['acknowledged_at']!,
          _acknowledgedAtMeta,
        ),
      );
    }
    if (data.containsKey('acknowledged_by')) {
      context.handle(
        _acknowledgedByMeta,
        acknowledgedBy.isAcceptableOrUnknown(
          data['acknowledged_by']!,
          _acknowledgedByMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('correlation_message')) {
      context.handle(
        _correlationMessageMeta,
        correlationMessage.isAcceptableOrUnknown(
          data['correlation_message']!,
          _correlationMessageMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  IncidentData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IncidentData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}device_id'],
      )!,
      deviceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_name'],
      )!,
      ownerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_name'],
      )!,
      department: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}department'],
      )!,
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
      deviceIp: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_ip'],
      )!,
      incidentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}incident_type'],
      )!,
      severity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}severity'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resolved_at'],
      ),
      acknowledgedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}acknowledged_at'],
      ),
      acknowledgedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}acknowledged_by'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      correlationMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}correlation_message'],
      ),
    );
  }

  @override
  $IncidentsTable createAlias(String alias) {
    return $IncidentsTable(attachedDatabase, alias);
  }
}

class IncidentData extends DataClass implements Insertable<IncidentData> {
  final int id;
  final int deviceId;
  final String deviceName;
  final String ownerName;
  final String department;
  final String? location;
  final String deviceIp;
  final String incidentType;
  final String severity;
  final String status;
  final DateTime startedAt;
  final DateTime? resolvedAt;
  final DateTime? acknowledgedAt;
  final String? acknowledgedBy;
  final String? notes;
  final String? correlationMessage;
  const IncidentData({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.ownerName,
    required this.department,
    this.location,
    required this.deviceIp,
    required this.incidentType,
    required this.severity,
    required this.status,
    required this.startedAt,
    this.resolvedAt,
    this.acknowledgedAt,
    this.acknowledgedBy,
    this.notes,
    this.correlationMessage,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['device_id'] = Variable<int>(deviceId);
    map['device_name'] = Variable<String>(deviceName);
    map['owner_name'] = Variable<String>(ownerName);
    map['department'] = Variable<String>(department);
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    map['device_ip'] = Variable<String>(deviceIp);
    map['incident_type'] = Variable<String>(incidentType);
    map['severity'] = Variable<String>(severity);
    map['status'] = Variable<String>(status);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt);
    }
    if (!nullToAbsent || acknowledgedAt != null) {
      map['acknowledged_at'] = Variable<DateTime>(acknowledgedAt);
    }
    if (!nullToAbsent || acknowledgedBy != null) {
      map['acknowledged_by'] = Variable<String>(acknowledgedBy);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || correlationMessage != null) {
      map['correlation_message'] = Variable<String>(correlationMessage);
    }
    return map;
  }

  IncidentsCompanion toCompanion(bool nullToAbsent) {
    return IncidentsCompanion(
      id: Value(id),
      deviceId: Value(deviceId),
      deviceName: Value(deviceName),
      ownerName: Value(ownerName),
      department: Value(department),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      deviceIp: Value(deviceIp),
      incidentType: Value(incidentType),
      severity: Value(severity),
      status: Value(status),
      startedAt: Value(startedAt),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
      acknowledgedAt: acknowledgedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(acknowledgedAt),
      acknowledgedBy: acknowledgedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(acknowledgedBy),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      correlationMessage: correlationMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(correlationMessage),
    );
  }

  factory IncidentData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IncidentData(
      id: serializer.fromJson<int>(json['id']),
      deviceId: serializer.fromJson<int>(json['deviceId']),
      deviceName: serializer.fromJson<String>(json['deviceName']),
      ownerName: serializer.fromJson<String>(json['ownerName']),
      department: serializer.fromJson<String>(json['department']),
      location: serializer.fromJson<String?>(json['location']),
      deviceIp: serializer.fromJson<String>(json['deviceIp']),
      incidentType: serializer.fromJson<String>(json['incidentType']),
      severity: serializer.fromJson<String>(json['severity']),
      status: serializer.fromJson<String>(json['status']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      resolvedAt: serializer.fromJson<DateTime?>(json['resolvedAt']),
      acknowledgedAt: serializer.fromJson<DateTime?>(json['acknowledgedAt']),
      acknowledgedBy: serializer.fromJson<String?>(json['acknowledgedBy']),
      notes: serializer.fromJson<String?>(json['notes']),
      correlationMessage: serializer.fromJson<String?>(
        json['correlationMessage'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'deviceId': serializer.toJson<int>(deviceId),
      'deviceName': serializer.toJson<String>(deviceName),
      'ownerName': serializer.toJson<String>(ownerName),
      'department': serializer.toJson<String>(department),
      'location': serializer.toJson<String?>(location),
      'deviceIp': serializer.toJson<String>(deviceIp),
      'incidentType': serializer.toJson<String>(incidentType),
      'severity': serializer.toJson<String>(severity),
      'status': serializer.toJson<String>(status),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
      'acknowledgedAt': serializer.toJson<DateTime?>(acknowledgedAt),
      'acknowledgedBy': serializer.toJson<String?>(acknowledgedBy),
      'notes': serializer.toJson<String?>(notes),
      'correlationMessage': serializer.toJson<String?>(correlationMessage),
    };
  }

  IncidentData copyWith({
    int? id,
    int? deviceId,
    String? deviceName,
    String? ownerName,
    String? department,
    Value<String?> location = const Value.absent(),
    String? deviceIp,
    String? incidentType,
    String? severity,
    String? status,
    DateTime? startedAt,
    Value<DateTime?> resolvedAt = const Value.absent(),
    Value<DateTime?> acknowledgedAt = const Value.absent(),
    Value<String?> acknowledgedBy = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> correlationMessage = const Value.absent(),
  }) => IncidentData(
    id: id ?? this.id,
    deviceId: deviceId ?? this.deviceId,
    deviceName: deviceName ?? this.deviceName,
    ownerName: ownerName ?? this.ownerName,
    department: department ?? this.department,
    location: location.present ? location.value : this.location,
    deviceIp: deviceIp ?? this.deviceIp,
    incidentType: incidentType ?? this.incidentType,
    severity: severity ?? this.severity,
    status: status ?? this.status,
    startedAt: startedAt ?? this.startedAt,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
    acknowledgedAt: acknowledgedAt.present
        ? acknowledgedAt.value
        : this.acknowledgedAt,
    acknowledgedBy: acknowledgedBy.present
        ? acknowledgedBy.value
        : this.acknowledgedBy,
    notes: notes.present ? notes.value : this.notes,
    correlationMessage: correlationMessage.present
        ? correlationMessage.value
        : this.correlationMessage,
  );
  IncidentData copyWithCompanion(IncidentsCompanion data) {
    return IncidentData(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      deviceName: data.deviceName.present
          ? data.deviceName.value
          : this.deviceName,
      ownerName: data.ownerName.present ? data.ownerName.value : this.ownerName,
      department: data.department.present
          ? data.department.value
          : this.department,
      location: data.location.present ? data.location.value : this.location,
      deviceIp: data.deviceIp.present ? data.deviceIp.value : this.deviceIp,
      incidentType: data.incidentType.present
          ? data.incidentType.value
          : this.incidentType,
      severity: data.severity.present ? data.severity.value : this.severity,
      status: data.status.present ? data.status.value : this.status,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      resolvedAt: data.resolvedAt.present
          ? data.resolvedAt.value
          : this.resolvedAt,
      acknowledgedAt: data.acknowledgedAt.present
          ? data.acknowledgedAt.value
          : this.acknowledgedAt,
      acknowledgedBy: data.acknowledgedBy.present
          ? data.acknowledgedBy.value
          : this.acknowledgedBy,
      notes: data.notes.present ? data.notes.value : this.notes,
      correlationMessage: data.correlationMessage.present
          ? data.correlationMessage.value
          : this.correlationMessage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IncidentData(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('deviceName: $deviceName, ')
          ..write('ownerName: $ownerName, ')
          ..write('department: $department, ')
          ..write('location: $location, ')
          ..write('deviceIp: $deviceIp, ')
          ..write('incidentType: $incidentType, ')
          ..write('severity: $severity, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('acknowledgedAt: $acknowledgedAt, ')
          ..write('acknowledgedBy: $acknowledgedBy, ')
          ..write('notes: $notes, ')
          ..write('correlationMessage: $correlationMessage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    deviceId,
    deviceName,
    ownerName,
    department,
    location,
    deviceIp,
    incidentType,
    severity,
    status,
    startedAt,
    resolvedAt,
    acknowledgedAt,
    acknowledgedBy,
    notes,
    correlationMessage,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IncidentData &&
          other.id == this.id &&
          other.deviceId == this.deviceId &&
          other.deviceName == this.deviceName &&
          other.ownerName == this.ownerName &&
          other.department == this.department &&
          other.location == this.location &&
          other.deviceIp == this.deviceIp &&
          other.incidentType == this.incidentType &&
          other.severity == this.severity &&
          other.status == this.status &&
          other.startedAt == this.startedAt &&
          other.resolvedAt == this.resolvedAt &&
          other.acknowledgedAt == this.acknowledgedAt &&
          other.acknowledgedBy == this.acknowledgedBy &&
          other.notes == this.notes &&
          other.correlationMessage == this.correlationMessage);
}

class IncidentsCompanion extends UpdateCompanion<IncidentData> {
  final Value<int> id;
  final Value<int> deviceId;
  final Value<String> deviceName;
  final Value<String> ownerName;
  final Value<String> department;
  final Value<String?> location;
  final Value<String> deviceIp;
  final Value<String> incidentType;
  final Value<String> severity;
  final Value<String> status;
  final Value<DateTime> startedAt;
  final Value<DateTime?> resolvedAt;
  final Value<DateTime?> acknowledgedAt;
  final Value<String?> acknowledgedBy;
  final Value<String?> notes;
  final Value<String?> correlationMessage;
  const IncidentsCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.deviceName = const Value.absent(),
    this.ownerName = const Value.absent(),
    this.department = const Value.absent(),
    this.location = const Value.absent(),
    this.deviceIp = const Value.absent(),
    this.incidentType = const Value.absent(),
    this.severity = const Value.absent(),
    this.status = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.acknowledgedAt = const Value.absent(),
    this.acknowledgedBy = const Value.absent(),
    this.notes = const Value.absent(),
    this.correlationMessage = const Value.absent(),
  });
  IncidentsCompanion.insert({
    this.id = const Value.absent(),
    required int deviceId,
    required String deviceName,
    required String ownerName,
    required String department,
    this.location = const Value.absent(),
    required String deviceIp,
    required String incidentType,
    this.severity = const Value.absent(),
    this.status = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.acknowledgedAt = const Value.absent(),
    this.acknowledgedBy = const Value.absent(),
    this.notes = const Value.absent(),
    this.correlationMessage = const Value.absent(),
  }) : deviceId = Value(deviceId),
       deviceName = Value(deviceName),
       ownerName = Value(ownerName),
       department = Value(department),
       deviceIp = Value(deviceIp),
       incidentType = Value(incidentType);
  static Insertable<IncidentData> custom({
    Expression<int>? id,
    Expression<int>? deviceId,
    Expression<String>? deviceName,
    Expression<String>? ownerName,
    Expression<String>? department,
    Expression<String>? location,
    Expression<String>? deviceIp,
    Expression<String>? incidentType,
    Expression<String>? severity,
    Expression<String>? status,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? resolvedAt,
    Expression<DateTime>? acknowledgedAt,
    Expression<String>? acknowledgedBy,
    Expression<String>? notes,
    Expression<String>? correlationMessage,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
      if (deviceName != null) 'device_name': deviceName,
      if (ownerName != null) 'owner_name': ownerName,
      if (department != null) 'department': department,
      if (location != null) 'location': location,
      if (deviceIp != null) 'device_ip': deviceIp,
      if (incidentType != null) 'incident_type': incidentType,
      if (severity != null) 'severity': severity,
      if (status != null) 'status': status,
      if (startedAt != null) 'started_at': startedAt,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (acknowledgedAt != null) 'acknowledged_at': acknowledgedAt,
      if (acknowledgedBy != null) 'acknowledged_by': acknowledgedBy,
      if (notes != null) 'notes': notes,
      if (correlationMessage != null) 'correlation_message': correlationMessage,
    });
  }

  IncidentsCompanion copyWith({
    Value<int>? id,
    Value<int>? deviceId,
    Value<String>? deviceName,
    Value<String>? ownerName,
    Value<String>? department,
    Value<String?>? location,
    Value<String>? deviceIp,
    Value<String>? incidentType,
    Value<String>? severity,
    Value<String>? status,
    Value<DateTime>? startedAt,
    Value<DateTime?>? resolvedAt,
    Value<DateTime?>? acknowledgedAt,
    Value<String?>? acknowledgedBy,
    Value<String?>? notes,
    Value<String?>? correlationMessage,
  }) {
    return IncidentsCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      ownerName: ownerName ?? this.ownerName,
      department: department ?? this.department,
      location: location ?? this.location,
      deviceIp: deviceIp ?? this.deviceIp,
      incidentType: incidentType ?? this.incidentType,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      acknowledgedBy: acknowledgedBy ?? this.acknowledgedBy,
      notes: notes ?? this.notes,
      correlationMessage: correlationMessage ?? this.correlationMessage,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<int>(deviceId.value);
    }
    if (deviceName.present) {
      map['device_name'] = Variable<String>(deviceName.value);
    }
    if (ownerName.present) {
      map['owner_name'] = Variable<String>(ownerName.value);
    }
    if (department.present) {
      map['department'] = Variable<String>(department.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (deviceIp.present) {
      map['device_ip'] = Variable<String>(deviceIp.value);
    }
    if (incidentType.present) {
      map['incident_type'] = Variable<String>(incidentType.value);
    }
    if (severity.present) {
      map['severity'] = Variable<String>(severity.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    if (acknowledgedAt.present) {
      map['acknowledged_at'] = Variable<DateTime>(acknowledgedAt.value);
    }
    if (acknowledgedBy.present) {
      map['acknowledged_by'] = Variable<String>(acknowledgedBy.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (correlationMessage.present) {
      map['correlation_message'] = Variable<String>(correlationMessage.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IncidentsCompanion(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('deviceName: $deviceName, ')
          ..write('ownerName: $ownerName, ')
          ..write('department: $department, ')
          ..write('location: $location, ')
          ..write('deviceIp: $deviceIp, ')
          ..write('incidentType: $incidentType, ')
          ..write('severity: $severity, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('acknowledgedAt: $acknowledgedAt, ')
          ..write('acknowledgedBy: $acknowledgedBy, ')
          ..write('notes: $notes, ')
          ..write('correlationMessage: $correlationMessage')
          ..write(')'))
        .toString();
  }
}

class $DiscoveryConfigurationsTable extends DiscoveryConfigurations
    with TableInfo<$DiscoveryConfigurationsTable, DiscoveryConfigurationData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiscoveryConfigurationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _authorizedRangesJsonMeta =
      const VerificationMeta('authorizedRangesJson');
  @override
  late final GeneratedColumn<String> authorizedRangesJson =
      GeneratedColumn<String>(
        'authorized_ranges_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('["192.168.27.0/24","192.168.22.0/24"]'),
      );
  static const VerificationMeta _enabledStrategiesJsonMeta =
      const VerificationMeta('enabledStrategiesJson');
  @override
  late final GeneratedColumn<String> enabledStrategiesJson =
      GeneratedColumn<String>(
        'enabled_strategies_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(
          '["icmp","arp","dns","tcp_probe","onvif","mdns"]',
        ),
      );
  static const VerificationMeta _maxConcurrencyMeta = const VerificationMeta(
    'maxConcurrency',
  );
  @override
  late final GeneratedColumn<int> maxConcurrency = GeneratedColumn<int>(
    'max_concurrency',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(20),
  );
  static const VerificationMeta _timeoutSecondsMeta = const VerificationMeta(
    'timeoutSeconds',
  );
  @override
  late final GeneratedColumn<int> timeoutSeconds = GeneratedColumn<int>(
    'timeout_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    authorizedRangesJson,
    enabledStrategiesJson,
    maxConcurrency,
    timeoutSeconds,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'discovery_configurations';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiscoveryConfigurationData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('authorized_ranges_json')) {
      context.handle(
        _authorizedRangesJsonMeta,
        authorizedRangesJson.isAcceptableOrUnknown(
          data['authorized_ranges_json']!,
          _authorizedRangesJsonMeta,
        ),
      );
    }
    if (data.containsKey('enabled_strategies_json')) {
      context.handle(
        _enabledStrategiesJsonMeta,
        enabledStrategiesJson.isAcceptableOrUnknown(
          data['enabled_strategies_json']!,
          _enabledStrategiesJsonMeta,
        ),
      );
    }
    if (data.containsKey('max_concurrency')) {
      context.handle(
        _maxConcurrencyMeta,
        maxConcurrency.isAcceptableOrUnknown(
          data['max_concurrency']!,
          _maxConcurrencyMeta,
        ),
      );
    }
    if (data.containsKey('timeout_seconds')) {
      context.handle(
        _timeoutSecondsMeta,
        timeoutSeconds.isAcceptableOrUnknown(
          data['timeout_seconds']!,
          _timeoutSecondsMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DiscoveryConfigurationData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiscoveryConfigurationData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      authorizedRangesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}authorized_ranges_json'],
      )!,
      enabledStrategiesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}enabled_strategies_json'],
      )!,
      maxConcurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_concurrency'],
      )!,
      timeoutSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timeout_seconds'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DiscoveryConfigurationsTable createAlias(String alias) {
    return $DiscoveryConfigurationsTable(attachedDatabase, alias);
  }
}

class DiscoveryConfigurationData extends DataClass
    implements Insertable<DiscoveryConfigurationData> {
  final int id;
  final String authorizedRangesJson;
  final String enabledStrategiesJson;
  final int maxConcurrency;
  final int timeoutSeconds;
  final DateTime updatedAt;
  const DiscoveryConfigurationData({
    required this.id,
    required this.authorizedRangesJson,
    required this.enabledStrategiesJson,
    required this.maxConcurrency,
    required this.timeoutSeconds,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['authorized_ranges_json'] = Variable<String>(authorizedRangesJson);
    map['enabled_strategies_json'] = Variable<String>(enabledStrategiesJson);
    map['max_concurrency'] = Variable<int>(maxConcurrency);
    map['timeout_seconds'] = Variable<int>(timeoutSeconds);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DiscoveryConfigurationsCompanion toCompanion(bool nullToAbsent) {
    return DiscoveryConfigurationsCompanion(
      id: Value(id),
      authorizedRangesJson: Value(authorizedRangesJson),
      enabledStrategiesJson: Value(enabledStrategiesJson),
      maxConcurrency: Value(maxConcurrency),
      timeoutSeconds: Value(timeoutSeconds),
      updatedAt: Value(updatedAt),
    );
  }

  factory DiscoveryConfigurationData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiscoveryConfigurationData(
      id: serializer.fromJson<int>(json['id']),
      authorizedRangesJson: serializer.fromJson<String>(
        json['authorizedRangesJson'],
      ),
      enabledStrategiesJson: serializer.fromJson<String>(
        json['enabledStrategiesJson'],
      ),
      maxConcurrency: serializer.fromJson<int>(json['maxConcurrency']),
      timeoutSeconds: serializer.fromJson<int>(json['timeoutSeconds']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'authorizedRangesJson': serializer.toJson<String>(authorizedRangesJson),
      'enabledStrategiesJson': serializer.toJson<String>(enabledStrategiesJson),
      'maxConcurrency': serializer.toJson<int>(maxConcurrency),
      'timeoutSeconds': serializer.toJson<int>(timeoutSeconds),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DiscoveryConfigurationData copyWith({
    int? id,
    String? authorizedRangesJson,
    String? enabledStrategiesJson,
    int? maxConcurrency,
    int? timeoutSeconds,
    DateTime? updatedAt,
  }) => DiscoveryConfigurationData(
    id: id ?? this.id,
    authorizedRangesJson: authorizedRangesJson ?? this.authorizedRangesJson,
    enabledStrategiesJson: enabledStrategiesJson ?? this.enabledStrategiesJson,
    maxConcurrency: maxConcurrency ?? this.maxConcurrency,
    timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DiscoveryConfigurationData copyWithCompanion(
    DiscoveryConfigurationsCompanion data,
  ) {
    return DiscoveryConfigurationData(
      id: data.id.present ? data.id.value : this.id,
      authorizedRangesJson: data.authorizedRangesJson.present
          ? data.authorizedRangesJson.value
          : this.authorizedRangesJson,
      enabledStrategiesJson: data.enabledStrategiesJson.present
          ? data.enabledStrategiesJson.value
          : this.enabledStrategiesJson,
      maxConcurrency: data.maxConcurrency.present
          ? data.maxConcurrency.value
          : this.maxConcurrency,
      timeoutSeconds: data.timeoutSeconds.present
          ? data.timeoutSeconds.value
          : this.timeoutSeconds,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiscoveryConfigurationData(')
          ..write('id: $id, ')
          ..write('authorizedRangesJson: $authorizedRangesJson, ')
          ..write('enabledStrategiesJson: $enabledStrategiesJson, ')
          ..write('maxConcurrency: $maxConcurrency, ')
          ..write('timeoutSeconds: $timeoutSeconds, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    authorizedRangesJson,
    enabledStrategiesJson,
    maxConcurrency,
    timeoutSeconds,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiscoveryConfigurationData &&
          other.id == this.id &&
          other.authorizedRangesJson == this.authorizedRangesJson &&
          other.enabledStrategiesJson == this.enabledStrategiesJson &&
          other.maxConcurrency == this.maxConcurrency &&
          other.timeoutSeconds == this.timeoutSeconds &&
          other.updatedAt == this.updatedAt);
}

class DiscoveryConfigurationsCompanion
    extends UpdateCompanion<DiscoveryConfigurationData> {
  final Value<int> id;
  final Value<String> authorizedRangesJson;
  final Value<String> enabledStrategiesJson;
  final Value<int> maxConcurrency;
  final Value<int> timeoutSeconds;
  final Value<DateTime> updatedAt;
  const DiscoveryConfigurationsCompanion({
    this.id = const Value.absent(),
    this.authorizedRangesJson = const Value.absent(),
    this.enabledStrategiesJson = const Value.absent(),
    this.maxConcurrency = const Value.absent(),
    this.timeoutSeconds = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  DiscoveryConfigurationsCompanion.insert({
    this.id = const Value.absent(),
    this.authorizedRangesJson = const Value.absent(),
    this.enabledStrategiesJson = const Value.absent(),
    this.maxConcurrency = const Value.absent(),
    this.timeoutSeconds = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  static Insertable<DiscoveryConfigurationData> custom({
    Expression<int>? id,
    Expression<String>? authorizedRangesJson,
    Expression<String>? enabledStrategiesJson,
    Expression<int>? maxConcurrency,
    Expression<int>? timeoutSeconds,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (authorizedRangesJson != null)
        'authorized_ranges_json': authorizedRangesJson,
      if (enabledStrategiesJson != null)
        'enabled_strategies_json': enabledStrategiesJson,
      if (maxConcurrency != null) 'max_concurrency': maxConcurrency,
      if (timeoutSeconds != null) 'timeout_seconds': timeoutSeconds,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  DiscoveryConfigurationsCompanion copyWith({
    Value<int>? id,
    Value<String>? authorizedRangesJson,
    Value<String>? enabledStrategiesJson,
    Value<int>? maxConcurrency,
    Value<int>? timeoutSeconds,
    Value<DateTime>? updatedAt,
  }) {
    return DiscoveryConfigurationsCompanion(
      id: id ?? this.id,
      authorizedRangesJson: authorizedRangesJson ?? this.authorizedRangesJson,
      enabledStrategiesJson:
          enabledStrategiesJson ?? this.enabledStrategiesJson,
      maxConcurrency: maxConcurrency ?? this.maxConcurrency,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (authorizedRangesJson.present) {
      map['authorized_ranges_json'] = Variable<String>(
        authorizedRangesJson.value,
      );
    }
    if (enabledStrategiesJson.present) {
      map['enabled_strategies_json'] = Variable<String>(
        enabledStrategiesJson.value,
      );
    }
    if (maxConcurrency.present) {
      map['max_concurrency'] = Variable<int>(maxConcurrency.value);
    }
    if (timeoutSeconds.present) {
      map['timeout_seconds'] = Variable<int>(timeoutSeconds.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiscoveryConfigurationsCompanion(')
          ..write('id: $id, ')
          ..write('authorizedRangesJson: $authorizedRangesJson, ')
          ..write('enabledStrategiesJson: $enabledStrategiesJson, ')
          ..write('maxConcurrency: $maxConcurrency, ')
          ..write('timeoutSeconds: $timeoutSeconds, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $DiscoveryScansTable extends DiscoveryScans
    with TableInfo<$DiscoveryScansTable, DiscoveryScanData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiscoveryScansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('draft'),
  );
  static const VerificationMeta _rangesJsonMeta = const VerificationMeta(
    'rangesJson',
  );
  @override
  late final GeneratedColumn<String> rangesJson = GeneratedColumn<String>(
    'ranges_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledStrategiesJsonMeta =
      const VerificationMeta('enabledStrategiesJson');
  @override
  late final GeneratedColumn<String> enabledStrategiesJson =
      GeneratedColumn<String>(
        'enabled_strategies_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(
          '["icmp","arp","dns","tcp_probe","onvif","mdns"]',
        ),
      );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _targetsEnumeratedMeta = const VerificationMeta(
    'targetsEnumerated',
  );
  @override
  late final GeneratedColumn<int> targetsEnumerated = GeneratedColumn<int>(
    'targets_enumerated',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _targetsAttemptedMeta = const VerificationMeta(
    'targetsAttempted',
  );
  @override
  late final GeneratedColumn<int> targetsAttempted = GeneratedColumn<int>(
    'targets_attempted',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _responsesReceivedMeta = const VerificationMeta(
    'responsesReceived',
  );
  @override
  late final GeneratedColumn<int> responsesReceived = GeneratedColumn<int>(
    'responses_received',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _classifiedCountMeta = const VerificationMeta(
    'classifiedCount',
  );
  @override
  late final GeneratedColumn<int> classifiedCount = GeneratedColumn<int>(
    'classified_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _unknownCountMeta = const VerificationMeta(
    'unknownCount',
  );
  @override
  late final GeneratedColumn<int> unknownCount = GeneratedColumn<int>(
    'unknown_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _failureCountMeta = const VerificationMeta(
    'failureCount',
  );
  @override
  late final GeneratedColumn<int> failureCount = GeneratedColumn<int>(
    'failure_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _diagnosticSummaryMeta = const VerificationMeta(
    'diagnosticSummary',
  );
  @override
  late final GeneratedColumn<String> diagnosticSummary =
      GeneratedColumn<String>(
        'diagnostic_summary',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    status,
    rangesJson,
    enabledStrategiesJson,
    startedAt,
    completedAt,
    targetsEnumerated,
    targetsAttempted,
    responsesReceived,
    classifiedCount,
    unknownCount,
    failureCount,
    diagnosticSummary,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'discovery_scans';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiscoveryScanData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('ranges_json')) {
      context.handle(
        _rangesJsonMeta,
        rangesJson.isAcceptableOrUnknown(data['ranges_json']!, _rangesJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_rangesJsonMeta);
    }
    if (data.containsKey('enabled_strategies_json')) {
      context.handle(
        _enabledStrategiesJsonMeta,
        enabledStrategiesJson.isAcceptableOrUnknown(
          data['enabled_strategies_json']!,
          _enabledStrategiesJsonMeta,
        ),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('targets_enumerated')) {
      context.handle(
        _targetsEnumeratedMeta,
        targetsEnumerated.isAcceptableOrUnknown(
          data['targets_enumerated']!,
          _targetsEnumeratedMeta,
        ),
      );
    }
    if (data.containsKey('targets_attempted')) {
      context.handle(
        _targetsAttemptedMeta,
        targetsAttempted.isAcceptableOrUnknown(
          data['targets_attempted']!,
          _targetsAttemptedMeta,
        ),
      );
    }
    if (data.containsKey('responses_received')) {
      context.handle(
        _responsesReceivedMeta,
        responsesReceived.isAcceptableOrUnknown(
          data['responses_received']!,
          _responsesReceivedMeta,
        ),
      );
    }
    if (data.containsKey('classified_count')) {
      context.handle(
        _classifiedCountMeta,
        classifiedCount.isAcceptableOrUnknown(
          data['classified_count']!,
          _classifiedCountMeta,
        ),
      );
    }
    if (data.containsKey('unknown_count')) {
      context.handle(
        _unknownCountMeta,
        unknownCount.isAcceptableOrUnknown(
          data['unknown_count']!,
          _unknownCountMeta,
        ),
      );
    }
    if (data.containsKey('failure_count')) {
      context.handle(
        _failureCountMeta,
        failureCount.isAcceptableOrUnknown(
          data['failure_count']!,
          _failureCountMeta,
        ),
      );
    }
    if (data.containsKey('diagnostic_summary')) {
      context.handle(
        _diagnosticSummaryMeta,
        diagnosticSummary.isAcceptableOrUnknown(
          data['diagnostic_summary']!,
          _diagnosticSummaryMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DiscoveryScanData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiscoveryScanData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      rangesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ranges_json'],
      )!,
      enabledStrategiesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}enabled_strategies_json'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      targetsEnumerated: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}targets_enumerated'],
      )!,
      targetsAttempted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}targets_attempted'],
      )!,
      responsesReceived: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}responses_received'],
      )!,
      classifiedCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}classified_count'],
      )!,
      unknownCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unknown_count'],
      )!,
      failureCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}failure_count'],
      )!,
      diagnosticSummary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}diagnostic_summary'],
      ),
    );
  }

  @override
  $DiscoveryScansTable createAlias(String alias) {
    return $DiscoveryScansTable(attachedDatabase, alias);
  }
}

class DiscoveryScanData extends DataClass
    implements Insertable<DiscoveryScanData> {
  final int id;
  final String status;
  final String rangesJson;
  final String enabledStrategiesJson;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int targetsEnumerated;
  final int targetsAttempted;
  final int responsesReceived;
  final int classifiedCount;
  final int unknownCount;
  final int failureCount;
  final String? diagnosticSummary;
  const DiscoveryScanData({
    required this.id,
    required this.status,
    required this.rangesJson,
    required this.enabledStrategiesJson,
    required this.startedAt,
    this.completedAt,
    required this.targetsEnumerated,
    required this.targetsAttempted,
    required this.responsesReceived,
    required this.classifiedCount,
    required this.unknownCount,
    required this.failureCount,
    this.diagnosticSummary,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['status'] = Variable<String>(status);
    map['ranges_json'] = Variable<String>(rangesJson);
    map['enabled_strategies_json'] = Variable<String>(enabledStrategiesJson);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['targets_enumerated'] = Variable<int>(targetsEnumerated);
    map['targets_attempted'] = Variable<int>(targetsAttempted);
    map['responses_received'] = Variable<int>(responsesReceived);
    map['classified_count'] = Variable<int>(classifiedCount);
    map['unknown_count'] = Variable<int>(unknownCount);
    map['failure_count'] = Variable<int>(failureCount);
    if (!nullToAbsent || diagnosticSummary != null) {
      map['diagnostic_summary'] = Variable<String>(diagnosticSummary);
    }
    return map;
  }

  DiscoveryScansCompanion toCompanion(bool nullToAbsent) {
    return DiscoveryScansCompanion(
      id: Value(id),
      status: Value(status),
      rangesJson: Value(rangesJson),
      enabledStrategiesJson: Value(enabledStrategiesJson),
      startedAt: Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      targetsEnumerated: Value(targetsEnumerated),
      targetsAttempted: Value(targetsAttempted),
      responsesReceived: Value(responsesReceived),
      classifiedCount: Value(classifiedCount),
      unknownCount: Value(unknownCount),
      failureCount: Value(failureCount),
      diagnosticSummary: diagnosticSummary == null && nullToAbsent
          ? const Value.absent()
          : Value(diagnosticSummary),
    );
  }

  factory DiscoveryScanData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiscoveryScanData(
      id: serializer.fromJson<int>(json['id']),
      status: serializer.fromJson<String>(json['status']),
      rangesJson: serializer.fromJson<String>(json['rangesJson']),
      enabledStrategiesJson: serializer.fromJson<String>(
        json['enabledStrategiesJson'],
      ),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      targetsEnumerated: serializer.fromJson<int>(json['targetsEnumerated']),
      targetsAttempted: serializer.fromJson<int>(json['targetsAttempted']),
      responsesReceived: serializer.fromJson<int>(json['responsesReceived']),
      classifiedCount: serializer.fromJson<int>(json['classifiedCount']),
      unknownCount: serializer.fromJson<int>(json['unknownCount']),
      failureCount: serializer.fromJson<int>(json['failureCount']),
      diagnosticSummary: serializer.fromJson<String?>(
        json['diagnosticSummary'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'status': serializer.toJson<String>(status),
      'rangesJson': serializer.toJson<String>(rangesJson),
      'enabledStrategiesJson': serializer.toJson<String>(enabledStrategiesJson),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'targetsEnumerated': serializer.toJson<int>(targetsEnumerated),
      'targetsAttempted': serializer.toJson<int>(targetsAttempted),
      'responsesReceived': serializer.toJson<int>(responsesReceived),
      'classifiedCount': serializer.toJson<int>(classifiedCount),
      'unknownCount': serializer.toJson<int>(unknownCount),
      'failureCount': serializer.toJson<int>(failureCount),
      'diagnosticSummary': serializer.toJson<String?>(diagnosticSummary),
    };
  }

  DiscoveryScanData copyWith({
    int? id,
    String? status,
    String? rangesJson,
    String? enabledStrategiesJson,
    DateTime? startedAt,
    Value<DateTime?> completedAt = const Value.absent(),
    int? targetsEnumerated,
    int? targetsAttempted,
    int? responsesReceived,
    int? classifiedCount,
    int? unknownCount,
    int? failureCount,
    Value<String?> diagnosticSummary = const Value.absent(),
  }) => DiscoveryScanData(
    id: id ?? this.id,
    status: status ?? this.status,
    rangesJson: rangesJson ?? this.rangesJson,
    enabledStrategiesJson: enabledStrategiesJson ?? this.enabledStrategiesJson,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    targetsEnumerated: targetsEnumerated ?? this.targetsEnumerated,
    targetsAttempted: targetsAttempted ?? this.targetsAttempted,
    responsesReceived: responsesReceived ?? this.responsesReceived,
    classifiedCount: classifiedCount ?? this.classifiedCount,
    unknownCount: unknownCount ?? this.unknownCount,
    failureCount: failureCount ?? this.failureCount,
    diagnosticSummary: diagnosticSummary.present
        ? diagnosticSummary.value
        : this.diagnosticSummary,
  );
  DiscoveryScanData copyWithCompanion(DiscoveryScansCompanion data) {
    return DiscoveryScanData(
      id: data.id.present ? data.id.value : this.id,
      status: data.status.present ? data.status.value : this.status,
      rangesJson: data.rangesJson.present
          ? data.rangesJson.value
          : this.rangesJson,
      enabledStrategiesJson: data.enabledStrategiesJson.present
          ? data.enabledStrategiesJson.value
          : this.enabledStrategiesJson,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      targetsEnumerated: data.targetsEnumerated.present
          ? data.targetsEnumerated.value
          : this.targetsEnumerated,
      targetsAttempted: data.targetsAttempted.present
          ? data.targetsAttempted.value
          : this.targetsAttempted,
      responsesReceived: data.responsesReceived.present
          ? data.responsesReceived.value
          : this.responsesReceived,
      classifiedCount: data.classifiedCount.present
          ? data.classifiedCount.value
          : this.classifiedCount,
      unknownCount: data.unknownCount.present
          ? data.unknownCount.value
          : this.unknownCount,
      failureCount: data.failureCount.present
          ? data.failureCount.value
          : this.failureCount,
      diagnosticSummary: data.diagnosticSummary.present
          ? data.diagnosticSummary.value
          : this.diagnosticSummary,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiscoveryScanData(')
          ..write('id: $id, ')
          ..write('status: $status, ')
          ..write('rangesJson: $rangesJson, ')
          ..write('enabledStrategiesJson: $enabledStrategiesJson, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('targetsEnumerated: $targetsEnumerated, ')
          ..write('targetsAttempted: $targetsAttempted, ')
          ..write('responsesReceived: $responsesReceived, ')
          ..write('classifiedCount: $classifiedCount, ')
          ..write('unknownCount: $unknownCount, ')
          ..write('failureCount: $failureCount, ')
          ..write('diagnosticSummary: $diagnosticSummary')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    status,
    rangesJson,
    enabledStrategiesJson,
    startedAt,
    completedAt,
    targetsEnumerated,
    targetsAttempted,
    responsesReceived,
    classifiedCount,
    unknownCount,
    failureCount,
    diagnosticSummary,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiscoveryScanData &&
          other.id == this.id &&
          other.status == this.status &&
          other.rangesJson == this.rangesJson &&
          other.enabledStrategiesJson == this.enabledStrategiesJson &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.targetsEnumerated == this.targetsEnumerated &&
          other.targetsAttempted == this.targetsAttempted &&
          other.responsesReceived == this.responsesReceived &&
          other.classifiedCount == this.classifiedCount &&
          other.unknownCount == this.unknownCount &&
          other.failureCount == this.failureCount &&
          other.diagnosticSummary == this.diagnosticSummary);
}

class DiscoveryScansCompanion extends UpdateCompanion<DiscoveryScanData> {
  final Value<int> id;
  final Value<String> status;
  final Value<String> rangesJson;
  final Value<String> enabledStrategiesJson;
  final Value<DateTime> startedAt;
  final Value<DateTime?> completedAt;
  final Value<int> targetsEnumerated;
  final Value<int> targetsAttempted;
  final Value<int> responsesReceived;
  final Value<int> classifiedCount;
  final Value<int> unknownCount;
  final Value<int> failureCount;
  final Value<String?> diagnosticSummary;
  const DiscoveryScansCompanion({
    this.id = const Value.absent(),
    this.status = const Value.absent(),
    this.rangesJson = const Value.absent(),
    this.enabledStrategiesJson = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.targetsEnumerated = const Value.absent(),
    this.targetsAttempted = const Value.absent(),
    this.responsesReceived = const Value.absent(),
    this.classifiedCount = const Value.absent(),
    this.unknownCount = const Value.absent(),
    this.failureCount = const Value.absent(),
    this.diagnosticSummary = const Value.absent(),
  });
  DiscoveryScansCompanion.insert({
    this.id = const Value.absent(),
    this.status = const Value.absent(),
    required String rangesJson,
    this.enabledStrategiesJson = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.targetsEnumerated = const Value.absent(),
    this.targetsAttempted = const Value.absent(),
    this.responsesReceived = const Value.absent(),
    this.classifiedCount = const Value.absent(),
    this.unknownCount = const Value.absent(),
    this.failureCount = const Value.absent(),
    this.diagnosticSummary = const Value.absent(),
  }) : rangesJson = Value(rangesJson);
  static Insertable<DiscoveryScanData> custom({
    Expression<int>? id,
    Expression<String>? status,
    Expression<String>? rangesJson,
    Expression<String>? enabledStrategiesJson,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? completedAt,
    Expression<int>? targetsEnumerated,
    Expression<int>? targetsAttempted,
    Expression<int>? responsesReceived,
    Expression<int>? classifiedCount,
    Expression<int>? unknownCount,
    Expression<int>? failureCount,
    Expression<String>? diagnosticSummary,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (status != null) 'status': status,
      if (rangesJson != null) 'ranges_json': rangesJson,
      if (enabledStrategiesJson != null)
        'enabled_strategies_json': enabledStrategiesJson,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (targetsEnumerated != null) 'targets_enumerated': targetsEnumerated,
      if (targetsAttempted != null) 'targets_attempted': targetsAttempted,
      if (responsesReceived != null) 'responses_received': responsesReceived,
      if (classifiedCount != null) 'classified_count': classifiedCount,
      if (unknownCount != null) 'unknown_count': unknownCount,
      if (failureCount != null) 'failure_count': failureCount,
      if (diagnosticSummary != null) 'diagnostic_summary': diagnosticSummary,
    });
  }

  DiscoveryScansCompanion copyWith({
    Value<int>? id,
    Value<String>? status,
    Value<String>? rangesJson,
    Value<String>? enabledStrategiesJson,
    Value<DateTime>? startedAt,
    Value<DateTime?>? completedAt,
    Value<int>? targetsEnumerated,
    Value<int>? targetsAttempted,
    Value<int>? responsesReceived,
    Value<int>? classifiedCount,
    Value<int>? unknownCount,
    Value<int>? failureCount,
    Value<String?>? diagnosticSummary,
  }) {
    return DiscoveryScansCompanion(
      id: id ?? this.id,
      status: status ?? this.status,
      rangesJson: rangesJson ?? this.rangesJson,
      enabledStrategiesJson:
          enabledStrategiesJson ?? this.enabledStrategiesJson,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      targetsEnumerated: targetsEnumerated ?? this.targetsEnumerated,
      targetsAttempted: targetsAttempted ?? this.targetsAttempted,
      responsesReceived: responsesReceived ?? this.responsesReceived,
      classifiedCount: classifiedCount ?? this.classifiedCount,
      unknownCount: unknownCount ?? this.unknownCount,
      failureCount: failureCount ?? this.failureCount,
      diagnosticSummary: diagnosticSummary ?? this.diagnosticSummary,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rangesJson.present) {
      map['ranges_json'] = Variable<String>(rangesJson.value);
    }
    if (enabledStrategiesJson.present) {
      map['enabled_strategies_json'] = Variable<String>(
        enabledStrategiesJson.value,
      );
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (targetsEnumerated.present) {
      map['targets_enumerated'] = Variable<int>(targetsEnumerated.value);
    }
    if (targetsAttempted.present) {
      map['targets_attempted'] = Variable<int>(targetsAttempted.value);
    }
    if (responsesReceived.present) {
      map['responses_received'] = Variable<int>(responsesReceived.value);
    }
    if (classifiedCount.present) {
      map['classified_count'] = Variable<int>(classifiedCount.value);
    }
    if (unknownCount.present) {
      map['unknown_count'] = Variable<int>(unknownCount.value);
    }
    if (failureCount.present) {
      map['failure_count'] = Variable<int>(failureCount.value);
    }
    if (diagnosticSummary.present) {
      map['diagnostic_summary'] = Variable<String>(diagnosticSummary.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiscoveryScansCompanion(')
          ..write('id: $id, ')
          ..write('status: $status, ')
          ..write('rangesJson: $rangesJson, ')
          ..write('enabledStrategiesJson: $enabledStrategiesJson, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('targetsEnumerated: $targetsEnumerated, ')
          ..write('targetsAttempted: $targetsAttempted, ')
          ..write('responsesReceived: $responsesReceived, ')
          ..write('classifiedCount: $classifiedCount, ')
          ..write('unknownCount: $unknownCount, ')
          ..write('failureCount: $failureCount, ')
          ..write('diagnosticSummary: $diagnosticSummary')
          ..write(')'))
        .toString();
  }
}

class $DiscoveredDevicesTable extends DiscoveredDevices
    with TableInfo<$DiscoveredDevicesTable, DiscoveredDeviceData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiscoveredDevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _scanIdMeta = const VerificationMeta('scanId');
  @override
  late final GeneratedColumn<int> scanId = GeneratedColumn<int>(
    'scan_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ipMeta = const VerificationMeta('ip');
  @override
  late final GeneratedColumn<String> ip = GeneratedColumn<String>(
    'ip',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _macMeta = const VerificationMeta('mac');
  @override
  late final GeneratedColumn<String> mac = GeneratedColumn<String>(
    'mac',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hostnameMeta = const VerificationMeta(
    'hostname',
  );
  @override
  late final GeneratedColumn<String> hostname = GeneratedColumn<String>(
    'hostname',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vendorMeta = const VerificationMeta('vendor');
  @override
  late final GeneratedColumn<String> vendor = GeneratedColumn<String>(
    'vendor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _observedServicesJsonMeta =
      const VerificationMeta('observedServicesJson');
  @override
  late final GeneratedColumn<String> observedServicesJson =
      GeneratedColumn<String>(
        'observed_services_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _predictedCategoryMeta = const VerificationMeta(
    'predictedCategory',
  );
  @override
  late final GeneratedColumn<String> predictedCategory =
      GeneratedColumn<String>(
        'predicted_category',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('unknown'),
      );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<String> confidence = GeneratedColumn<String>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unknown'),
  );
  static const VerificationMeta _evidenceJsonMeta = const VerificationMeta(
    'evidenceJson',
  );
  @override
  late final GeneratedColumn<String> evidenceJson = GeneratedColumn<String>(
    'evidence_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _classificationMethodMeta =
      const VerificationMeta('classificationMethod');
  @override
  late final GeneratedColumn<String> classificationMethod =
      GeneratedColumn<String>(
        'classification_method',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('multi_evidence_v1'),
      );
  static const VerificationMeta _firstSeenMeta = const VerificationMeta(
    'firstSeen',
  );
  @override
  late final GeneratedColumn<DateTime> firstSeen = GeneratedColumn<DateTime>(
    'first_seen',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _lastSeenMeta = const VerificationMeta(
    'lastSeen',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeen = GeneratedColumn<DateTime>(
    'last_seen',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _lastSuccessfulProbeMeta =
      const VerificationMeta('lastSuccessfulProbe');
  @override
  late final GeneratedColumn<DateTime> lastSuccessfulProbe =
      GeneratedColumn<DateTime>(
        'last_successful_probe',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastProbeFailureReasonMeta =
      const VerificationMeta('lastProbeFailureReason');
  @override
  late final GeneratedColumn<String> lastProbeFailureReason =
      GeneratedColumn<String>(
        'last_probe_failure_reason',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _reviewStateMeta = const VerificationMeta(
    'reviewState',
  );
  @override
  late final GeneratedColumn<String> reviewState = GeneratedColumn<String>(
    'review_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending_review'),
  );
  static const VerificationMeta _adminConfirmedCategoryMeta =
      const VerificationMeta('adminConfirmedCategory');
  @override
  late final GeneratedColumn<String> adminConfirmedCategory =
      GeneratedColumn<String>(
        'admin_confirmed_category',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _adminReviewerIdMeta = const VerificationMeta(
    'adminReviewerId',
  );
  @override
  late final GeneratedColumn<int> adminReviewerId = GeneratedColumn<int>(
    'admin_reviewer_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _adminReviewTimestampMeta =
      const VerificationMeta('adminReviewTimestamp');
  @override
  late final GeneratedColumn<DateTime> adminReviewTimestamp =
      GeneratedColumn<DateTime>(
        'admin_review_timestamp',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _associatedDeviceIdMeta =
      const VerificationMeta('associatedDeviceId');
  @override
  late final GeneratedColumn<int> associatedDeviceId = GeneratedColumn<int>(
    'associated_device_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    scanId,
    ip,
    mac,
    hostname,
    vendor,
    observedServicesJson,
    predictedCategory,
    confidence,
    evidenceJson,
    classificationMethod,
    firstSeen,
    lastSeen,
    lastSuccessfulProbe,
    lastProbeFailureReason,
    reviewState,
    adminConfirmedCategory,
    adminReviewerId,
    adminReviewTimestamp,
    associatedDeviceId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'discovered_devices';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiscoveredDeviceData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('scan_id')) {
      context.handle(
        _scanIdMeta,
        scanId.isAcceptableOrUnknown(data['scan_id']!, _scanIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scanIdMeta);
    }
    if (data.containsKey('ip')) {
      context.handle(_ipMeta, ip.isAcceptableOrUnknown(data['ip']!, _ipMeta));
    } else if (isInserting) {
      context.missing(_ipMeta);
    }
    if (data.containsKey('mac')) {
      context.handle(
        _macMeta,
        mac.isAcceptableOrUnknown(data['mac']!, _macMeta),
      );
    }
    if (data.containsKey('hostname')) {
      context.handle(
        _hostnameMeta,
        hostname.isAcceptableOrUnknown(data['hostname']!, _hostnameMeta),
      );
    }
    if (data.containsKey('vendor')) {
      context.handle(
        _vendorMeta,
        vendor.isAcceptableOrUnknown(data['vendor']!, _vendorMeta),
      );
    }
    if (data.containsKey('observed_services_json')) {
      context.handle(
        _observedServicesJsonMeta,
        observedServicesJson.isAcceptableOrUnknown(
          data['observed_services_json']!,
          _observedServicesJsonMeta,
        ),
      );
    }
    if (data.containsKey('predicted_category')) {
      context.handle(
        _predictedCategoryMeta,
        predictedCategory.isAcceptableOrUnknown(
          data['predicted_category']!,
          _predictedCategoryMeta,
        ),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('evidence_json')) {
      context.handle(
        _evidenceJsonMeta,
        evidenceJson.isAcceptableOrUnknown(
          data['evidence_json']!,
          _evidenceJsonMeta,
        ),
      );
    }
    if (data.containsKey('classification_method')) {
      context.handle(
        _classificationMethodMeta,
        classificationMethod.isAcceptableOrUnknown(
          data['classification_method']!,
          _classificationMethodMeta,
        ),
      );
    }
    if (data.containsKey('first_seen')) {
      context.handle(
        _firstSeenMeta,
        firstSeen.isAcceptableOrUnknown(data['first_seen']!, _firstSeenMeta),
      );
    }
    if (data.containsKey('last_seen')) {
      context.handle(
        _lastSeenMeta,
        lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta),
      );
    }
    if (data.containsKey('last_successful_probe')) {
      context.handle(
        _lastSuccessfulProbeMeta,
        lastSuccessfulProbe.isAcceptableOrUnknown(
          data['last_successful_probe']!,
          _lastSuccessfulProbeMeta,
        ),
      );
    }
    if (data.containsKey('last_probe_failure_reason')) {
      context.handle(
        _lastProbeFailureReasonMeta,
        lastProbeFailureReason.isAcceptableOrUnknown(
          data['last_probe_failure_reason']!,
          _lastProbeFailureReasonMeta,
        ),
      );
    }
    if (data.containsKey('review_state')) {
      context.handle(
        _reviewStateMeta,
        reviewState.isAcceptableOrUnknown(
          data['review_state']!,
          _reviewStateMeta,
        ),
      );
    }
    if (data.containsKey('admin_confirmed_category')) {
      context.handle(
        _adminConfirmedCategoryMeta,
        adminConfirmedCategory.isAcceptableOrUnknown(
          data['admin_confirmed_category']!,
          _adminConfirmedCategoryMeta,
        ),
      );
    }
    if (data.containsKey('admin_reviewer_id')) {
      context.handle(
        _adminReviewerIdMeta,
        adminReviewerId.isAcceptableOrUnknown(
          data['admin_reviewer_id']!,
          _adminReviewerIdMeta,
        ),
      );
    }
    if (data.containsKey('admin_review_timestamp')) {
      context.handle(
        _adminReviewTimestampMeta,
        adminReviewTimestamp.isAcceptableOrUnknown(
          data['admin_review_timestamp']!,
          _adminReviewTimestampMeta,
        ),
      );
    }
    if (data.containsKey('associated_device_id')) {
      context.handle(
        _associatedDeviceIdMeta,
        associatedDeviceId.isAcceptableOrUnknown(
          data['associated_device_id']!,
          _associatedDeviceIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DiscoveredDeviceData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiscoveredDeviceData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      scanId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scan_id'],
      )!,
      ip: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ip'],
      )!,
      mac: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mac'],
      ),
      hostname: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hostname'],
      ),
      vendor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vendor'],
      ),
      observedServicesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}observed_services_json'],
      ),
      predictedCategory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}predicted_category'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}confidence'],
      )!,
      evidenceJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}evidence_json'],
      ),
      classificationMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}classification_method'],
      )!,
      firstSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}first_seen'],
      )!,
      lastSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen'],
      )!,
      lastSuccessfulProbe: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_successful_probe'],
      ),
      lastProbeFailureReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_probe_failure_reason'],
      ),
      reviewState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}review_state'],
      )!,
      adminConfirmedCategory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}admin_confirmed_category'],
      ),
      adminReviewerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}admin_reviewer_id'],
      ),
      adminReviewTimestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}admin_review_timestamp'],
      ),
      associatedDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}associated_device_id'],
      ),
    );
  }

  @override
  $DiscoveredDevicesTable createAlias(String alias) {
    return $DiscoveredDevicesTable(attachedDatabase, alias);
  }
}

class DiscoveredDeviceData extends DataClass
    implements Insertable<DiscoveredDeviceData> {
  final int id;
  final int scanId;
  final String ip;
  final String? mac;
  final String? hostname;
  final String? vendor;
  final String? observedServicesJson;
  final String predictedCategory;
  final String confidence;
  final String? evidenceJson;
  final String classificationMethod;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final DateTime? lastSuccessfulProbe;
  final String? lastProbeFailureReason;
  final String reviewState;
  final String? adminConfirmedCategory;
  final int? adminReviewerId;
  final DateTime? adminReviewTimestamp;
  final int? associatedDeviceId;
  const DiscoveredDeviceData({
    required this.id,
    required this.scanId,
    required this.ip,
    this.mac,
    this.hostname,
    this.vendor,
    this.observedServicesJson,
    required this.predictedCategory,
    required this.confidence,
    this.evidenceJson,
    required this.classificationMethod,
    required this.firstSeen,
    required this.lastSeen,
    this.lastSuccessfulProbe,
    this.lastProbeFailureReason,
    required this.reviewState,
    this.adminConfirmedCategory,
    this.adminReviewerId,
    this.adminReviewTimestamp,
    this.associatedDeviceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['scan_id'] = Variable<int>(scanId);
    map['ip'] = Variable<String>(ip);
    if (!nullToAbsent || mac != null) {
      map['mac'] = Variable<String>(mac);
    }
    if (!nullToAbsent || hostname != null) {
      map['hostname'] = Variable<String>(hostname);
    }
    if (!nullToAbsent || vendor != null) {
      map['vendor'] = Variable<String>(vendor);
    }
    if (!nullToAbsent || observedServicesJson != null) {
      map['observed_services_json'] = Variable<String>(observedServicesJson);
    }
    map['predicted_category'] = Variable<String>(predictedCategory);
    map['confidence'] = Variable<String>(confidence);
    if (!nullToAbsent || evidenceJson != null) {
      map['evidence_json'] = Variable<String>(evidenceJson);
    }
    map['classification_method'] = Variable<String>(classificationMethod);
    map['first_seen'] = Variable<DateTime>(firstSeen);
    map['last_seen'] = Variable<DateTime>(lastSeen);
    if (!nullToAbsent || lastSuccessfulProbe != null) {
      map['last_successful_probe'] = Variable<DateTime>(lastSuccessfulProbe);
    }
    if (!nullToAbsent || lastProbeFailureReason != null) {
      map['last_probe_failure_reason'] = Variable<String>(
        lastProbeFailureReason,
      );
    }
    map['review_state'] = Variable<String>(reviewState);
    if (!nullToAbsent || adminConfirmedCategory != null) {
      map['admin_confirmed_category'] = Variable<String>(
        adminConfirmedCategory,
      );
    }
    if (!nullToAbsent || adminReviewerId != null) {
      map['admin_reviewer_id'] = Variable<int>(adminReviewerId);
    }
    if (!nullToAbsent || adminReviewTimestamp != null) {
      map['admin_review_timestamp'] = Variable<DateTime>(adminReviewTimestamp);
    }
    if (!nullToAbsent || associatedDeviceId != null) {
      map['associated_device_id'] = Variable<int>(associatedDeviceId);
    }
    return map;
  }

  DiscoveredDevicesCompanion toCompanion(bool nullToAbsent) {
    return DiscoveredDevicesCompanion(
      id: Value(id),
      scanId: Value(scanId),
      ip: Value(ip),
      mac: mac == null && nullToAbsent ? const Value.absent() : Value(mac),
      hostname: hostname == null && nullToAbsent
          ? const Value.absent()
          : Value(hostname),
      vendor: vendor == null && nullToAbsent
          ? const Value.absent()
          : Value(vendor),
      observedServicesJson: observedServicesJson == null && nullToAbsent
          ? const Value.absent()
          : Value(observedServicesJson),
      predictedCategory: Value(predictedCategory),
      confidence: Value(confidence),
      evidenceJson: evidenceJson == null && nullToAbsent
          ? const Value.absent()
          : Value(evidenceJson),
      classificationMethod: Value(classificationMethod),
      firstSeen: Value(firstSeen),
      lastSeen: Value(lastSeen),
      lastSuccessfulProbe: lastSuccessfulProbe == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSuccessfulProbe),
      lastProbeFailureReason: lastProbeFailureReason == null && nullToAbsent
          ? const Value.absent()
          : Value(lastProbeFailureReason),
      reviewState: Value(reviewState),
      adminConfirmedCategory: adminConfirmedCategory == null && nullToAbsent
          ? const Value.absent()
          : Value(adminConfirmedCategory),
      adminReviewerId: adminReviewerId == null && nullToAbsent
          ? const Value.absent()
          : Value(adminReviewerId),
      adminReviewTimestamp: adminReviewTimestamp == null && nullToAbsent
          ? const Value.absent()
          : Value(adminReviewTimestamp),
      associatedDeviceId: associatedDeviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(associatedDeviceId),
    );
  }

  factory DiscoveredDeviceData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiscoveredDeviceData(
      id: serializer.fromJson<int>(json['id']),
      scanId: serializer.fromJson<int>(json['scanId']),
      ip: serializer.fromJson<String>(json['ip']),
      mac: serializer.fromJson<String?>(json['mac']),
      hostname: serializer.fromJson<String?>(json['hostname']),
      vendor: serializer.fromJson<String?>(json['vendor']),
      observedServicesJson: serializer.fromJson<String?>(
        json['observedServicesJson'],
      ),
      predictedCategory: serializer.fromJson<String>(json['predictedCategory']),
      confidence: serializer.fromJson<String>(json['confidence']),
      evidenceJson: serializer.fromJson<String?>(json['evidenceJson']),
      classificationMethod: serializer.fromJson<String>(
        json['classificationMethod'],
      ),
      firstSeen: serializer.fromJson<DateTime>(json['firstSeen']),
      lastSeen: serializer.fromJson<DateTime>(json['lastSeen']),
      lastSuccessfulProbe: serializer.fromJson<DateTime?>(
        json['lastSuccessfulProbe'],
      ),
      lastProbeFailureReason: serializer.fromJson<String?>(
        json['lastProbeFailureReason'],
      ),
      reviewState: serializer.fromJson<String>(json['reviewState']),
      adminConfirmedCategory: serializer.fromJson<String?>(
        json['adminConfirmedCategory'],
      ),
      adminReviewerId: serializer.fromJson<int?>(json['adminReviewerId']),
      adminReviewTimestamp: serializer.fromJson<DateTime?>(
        json['adminReviewTimestamp'],
      ),
      associatedDeviceId: serializer.fromJson<int?>(json['associatedDeviceId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'scanId': serializer.toJson<int>(scanId),
      'ip': serializer.toJson<String>(ip),
      'mac': serializer.toJson<String?>(mac),
      'hostname': serializer.toJson<String?>(hostname),
      'vendor': serializer.toJson<String?>(vendor),
      'observedServicesJson': serializer.toJson<String?>(observedServicesJson),
      'predictedCategory': serializer.toJson<String>(predictedCategory),
      'confidence': serializer.toJson<String>(confidence),
      'evidenceJson': serializer.toJson<String?>(evidenceJson),
      'classificationMethod': serializer.toJson<String>(classificationMethod),
      'firstSeen': serializer.toJson<DateTime>(firstSeen),
      'lastSeen': serializer.toJson<DateTime>(lastSeen),
      'lastSuccessfulProbe': serializer.toJson<DateTime?>(lastSuccessfulProbe),
      'lastProbeFailureReason': serializer.toJson<String?>(
        lastProbeFailureReason,
      ),
      'reviewState': serializer.toJson<String>(reviewState),
      'adminConfirmedCategory': serializer.toJson<String?>(
        adminConfirmedCategory,
      ),
      'adminReviewerId': serializer.toJson<int?>(adminReviewerId),
      'adminReviewTimestamp': serializer.toJson<DateTime?>(
        adminReviewTimestamp,
      ),
      'associatedDeviceId': serializer.toJson<int?>(associatedDeviceId),
    };
  }

  DiscoveredDeviceData copyWith({
    int? id,
    int? scanId,
    String? ip,
    Value<String?> mac = const Value.absent(),
    Value<String?> hostname = const Value.absent(),
    Value<String?> vendor = const Value.absent(),
    Value<String?> observedServicesJson = const Value.absent(),
    String? predictedCategory,
    String? confidence,
    Value<String?> evidenceJson = const Value.absent(),
    String? classificationMethod,
    DateTime? firstSeen,
    DateTime? lastSeen,
    Value<DateTime?> lastSuccessfulProbe = const Value.absent(),
    Value<String?> lastProbeFailureReason = const Value.absent(),
    String? reviewState,
    Value<String?> adminConfirmedCategory = const Value.absent(),
    Value<int?> adminReviewerId = const Value.absent(),
    Value<DateTime?> adminReviewTimestamp = const Value.absent(),
    Value<int?> associatedDeviceId = const Value.absent(),
  }) => DiscoveredDeviceData(
    id: id ?? this.id,
    scanId: scanId ?? this.scanId,
    ip: ip ?? this.ip,
    mac: mac.present ? mac.value : this.mac,
    hostname: hostname.present ? hostname.value : this.hostname,
    vendor: vendor.present ? vendor.value : this.vendor,
    observedServicesJson: observedServicesJson.present
        ? observedServicesJson.value
        : this.observedServicesJson,
    predictedCategory: predictedCategory ?? this.predictedCategory,
    confidence: confidence ?? this.confidence,
    evidenceJson: evidenceJson.present ? evidenceJson.value : this.evidenceJson,
    classificationMethod: classificationMethod ?? this.classificationMethod,
    firstSeen: firstSeen ?? this.firstSeen,
    lastSeen: lastSeen ?? this.lastSeen,
    lastSuccessfulProbe: lastSuccessfulProbe.present
        ? lastSuccessfulProbe.value
        : this.lastSuccessfulProbe,
    lastProbeFailureReason: lastProbeFailureReason.present
        ? lastProbeFailureReason.value
        : this.lastProbeFailureReason,
    reviewState: reviewState ?? this.reviewState,
    adminConfirmedCategory: adminConfirmedCategory.present
        ? adminConfirmedCategory.value
        : this.adminConfirmedCategory,
    adminReviewerId: adminReviewerId.present
        ? adminReviewerId.value
        : this.adminReviewerId,
    adminReviewTimestamp: adminReviewTimestamp.present
        ? adminReviewTimestamp.value
        : this.adminReviewTimestamp,
    associatedDeviceId: associatedDeviceId.present
        ? associatedDeviceId.value
        : this.associatedDeviceId,
  );
  DiscoveredDeviceData copyWithCompanion(DiscoveredDevicesCompanion data) {
    return DiscoveredDeviceData(
      id: data.id.present ? data.id.value : this.id,
      scanId: data.scanId.present ? data.scanId.value : this.scanId,
      ip: data.ip.present ? data.ip.value : this.ip,
      mac: data.mac.present ? data.mac.value : this.mac,
      hostname: data.hostname.present ? data.hostname.value : this.hostname,
      vendor: data.vendor.present ? data.vendor.value : this.vendor,
      observedServicesJson: data.observedServicesJson.present
          ? data.observedServicesJson.value
          : this.observedServicesJson,
      predictedCategory: data.predictedCategory.present
          ? data.predictedCategory.value
          : this.predictedCategory,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      evidenceJson: data.evidenceJson.present
          ? data.evidenceJson.value
          : this.evidenceJson,
      classificationMethod: data.classificationMethod.present
          ? data.classificationMethod.value
          : this.classificationMethod,
      firstSeen: data.firstSeen.present ? data.firstSeen.value : this.firstSeen,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
      lastSuccessfulProbe: data.lastSuccessfulProbe.present
          ? data.lastSuccessfulProbe.value
          : this.lastSuccessfulProbe,
      lastProbeFailureReason: data.lastProbeFailureReason.present
          ? data.lastProbeFailureReason.value
          : this.lastProbeFailureReason,
      reviewState: data.reviewState.present
          ? data.reviewState.value
          : this.reviewState,
      adminConfirmedCategory: data.adminConfirmedCategory.present
          ? data.adminConfirmedCategory.value
          : this.adminConfirmedCategory,
      adminReviewerId: data.adminReviewerId.present
          ? data.adminReviewerId.value
          : this.adminReviewerId,
      adminReviewTimestamp: data.adminReviewTimestamp.present
          ? data.adminReviewTimestamp.value
          : this.adminReviewTimestamp,
      associatedDeviceId: data.associatedDeviceId.present
          ? data.associatedDeviceId.value
          : this.associatedDeviceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiscoveredDeviceData(')
          ..write('id: $id, ')
          ..write('scanId: $scanId, ')
          ..write('ip: $ip, ')
          ..write('mac: $mac, ')
          ..write('hostname: $hostname, ')
          ..write('vendor: $vendor, ')
          ..write('observedServicesJson: $observedServicesJson, ')
          ..write('predictedCategory: $predictedCategory, ')
          ..write('confidence: $confidence, ')
          ..write('evidenceJson: $evidenceJson, ')
          ..write('classificationMethod: $classificationMethod, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('lastSuccessfulProbe: $lastSuccessfulProbe, ')
          ..write('lastProbeFailureReason: $lastProbeFailureReason, ')
          ..write('reviewState: $reviewState, ')
          ..write('adminConfirmedCategory: $adminConfirmedCategory, ')
          ..write('adminReviewerId: $adminReviewerId, ')
          ..write('adminReviewTimestamp: $adminReviewTimestamp, ')
          ..write('associatedDeviceId: $associatedDeviceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    scanId,
    ip,
    mac,
    hostname,
    vendor,
    observedServicesJson,
    predictedCategory,
    confidence,
    evidenceJson,
    classificationMethod,
    firstSeen,
    lastSeen,
    lastSuccessfulProbe,
    lastProbeFailureReason,
    reviewState,
    adminConfirmedCategory,
    adminReviewerId,
    adminReviewTimestamp,
    associatedDeviceId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiscoveredDeviceData &&
          other.id == this.id &&
          other.scanId == this.scanId &&
          other.ip == this.ip &&
          other.mac == this.mac &&
          other.hostname == this.hostname &&
          other.vendor == this.vendor &&
          other.observedServicesJson == this.observedServicesJson &&
          other.predictedCategory == this.predictedCategory &&
          other.confidence == this.confidence &&
          other.evidenceJson == this.evidenceJson &&
          other.classificationMethod == this.classificationMethod &&
          other.firstSeen == this.firstSeen &&
          other.lastSeen == this.lastSeen &&
          other.lastSuccessfulProbe == this.lastSuccessfulProbe &&
          other.lastProbeFailureReason == this.lastProbeFailureReason &&
          other.reviewState == this.reviewState &&
          other.adminConfirmedCategory == this.adminConfirmedCategory &&
          other.adminReviewerId == this.adminReviewerId &&
          other.adminReviewTimestamp == this.adminReviewTimestamp &&
          other.associatedDeviceId == this.associatedDeviceId);
}

class DiscoveredDevicesCompanion extends UpdateCompanion<DiscoveredDeviceData> {
  final Value<int> id;
  final Value<int> scanId;
  final Value<String> ip;
  final Value<String?> mac;
  final Value<String?> hostname;
  final Value<String?> vendor;
  final Value<String?> observedServicesJson;
  final Value<String> predictedCategory;
  final Value<String> confidence;
  final Value<String?> evidenceJson;
  final Value<String> classificationMethod;
  final Value<DateTime> firstSeen;
  final Value<DateTime> lastSeen;
  final Value<DateTime?> lastSuccessfulProbe;
  final Value<String?> lastProbeFailureReason;
  final Value<String> reviewState;
  final Value<String?> adminConfirmedCategory;
  final Value<int?> adminReviewerId;
  final Value<DateTime?> adminReviewTimestamp;
  final Value<int?> associatedDeviceId;
  const DiscoveredDevicesCompanion({
    this.id = const Value.absent(),
    this.scanId = const Value.absent(),
    this.ip = const Value.absent(),
    this.mac = const Value.absent(),
    this.hostname = const Value.absent(),
    this.vendor = const Value.absent(),
    this.observedServicesJson = const Value.absent(),
    this.predictedCategory = const Value.absent(),
    this.confidence = const Value.absent(),
    this.evidenceJson = const Value.absent(),
    this.classificationMethod = const Value.absent(),
    this.firstSeen = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.lastSuccessfulProbe = const Value.absent(),
    this.lastProbeFailureReason = const Value.absent(),
    this.reviewState = const Value.absent(),
    this.adminConfirmedCategory = const Value.absent(),
    this.adminReviewerId = const Value.absent(),
    this.adminReviewTimestamp = const Value.absent(),
    this.associatedDeviceId = const Value.absent(),
  });
  DiscoveredDevicesCompanion.insert({
    this.id = const Value.absent(),
    required int scanId,
    required String ip,
    this.mac = const Value.absent(),
    this.hostname = const Value.absent(),
    this.vendor = const Value.absent(),
    this.observedServicesJson = const Value.absent(),
    this.predictedCategory = const Value.absent(),
    this.confidence = const Value.absent(),
    this.evidenceJson = const Value.absent(),
    this.classificationMethod = const Value.absent(),
    this.firstSeen = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.lastSuccessfulProbe = const Value.absent(),
    this.lastProbeFailureReason = const Value.absent(),
    this.reviewState = const Value.absent(),
    this.adminConfirmedCategory = const Value.absent(),
    this.adminReviewerId = const Value.absent(),
    this.adminReviewTimestamp = const Value.absent(),
    this.associatedDeviceId = const Value.absent(),
  }) : scanId = Value(scanId),
       ip = Value(ip);
  static Insertable<DiscoveredDeviceData> custom({
    Expression<int>? id,
    Expression<int>? scanId,
    Expression<String>? ip,
    Expression<String>? mac,
    Expression<String>? hostname,
    Expression<String>? vendor,
    Expression<String>? observedServicesJson,
    Expression<String>? predictedCategory,
    Expression<String>? confidence,
    Expression<String>? evidenceJson,
    Expression<String>? classificationMethod,
    Expression<DateTime>? firstSeen,
    Expression<DateTime>? lastSeen,
    Expression<DateTime>? lastSuccessfulProbe,
    Expression<String>? lastProbeFailureReason,
    Expression<String>? reviewState,
    Expression<String>? adminConfirmedCategory,
    Expression<int>? adminReviewerId,
    Expression<DateTime>? adminReviewTimestamp,
    Expression<int>? associatedDeviceId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scanId != null) 'scan_id': scanId,
      if (ip != null) 'ip': ip,
      if (mac != null) 'mac': mac,
      if (hostname != null) 'hostname': hostname,
      if (vendor != null) 'vendor': vendor,
      if (observedServicesJson != null)
        'observed_services_json': observedServicesJson,
      if (predictedCategory != null) 'predicted_category': predictedCategory,
      if (confidence != null) 'confidence': confidence,
      if (evidenceJson != null) 'evidence_json': evidenceJson,
      if (classificationMethod != null)
        'classification_method': classificationMethod,
      if (firstSeen != null) 'first_seen': firstSeen,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (lastSuccessfulProbe != null)
        'last_successful_probe': lastSuccessfulProbe,
      if (lastProbeFailureReason != null)
        'last_probe_failure_reason': lastProbeFailureReason,
      if (reviewState != null) 'review_state': reviewState,
      if (adminConfirmedCategory != null)
        'admin_confirmed_category': adminConfirmedCategory,
      if (adminReviewerId != null) 'admin_reviewer_id': adminReviewerId,
      if (adminReviewTimestamp != null)
        'admin_review_timestamp': adminReviewTimestamp,
      if (associatedDeviceId != null)
        'associated_device_id': associatedDeviceId,
    });
  }

  DiscoveredDevicesCompanion copyWith({
    Value<int>? id,
    Value<int>? scanId,
    Value<String>? ip,
    Value<String?>? mac,
    Value<String?>? hostname,
    Value<String?>? vendor,
    Value<String?>? observedServicesJson,
    Value<String>? predictedCategory,
    Value<String>? confidence,
    Value<String?>? evidenceJson,
    Value<String>? classificationMethod,
    Value<DateTime>? firstSeen,
    Value<DateTime>? lastSeen,
    Value<DateTime?>? lastSuccessfulProbe,
    Value<String?>? lastProbeFailureReason,
    Value<String>? reviewState,
    Value<String?>? adminConfirmedCategory,
    Value<int?>? adminReviewerId,
    Value<DateTime?>? adminReviewTimestamp,
    Value<int?>? associatedDeviceId,
  }) {
    return DiscoveredDevicesCompanion(
      id: id ?? this.id,
      scanId: scanId ?? this.scanId,
      ip: ip ?? this.ip,
      mac: mac ?? this.mac,
      hostname: hostname ?? this.hostname,
      vendor: vendor ?? this.vendor,
      observedServicesJson: observedServicesJson ?? this.observedServicesJson,
      predictedCategory: predictedCategory ?? this.predictedCategory,
      confidence: confidence ?? this.confidence,
      evidenceJson: evidenceJson ?? this.evidenceJson,
      classificationMethod: classificationMethod ?? this.classificationMethod,
      firstSeen: firstSeen ?? this.firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      lastSuccessfulProbe: lastSuccessfulProbe ?? this.lastSuccessfulProbe,
      lastProbeFailureReason:
          lastProbeFailureReason ?? this.lastProbeFailureReason,
      reviewState: reviewState ?? this.reviewState,
      adminConfirmedCategory:
          adminConfirmedCategory ?? this.adminConfirmedCategory,
      adminReviewerId: adminReviewerId ?? this.adminReviewerId,
      adminReviewTimestamp: adminReviewTimestamp ?? this.adminReviewTimestamp,
      associatedDeviceId: associatedDeviceId ?? this.associatedDeviceId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (scanId.present) {
      map['scan_id'] = Variable<int>(scanId.value);
    }
    if (ip.present) {
      map['ip'] = Variable<String>(ip.value);
    }
    if (mac.present) {
      map['mac'] = Variable<String>(mac.value);
    }
    if (hostname.present) {
      map['hostname'] = Variable<String>(hostname.value);
    }
    if (vendor.present) {
      map['vendor'] = Variable<String>(vendor.value);
    }
    if (observedServicesJson.present) {
      map['observed_services_json'] = Variable<String>(
        observedServicesJson.value,
      );
    }
    if (predictedCategory.present) {
      map['predicted_category'] = Variable<String>(predictedCategory.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<String>(confidence.value);
    }
    if (evidenceJson.present) {
      map['evidence_json'] = Variable<String>(evidenceJson.value);
    }
    if (classificationMethod.present) {
      map['classification_method'] = Variable<String>(
        classificationMethod.value,
      );
    }
    if (firstSeen.present) {
      map['first_seen'] = Variable<DateTime>(firstSeen.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<DateTime>(lastSeen.value);
    }
    if (lastSuccessfulProbe.present) {
      map['last_successful_probe'] = Variable<DateTime>(
        lastSuccessfulProbe.value,
      );
    }
    if (lastProbeFailureReason.present) {
      map['last_probe_failure_reason'] = Variable<String>(
        lastProbeFailureReason.value,
      );
    }
    if (reviewState.present) {
      map['review_state'] = Variable<String>(reviewState.value);
    }
    if (adminConfirmedCategory.present) {
      map['admin_confirmed_category'] = Variable<String>(
        adminConfirmedCategory.value,
      );
    }
    if (adminReviewerId.present) {
      map['admin_reviewer_id'] = Variable<int>(adminReviewerId.value);
    }
    if (adminReviewTimestamp.present) {
      map['admin_review_timestamp'] = Variable<DateTime>(
        adminReviewTimestamp.value,
      );
    }
    if (associatedDeviceId.present) {
      map['associated_device_id'] = Variable<int>(associatedDeviceId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiscoveredDevicesCompanion(')
          ..write('id: $id, ')
          ..write('scanId: $scanId, ')
          ..write('ip: $ip, ')
          ..write('mac: $mac, ')
          ..write('hostname: $hostname, ')
          ..write('vendor: $vendor, ')
          ..write('observedServicesJson: $observedServicesJson, ')
          ..write('predictedCategory: $predictedCategory, ')
          ..write('confidence: $confidence, ')
          ..write('evidenceJson: $evidenceJson, ')
          ..write('classificationMethod: $classificationMethod, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('lastSuccessfulProbe: $lastSuccessfulProbe, ')
          ..write('lastProbeFailureReason: $lastProbeFailureReason, ')
          ..write('reviewState: $reviewState, ')
          ..write('adminConfirmedCategory: $adminConfirmedCategory, ')
          ..write('adminReviewerId: $adminReviewerId, ')
          ..write('adminReviewTimestamp: $adminReviewTimestamp, ')
          ..write('associatedDeviceId: $associatedDeviceId')
          ..write(')'))
        .toString();
  }
}

class $DiscoveryEvidencesTable extends DiscoveryEvidences
    with TableInfo<$DiscoveryEvidencesTable, DiscoveryEvidenceData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiscoveryEvidencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _discoveredDeviceIdMeta =
      const VerificationMeta('discoveredDeviceId');
  @override
  late final GeneratedColumn<int> discoveredDeviceId = GeneratedColumn<int>(
    'discovered_device_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _strategyNameMeta = const VerificationMeta(
    'strategyName',
  );
  @override
  late final GeneratedColumn<String> strategyName = GeneratedColumn<String>(
    'strategy_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _probeTargetMeta = const VerificationMeta(
    'probeTarget',
  );
  @override
  late final GeneratedColumn<String> probeTarget = GeneratedColumn<String>(
    'probe_target',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isSuccessMeta = const VerificationMeta(
    'isSuccess',
  );
  @override
  late final GeneratedColumn<bool> isSuccess = GeneratedColumn<bool>(
    'is_success',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_success" IN (0, 1))',
    ),
  );
  static const VerificationMeta _detailsMeta = const VerificationMeta(
    'details',
  );
  @override
  late final GeneratedColumn<String> details = GeneratedColumn<String>(
    'details',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    discoveredDeviceId,
    strategyName,
    probeTarget,
    isSuccess,
    details,
    timestamp,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'discovery_evidences';
  @override
  VerificationContext validateIntegrity(
    Insertable<DiscoveryEvidenceData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('discovered_device_id')) {
      context.handle(
        _discoveredDeviceIdMeta,
        discoveredDeviceId.isAcceptableOrUnknown(
          data['discovered_device_id']!,
          _discoveredDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_discoveredDeviceIdMeta);
    }
    if (data.containsKey('strategy_name')) {
      context.handle(
        _strategyNameMeta,
        strategyName.isAcceptableOrUnknown(
          data['strategy_name']!,
          _strategyNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_strategyNameMeta);
    }
    if (data.containsKey('probe_target')) {
      context.handle(
        _probeTargetMeta,
        probeTarget.isAcceptableOrUnknown(
          data['probe_target']!,
          _probeTargetMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_probeTargetMeta);
    }
    if (data.containsKey('is_success')) {
      context.handle(
        _isSuccessMeta,
        isSuccess.isAcceptableOrUnknown(data['is_success']!, _isSuccessMeta),
      );
    } else if (isInserting) {
      context.missing(_isSuccessMeta);
    }
    if (data.containsKey('details')) {
      context.handle(
        _detailsMeta,
        details.isAcceptableOrUnknown(data['details']!, _detailsMeta),
      );
    } else if (isInserting) {
      context.missing(_detailsMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DiscoveryEvidenceData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiscoveryEvidenceData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      discoveredDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}discovered_device_id'],
      )!,
      strategyName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}strategy_name'],
      )!,
      probeTarget: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}probe_target'],
      )!,
      isSuccess: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_success'],
      )!,
      details: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}details'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
    );
  }

  @override
  $DiscoveryEvidencesTable createAlias(String alias) {
    return $DiscoveryEvidencesTable(attachedDatabase, alias);
  }
}

class DiscoveryEvidenceData extends DataClass
    implements Insertable<DiscoveryEvidenceData> {
  final int id;
  final int discoveredDeviceId;
  final String strategyName;
  final String probeTarget;
  final bool isSuccess;
  final String details;
  final DateTime timestamp;
  const DiscoveryEvidenceData({
    required this.id,
    required this.discoveredDeviceId,
    required this.strategyName,
    required this.probeTarget,
    required this.isSuccess,
    required this.details,
    required this.timestamp,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['discovered_device_id'] = Variable<int>(discoveredDeviceId);
    map['strategy_name'] = Variable<String>(strategyName);
    map['probe_target'] = Variable<String>(probeTarget);
    map['is_success'] = Variable<bool>(isSuccess);
    map['details'] = Variable<String>(details);
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  DiscoveryEvidencesCompanion toCompanion(bool nullToAbsent) {
    return DiscoveryEvidencesCompanion(
      id: Value(id),
      discoveredDeviceId: Value(discoveredDeviceId),
      strategyName: Value(strategyName),
      probeTarget: Value(probeTarget),
      isSuccess: Value(isSuccess),
      details: Value(details),
      timestamp: Value(timestamp),
    );
  }

  factory DiscoveryEvidenceData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiscoveryEvidenceData(
      id: serializer.fromJson<int>(json['id']),
      discoveredDeviceId: serializer.fromJson<int>(json['discoveredDeviceId']),
      strategyName: serializer.fromJson<String>(json['strategyName']),
      probeTarget: serializer.fromJson<String>(json['probeTarget']),
      isSuccess: serializer.fromJson<bool>(json['isSuccess']),
      details: serializer.fromJson<String>(json['details']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'discoveredDeviceId': serializer.toJson<int>(discoveredDeviceId),
      'strategyName': serializer.toJson<String>(strategyName),
      'probeTarget': serializer.toJson<String>(probeTarget),
      'isSuccess': serializer.toJson<bool>(isSuccess),
      'details': serializer.toJson<String>(details),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  DiscoveryEvidenceData copyWith({
    int? id,
    int? discoveredDeviceId,
    String? strategyName,
    String? probeTarget,
    bool? isSuccess,
    String? details,
    DateTime? timestamp,
  }) => DiscoveryEvidenceData(
    id: id ?? this.id,
    discoveredDeviceId: discoveredDeviceId ?? this.discoveredDeviceId,
    strategyName: strategyName ?? this.strategyName,
    probeTarget: probeTarget ?? this.probeTarget,
    isSuccess: isSuccess ?? this.isSuccess,
    details: details ?? this.details,
    timestamp: timestamp ?? this.timestamp,
  );
  DiscoveryEvidenceData copyWithCompanion(DiscoveryEvidencesCompanion data) {
    return DiscoveryEvidenceData(
      id: data.id.present ? data.id.value : this.id,
      discoveredDeviceId: data.discoveredDeviceId.present
          ? data.discoveredDeviceId.value
          : this.discoveredDeviceId,
      strategyName: data.strategyName.present
          ? data.strategyName.value
          : this.strategyName,
      probeTarget: data.probeTarget.present
          ? data.probeTarget.value
          : this.probeTarget,
      isSuccess: data.isSuccess.present ? data.isSuccess.value : this.isSuccess,
      details: data.details.present ? data.details.value : this.details,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiscoveryEvidenceData(')
          ..write('id: $id, ')
          ..write('discoveredDeviceId: $discoveredDeviceId, ')
          ..write('strategyName: $strategyName, ')
          ..write('probeTarget: $probeTarget, ')
          ..write('isSuccess: $isSuccess, ')
          ..write('details: $details, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    discoveredDeviceId,
    strategyName,
    probeTarget,
    isSuccess,
    details,
    timestamp,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiscoveryEvidenceData &&
          other.id == this.id &&
          other.discoveredDeviceId == this.discoveredDeviceId &&
          other.strategyName == this.strategyName &&
          other.probeTarget == this.probeTarget &&
          other.isSuccess == this.isSuccess &&
          other.details == this.details &&
          other.timestamp == this.timestamp);
}

class DiscoveryEvidencesCompanion
    extends UpdateCompanion<DiscoveryEvidenceData> {
  final Value<int> id;
  final Value<int> discoveredDeviceId;
  final Value<String> strategyName;
  final Value<String> probeTarget;
  final Value<bool> isSuccess;
  final Value<String> details;
  final Value<DateTime> timestamp;
  const DiscoveryEvidencesCompanion({
    this.id = const Value.absent(),
    this.discoveredDeviceId = const Value.absent(),
    this.strategyName = const Value.absent(),
    this.probeTarget = const Value.absent(),
    this.isSuccess = const Value.absent(),
    this.details = const Value.absent(),
    this.timestamp = const Value.absent(),
  });
  DiscoveryEvidencesCompanion.insert({
    this.id = const Value.absent(),
    required int discoveredDeviceId,
    required String strategyName,
    required String probeTarget,
    required bool isSuccess,
    required String details,
    this.timestamp = const Value.absent(),
  }) : discoveredDeviceId = Value(discoveredDeviceId),
       strategyName = Value(strategyName),
       probeTarget = Value(probeTarget),
       isSuccess = Value(isSuccess),
       details = Value(details);
  static Insertable<DiscoveryEvidenceData> custom({
    Expression<int>? id,
    Expression<int>? discoveredDeviceId,
    Expression<String>? strategyName,
    Expression<String>? probeTarget,
    Expression<bool>? isSuccess,
    Expression<String>? details,
    Expression<DateTime>? timestamp,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (discoveredDeviceId != null)
        'discovered_device_id': discoveredDeviceId,
      if (strategyName != null) 'strategy_name': strategyName,
      if (probeTarget != null) 'probe_target': probeTarget,
      if (isSuccess != null) 'is_success': isSuccess,
      if (details != null) 'details': details,
      if (timestamp != null) 'timestamp': timestamp,
    });
  }

  DiscoveryEvidencesCompanion copyWith({
    Value<int>? id,
    Value<int>? discoveredDeviceId,
    Value<String>? strategyName,
    Value<String>? probeTarget,
    Value<bool>? isSuccess,
    Value<String>? details,
    Value<DateTime>? timestamp,
  }) {
    return DiscoveryEvidencesCompanion(
      id: id ?? this.id,
      discoveredDeviceId: discoveredDeviceId ?? this.discoveredDeviceId,
      strategyName: strategyName ?? this.strategyName,
      probeTarget: probeTarget ?? this.probeTarget,
      isSuccess: isSuccess ?? this.isSuccess,
      details: details ?? this.details,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (discoveredDeviceId.present) {
      map['discovered_device_id'] = Variable<int>(discoveredDeviceId.value);
    }
    if (strategyName.present) {
      map['strategy_name'] = Variable<String>(strategyName.value);
    }
    if (probeTarget.present) {
      map['probe_target'] = Variable<String>(probeTarget.value);
    }
    if (isSuccess.present) {
      map['is_success'] = Variable<bool>(isSuccess.value);
    }
    if (details.present) {
      map['details'] = Variable<String>(details.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiscoveryEvidencesCompanion(')
          ..write('id: $id, ')
          ..write('discoveredDeviceId: $discoveredDeviceId, ')
          ..write('strategyName: $strategyName, ')
          ..write('probeTarget: $probeTarget, ')
          ..write('isSuccess: $isSuccess, ')
          ..write('details: $details, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }
}

class $InfrastructureDevicesTable extends InfrastructureDevices
    with TableInfo<$InfrastructureDevicesTable, InfrastructureDeviceData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InfrastructureDevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ipMeta = const VerificationMeta('ip');
  @override
  late final GeneratedColumn<String> ip = GeneratedColumn<String>(
    'ip',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _macMeta = const VerificationMeta('mac');
  @override
  late final GeneratedColumn<String> mac = GeneratedColumn<String>(
    'mac',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('other_unknown'),
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isCriticalInfrastructureMeta =
      const VerificationMeta('isCriticalInfrastructure');
  @override
  late final GeneratedColumn<bool> isCriticalInfrastructure =
      GeneratedColumn<bool>(
        'is_critical_infrastructure',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_critical_infrastructure" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _requiresAdminConfirmationMeta =
      const VerificationMeta('requiresAdminConfirmation');
  @override
  late final GeneratedColumn<bool> requiresAdminConfirmation =
      GeneratedColumn<bool>(
        'requires_admin_confirmation',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("requires_admin_confirmation" IN (0, 1))',
        ),
        defaultValue: const Constant(true),
      );
  static const VerificationMeta _linkedSubnetsJsonMeta = const VerificationMeta(
    'linkedSubnetsJson',
  );
  @override
  late final GeneratedColumn<String> linkedSubnetsJson =
      GeneratedColumn<String>(
        'linked_subnets_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _controllerUrlMeta = const VerificationMeta(
    'controllerUrl',
  );
  @override
  late final GeneratedColumn<String> controllerUrl = GeneratedColumn<String>(
    'controller_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _siteNameMeta = const VerificationMeta(
    'siteName',
  );
  @override
  late final GeneratedColumn<String> siteName = GeneratedColumn<String>(
    'site_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('default'),
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isReadOnlyMeta = const VerificationMeta(
    'isReadOnly',
  );
  @override
  late final GeneratedColumn<bool> isReadOnly = GeneratedColumn<bool>(
    'is_read_only',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_read_only" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    ip,
    mac,
    role,
    location,
    isCriticalInfrastructure,
    requiresAdminConfirmation,
    linkedSubnetsJson,
    controllerUrl,
    siteName,
    isEnabled,
    isReadOnly,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'infrastructure_devices';
  @override
  VerificationContext validateIntegrity(
    Insertable<InfrastructureDeviceData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('ip')) {
      context.handle(_ipMeta, ip.isAcceptableOrUnknown(data['ip']!, _ipMeta));
    } else if (isInserting) {
      context.missing(_ipMeta);
    }
    if (data.containsKey('mac')) {
      context.handle(
        _macMeta,
        mac.isAcceptableOrUnknown(data['mac']!, _macMeta),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('is_critical_infrastructure')) {
      context.handle(
        _isCriticalInfrastructureMeta,
        isCriticalInfrastructure.isAcceptableOrUnknown(
          data['is_critical_infrastructure']!,
          _isCriticalInfrastructureMeta,
        ),
      );
    }
    if (data.containsKey('requires_admin_confirmation')) {
      context.handle(
        _requiresAdminConfirmationMeta,
        requiresAdminConfirmation.isAcceptableOrUnknown(
          data['requires_admin_confirmation']!,
          _requiresAdminConfirmationMeta,
        ),
      );
    }
    if (data.containsKey('linked_subnets_json')) {
      context.handle(
        _linkedSubnetsJsonMeta,
        linkedSubnetsJson.isAcceptableOrUnknown(
          data['linked_subnets_json']!,
          _linkedSubnetsJsonMeta,
        ),
      );
    }
    if (data.containsKey('controller_url')) {
      context.handle(
        _controllerUrlMeta,
        controllerUrl.isAcceptableOrUnknown(
          data['controller_url']!,
          _controllerUrlMeta,
        ),
      );
    }
    if (data.containsKey('site_name')) {
      context.handle(
        _siteNameMeta,
        siteName.isAcceptableOrUnknown(data['site_name']!, _siteNameMeta),
      );
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('is_read_only')) {
      context.handle(
        _isReadOnlyMeta,
        isReadOnly.isAcceptableOrUnknown(
          data['is_read_only']!,
          _isReadOnlyMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InfrastructureDeviceData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InfrastructureDeviceData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      ip: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ip'],
      )!,
      mac: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mac'],
      ),
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
      isCriticalInfrastructure: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_critical_infrastructure'],
      )!,
      requiresAdminConfirmation: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}requires_admin_confirmation'],
      )!,
      linkedSubnetsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linked_subnets_json'],
      )!,
      controllerUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}controller_url'],
      ),
      siteName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}site_name'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      isReadOnly: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_read_only'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $InfrastructureDevicesTable createAlias(String alias) {
    return $InfrastructureDevicesTable(attachedDatabase, alias);
  }
}

class InfrastructureDeviceData extends DataClass
    implements Insertable<InfrastructureDeviceData> {
  final int id;
  final String name;
  final String ip;
  final String? mac;
  final String role;
  final String? location;
  final bool isCriticalInfrastructure;
  final bool requiresAdminConfirmation;
  final String linkedSubnetsJson;
  final String? controllerUrl;
  final String siteName;
  final bool isEnabled;
  final bool isReadOnly;
  final DateTime createdAt;
  final DateTime? updatedAt;
  const InfrastructureDeviceData({
    required this.id,
    required this.name,
    required this.ip,
    this.mac,
    required this.role,
    this.location,
    required this.isCriticalInfrastructure,
    required this.requiresAdminConfirmation,
    required this.linkedSubnetsJson,
    this.controllerUrl,
    required this.siteName,
    required this.isEnabled,
    required this.isReadOnly,
    required this.createdAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['ip'] = Variable<String>(ip);
    if (!nullToAbsent || mac != null) {
      map['mac'] = Variable<String>(mac);
    }
    map['role'] = Variable<String>(role);
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    map['is_critical_infrastructure'] = Variable<bool>(
      isCriticalInfrastructure,
    );
    map['requires_admin_confirmation'] = Variable<bool>(
      requiresAdminConfirmation,
    );
    map['linked_subnets_json'] = Variable<String>(linkedSubnetsJson);
    if (!nullToAbsent || controllerUrl != null) {
      map['controller_url'] = Variable<String>(controllerUrl);
    }
    map['site_name'] = Variable<String>(siteName);
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['is_read_only'] = Variable<bool>(isReadOnly);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    return map;
  }

  InfrastructureDevicesCompanion toCompanion(bool nullToAbsent) {
    return InfrastructureDevicesCompanion(
      id: Value(id),
      name: Value(name),
      ip: Value(ip),
      mac: mac == null && nullToAbsent ? const Value.absent() : Value(mac),
      role: Value(role),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      isCriticalInfrastructure: Value(isCriticalInfrastructure),
      requiresAdminConfirmation: Value(requiresAdminConfirmation),
      linkedSubnetsJson: Value(linkedSubnetsJson),
      controllerUrl: controllerUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(controllerUrl),
      siteName: Value(siteName),
      isEnabled: Value(isEnabled),
      isReadOnly: Value(isReadOnly),
      createdAt: Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory InfrastructureDeviceData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InfrastructureDeviceData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      ip: serializer.fromJson<String>(json['ip']),
      mac: serializer.fromJson<String?>(json['mac']),
      role: serializer.fromJson<String>(json['role']),
      location: serializer.fromJson<String?>(json['location']),
      isCriticalInfrastructure: serializer.fromJson<bool>(
        json['isCriticalInfrastructure'],
      ),
      requiresAdminConfirmation: serializer.fromJson<bool>(
        json['requiresAdminConfirmation'],
      ),
      linkedSubnetsJson: serializer.fromJson<String>(json['linkedSubnetsJson']),
      controllerUrl: serializer.fromJson<String?>(json['controllerUrl']),
      siteName: serializer.fromJson<String>(json['siteName']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      isReadOnly: serializer.fromJson<bool>(json['isReadOnly']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'ip': serializer.toJson<String>(ip),
      'mac': serializer.toJson<String?>(mac),
      'role': serializer.toJson<String>(role),
      'location': serializer.toJson<String?>(location),
      'isCriticalInfrastructure': serializer.toJson<bool>(
        isCriticalInfrastructure,
      ),
      'requiresAdminConfirmation': serializer.toJson<bool>(
        requiresAdminConfirmation,
      ),
      'linkedSubnetsJson': serializer.toJson<String>(linkedSubnetsJson),
      'controllerUrl': serializer.toJson<String?>(controllerUrl),
      'siteName': serializer.toJson<String>(siteName),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'isReadOnly': serializer.toJson<bool>(isReadOnly),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
    };
  }

  InfrastructureDeviceData copyWith({
    int? id,
    String? name,
    String? ip,
    Value<String?> mac = const Value.absent(),
    String? role,
    Value<String?> location = const Value.absent(),
    bool? isCriticalInfrastructure,
    bool? requiresAdminConfirmation,
    String? linkedSubnetsJson,
    Value<String?> controllerUrl = const Value.absent(),
    String? siteName,
    bool? isEnabled,
    bool? isReadOnly,
    DateTime? createdAt,
    Value<DateTime?> updatedAt = const Value.absent(),
  }) => InfrastructureDeviceData(
    id: id ?? this.id,
    name: name ?? this.name,
    ip: ip ?? this.ip,
    mac: mac.present ? mac.value : this.mac,
    role: role ?? this.role,
    location: location.present ? location.value : this.location,
    isCriticalInfrastructure:
        isCriticalInfrastructure ?? this.isCriticalInfrastructure,
    requiresAdminConfirmation:
        requiresAdminConfirmation ?? this.requiresAdminConfirmation,
    linkedSubnetsJson: linkedSubnetsJson ?? this.linkedSubnetsJson,
    controllerUrl: controllerUrl.present
        ? controllerUrl.value
        : this.controllerUrl,
    siteName: siteName ?? this.siteName,
    isEnabled: isEnabled ?? this.isEnabled,
    isReadOnly: isReadOnly ?? this.isReadOnly,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  InfrastructureDeviceData copyWithCompanion(
    InfrastructureDevicesCompanion data,
  ) {
    return InfrastructureDeviceData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      ip: data.ip.present ? data.ip.value : this.ip,
      mac: data.mac.present ? data.mac.value : this.mac,
      role: data.role.present ? data.role.value : this.role,
      location: data.location.present ? data.location.value : this.location,
      isCriticalInfrastructure: data.isCriticalInfrastructure.present
          ? data.isCriticalInfrastructure.value
          : this.isCriticalInfrastructure,
      requiresAdminConfirmation: data.requiresAdminConfirmation.present
          ? data.requiresAdminConfirmation.value
          : this.requiresAdminConfirmation,
      linkedSubnetsJson: data.linkedSubnetsJson.present
          ? data.linkedSubnetsJson.value
          : this.linkedSubnetsJson,
      controllerUrl: data.controllerUrl.present
          ? data.controllerUrl.value
          : this.controllerUrl,
      siteName: data.siteName.present ? data.siteName.value : this.siteName,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      isReadOnly: data.isReadOnly.present
          ? data.isReadOnly.value
          : this.isReadOnly,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InfrastructureDeviceData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('ip: $ip, ')
          ..write('mac: $mac, ')
          ..write('role: $role, ')
          ..write('location: $location, ')
          ..write('isCriticalInfrastructure: $isCriticalInfrastructure, ')
          ..write('requiresAdminConfirmation: $requiresAdminConfirmation, ')
          ..write('linkedSubnetsJson: $linkedSubnetsJson, ')
          ..write('controllerUrl: $controllerUrl, ')
          ..write('siteName: $siteName, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('isReadOnly: $isReadOnly, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    ip,
    mac,
    role,
    location,
    isCriticalInfrastructure,
    requiresAdminConfirmation,
    linkedSubnetsJson,
    controllerUrl,
    siteName,
    isEnabled,
    isReadOnly,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InfrastructureDeviceData &&
          other.id == this.id &&
          other.name == this.name &&
          other.ip == this.ip &&
          other.mac == this.mac &&
          other.role == this.role &&
          other.location == this.location &&
          other.isCriticalInfrastructure == this.isCriticalInfrastructure &&
          other.requiresAdminConfirmation == this.requiresAdminConfirmation &&
          other.linkedSubnetsJson == this.linkedSubnetsJson &&
          other.controllerUrl == this.controllerUrl &&
          other.siteName == this.siteName &&
          other.isEnabled == this.isEnabled &&
          other.isReadOnly == this.isReadOnly &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class InfrastructureDevicesCompanion
    extends UpdateCompanion<InfrastructureDeviceData> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> ip;
  final Value<String?> mac;
  final Value<String> role;
  final Value<String?> location;
  final Value<bool> isCriticalInfrastructure;
  final Value<bool> requiresAdminConfirmation;
  final Value<String> linkedSubnetsJson;
  final Value<String?> controllerUrl;
  final Value<String> siteName;
  final Value<bool> isEnabled;
  final Value<bool> isReadOnly;
  final Value<DateTime> createdAt;
  final Value<DateTime?> updatedAt;
  const InfrastructureDevicesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.ip = const Value.absent(),
    this.mac = const Value.absent(),
    this.role = const Value.absent(),
    this.location = const Value.absent(),
    this.isCriticalInfrastructure = const Value.absent(),
    this.requiresAdminConfirmation = const Value.absent(),
    this.linkedSubnetsJson = const Value.absent(),
    this.controllerUrl = const Value.absent(),
    this.siteName = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.isReadOnly = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  InfrastructureDevicesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String ip,
    this.mac = const Value.absent(),
    this.role = const Value.absent(),
    this.location = const Value.absent(),
    this.isCriticalInfrastructure = const Value.absent(),
    this.requiresAdminConfirmation = const Value.absent(),
    this.linkedSubnetsJson = const Value.absent(),
    this.controllerUrl = const Value.absent(),
    this.siteName = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.isReadOnly = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name),
       ip = Value(ip);
  static Insertable<InfrastructureDeviceData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? ip,
    Expression<String>? mac,
    Expression<String>? role,
    Expression<String>? location,
    Expression<bool>? isCriticalInfrastructure,
    Expression<bool>? requiresAdminConfirmation,
    Expression<String>? linkedSubnetsJson,
    Expression<String>? controllerUrl,
    Expression<String>? siteName,
    Expression<bool>? isEnabled,
    Expression<bool>? isReadOnly,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (ip != null) 'ip': ip,
      if (mac != null) 'mac': mac,
      if (role != null) 'role': role,
      if (location != null) 'location': location,
      if (isCriticalInfrastructure != null)
        'is_critical_infrastructure': isCriticalInfrastructure,
      if (requiresAdminConfirmation != null)
        'requires_admin_confirmation': requiresAdminConfirmation,
      if (linkedSubnetsJson != null) 'linked_subnets_json': linkedSubnetsJson,
      if (controllerUrl != null) 'controller_url': controllerUrl,
      if (siteName != null) 'site_name': siteName,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (isReadOnly != null) 'is_read_only': isReadOnly,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  InfrastructureDevicesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? ip,
    Value<String?>? mac,
    Value<String>? role,
    Value<String?>? location,
    Value<bool>? isCriticalInfrastructure,
    Value<bool>? requiresAdminConfirmation,
    Value<String>? linkedSubnetsJson,
    Value<String?>? controllerUrl,
    Value<String>? siteName,
    Value<bool>? isEnabled,
    Value<bool>? isReadOnly,
    Value<DateTime>? createdAt,
    Value<DateTime?>? updatedAt,
  }) {
    return InfrastructureDevicesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      mac: mac ?? this.mac,
      role: role ?? this.role,
      location: location ?? this.location,
      isCriticalInfrastructure:
          isCriticalInfrastructure ?? this.isCriticalInfrastructure,
      requiresAdminConfirmation:
          requiresAdminConfirmation ?? this.requiresAdminConfirmation,
      linkedSubnetsJson: linkedSubnetsJson ?? this.linkedSubnetsJson,
      controllerUrl: controllerUrl ?? this.controllerUrl,
      siteName: siteName ?? this.siteName,
      isEnabled: isEnabled ?? this.isEnabled,
      isReadOnly: isReadOnly ?? this.isReadOnly,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (ip.present) {
      map['ip'] = Variable<String>(ip.value);
    }
    if (mac.present) {
      map['mac'] = Variable<String>(mac.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (isCriticalInfrastructure.present) {
      map['is_critical_infrastructure'] = Variable<bool>(
        isCriticalInfrastructure.value,
      );
    }
    if (requiresAdminConfirmation.present) {
      map['requires_admin_confirmation'] = Variable<bool>(
        requiresAdminConfirmation.value,
      );
    }
    if (linkedSubnetsJson.present) {
      map['linked_subnets_json'] = Variable<String>(linkedSubnetsJson.value);
    }
    if (controllerUrl.present) {
      map['controller_url'] = Variable<String>(controllerUrl.value);
    }
    if (siteName.present) {
      map['site_name'] = Variable<String>(siteName.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (isReadOnly.present) {
      map['is_read_only'] = Variable<bool>(isReadOnly.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InfrastructureDevicesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('ip: $ip, ')
          ..write('mac: $mac, ')
          ..write('role: $role, ')
          ..write('location: $location, ')
          ..write('isCriticalInfrastructure: $isCriticalInfrastructure, ')
          ..write('requiresAdminConfirmation: $requiresAdminConfirmation, ')
          ..write('linkedSubnetsJson: $linkedSubnetsJson, ')
          ..write('controllerUrl: $controllerUrl, ')
          ..write('siteName: $siteName, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('isReadOnly: $isReadOnly, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UsersTable users = $UsersTable(this);
  late final $AuditLogsTable auditLogs = $AuditLogsTable(this);
  late final $LocationsTable locations = $LocationsTable(this);
  late final $DevicesTable devices = $DevicesTable(this);
  late final $CheckResultsTable checkResults = $CheckResultsTable(this);
  late final $DeviceStatusesTable deviceStatuses = $DeviceStatusesTable(this);
  late final $IncidentsTable incidents = $IncidentsTable(this);
  late final $DiscoveryConfigurationsTable discoveryConfigurations =
      $DiscoveryConfigurationsTable(this);
  late final $DiscoveryScansTable discoveryScans = $DiscoveryScansTable(this);
  late final $DiscoveredDevicesTable discoveredDevices =
      $DiscoveredDevicesTable(this);
  late final $DiscoveryEvidencesTable discoveryEvidences =
      $DiscoveryEvidencesTable(this);
  late final $InfrastructureDevicesTable infrastructureDevices =
      $InfrastructureDevicesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    users,
    auditLogs,
    locations,
    devices,
    checkResults,
    deviceStatuses,
    incidents,
    discoveryConfigurations,
    discoveryScans,
    discoveredDevices,
    discoveryEvidences,
    infrastructureDevices,
  ];
}

typedef $$UsersTableCreateCompanionBuilder =
    UsersCompanion Function({
      Value<int> id,
      required String username,
      required String passwordHash,
      Value<String> role,
      Value<bool> isEnabled,
      Value<DateTime> createdAt,
      Value<DateTime?> updatedAt,
      Value<DateTime?> lastLoginAt,
    });
typedef $$UsersTableUpdateCompanionBuilder =
    UsersCompanion Function({
      Value<int> id,
      Value<String> username,
      Value<String> passwordHash,
      Value<String> role,
      Value<bool> isEnabled,
      Value<DateTime> createdAt,
      Value<DateTime?> updatedAt,
      Value<DateTime?> lastLoginAt,
    });

class $$UsersTableFilterComposer extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastLoginAt => $composableBuilder(
    column: $table.lastLoginAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsersTableOrderingComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastLoginAt => $composableBuilder(
    column: $table.lastLoginAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastLoginAt => $composableBuilder(
    column: $table.lastLoginAt,
    builder: (column) => column,
  );
}

class $$UsersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UsersTable,
          User,
          $$UsersTableFilterComposer,
          $$UsersTableOrderingComposer,
          $$UsersTableAnnotationComposer,
          $$UsersTableCreateCompanionBuilder,
          $$UsersTableUpdateCompanionBuilder,
          (User, BaseReferences<_$AppDatabase, $UsersTable, User>),
          User,
          PrefetchHooks Function()
        > {
  $$UsersTableTableManager(_$AppDatabase db, $UsersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> username = const Value.absent(),
                Value<String> passwordHash = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> lastLoginAt = const Value.absent(),
              }) => UsersCompanion(
                id: id,
                username: username,
                passwordHash: passwordHash,
                role: role,
                isEnabled: isEnabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastLoginAt: lastLoginAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String username,
                required String passwordHash,
                Value<String> role = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> lastLoginAt = const Value.absent(),
              }) => UsersCompanion.insert(
                id: id,
                username: username,
                passwordHash: passwordHash,
                role: role,
                isEnabled: isEnabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastLoginAt: lastLoginAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UsersTable,
      User,
      $$UsersTableFilterComposer,
      $$UsersTableOrderingComposer,
      $$UsersTableAnnotationComposer,
      $$UsersTableCreateCompanionBuilder,
      $$UsersTableUpdateCompanionBuilder,
      (User, BaseReferences<_$AppDatabase, $UsersTable, User>),
      User,
      PrefetchHooks Function()
    >;
typedef $$AuditLogsTableCreateCompanionBuilder =
    AuditLogsCompanion Function({
      Value<int> id,
      Value<int?> userId,
      required String username,
      required String action,
      Value<String?> details,
      Value<DateTime> timestamp,
    });
typedef $$AuditLogsTableUpdateCompanionBuilder =
    AuditLogsCompanion Function({
      Value<int> id,
      Value<int?> userId,
      Value<String> username,
      Value<String> action,
      Value<String?> details,
      Value<DateTime> timestamp,
    });

class $$AuditLogsTableFilterComposer
    extends Composer<_$AppDatabase, $AuditLogsTable> {
  $$AuditLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AuditLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $AuditLogsTable> {
  $$AuditLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AuditLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AuditLogsTable> {
  $$AuditLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<String> get details =>
      $composableBuilder(column: $table.details, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$AuditLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AuditLogsTable,
          AuditLog,
          $$AuditLogsTableFilterComposer,
          $$AuditLogsTableOrderingComposer,
          $$AuditLogsTableAnnotationComposer,
          $$AuditLogsTableCreateCompanionBuilder,
          $$AuditLogsTableUpdateCompanionBuilder,
          (AuditLog, BaseReferences<_$AppDatabase, $AuditLogsTable, AuditLog>),
          AuditLog,
          PrefetchHooks Function()
        > {
  $$AuditLogsTableTableManager(_$AppDatabase db, $AuditLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AuditLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AuditLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AuditLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> userId = const Value.absent(),
                Value<String> username = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<String?> details = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
              }) => AuditLogsCompanion(
                id: id,
                userId: userId,
                username: username,
                action: action,
                details: details,
                timestamp: timestamp,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> userId = const Value.absent(),
                required String username,
                required String action,
                Value<String?> details = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
              }) => AuditLogsCompanion.insert(
                id: id,
                userId: userId,
                username: username,
                action: action,
                details: details,
                timestamp: timestamp,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AuditLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AuditLogsTable,
      AuditLog,
      $$AuditLogsTableFilterComposer,
      $$AuditLogsTableOrderingComposer,
      $$AuditLogsTableAnnotationComposer,
      $$AuditLogsTableCreateCompanionBuilder,
      $$AuditLogsTableUpdateCompanionBuilder,
      (AuditLog, BaseReferences<_$AppDatabase, $AuditLogsTable, AuditLog>),
      AuditLog,
      PrefetchHooks Function()
    >;
typedef $$LocationsTableCreateCompanionBuilder =
    LocationsCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> description,
    });
typedef $$LocationsTableUpdateCompanionBuilder =
    LocationsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> description,
    });

class $$LocationsTableFilterComposer
    extends Composer<_$AppDatabase, $LocationsTable> {
  $$LocationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocationsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocationsTable> {
  $$LocationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocationsTable> {
  $$LocationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );
}

class $$LocationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocationsTable,
          Location,
          $$LocationsTableFilterComposer,
          $$LocationsTableOrderingComposer,
          $$LocationsTableAnnotationComposer,
          $$LocationsTableCreateCompanionBuilder,
          $$LocationsTableUpdateCompanionBuilder,
          (Location, BaseReferences<_$AppDatabase, $LocationsTable, Location>),
          Location,
          PrefetchHooks Function()
        > {
  $$LocationsTableTableManager(_$AppDatabase db, $LocationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
              }) => LocationsCompanion(
                id: id,
                name: name,
                description: description,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> description = const Value.absent(),
              }) => LocationsCompanion.insert(
                id: id,
                name: name,
                description: description,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocationsTable,
      Location,
      $$LocationsTableFilterComposer,
      $$LocationsTableOrderingComposer,
      $$LocationsTableAnnotationComposer,
      $$LocationsTableCreateCompanionBuilder,
      $$LocationsTableUpdateCompanionBuilder,
      (Location, BaseReferences<_$AppDatabase, $LocationsTable, Location>),
      Location,
      PrefetchHooks Function()
    >;
typedef $$DevicesTableCreateCompanionBuilder =
    DevicesCompanion Function({
      Value<int> id,
      required String name,
      Value<String> type,
      required String ip,
      required String ownerName,
      required String department,
      Value<String?> officeLocation,
      Value<int?> parentSwitchId,
      Value<String?> parentSwitchName,
      Value<String?> vendor,
      Value<String?> model,
      Value<String?> mac,
      Value<String?> hostname,
      Value<String?> operatingSystem,
      Value<String?> notes,
      Value<bool> isMonitored,
      Value<bool> isEnabled,
      Value<DateTime> createdAt,
      Value<DateTime?> updatedAt,
    });
typedef $$DevicesTableUpdateCompanionBuilder =
    DevicesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> type,
      Value<String> ip,
      Value<String> ownerName,
      Value<String> department,
      Value<String?> officeLocation,
      Value<int?> parentSwitchId,
      Value<String?> parentSwitchName,
      Value<String?> vendor,
      Value<String?> model,
      Value<String?> mac,
      Value<String?> hostname,
      Value<String?> operatingSystem,
      Value<String?> notes,
      Value<bool> isMonitored,
      Value<bool> isEnabled,
      Value<DateTime> createdAt,
      Value<DateTime?> updatedAt,
    });

class $$DevicesTableFilterComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ip => $composableBuilder(
    column: $table.ip,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerName => $composableBuilder(
    column: $table.ownerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get department => $composableBuilder(
    column: $table.department,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get officeLocation => $composableBuilder(
    column: $table.officeLocation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get parentSwitchId => $composableBuilder(
    column: $table.parentSwitchId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentSwitchName => $composableBuilder(
    column: $table.parentSwitchName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vendor => $composableBuilder(
    column: $table.vendor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mac => $composableBuilder(
    column: $table.mac,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hostname => $composableBuilder(
    column: $table.hostname,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operatingSystem => $composableBuilder(
    column: $table.operatingSystem,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMonitored => $composableBuilder(
    column: $table.isMonitored,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DevicesTableOrderingComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ip => $composableBuilder(
    column: $table.ip,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerName => $composableBuilder(
    column: $table.ownerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get department => $composableBuilder(
    column: $table.department,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get officeLocation => $composableBuilder(
    column: $table.officeLocation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get parentSwitchId => $composableBuilder(
    column: $table.parentSwitchId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentSwitchName => $composableBuilder(
    column: $table.parentSwitchName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vendor => $composableBuilder(
    column: $table.vendor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mac => $composableBuilder(
    column: $table.mac,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hostname => $composableBuilder(
    column: $table.hostname,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operatingSystem => $composableBuilder(
    column: $table.operatingSystem,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMonitored => $composableBuilder(
    column: $table.isMonitored,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DevicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get ip =>
      $composableBuilder(column: $table.ip, builder: (column) => column);

  GeneratedColumn<String> get ownerName =>
      $composableBuilder(column: $table.ownerName, builder: (column) => column);

  GeneratedColumn<String> get department => $composableBuilder(
    column: $table.department,
    builder: (column) => column,
  );

  GeneratedColumn<String> get officeLocation => $composableBuilder(
    column: $table.officeLocation,
    builder: (column) => column,
  );

  GeneratedColumn<int> get parentSwitchId => $composableBuilder(
    column: $table.parentSwitchId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentSwitchName => $composableBuilder(
    column: $table.parentSwitchName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get vendor =>
      $composableBuilder(column: $table.vendor, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get mac =>
      $composableBuilder(column: $table.mac, builder: (column) => column);

  GeneratedColumn<String> get hostname =>
      $composableBuilder(column: $table.hostname, builder: (column) => column);

  GeneratedColumn<String> get operatingSystem => $composableBuilder(
    column: $table.operatingSystem,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<bool> get isMonitored => $composableBuilder(
    column: $table.isMonitored,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DevicesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DevicesTable,
          Device,
          $$DevicesTableFilterComposer,
          $$DevicesTableOrderingComposer,
          $$DevicesTableAnnotationComposer,
          $$DevicesTableCreateCompanionBuilder,
          $$DevicesTableUpdateCompanionBuilder,
          (Device, BaseReferences<_$AppDatabase, $DevicesTable, Device>),
          Device,
          PrefetchHooks Function()
        > {
  $$DevicesTableTableManager(_$AppDatabase db, $DevicesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DevicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DevicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DevicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> ip = const Value.absent(),
                Value<String> ownerName = const Value.absent(),
                Value<String> department = const Value.absent(),
                Value<String?> officeLocation = const Value.absent(),
                Value<int?> parentSwitchId = const Value.absent(),
                Value<String?> parentSwitchName = const Value.absent(),
                Value<String?> vendor = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String?> mac = const Value.absent(),
                Value<String?> hostname = const Value.absent(),
                Value<String?> operatingSystem = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<bool> isMonitored = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
              }) => DevicesCompanion(
                id: id,
                name: name,
                type: type,
                ip: ip,
                ownerName: ownerName,
                department: department,
                officeLocation: officeLocation,
                parentSwitchId: parentSwitchId,
                parentSwitchName: parentSwitchName,
                vendor: vendor,
                model: model,
                mac: mac,
                hostname: hostname,
                operatingSystem: operatingSystem,
                notes: notes,
                isMonitored: isMonitored,
                isEnabled: isEnabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> type = const Value.absent(),
                required String ip,
                required String ownerName,
                required String department,
                Value<String?> officeLocation = const Value.absent(),
                Value<int?> parentSwitchId = const Value.absent(),
                Value<String?> parentSwitchName = const Value.absent(),
                Value<String?> vendor = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String?> mac = const Value.absent(),
                Value<String?> hostname = const Value.absent(),
                Value<String?> operatingSystem = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<bool> isMonitored = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
              }) => DevicesCompanion.insert(
                id: id,
                name: name,
                type: type,
                ip: ip,
                ownerName: ownerName,
                department: department,
                officeLocation: officeLocation,
                parentSwitchId: parentSwitchId,
                parentSwitchName: parentSwitchName,
                vendor: vendor,
                model: model,
                mac: mac,
                hostname: hostname,
                operatingSystem: operatingSystem,
                notes: notes,
                isMonitored: isMonitored,
                isEnabled: isEnabled,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DevicesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DevicesTable,
      Device,
      $$DevicesTableFilterComposer,
      $$DevicesTableOrderingComposer,
      $$DevicesTableAnnotationComposer,
      $$DevicesTableCreateCompanionBuilder,
      $$DevicesTableUpdateCompanionBuilder,
      (Device, BaseReferences<_$AppDatabase, $DevicesTable, Device>),
      Device,
      PrefetchHooks Function()
    >;
typedef $$CheckResultsTableCreateCompanionBuilder =
    CheckResultsCompanion Function({
      Value<int> id,
      required int deviceId,
      Value<String?> assetId,
      required String targetIp,
      Value<String> checkType,
      required bool isSuccess,
      Value<int?> latencyMs,
      Value<double?> packetLossPercent,
      Value<String?> errorMessage,
      Value<DateTime> timestamp,
    });
typedef $$CheckResultsTableUpdateCompanionBuilder =
    CheckResultsCompanion Function({
      Value<int> id,
      Value<int> deviceId,
      Value<String?> assetId,
      Value<String> targetIp,
      Value<String> checkType,
      Value<bool> isSuccess,
      Value<int?> latencyMs,
      Value<double?> packetLossPercent,
      Value<String?> errorMessage,
      Value<DateTime> timestamp,
    });

class $$CheckResultsTableFilterComposer
    extends Composer<_$AppDatabase, $CheckResultsTable> {
  $$CheckResultsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetIp => $composableBuilder(
    column: $table.targetIp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checkType => $composableBuilder(
    column: $table.checkType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSuccess => $composableBuilder(
    column: $table.isSuccess,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get latencyMs => $composableBuilder(
    column: $table.latencyMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get packetLossPercent => $composableBuilder(
    column: $table.packetLossPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CheckResultsTableOrderingComposer
    extends Composer<_$AppDatabase, $CheckResultsTable> {
  $$CheckResultsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetIp => $composableBuilder(
    column: $table.targetIp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checkType => $composableBuilder(
    column: $table.checkType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSuccess => $composableBuilder(
    column: $table.isSuccess,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get latencyMs => $composableBuilder(
    column: $table.latencyMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get packetLossPercent => $composableBuilder(
    column: $table.packetLossPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CheckResultsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CheckResultsTable> {
  $$CheckResultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<String> get targetIp =>
      $composableBuilder(column: $table.targetIp, builder: (column) => column);

  GeneratedColumn<String> get checkType =>
      $composableBuilder(column: $table.checkType, builder: (column) => column);

  GeneratedColumn<bool> get isSuccess =>
      $composableBuilder(column: $table.isSuccess, builder: (column) => column);

  GeneratedColumn<int> get latencyMs =>
      $composableBuilder(column: $table.latencyMs, builder: (column) => column);

  GeneratedColumn<double> get packetLossPercent => $composableBuilder(
    column: $table.packetLossPercent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$CheckResultsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CheckResultsTable,
          CheckResultData,
          $$CheckResultsTableFilterComposer,
          $$CheckResultsTableOrderingComposer,
          $$CheckResultsTableAnnotationComposer,
          $$CheckResultsTableCreateCompanionBuilder,
          $$CheckResultsTableUpdateCompanionBuilder,
          (
            CheckResultData,
            BaseReferences<_$AppDatabase, $CheckResultsTable, CheckResultData>,
          ),
          CheckResultData,
          PrefetchHooks Function()
        > {
  $$CheckResultsTableTableManager(_$AppDatabase db, $CheckResultsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CheckResultsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CheckResultsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CheckResultsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> deviceId = const Value.absent(),
                Value<String?> assetId = const Value.absent(),
                Value<String> targetIp = const Value.absent(),
                Value<String> checkType = const Value.absent(),
                Value<bool> isSuccess = const Value.absent(),
                Value<int?> latencyMs = const Value.absent(),
                Value<double?> packetLossPercent = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
              }) => CheckResultsCompanion(
                id: id,
                deviceId: deviceId,
                assetId: assetId,
                targetIp: targetIp,
                checkType: checkType,
                isSuccess: isSuccess,
                latencyMs: latencyMs,
                packetLossPercent: packetLossPercent,
                errorMessage: errorMessage,
                timestamp: timestamp,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int deviceId,
                Value<String?> assetId = const Value.absent(),
                required String targetIp,
                Value<String> checkType = const Value.absent(),
                required bool isSuccess,
                Value<int?> latencyMs = const Value.absent(),
                Value<double?> packetLossPercent = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
              }) => CheckResultsCompanion.insert(
                id: id,
                deviceId: deviceId,
                assetId: assetId,
                targetIp: targetIp,
                checkType: checkType,
                isSuccess: isSuccess,
                latencyMs: latencyMs,
                packetLossPercent: packetLossPercent,
                errorMessage: errorMessage,
                timestamp: timestamp,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CheckResultsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CheckResultsTable,
      CheckResultData,
      $$CheckResultsTableFilterComposer,
      $$CheckResultsTableOrderingComposer,
      $$CheckResultsTableAnnotationComposer,
      $$CheckResultsTableCreateCompanionBuilder,
      $$CheckResultsTableUpdateCompanionBuilder,
      (
        CheckResultData,
        BaseReferences<_$AppDatabase, $CheckResultsTable, CheckResultData>,
      ),
      CheckResultData,
      PrefetchHooks Function()
    >;
typedef $$DeviceStatusesTableCreateCompanionBuilder =
    DeviceStatusesCompanion Function({
      Value<int> deviceId,
      Value<String> status,
      Value<DateTime?> lastSeen,
      Value<DateTime?> lastCheckAt,
      Value<int?> lastLatencyMs,
      Value<int?> lastSuccessfulLatencyMs,
      Value<String?> lastFailureReason,
      Value<int> consecutiveFailures,
      Value<int> consecutiveSuccesses,
      Value<DateTime> statusChangedAt,
      Value<bool> isMaintenance,
    });
typedef $$DeviceStatusesTableUpdateCompanionBuilder =
    DeviceStatusesCompanion Function({
      Value<int> deviceId,
      Value<String> status,
      Value<DateTime?> lastSeen,
      Value<DateTime?> lastCheckAt,
      Value<int?> lastLatencyMs,
      Value<int?> lastSuccessfulLatencyMs,
      Value<String?> lastFailureReason,
      Value<int> consecutiveFailures,
      Value<int> consecutiveSuccesses,
      Value<DateTime> statusChangedAt,
      Value<bool> isMaintenance,
    });

class $$DeviceStatusesTableFilterComposer
    extends Composer<_$AppDatabase, $DeviceStatusesTable> {
  $$DeviceStatusesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastCheckAt => $composableBuilder(
    column: $table.lastCheckAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastLatencyMs => $composableBuilder(
    column: $table.lastLatencyMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSuccessfulLatencyMs => $composableBuilder(
    column: $table.lastSuccessfulLatencyMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastFailureReason => $composableBuilder(
    column: $table.lastFailureReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get consecutiveFailures => $composableBuilder(
    column: $table.consecutiveFailures,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get consecutiveSuccesses => $composableBuilder(
    column: $table.consecutiveSuccesses,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get statusChangedAt => $composableBuilder(
    column: $table.statusChangedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMaintenance => $composableBuilder(
    column: $table.isMaintenance,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeviceStatusesTableOrderingComposer
    extends Composer<_$AppDatabase, $DeviceStatusesTable> {
  $$DeviceStatusesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastCheckAt => $composableBuilder(
    column: $table.lastCheckAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastLatencyMs => $composableBuilder(
    column: $table.lastLatencyMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSuccessfulLatencyMs => $composableBuilder(
    column: $table.lastSuccessfulLatencyMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastFailureReason => $composableBuilder(
    column: $table.lastFailureReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get consecutiveFailures => $composableBuilder(
    column: $table.consecutiveFailures,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get consecutiveSuccesses => $composableBuilder(
    column: $table.consecutiveSuccesses,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get statusChangedAt => $composableBuilder(
    column: $table.statusChangedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMaintenance => $composableBuilder(
    column: $table.isMaintenance,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeviceStatusesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeviceStatusesTable> {
  $$DeviceStatusesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);

  GeneratedColumn<DateTime> get lastCheckAt => $composableBuilder(
    column: $table.lastCheckAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastLatencyMs => $composableBuilder(
    column: $table.lastLatencyMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSuccessfulLatencyMs => $composableBuilder(
    column: $table.lastSuccessfulLatencyMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastFailureReason => $composableBuilder(
    column: $table.lastFailureReason,
    builder: (column) => column,
  );

  GeneratedColumn<int> get consecutiveFailures => $composableBuilder(
    column: $table.consecutiveFailures,
    builder: (column) => column,
  );

  GeneratedColumn<int> get consecutiveSuccesses => $composableBuilder(
    column: $table.consecutiveSuccesses,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get statusChangedAt => $composableBuilder(
    column: $table.statusChangedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isMaintenance => $composableBuilder(
    column: $table.isMaintenance,
    builder: (column) => column,
  );
}

class $$DeviceStatusesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DeviceStatusesTable,
          DeviceStatusData,
          $$DeviceStatusesTableFilterComposer,
          $$DeviceStatusesTableOrderingComposer,
          $$DeviceStatusesTableAnnotationComposer,
          $$DeviceStatusesTableCreateCompanionBuilder,
          $$DeviceStatusesTableUpdateCompanionBuilder,
          (
            DeviceStatusData,
            BaseReferences<
              _$AppDatabase,
              $DeviceStatusesTable,
              DeviceStatusData
            >,
          ),
          DeviceStatusData,
          PrefetchHooks Function()
        > {
  $$DeviceStatusesTableTableManager(
    _$AppDatabase db,
    $DeviceStatusesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeviceStatusesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeviceStatusesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeviceStatusesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> deviceId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> lastSeen = const Value.absent(),
                Value<DateTime?> lastCheckAt = const Value.absent(),
                Value<int?> lastLatencyMs = const Value.absent(),
                Value<int?> lastSuccessfulLatencyMs = const Value.absent(),
                Value<String?> lastFailureReason = const Value.absent(),
                Value<int> consecutiveFailures = const Value.absent(),
                Value<int> consecutiveSuccesses = const Value.absent(),
                Value<DateTime> statusChangedAt = const Value.absent(),
                Value<bool> isMaintenance = const Value.absent(),
              }) => DeviceStatusesCompanion(
                deviceId: deviceId,
                status: status,
                lastSeen: lastSeen,
                lastCheckAt: lastCheckAt,
                lastLatencyMs: lastLatencyMs,
                lastSuccessfulLatencyMs: lastSuccessfulLatencyMs,
                lastFailureReason: lastFailureReason,
                consecutiveFailures: consecutiveFailures,
                consecutiveSuccesses: consecutiveSuccesses,
                statusChangedAt: statusChangedAt,
                isMaintenance: isMaintenance,
              ),
          createCompanionCallback:
              ({
                Value<int> deviceId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime?> lastSeen = const Value.absent(),
                Value<DateTime?> lastCheckAt = const Value.absent(),
                Value<int?> lastLatencyMs = const Value.absent(),
                Value<int?> lastSuccessfulLatencyMs = const Value.absent(),
                Value<String?> lastFailureReason = const Value.absent(),
                Value<int> consecutiveFailures = const Value.absent(),
                Value<int> consecutiveSuccesses = const Value.absent(),
                Value<DateTime> statusChangedAt = const Value.absent(),
                Value<bool> isMaintenance = const Value.absent(),
              }) => DeviceStatusesCompanion.insert(
                deviceId: deviceId,
                status: status,
                lastSeen: lastSeen,
                lastCheckAt: lastCheckAt,
                lastLatencyMs: lastLatencyMs,
                lastSuccessfulLatencyMs: lastSuccessfulLatencyMs,
                lastFailureReason: lastFailureReason,
                consecutiveFailures: consecutiveFailures,
                consecutiveSuccesses: consecutiveSuccesses,
                statusChangedAt: statusChangedAt,
                isMaintenance: isMaintenance,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeviceStatusesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DeviceStatusesTable,
      DeviceStatusData,
      $$DeviceStatusesTableFilterComposer,
      $$DeviceStatusesTableOrderingComposer,
      $$DeviceStatusesTableAnnotationComposer,
      $$DeviceStatusesTableCreateCompanionBuilder,
      $$DeviceStatusesTableUpdateCompanionBuilder,
      (
        DeviceStatusData,
        BaseReferences<_$AppDatabase, $DeviceStatusesTable, DeviceStatusData>,
      ),
      DeviceStatusData,
      PrefetchHooks Function()
    >;
typedef $$IncidentsTableCreateCompanionBuilder =
    IncidentsCompanion Function({
      Value<int> id,
      required int deviceId,
      required String deviceName,
      required String ownerName,
      required String department,
      Value<String?> location,
      required String deviceIp,
      required String incidentType,
      Value<String> severity,
      Value<String> status,
      Value<DateTime> startedAt,
      Value<DateTime?> resolvedAt,
      Value<DateTime?> acknowledgedAt,
      Value<String?> acknowledgedBy,
      Value<String?> notes,
      Value<String?> correlationMessage,
    });
typedef $$IncidentsTableUpdateCompanionBuilder =
    IncidentsCompanion Function({
      Value<int> id,
      Value<int> deviceId,
      Value<String> deviceName,
      Value<String> ownerName,
      Value<String> department,
      Value<String?> location,
      Value<String> deviceIp,
      Value<String> incidentType,
      Value<String> severity,
      Value<String> status,
      Value<DateTime> startedAt,
      Value<DateTime?> resolvedAt,
      Value<DateTime?> acknowledgedAt,
      Value<String?> acknowledgedBy,
      Value<String?> notes,
      Value<String?> correlationMessage,
    });

class $$IncidentsTableFilterComposer
    extends Composer<_$AppDatabase, $IncidentsTable> {
  $$IncidentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerName => $composableBuilder(
    column: $table.ownerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get department => $composableBuilder(
    column: $table.department,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceIp => $composableBuilder(
    column: $table.deviceIp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get incidentType => $composableBuilder(
    column: $table.incidentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get acknowledgedAt => $composableBuilder(
    column: $table.acknowledgedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get acknowledgedBy => $composableBuilder(
    column: $table.acknowledgedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get correlationMessage => $composableBuilder(
    column: $table.correlationMessage,
    builder: (column) => ColumnFilters(column),
  );
}

class $$IncidentsTableOrderingComposer
    extends Composer<_$AppDatabase, $IncidentsTable> {
  $$IncidentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerName => $composableBuilder(
    column: $table.ownerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get department => $composableBuilder(
    column: $table.department,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceIp => $composableBuilder(
    column: $table.deviceIp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get incidentType => $composableBuilder(
    column: $table.incidentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get acknowledgedAt => $composableBuilder(
    column: $table.acknowledgedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get acknowledgedBy => $composableBuilder(
    column: $table.acknowledgedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get correlationMessage => $composableBuilder(
    column: $table.correlationMessage,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IncidentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $IncidentsTable> {
  $$IncidentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get deviceName => $composableBuilder(
    column: $table.deviceName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ownerName =>
      $composableBuilder(column: $table.ownerName, builder: (column) => column);

  GeneratedColumn<String> get department => $composableBuilder(
    column: $table.department,
    builder: (column) => column,
  );

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get deviceIp =>
      $composableBuilder(column: $table.deviceIp, builder: (column) => column);

  GeneratedColumn<String> get incidentType => $composableBuilder(
    column: $table.incidentType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get severity =>
      $composableBuilder(column: $table.severity, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get acknowledgedAt => $composableBuilder(
    column: $table.acknowledgedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get acknowledgedBy => $composableBuilder(
    column: $table.acknowledgedBy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get correlationMessage => $composableBuilder(
    column: $table.correlationMessage,
    builder: (column) => column,
  );
}

class $$IncidentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IncidentsTable,
          IncidentData,
          $$IncidentsTableFilterComposer,
          $$IncidentsTableOrderingComposer,
          $$IncidentsTableAnnotationComposer,
          $$IncidentsTableCreateCompanionBuilder,
          $$IncidentsTableUpdateCompanionBuilder,
          (
            IncidentData,
            BaseReferences<_$AppDatabase, $IncidentsTable, IncidentData>,
          ),
          IncidentData,
          PrefetchHooks Function()
        > {
  $$IncidentsTableTableManager(_$AppDatabase db, $IncidentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IncidentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IncidentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IncidentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> deviceId = const Value.absent(),
                Value<String> deviceName = const Value.absent(),
                Value<String> ownerName = const Value.absent(),
                Value<String> department = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<String> deviceIp = const Value.absent(),
                Value<String> incidentType = const Value.absent(),
                Value<String> severity = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<DateTime?> acknowledgedAt = const Value.absent(),
                Value<String?> acknowledgedBy = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> correlationMessage = const Value.absent(),
              }) => IncidentsCompanion(
                id: id,
                deviceId: deviceId,
                deviceName: deviceName,
                ownerName: ownerName,
                department: department,
                location: location,
                deviceIp: deviceIp,
                incidentType: incidentType,
                severity: severity,
                status: status,
                startedAt: startedAt,
                resolvedAt: resolvedAt,
                acknowledgedAt: acknowledgedAt,
                acknowledgedBy: acknowledgedBy,
                notes: notes,
                correlationMessage: correlationMessage,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int deviceId,
                required String deviceName,
                required String ownerName,
                required String department,
                Value<String?> location = const Value.absent(),
                required String deviceIp,
                required String incidentType,
                Value<String> severity = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<DateTime?> acknowledgedAt = const Value.absent(),
                Value<String?> acknowledgedBy = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> correlationMessage = const Value.absent(),
              }) => IncidentsCompanion.insert(
                id: id,
                deviceId: deviceId,
                deviceName: deviceName,
                ownerName: ownerName,
                department: department,
                location: location,
                deviceIp: deviceIp,
                incidentType: incidentType,
                severity: severity,
                status: status,
                startedAt: startedAt,
                resolvedAt: resolvedAt,
                acknowledgedAt: acknowledgedAt,
                acknowledgedBy: acknowledgedBy,
                notes: notes,
                correlationMessage: correlationMessage,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$IncidentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IncidentsTable,
      IncidentData,
      $$IncidentsTableFilterComposer,
      $$IncidentsTableOrderingComposer,
      $$IncidentsTableAnnotationComposer,
      $$IncidentsTableCreateCompanionBuilder,
      $$IncidentsTableUpdateCompanionBuilder,
      (
        IncidentData,
        BaseReferences<_$AppDatabase, $IncidentsTable, IncidentData>,
      ),
      IncidentData,
      PrefetchHooks Function()
    >;
typedef $$DiscoveryConfigurationsTableCreateCompanionBuilder =
    DiscoveryConfigurationsCompanion Function({
      Value<int> id,
      Value<String> authorizedRangesJson,
      Value<String> enabledStrategiesJson,
      Value<int> maxConcurrency,
      Value<int> timeoutSeconds,
      Value<DateTime> updatedAt,
    });
typedef $$DiscoveryConfigurationsTableUpdateCompanionBuilder =
    DiscoveryConfigurationsCompanion Function({
      Value<int> id,
      Value<String> authorizedRangesJson,
      Value<String> enabledStrategiesJson,
      Value<int> maxConcurrency,
      Value<int> timeoutSeconds,
      Value<DateTime> updatedAt,
    });

class $$DiscoveryConfigurationsTableFilterComposer
    extends Composer<_$AppDatabase, $DiscoveryConfigurationsTable> {
  $$DiscoveryConfigurationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorizedRangesJson => $composableBuilder(
    column: $table.authorizedRangesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get enabledStrategiesJson => $composableBuilder(
    column: $table.enabledStrategiesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxConcurrency => $composableBuilder(
    column: $table.maxConcurrency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timeoutSeconds => $composableBuilder(
    column: $table.timeoutSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DiscoveryConfigurationsTableOrderingComposer
    extends Composer<_$AppDatabase, $DiscoveryConfigurationsTable> {
  $$DiscoveryConfigurationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorizedRangesJson => $composableBuilder(
    column: $table.authorizedRangesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get enabledStrategiesJson => $composableBuilder(
    column: $table.enabledStrategiesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxConcurrency => $composableBuilder(
    column: $table.maxConcurrency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timeoutSeconds => $composableBuilder(
    column: $table.timeoutSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiscoveryConfigurationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiscoveryConfigurationsTable> {
  $$DiscoveryConfigurationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get authorizedRangesJson => $composableBuilder(
    column: $table.authorizedRangesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get enabledStrategiesJson => $composableBuilder(
    column: $table.enabledStrategiesJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxConcurrency => $composableBuilder(
    column: $table.maxConcurrency,
    builder: (column) => column,
  );

  GeneratedColumn<int> get timeoutSeconds => $composableBuilder(
    column: $table.timeoutSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DiscoveryConfigurationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiscoveryConfigurationsTable,
          DiscoveryConfigurationData,
          $$DiscoveryConfigurationsTableFilterComposer,
          $$DiscoveryConfigurationsTableOrderingComposer,
          $$DiscoveryConfigurationsTableAnnotationComposer,
          $$DiscoveryConfigurationsTableCreateCompanionBuilder,
          $$DiscoveryConfigurationsTableUpdateCompanionBuilder,
          (
            DiscoveryConfigurationData,
            BaseReferences<
              _$AppDatabase,
              $DiscoveryConfigurationsTable,
              DiscoveryConfigurationData
            >,
          ),
          DiscoveryConfigurationData,
          PrefetchHooks Function()
        > {
  $$DiscoveryConfigurationsTableTableManager(
    _$AppDatabase db,
    $DiscoveryConfigurationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiscoveryConfigurationsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DiscoveryConfigurationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DiscoveryConfigurationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> authorizedRangesJson = const Value.absent(),
                Value<String> enabledStrategiesJson = const Value.absent(),
                Value<int> maxConcurrency = const Value.absent(),
                Value<int> timeoutSeconds = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => DiscoveryConfigurationsCompanion(
                id: id,
                authorizedRangesJson: authorizedRangesJson,
                enabledStrategiesJson: enabledStrategiesJson,
                maxConcurrency: maxConcurrency,
                timeoutSeconds: timeoutSeconds,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> authorizedRangesJson = const Value.absent(),
                Value<String> enabledStrategiesJson = const Value.absent(),
                Value<int> maxConcurrency = const Value.absent(),
                Value<int> timeoutSeconds = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => DiscoveryConfigurationsCompanion.insert(
                id: id,
                authorizedRangesJson: authorizedRangesJson,
                enabledStrategiesJson: enabledStrategiesJson,
                maxConcurrency: maxConcurrency,
                timeoutSeconds: timeoutSeconds,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DiscoveryConfigurationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiscoveryConfigurationsTable,
      DiscoveryConfigurationData,
      $$DiscoveryConfigurationsTableFilterComposer,
      $$DiscoveryConfigurationsTableOrderingComposer,
      $$DiscoveryConfigurationsTableAnnotationComposer,
      $$DiscoveryConfigurationsTableCreateCompanionBuilder,
      $$DiscoveryConfigurationsTableUpdateCompanionBuilder,
      (
        DiscoveryConfigurationData,
        BaseReferences<
          _$AppDatabase,
          $DiscoveryConfigurationsTable,
          DiscoveryConfigurationData
        >,
      ),
      DiscoveryConfigurationData,
      PrefetchHooks Function()
    >;
typedef $$DiscoveryScansTableCreateCompanionBuilder =
    DiscoveryScansCompanion Function({
      Value<int> id,
      Value<String> status,
      required String rangesJson,
      Value<String> enabledStrategiesJson,
      Value<DateTime> startedAt,
      Value<DateTime?> completedAt,
      Value<int> targetsEnumerated,
      Value<int> targetsAttempted,
      Value<int> responsesReceived,
      Value<int> classifiedCount,
      Value<int> unknownCount,
      Value<int> failureCount,
      Value<String?> diagnosticSummary,
    });
typedef $$DiscoveryScansTableUpdateCompanionBuilder =
    DiscoveryScansCompanion Function({
      Value<int> id,
      Value<String> status,
      Value<String> rangesJson,
      Value<String> enabledStrategiesJson,
      Value<DateTime> startedAt,
      Value<DateTime?> completedAt,
      Value<int> targetsEnumerated,
      Value<int> targetsAttempted,
      Value<int> responsesReceived,
      Value<int> classifiedCount,
      Value<int> unknownCount,
      Value<int> failureCount,
      Value<String?> diagnosticSummary,
    });

class $$DiscoveryScansTableFilterComposer
    extends Composer<_$AppDatabase, $DiscoveryScansTable> {
  $$DiscoveryScansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rangesJson => $composableBuilder(
    column: $table.rangesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get enabledStrategiesJson => $composableBuilder(
    column: $table.enabledStrategiesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetsEnumerated => $composableBuilder(
    column: $table.targetsEnumerated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetsAttempted => $composableBuilder(
    column: $table.targetsAttempted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get responsesReceived => $composableBuilder(
    column: $table.responsesReceived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get classifiedCount => $composableBuilder(
    column: $table.classifiedCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unknownCount => $composableBuilder(
    column: $table.unknownCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get failureCount => $composableBuilder(
    column: $table.failureCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get diagnosticSummary => $composableBuilder(
    column: $table.diagnosticSummary,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DiscoveryScansTableOrderingComposer
    extends Composer<_$AppDatabase, $DiscoveryScansTable> {
  $$DiscoveryScansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rangesJson => $composableBuilder(
    column: $table.rangesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get enabledStrategiesJson => $composableBuilder(
    column: $table.enabledStrategiesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetsEnumerated => $composableBuilder(
    column: $table.targetsEnumerated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetsAttempted => $composableBuilder(
    column: $table.targetsAttempted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get responsesReceived => $composableBuilder(
    column: $table.responsesReceived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get classifiedCount => $composableBuilder(
    column: $table.classifiedCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unknownCount => $composableBuilder(
    column: $table.unknownCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get failureCount => $composableBuilder(
    column: $table.failureCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get diagnosticSummary => $composableBuilder(
    column: $table.diagnosticSummary,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiscoveryScansTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiscoveryScansTable> {
  $$DiscoveryScansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get rangesJson => $composableBuilder(
    column: $table.rangesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get enabledStrategiesJson => $composableBuilder(
    column: $table.enabledStrategiesJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get targetsEnumerated => $composableBuilder(
    column: $table.targetsEnumerated,
    builder: (column) => column,
  );

  GeneratedColumn<int> get targetsAttempted => $composableBuilder(
    column: $table.targetsAttempted,
    builder: (column) => column,
  );

  GeneratedColumn<int> get responsesReceived => $composableBuilder(
    column: $table.responsesReceived,
    builder: (column) => column,
  );

  GeneratedColumn<int> get classifiedCount => $composableBuilder(
    column: $table.classifiedCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unknownCount => $composableBuilder(
    column: $table.unknownCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get failureCount => $composableBuilder(
    column: $table.failureCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get diagnosticSummary => $composableBuilder(
    column: $table.diagnosticSummary,
    builder: (column) => column,
  );
}

class $$DiscoveryScansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiscoveryScansTable,
          DiscoveryScanData,
          $$DiscoveryScansTableFilterComposer,
          $$DiscoveryScansTableOrderingComposer,
          $$DiscoveryScansTableAnnotationComposer,
          $$DiscoveryScansTableCreateCompanionBuilder,
          $$DiscoveryScansTableUpdateCompanionBuilder,
          (
            DiscoveryScanData,
            BaseReferences<
              _$AppDatabase,
              $DiscoveryScansTable,
              DiscoveryScanData
            >,
          ),
          DiscoveryScanData,
          PrefetchHooks Function()
        > {
  $$DiscoveryScansTableTableManager(
    _$AppDatabase db,
    $DiscoveryScansTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiscoveryScansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiscoveryScansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiscoveryScansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> rangesJson = const Value.absent(),
                Value<String> enabledStrategiesJson = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> targetsEnumerated = const Value.absent(),
                Value<int> targetsAttempted = const Value.absent(),
                Value<int> responsesReceived = const Value.absent(),
                Value<int> classifiedCount = const Value.absent(),
                Value<int> unknownCount = const Value.absent(),
                Value<int> failureCount = const Value.absent(),
                Value<String?> diagnosticSummary = const Value.absent(),
              }) => DiscoveryScansCompanion(
                id: id,
                status: status,
                rangesJson: rangesJson,
                enabledStrategiesJson: enabledStrategiesJson,
                startedAt: startedAt,
                completedAt: completedAt,
                targetsEnumerated: targetsEnumerated,
                targetsAttempted: targetsAttempted,
                responsesReceived: responsesReceived,
                classifiedCount: classifiedCount,
                unknownCount: unknownCount,
                failureCount: failureCount,
                diagnosticSummary: diagnosticSummary,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> status = const Value.absent(),
                required String rangesJson,
                Value<String> enabledStrategiesJson = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> targetsEnumerated = const Value.absent(),
                Value<int> targetsAttempted = const Value.absent(),
                Value<int> responsesReceived = const Value.absent(),
                Value<int> classifiedCount = const Value.absent(),
                Value<int> unknownCount = const Value.absent(),
                Value<int> failureCount = const Value.absent(),
                Value<String?> diagnosticSummary = const Value.absent(),
              }) => DiscoveryScansCompanion.insert(
                id: id,
                status: status,
                rangesJson: rangesJson,
                enabledStrategiesJson: enabledStrategiesJson,
                startedAt: startedAt,
                completedAt: completedAt,
                targetsEnumerated: targetsEnumerated,
                targetsAttempted: targetsAttempted,
                responsesReceived: responsesReceived,
                classifiedCount: classifiedCount,
                unknownCount: unknownCount,
                failureCount: failureCount,
                diagnosticSummary: diagnosticSummary,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DiscoveryScansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiscoveryScansTable,
      DiscoveryScanData,
      $$DiscoveryScansTableFilterComposer,
      $$DiscoveryScansTableOrderingComposer,
      $$DiscoveryScansTableAnnotationComposer,
      $$DiscoveryScansTableCreateCompanionBuilder,
      $$DiscoveryScansTableUpdateCompanionBuilder,
      (
        DiscoveryScanData,
        BaseReferences<_$AppDatabase, $DiscoveryScansTable, DiscoveryScanData>,
      ),
      DiscoveryScanData,
      PrefetchHooks Function()
    >;
typedef $$DiscoveredDevicesTableCreateCompanionBuilder =
    DiscoveredDevicesCompanion Function({
      Value<int> id,
      required int scanId,
      required String ip,
      Value<String?> mac,
      Value<String?> hostname,
      Value<String?> vendor,
      Value<String?> observedServicesJson,
      Value<String> predictedCategory,
      Value<String> confidence,
      Value<String?> evidenceJson,
      Value<String> classificationMethod,
      Value<DateTime> firstSeen,
      Value<DateTime> lastSeen,
      Value<DateTime?> lastSuccessfulProbe,
      Value<String?> lastProbeFailureReason,
      Value<String> reviewState,
      Value<String?> adminConfirmedCategory,
      Value<int?> adminReviewerId,
      Value<DateTime?> adminReviewTimestamp,
      Value<int?> associatedDeviceId,
    });
typedef $$DiscoveredDevicesTableUpdateCompanionBuilder =
    DiscoveredDevicesCompanion Function({
      Value<int> id,
      Value<int> scanId,
      Value<String> ip,
      Value<String?> mac,
      Value<String?> hostname,
      Value<String?> vendor,
      Value<String?> observedServicesJson,
      Value<String> predictedCategory,
      Value<String> confidence,
      Value<String?> evidenceJson,
      Value<String> classificationMethod,
      Value<DateTime> firstSeen,
      Value<DateTime> lastSeen,
      Value<DateTime?> lastSuccessfulProbe,
      Value<String?> lastProbeFailureReason,
      Value<String> reviewState,
      Value<String?> adminConfirmedCategory,
      Value<int?> adminReviewerId,
      Value<DateTime?> adminReviewTimestamp,
      Value<int?> associatedDeviceId,
    });

class $$DiscoveredDevicesTableFilterComposer
    extends Composer<_$AppDatabase, $DiscoveredDevicesTable> {
  $$DiscoveredDevicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scanId => $composableBuilder(
    column: $table.scanId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ip => $composableBuilder(
    column: $table.ip,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mac => $composableBuilder(
    column: $table.mac,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hostname => $composableBuilder(
    column: $table.hostname,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vendor => $composableBuilder(
    column: $table.vendor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get observedServicesJson => $composableBuilder(
    column: $table.observedServicesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get predictedCategory => $composableBuilder(
    column: $table.predictedCategory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get evidenceJson => $composableBuilder(
    column: $table.evidenceJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get classificationMethod => $composableBuilder(
    column: $table.classificationMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get firstSeen => $composableBuilder(
    column: $table.firstSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSuccessfulProbe => $composableBuilder(
    column: $table.lastSuccessfulProbe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastProbeFailureReason => $composableBuilder(
    column: $table.lastProbeFailureReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reviewState => $composableBuilder(
    column: $table.reviewState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get adminConfirmedCategory => $composableBuilder(
    column: $table.adminConfirmedCategory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get adminReviewerId => $composableBuilder(
    column: $table.adminReviewerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get adminReviewTimestamp => $composableBuilder(
    column: $table.adminReviewTimestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get associatedDeviceId => $composableBuilder(
    column: $table.associatedDeviceId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DiscoveredDevicesTableOrderingComposer
    extends Composer<_$AppDatabase, $DiscoveredDevicesTable> {
  $$DiscoveredDevicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scanId => $composableBuilder(
    column: $table.scanId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ip => $composableBuilder(
    column: $table.ip,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mac => $composableBuilder(
    column: $table.mac,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hostname => $composableBuilder(
    column: $table.hostname,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vendor => $composableBuilder(
    column: $table.vendor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get observedServicesJson => $composableBuilder(
    column: $table.observedServicesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get predictedCategory => $composableBuilder(
    column: $table.predictedCategory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get evidenceJson => $composableBuilder(
    column: $table.evidenceJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get classificationMethod => $composableBuilder(
    column: $table.classificationMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firstSeen => $composableBuilder(
    column: $table.firstSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSuccessfulProbe => $composableBuilder(
    column: $table.lastSuccessfulProbe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastProbeFailureReason => $composableBuilder(
    column: $table.lastProbeFailureReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reviewState => $composableBuilder(
    column: $table.reviewState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get adminConfirmedCategory => $composableBuilder(
    column: $table.adminConfirmedCategory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get adminReviewerId => $composableBuilder(
    column: $table.adminReviewerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get adminReviewTimestamp => $composableBuilder(
    column: $table.adminReviewTimestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get associatedDeviceId => $composableBuilder(
    column: $table.associatedDeviceId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiscoveredDevicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiscoveredDevicesTable> {
  $$DiscoveredDevicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get scanId =>
      $composableBuilder(column: $table.scanId, builder: (column) => column);

  GeneratedColumn<String> get ip =>
      $composableBuilder(column: $table.ip, builder: (column) => column);

  GeneratedColumn<String> get mac =>
      $composableBuilder(column: $table.mac, builder: (column) => column);

  GeneratedColumn<String> get hostname =>
      $composableBuilder(column: $table.hostname, builder: (column) => column);

  GeneratedColumn<String> get vendor =>
      $composableBuilder(column: $table.vendor, builder: (column) => column);

  GeneratedColumn<String> get observedServicesJson => $composableBuilder(
    column: $table.observedServicesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get predictedCategory => $composableBuilder(
    column: $table.predictedCategory,
    builder: (column) => column,
  );

  GeneratedColumn<String> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get evidenceJson => $composableBuilder(
    column: $table.evidenceJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get classificationMethod => $composableBuilder(
    column: $table.classificationMethod,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get firstSeen =>
      $composableBuilder(column: $table.firstSeen, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSuccessfulProbe => $composableBuilder(
    column: $table.lastSuccessfulProbe,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastProbeFailureReason => $composableBuilder(
    column: $table.lastProbeFailureReason,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reviewState => $composableBuilder(
    column: $table.reviewState,
    builder: (column) => column,
  );

  GeneratedColumn<String> get adminConfirmedCategory => $composableBuilder(
    column: $table.adminConfirmedCategory,
    builder: (column) => column,
  );

  GeneratedColumn<int> get adminReviewerId => $composableBuilder(
    column: $table.adminReviewerId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get adminReviewTimestamp => $composableBuilder(
    column: $table.adminReviewTimestamp,
    builder: (column) => column,
  );

  GeneratedColumn<int> get associatedDeviceId => $composableBuilder(
    column: $table.associatedDeviceId,
    builder: (column) => column,
  );
}

class $$DiscoveredDevicesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiscoveredDevicesTable,
          DiscoveredDeviceData,
          $$DiscoveredDevicesTableFilterComposer,
          $$DiscoveredDevicesTableOrderingComposer,
          $$DiscoveredDevicesTableAnnotationComposer,
          $$DiscoveredDevicesTableCreateCompanionBuilder,
          $$DiscoveredDevicesTableUpdateCompanionBuilder,
          (
            DiscoveredDeviceData,
            BaseReferences<
              _$AppDatabase,
              $DiscoveredDevicesTable,
              DiscoveredDeviceData
            >,
          ),
          DiscoveredDeviceData,
          PrefetchHooks Function()
        > {
  $$DiscoveredDevicesTableTableManager(
    _$AppDatabase db,
    $DiscoveredDevicesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiscoveredDevicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiscoveredDevicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiscoveredDevicesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> scanId = const Value.absent(),
                Value<String> ip = const Value.absent(),
                Value<String?> mac = const Value.absent(),
                Value<String?> hostname = const Value.absent(),
                Value<String?> vendor = const Value.absent(),
                Value<String?> observedServicesJson = const Value.absent(),
                Value<String> predictedCategory = const Value.absent(),
                Value<String> confidence = const Value.absent(),
                Value<String?> evidenceJson = const Value.absent(),
                Value<String> classificationMethod = const Value.absent(),
                Value<DateTime> firstSeen = const Value.absent(),
                Value<DateTime> lastSeen = const Value.absent(),
                Value<DateTime?> lastSuccessfulProbe = const Value.absent(),
                Value<String?> lastProbeFailureReason = const Value.absent(),
                Value<String> reviewState = const Value.absent(),
                Value<String?> adminConfirmedCategory = const Value.absent(),
                Value<int?> adminReviewerId = const Value.absent(),
                Value<DateTime?> adminReviewTimestamp = const Value.absent(),
                Value<int?> associatedDeviceId = const Value.absent(),
              }) => DiscoveredDevicesCompanion(
                id: id,
                scanId: scanId,
                ip: ip,
                mac: mac,
                hostname: hostname,
                vendor: vendor,
                observedServicesJson: observedServicesJson,
                predictedCategory: predictedCategory,
                confidence: confidence,
                evidenceJson: evidenceJson,
                classificationMethod: classificationMethod,
                firstSeen: firstSeen,
                lastSeen: lastSeen,
                lastSuccessfulProbe: lastSuccessfulProbe,
                lastProbeFailureReason: lastProbeFailureReason,
                reviewState: reviewState,
                adminConfirmedCategory: adminConfirmedCategory,
                adminReviewerId: adminReviewerId,
                adminReviewTimestamp: adminReviewTimestamp,
                associatedDeviceId: associatedDeviceId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int scanId,
                required String ip,
                Value<String?> mac = const Value.absent(),
                Value<String?> hostname = const Value.absent(),
                Value<String?> vendor = const Value.absent(),
                Value<String?> observedServicesJson = const Value.absent(),
                Value<String> predictedCategory = const Value.absent(),
                Value<String> confidence = const Value.absent(),
                Value<String?> evidenceJson = const Value.absent(),
                Value<String> classificationMethod = const Value.absent(),
                Value<DateTime> firstSeen = const Value.absent(),
                Value<DateTime> lastSeen = const Value.absent(),
                Value<DateTime?> lastSuccessfulProbe = const Value.absent(),
                Value<String?> lastProbeFailureReason = const Value.absent(),
                Value<String> reviewState = const Value.absent(),
                Value<String?> adminConfirmedCategory = const Value.absent(),
                Value<int?> adminReviewerId = const Value.absent(),
                Value<DateTime?> adminReviewTimestamp = const Value.absent(),
                Value<int?> associatedDeviceId = const Value.absent(),
              }) => DiscoveredDevicesCompanion.insert(
                id: id,
                scanId: scanId,
                ip: ip,
                mac: mac,
                hostname: hostname,
                vendor: vendor,
                observedServicesJson: observedServicesJson,
                predictedCategory: predictedCategory,
                confidence: confidence,
                evidenceJson: evidenceJson,
                classificationMethod: classificationMethod,
                firstSeen: firstSeen,
                lastSeen: lastSeen,
                lastSuccessfulProbe: lastSuccessfulProbe,
                lastProbeFailureReason: lastProbeFailureReason,
                reviewState: reviewState,
                adminConfirmedCategory: adminConfirmedCategory,
                adminReviewerId: adminReviewerId,
                adminReviewTimestamp: adminReviewTimestamp,
                associatedDeviceId: associatedDeviceId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DiscoveredDevicesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiscoveredDevicesTable,
      DiscoveredDeviceData,
      $$DiscoveredDevicesTableFilterComposer,
      $$DiscoveredDevicesTableOrderingComposer,
      $$DiscoveredDevicesTableAnnotationComposer,
      $$DiscoveredDevicesTableCreateCompanionBuilder,
      $$DiscoveredDevicesTableUpdateCompanionBuilder,
      (
        DiscoveredDeviceData,
        BaseReferences<
          _$AppDatabase,
          $DiscoveredDevicesTable,
          DiscoveredDeviceData
        >,
      ),
      DiscoveredDeviceData,
      PrefetchHooks Function()
    >;
typedef $$DiscoveryEvidencesTableCreateCompanionBuilder =
    DiscoveryEvidencesCompanion Function({
      Value<int> id,
      required int discoveredDeviceId,
      required String strategyName,
      required String probeTarget,
      required bool isSuccess,
      required String details,
      Value<DateTime> timestamp,
    });
typedef $$DiscoveryEvidencesTableUpdateCompanionBuilder =
    DiscoveryEvidencesCompanion Function({
      Value<int> id,
      Value<int> discoveredDeviceId,
      Value<String> strategyName,
      Value<String> probeTarget,
      Value<bool> isSuccess,
      Value<String> details,
      Value<DateTime> timestamp,
    });

class $$DiscoveryEvidencesTableFilterComposer
    extends Composer<_$AppDatabase, $DiscoveryEvidencesTable> {
  $$DiscoveryEvidencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discoveredDeviceId => $composableBuilder(
    column: $table.discoveredDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get strategyName => $composableBuilder(
    column: $table.strategyName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get probeTarget => $composableBuilder(
    column: $table.probeTarget,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSuccess => $composableBuilder(
    column: $table.isSuccess,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DiscoveryEvidencesTableOrderingComposer
    extends Composer<_$AppDatabase, $DiscoveryEvidencesTable> {
  $$DiscoveryEvidencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discoveredDeviceId => $composableBuilder(
    column: $table.discoveredDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get strategyName => $composableBuilder(
    column: $table.strategyName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get probeTarget => $composableBuilder(
    column: $table.probeTarget,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSuccess => $composableBuilder(
    column: $table.isSuccess,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DiscoveryEvidencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiscoveryEvidencesTable> {
  $$DiscoveryEvidencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get discoveredDeviceId => $composableBuilder(
    column: $table.discoveredDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get strategyName => $composableBuilder(
    column: $table.strategyName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get probeTarget => $composableBuilder(
    column: $table.probeTarget,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isSuccess =>
      $composableBuilder(column: $table.isSuccess, builder: (column) => column);

  GeneratedColumn<String> get details =>
      $composableBuilder(column: $table.details, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$DiscoveryEvidencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DiscoveryEvidencesTable,
          DiscoveryEvidenceData,
          $$DiscoveryEvidencesTableFilterComposer,
          $$DiscoveryEvidencesTableOrderingComposer,
          $$DiscoveryEvidencesTableAnnotationComposer,
          $$DiscoveryEvidencesTableCreateCompanionBuilder,
          $$DiscoveryEvidencesTableUpdateCompanionBuilder,
          (
            DiscoveryEvidenceData,
            BaseReferences<
              _$AppDatabase,
              $DiscoveryEvidencesTable,
              DiscoveryEvidenceData
            >,
          ),
          DiscoveryEvidenceData,
          PrefetchHooks Function()
        > {
  $$DiscoveryEvidencesTableTableManager(
    _$AppDatabase db,
    $DiscoveryEvidencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiscoveryEvidencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiscoveryEvidencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiscoveryEvidencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> discoveredDeviceId = const Value.absent(),
                Value<String> strategyName = const Value.absent(),
                Value<String> probeTarget = const Value.absent(),
                Value<bool> isSuccess = const Value.absent(),
                Value<String> details = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
              }) => DiscoveryEvidencesCompanion(
                id: id,
                discoveredDeviceId: discoveredDeviceId,
                strategyName: strategyName,
                probeTarget: probeTarget,
                isSuccess: isSuccess,
                details: details,
                timestamp: timestamp,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int discoveredDeviceId,
                required String strategyName,
                required String probeTarget,
                required bool isSuccess,
                required String details,
                Value<DateTime> timestamp = const Value.absent(),
              }) => DiscoveryEvidencesCompanion.insert(
                id: id,
                discoveredDeviceId: discoveredDeviceId,
                strategyName: strategyName,
                probeTarget: probeTarget,
                isSuccess: isSuccess,
                details: details,
                timestamp: timestamp,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DiscoveryEvidencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DiscoveryEvidencesTable,
      DiscoveryEvidenceData,
      $$DiscoveryEvidencesTableFilterComposer,
      $$DiscoveryEvidencesTableOrderingComposer,
      $$DiscoveryEvidencesTableAnnotationComposer,
      $$DiscoveryEvidencesTableCreateCompanionBuilder,
      $$DiscoveryEvidencesTableUpdateCompanionBuilder,
      (
        DiscoveryEvidenceData,
        BaseReferences<
          _$AppDatabase,
          $DiscoveryEvidencesTable,
          DiscoveryEvidenceData
        >,
      ),
      DiscoveryEvidenceData,
      PrefetchHooks Function()
    >;
typedef $$InfrastructureDevicesTableCreateCompanionBuilder =
    InfrastructureDevicesCompanion Function({
      Value<int> id,
      required String name,
      required String ip,
      Value<String?> mac,
      Value<String> role,
      Value<String?> location,
      Value<bool> isCriticalInfrastructure,
      Value<bool> requiresAdminConfirmation,
      Value<String> linkedSubnetsJson,
      Value<String?> controllerUrl,
      Value<String> siteName,
      Value<bool> isEnabled,
      Value<bool> isReadOnly,
      Value<DateTime> createdAt,
      Value<DateTime?> updatedAt,
    });
typedef $$InfrastructureDevicesTableUpdateCompanionBuilder =
    InfrastructureDevicesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> ip,
      Value<String?> mac,
      Value<String> role,
      Value<String?> location,
      Value<bool> isCriticalInfrastructure,
      Value<bool> requiresAdminConfirmation,
      Value<String> linkedSubnetsJson,
      Value<String?> controllerUrl,
      Value<String> siteName,
      Value<bool> isEnabled,
      Value<bool> isReadOnly,
      Value<DateTime> createdAt,
      Value<DateTime?> updatedAt,
    });

class $$InfrastructureDevicesTableFilterComposer
    extends Composer<_$AppDatabase, $InfrastructureDevicesTable> {
  $$InfrastructureDevicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ip => $composableBuilder(
    column: $table.ip,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mac => $composableBuilder(
    column: $table.mac,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCriticalInfrastructure => $composableBuilder(
    column: $table.isCriticalInfrastructure,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get requiresAdminConfirmation => $composableBuilder(
    column: $table.requiresAdminConfirmation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkedSubnetsJson => $composableBuilder(
    column: $table.linkedSubnetsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get controllerUrl => $composableBuilder(
    column: $table.controllerUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get siteName => $composableBuilder(
    column: $table.siteName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isReadOnly => $composableBuilder(
    column: $table.isReadOnly,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InfrastructureDevicesTableOrderingComposer
    extends Composer<_$AppDatabase, $InfrastructureDevicesTable> {
  $$InfrastructureDevicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ip => $composableBuilder(
    column: $table.ip,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mac => $composableBuilder(
    column: $table.mac,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCriticalInfrastructure => $composableBuilder(
    column: $table.isCriticalInfrastructure,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get requiresAdminConfirmation => $composableBuilder(
    column: $table.requiresAdminConfirmation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkedSubnetsJson => $composableBuilder(
    column: $table.linkedSubnetsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get controllerUrl => $composableBuilder(
    column: $table.controllerUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get siteName => $composableBuilder(
    column: $table.siteName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isReadOnly => $composableBuilder(
    column: $table.isReadOnly,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InfrastructureDevicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $InfrastructureDevicesTable> {
  $$InfrastructureDevicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get ip =>
      $composableBuilder(column: $table.ip, builder: (column) => column);

  GeneratedColumn<String> get mac =>
      $composableBuilder(column: $table.mac, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<bool> get isCriticalInfrastructure => $composableBuilder(
    column: $table.isCriticalInfrastructure,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get requiresAdminConfirmation => $composableBuilder(
    column: $table.requiresAdminConfirmation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get linkedSubnetsJson => $composableBuilder(
    column: $table.linkedSubnetsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get controllerUrl => $composableBuilder(
    column: $table.controllerUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get siteName =>
      $composableBuilder(column: $table.siteName, builder: (column) => column);

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<bool> get isReadOnly => $composableBuilder(
    column: $table.isReadOnly,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$InfrastructureDevicesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InfrastructureDevicesTable,
          InfrastructureDeviceData,
          $$InfrastructureDevicesTableFilterComposer,
          $$InfrastructureDevicesTableOrderingComposer,
          $$InfrastructureDevicesTableAnnotationComposer,
          $$InfrastructureDevicesTableCreateCompanionBuilder,
          $$InfrastructureDevicesTableUpdateCompanionBuilder,
          (
            InfrastructureDeviceData,
            BaseReferences<
              _$AppDatabase,
              $InfrastructureDevicesTable,
              InfrastructureDeviceData
            >,
          ),
          InfrastructureDeviceData,
          PrefetchHooks Function()
        > {
  $$InfrastructureDevicesTableTableManager(
    _$AppDatabase db,
    $InfrastructureDevicesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InfrastructureDevicesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$InfrastructureDevicesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$InfrastructureDevicesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> ip = const Value.absent(),
                Value<String?> mac = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<bool> isCriticalInfrastructure = const Value.absent(),
                Value<bool> requiresAdminConfirmation = const Value.absent(),
                Value<String> linkedSubnetsJson = const Value.absent(),
                Value<String?> controllerUrl = const Value.absent(),
                Value<String> siteName = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<bool> isReadOnly = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
              }) => InfrastructureDevicesCompanion(
                id: id,
                name: name,
                ip: ip,
                mac: mac,
                role: role,
                location: location,
                isCriticalInfrastructure: isCriticalInfrastructure,
                requiresAdminConfirmation: requiresAdminConfirmation,
                linkedSubnetsJson: linkedSubnetsJson,
                controllerUrl: controllerUrl,
                siteName: siteName,
                isEnabled: isEnabled,
                isReadOnly: isReadOnly,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String ip,
                Value<String?> mac = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<bool> isCriticalInfrastructure = const Value.absent(),
                Value<bool> requiresAdminConfirmation = const Value.absent(),
                Value<String> linkedSubnetsJson = const Value.absent(),
                Value<String?> controllerUrl = const Value.absent(),
                Value<String> siteName = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<bool> isReadOnly = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
              }) => InfrastructureDevicesCompanion.insert(
                id: id,
                name: name,
                ip: ip,
                mac: mac,
                role: role,
                location: location,
                isCriticalInfrastructure: isCriticalInfrastructure,
                requiresAdminConfirmation: requiresAdminConfirmation,
                linkedSubnetsJson: linkedSubnetsJson,
                controllerUrl: controllerUrl,
                siteName: siteName,
                isEnabled: isEnabled,
                isReadOnly: isReadOnly,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InfrastructureDevicesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InfrastructureDevicesTable,
      InfrastructureDeviceData,
      $$InfrastructureDevicesTableFilterComposer,
      $$InfrastructureDevicesTableOrderingComposer,
      $$InfrastructureDevicesTableAnnotationComposer,
      $$InfrastructureDevicesTableCreateCompanionBuilder,
      $$InfrastructureDevicesTableUpdateCompanionBuilder,
      (
        InfrastructureDeviceData,
        BaseReferences<
          _$AppDatabase,
          $InfrastructureDevicesTable,
          InfrastructureDeviceData
        >,
      ),
      InfrastructureDeviceData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$AuditLogsTableTableManager get auditLogs =>
      $$AuditLogsTableTableManager(_db, _db.auditLogs);
  $$LocationsTableTableManager get locations =>
      $$LocationsTableTableManager(_db, _db.locations);
  $$DevicesTableTableManager get devices =>
      $$DevicesTableTableManager(_db, _db.devices);
  $$CheckResultsTableTableManager get checkResults =>
      $$CheckResultsTableTableManager(_db, _db.checkResults);
  $$DeviceStatusesTableTableManager get deviceStatuses =>
      $$DeviceStatusesTableTableManager(_db, _db.deviceStatuses);
  $$IncidentsTableTableManager get incidents =>
      $$IncidentsTableTableManager(_db, _db.incidents);
  $$DiscoveryConfigurationsTableTableManager get discoveryConfigurations =>
      $$DiscoveryConfigurationsTableTableManager(
        _db,
        _db.discoveryConfigurations,
      );
  $$DiscoveryScansTableTableManager get discoveryScans =>
      $$DiscoveryScansTableTableManager(_db, _db.discoveryScans);
  $$DiscoveredDevicesTableTableManager get discoveredDevices =>
      $$DiscoveredDevicesTableTableManager(_db, _db.discoveredDevices);
  $$DiscoveryEvidencesTableTableManager get discoveryEvidences =>
      $$DiscoveryEvidencesTableTableManager(_db, _db.discoveryEvidences);
  $$InfrastructureDevicesTableTableManager get infrastructureDevices =>
      $$InfrastructureDevicesTableTableManager(_db, _db.infrastructureDevices);
}
