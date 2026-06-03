import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream del estado de autenticación
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Usuario actual
  User? get currentUser => _auth.currentUser;

  // ── Sign In con email y contraseña ──────────────────────────────────────────
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return AuthResult.success(credential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapFirebaseError(e));
    } catch (_) {
      return AuthResult.failure('Ocurrió un error inesperado.');
    }
  }

  // ── Registro con email y contraseña ────────────────────────────────────────
  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return AuthResult.success(credential.user);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapFirebaseError(e));
    } catch (_) {
      return AuthResult.failure('Ocurrió un error inesperado.');
    }
  }

  // ── Restablecer contraseña ─────────────────────────────────────────────────
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapFirebaseError(e));
    } catch (_) {
      return AuthResult.failure('No se pudo enviar el correo.');
    }
  }

  // ── Cerrar sesión ──────────────────────────────────────────────────────────
  Future<void> signOut() => _auth.signOut();

  // ── Traducción de errores de Firebase ─────────────────────────────────────
  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No existe una cuenta con ese correo.';
      case 'wrong-password':
        return 'Contraseña incorrecta.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo.';
      case 'invalid-email':
        return 'El correo electrónico no es válido.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada.';
      case 'too-many-requests':
        return 'Demasiados intentos. Inténtalo más tarde.';
      case 'network-request-failed':
        return 'Sin conexión a internet.';
      case 'invalid-credential':
        return 'Credenciales inválidas. Verifica tu correo y contraseña.';
      default:
        return e.message ?? 'Error de autenticación.';
    }
  }
}

// ── Resultado de operación de auth ────────────────────────────────────────────
class AuthResult {
  final User? user;
  final String? error;
  bool get isSuccess => error == null;

  const AuthResult._({this.user, this.error});

  factory AuthResult.success(User? user) => AuthResult._(user: user);
  factory AuthResult.failure(String error) => AuthResult._(error: error);
}
