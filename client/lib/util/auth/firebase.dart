import 'package:chest/util/config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:chest/util/auxiliar.dart';
import 'package:chest/util/helpers/user.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthFirebase {
  static final GoogleSignIn? _googleSignIn = kIsWeb ? null : GoogleSignIn();
  // https://firebase.google.com/docs/auth/flutter/federated-auth#google
  static Future<bool?> signInGoogle() async {
    try {
      UserCredential userCredential;
      if (kIsWeb) {
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        userCredential =
            await FirebaseAuth.instance.signInWithPopup(googleProvider);
        // await FirebaseAuth.instance.signInWithRedirect(googleProvider);
        // userCredential = await FirebaseAuth.instance.getRedirectResult();
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();
        final GoogleSignInAuthentication? googleAuth =
            await googleUser?.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth?.accessToken,
          idToken: googleAuth?.idToken,
        );
        userCredential =
            await FirebaseAuth.instance.signInWithCredential(credential);
      }
      return userCredential.additionalUserInfo!.isNewUser;
    } catch (e, stackTrace) {
      if (Config.development) {
        debugPrint(e.toString());
      } else {
        await FirebaseCrashlytics.instance.recordError(e, stackTrace);
      }
      return null;
    }
  }

  static Future<void> _signOutGoogle() async {
    await FirebaseAuth.instance.signOut();
    if (_googleSignIn != null) {
      await _googleSignIn!.signOut();
    }
    Auxiliar.userCHEST = UserCHEST.guest();
  }

  static Future<bool?> signInApple() async {
    if (!kIsWeb) {
      AppleAuthProvider appleAuthProvider = AppleAuthProvider();
      UserCredential? userCredential;
      try {
        userCredential =
            await FirebaseAuth.instance.signInWithProvider(appleAuthProvider);
      } catch (err) {
        userCredential = null;
      }
      if (userCredential != null && userCredential.additionalUserInfo != null) {
        return userCredential.additionalUserInfo!.isNewUser;
      }
    }
    return null;
  }

  static Future<void> _signOutApple() async {
    await FirebaseAuth.instance.signOut();
    Auxiliar.userCHEST = UserCHEST.guest();
  }

  static Future<void> signOut(AuthProviders authProvider) async {
    // Si tenemos más métodos de autorización hay que pasarlo a un switch
    if (authProvider == AuthProviders.apple) {
      _signOutApple();
    } else {
      _signOutGoogle();
    }
  }
}

enum AuthProviders { google, apple }
