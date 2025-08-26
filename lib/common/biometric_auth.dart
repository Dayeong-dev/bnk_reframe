import 'package:local_auth/local_auth.dart';

class BiometricAuth {
  static final _auth = LocalAuthentication();

  static Future<bool> isSupportedAndEnrolled() async {
    final supported = await _auth.isDeviceSupported();
    final canCheck = await _auth.canCheckBiometrics;
    final types = await _auth.getAvailableBiometrics();
    return supported && canCheck && types.isNotEmpty;
  }

  static Future<bool> authenticate(String reason) async {
    return await _auth.authenticate(
      localizedReason: reason,
      options: const AuthenticationOptions(
        biometricOnly: false,
        stickyAuth: true,
        useErrorDialogs: true,
      ),
    );
  }

  static Future<bool> authenticateOnlyBio(String reason) async {
    return await _auth.authenticate(
      localizedReason: reason,
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
        useErrorDialogs: true,
      ),
    );
  }
}