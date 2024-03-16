import 'package:chest/util/config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:chest/util/auxiliar.dart';
import 'package:chest/util/helpers/user.dart';

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
    } catch (e) {
      if (Config.development) debugPrint(e.toString());
      return null;
    }
  }

  static Future<void> signOutGoogle() async {
    await FirebaseAuth.instance.signOut();
    if (_googleSignIn != null) {
      await _googleSignIn!.signOut();
    }
    Auxiliar.userCHEST = UserCHEST.guest();
  }
}
