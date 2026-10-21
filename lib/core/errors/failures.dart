import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  List<Object?> get props => [message, code];
}

class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message, {super.code});
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.code});
}

class PingFailure extends Failure {
  const PingFailure(super.message, {super.code});
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.code});
}

class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.code});
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([
    super.message = 'Unauthorized operation',
    String? code,
  ]) : super(code: code);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message, {super.code});
}

class ImportFailure extends Failure {
  final List<String> details;

  const ImportFailure(super.message, {this.details = const [], super.code});

  @override
  List<Object?> get props => [message, code, details];
}
