import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:chest/util/auxiliar.dart';
import 'package:chest/util/helpers/user.dart';

class AuthFirebase {
  // https://firebase.google.com/docs/auth/flutter/federated-auth#google
  // ud8a20DtdaNt7LYKA2Nx26HFPR32
  static Future<bool?> signInGoogle() async {
    try {
      UserCredential userCredential;
      if (kIsWeb) {
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        userCredential =
            await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
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
      debugPrint(e.toString());
      return null;
    }
  }

  static Future<void> signOutGoogle() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    Auxiliar.userCHEST = UserCHEST.guest();
  }
}
