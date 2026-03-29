import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../logger/app_logger.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _isGoogleSignInInitialized = false;

  Future<void> _ensureGoogleSignInInitialized() async {
    if (!_isGoogleSignInInitialized) {
      await _googleSignIn.initialize(
        serverClientId:
            '704860501882-ngcfh111vcg3asf3glm933fp24enp0jl.apps.googleusercontent.com',
      );
      _isGoogleSignInInitialized = true;
    }
  }

  // Get currently signed-in user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      await _ensureGoogleSignInInitialized();

      // Trigger the authentication flow
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate(
        scopeHint: ['email', 'profile'],
      );

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final GoogleSignInClientAuthorization? googleAuthz = await googleUser
          .authorizationClient
          .authorizationForScopes(['email', 'profile']);

      // Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuthz?.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      AppLogger.info(
        'User signed in with Google: ${userCredential.user?.email}',
      );
      return userCredential;
    } catch (e) {
      AppLogger.error('Error signing in with Google', e);
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      AppLogger.info('User signed out successfully.');
    } catch (e) {
      AppLogger.error('Error signing out', e);
    }
  }
}
