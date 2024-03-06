import 'dart:convert';

import 'package:chest/main.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:mustache_template/mustache.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:chest/util/auxiliar.dart';
import 'package:chest/util/helpers/queries.dart';
import 'package:chest/util/helpers/user.dart';
import 'package:chest/util/config.dart';

class LoginUsers extends StatefulWidget {
  const LoginUsers({super.key});

  @override
  State<LoginUsers> createState() => _LoginUsers();
}

class _LoginUsers extends State<LoginUsers> {
  late GlobalKey<FormState> _keyLoginForm;
  late TextEditingController _textController;
  late String _email, _pass;
  late bool _enableBt;

  @override
  void initState() {
    _keyLoginForm = GlobalKey<FormState>();
    _textController = TextEditingController();
    _enableBt = true;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> lstForm = widgetLstForm();
    final List<Widget> lstButtons = widgetLstButtons();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(AppLocalizations.of(context)!.iniciarSes),
          ),
          Form(
            key: _keyLoginForm,
            child: SliverPadding(
              padding: const EdgeInsets.only(
                top: 50,
                left: 10,
                right: 10,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: Center(
                        child: Container(
                            constraints: const BoxConstraints(
                                maxWidth: Auxiliar.maxWidth),
                            child: lstForm.elementAt(index)),
                      ),
                    );
                  },
                  childCount: lstForm.length,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                ((context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Center(
                      child: Container(
                          constraints: const BoxConstraints(
                              maxWidth: Auxiliar.maxWidth, minWidth: 250),
                          child: lstButtons.elementAt(index)),
                    ),
                  );
                }),
                childCount: lstButtons.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> widgetLstForm() {
    return [
      TextFormField(
        controller: _textController,
        onChanged: (String input) {
          setState(() {
            if (input.trim().isNotEmpty) {
              Auxiliar.checkAccents(input, _textController);
            }
          });
        },
        maxLines: 1,
        decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: AppLocalizations.of(context)!.textLogin,
            hintText: AppLocalizations.of(context)!.textLogin,
            hintMaxLines: 1,
            hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
        textCapitalization: TextCapitalization.none,
        keyboardType: TextInputType.emailAddress,
        enabled: _enableBt,
        validator: (v) {
          if (v == null ||
                  v.trim().isEmpty // || !EmailValidator.validate(v.trim())
              ) {
            return AppLocalizations.of(context)!.textLoginError;
          }
          _email = v.trim();
          return null;
        },
        textInputAction: TextInputAction.next,
      ),
      TextFormField(
        obscureText: true,
        maxLines: 1,
        decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: AppLocalizations.of(context)!.passLogin,
            hintText: AppLocalizations.of(context)!.passLogin,
            hintMaxLines: 1,
            hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
        textCapitalization: TextCapitalization.none,
        enabled: _enableBt,
        validator: (v) {
          if (v == null || v.trim().isEmpty || v.trim().length < 6) {
            return AppLocalizations.of(context)!.passLogin;
          }
          _pass = v.trim();
          return null;
        },
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (v) async {
          if (_enableBt && _keyLoginForm.currentState!.validate()) {
            await login();
          }
        },
      ),
    ];
  }

  List<Widget> widgetLstButtons() {
    return [
      FilledButton(
          onPressed: !_enableBt
              ? null
              : () async {
                  if (_keyLoginForm.currentState!.validate()) {
                    await login();
                  }
                },
          child: _enableBt
              ? Text(AppLocalizations.of(context)!.iniciarSes)
              : const CircularProgressIndicator()),
      // TextButton(
      //     onPressed: !_enableBt
      //         ? null
      //         : () {
      //             Navigator.push(
      //                 context,
      //                 MaterialPageRoute<void>(
      //                   builder: (BuildContext context) => const ForgotPass(),
      //                   fullscreenDialog: false,
      //                 ));
      //           },
      //     child: Text(AppLocalizations.of(context)!.olvidePass)),
      // TextButton(
      //     onPressed: !_enableBt
      //         ? null
      //         : () {
      //             Navigator.push(
      //                 context,
      //                 MaterialPageRoute<void>(
      //                   builder: (BuildContext context) => const NewUser(),
      //                   fullscreenDialog: false,
      //                 ));
      //           },
      //     child: Text(AppLocalizations.of(context)!.nuevoUsuario)),
    ];
  }

  Future<void> login() async {
    try {
      setState(() => _enableBt = false);
      ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
      ThemeData td = Theme.of(context);
      AppLocalizations? appLoca = AppLocalizations.of(context);

      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: _email, password: _pass);

      if (FirebaseAuth.instance.currentUser!.emailVerified) {
        http.get(Queries().signIn(), headers: {
          'Authorization': Template('Bearer {{{token}}}').renderString(
              {'token': await FirebaseAuth.instance.currentUser!.getIdToken()})
        }).then((data) async {
          switch (data.statusCode) {
            case 200:
              Map<String, dynamic> j = json.decode(data.body);
              setState(() => _enableBt = true);
              // TODO
              // Auxiliar.userCHEST = UserCHEST(j["id"], j["rol"]);
              // if (j.keys.contains("firstname") &&
              //     j["firstname"] != null &&
              //     j["firstname"].trim().isNotEmpty) {
              //   Auxiliar.userCHEST.firstname = j["firstname"];
              // }
              // if (j.keys.contains("lastname") &&
              //     j["lastname"] != null &&
              //     j["lastname"].trim().isNotEmpty) {
              //   Auxiliar.userCHEST.lastname = j["lastname"];
              // }
              if (!Config.development) {
                await FirebaseAnalytics.instance
                    .logLogin(loginMethod: "emailPass");
              }
              if (context.mounted) {
                smState.clearSnackBars();
                smState.showSnackBar(SnackBar(
                  duration: const Duration(seconds: 1),
                  content: Text(appLoca!.hola),
                ));
                Navigator.pop(context);
              }
              break;
            default:
              setState(() => _enableBt = true);
              smState.showSnackBar(SnackBar(
                backgroundColor: td.colorScheme.error,
                content: Text(
                  "Error",
                  style: td.textTheme.bodyMedium!
                      .copyWith(color: td.colorScheme.onError),
                ),
              ));
          }
        }).onError((error, stackTrace) {
          setState(() => _enableBt = true);
          ThemeData td = Theme.of(context);
          smState.showSnackBar(SnackBar(
            backgroundColor: td.colorScheme.error,
            content: Text(
              "Error",
              style: td.textTheme.bodyMedium!
                  .copyWith(color: td.colorScheme.onError),
            ),
          ));
        });
      } else {
        setState(() => _enableBt = true);
        smState.showSnackBar(SnackBar(
          backgroundColor: td.colorScheme.error,
          content: Text(
            appLoca!.errorEmailSinVerificar,
            style: td.textTheme.bodyMedium!
                .copyWith(color: td.colorScheme.onError),
          ),
        ));
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _enableBt = true);
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        ThemeData td = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: td.colorScheme.error,
          content: Text(
            AppLocalizations.of(context)!.errorUserPass,
            style: td.textTheme.bodyMedium!
                .copyWith(color: td.colorScheme.onError),
          ),
        ));
      }
    } catch (e) {
      setState(() => _enableBt = true);
      ThemeData td = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: td.colorScheme.error,
        content: Text(
          AppLocalizations.of(context)!.errorEmailSinVerificar,
          style:
              td.textTheme.bodyMedium!.copyWith(color: td.colorScheme.onError),
        ),
      ));
    }
  }
}

// class ForgotPass extends StatefulWidget {
//   const ForgotPass({super.key});

//   @override
//   State<ForgotPass> createState() => _ForgotPass();
// }

// class _ForgotPass extends State<ForgotPass> {
//   late GlobalKey<FormState> _keyPass;
//   late String _email;
//   late TextEditingController _textEditingControllerMail;
//   late bool _enableBt;
//   @override
//   void initState() {
//     _keyPass = GlobalKey<FormState>();
//     _textEditingControllerMail = TextEditingController();
//     _enableBt = true;
//     super.initState();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final List<Widget> formFormPassList = formFormPass();
//     final List<Widget> buttonForgotPassList = buttonForgotPass();
//     return Scaffold(
//       body: CustomScrollView(
//         slivers: [
//           SliverAppBar.large(
//             title: Text(AppLocalizations.of(context)!.olvidePass),
//           ),
//           Form(
//             key: _keyPass,
//             child: SliverPadding(
//               padding: const EdgeInsets.only(top: 50, left: 10, right: 10),
//               sliver: SliverList(
//                 delegate: SliverChildBuilderDelegate(
//                     (context, index) => Padding(
//                           padding: const EdgeInsets.only(bottom: 10),
//                           child: Center(
//                             child: Container(
//                                 constraints: const BoxConstraints(
//                                     maxWidth: Auxiliar.maxWidth),
//                                 child: formFormPassList.elementAt(index)),
//                           ),
//                         ),
//                     childCount: formFormPassList.length),
//               ),
//             ),
//           ),
//           SliverPadding(
//             padding: const EdgeInsets.only(bottom: 10, left: 10, right: 10),
//             sliver: SliverList(
//               delegate: SliverChildBuilderDelegate(
//                 (context, index) => Center(
//                   child: Container(
//                     constraints:
//                         const BoxConstraints(maxWidth: Auxiliar.maxWidth),
//                     child: Align(
//                       alignment: Alignment.bottomRight,
//                       child: buttonForgotPassList.elementAt(index),
//                     ),
//                   ),
//                 ),
//                 childCount: buttonForgotPassList.length,
//               ),
//             ),
//           )
//         ],
//       ),
//     );
//   }

//   List<Widget> formFormPass() {
//     return [
//       TextFormField(
//         controller: _textEditingControllerMail,
//         onChanged: (String input) {
//           setState(() {
//             if (input.trim().isNotEmpty) {
//               Auxiliar.checkAccents(input, _textEditingControllerMail);
//             }
//           });
//         },
//         autovalidateMode: AutovalidateMode.disabled,
//         maxLines: 1,
//         decoration: InputDecoration(
//             border: const OutlineInputBorder(),
//             labelText: Template('{{{txt}}} *')
//                 .renderString({"txt": AppLocalizations.of(context)!.textLogin}),
//             hintText: AppLocalizations.of(context)!.textLogin,
//             hintMaxLines: 1,
//             hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
//         textCapitalization: TextCapitalization.none,
//         keyboardType: TextInputType.emailAddress,
//         textInputAction: TextInputAction.done,
//         enabled: _enableBt,
//         validator: (v) {
//           if (v == null ||
//                   v.trim().isEmpty // || !EmailValidator.validate(v.trim())
//               ) {
//             return AppLocalizations.of(context)!.textLoginError;
//           }
//           _email = v.trim();
//           return null;
//         },
//         onFieldSubmitted: (v) async {
//           if (_enableBt && _keyPass.currentState!.validate()) {
//             forgotPass();
//           }
//         },
//       ),
//     ];
//   }

//   List<Widget> buttonForgotPass() {
//     return [
//       FilledButton(
//         onPressed: !_enableBt
//             ? null
//             : () async {
//                 if (_keyPass.currentState!.validate()) {
//                   forgotPass();
//                 }
//               },
//         child: Text(AppLocalizations.of(context)!.restablecerPass),
//       ),
//     ];
//   }

//   void forgotPass() async {
//     AppLocalizations? appLoca = AppLocalizations.of(context);
//     ThemeData td = Theme.of(context);
//     ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
//     setState(() => _enableBt = false);
//     try {
//       await FirebaseAuth.instance.sendPasswordResetEmail(email: _email).then(
//         (value) {
//           setState(() {
//             _enableBt = true;
//           });
//           Navigator.pop(context);
//           smState.showSnackBar(
//             SnackBar(
//               content: Text(
//                 appLoca!.passRestablecida,
//               ),
//             ),
//           );
//         },
//       );
//     } on FirebaseAuthException catch (e) {
//       if (e.code == 'user-not-found') {
//         Navigator.pop(context);
//         smState.showSnackBar(
//           SnackBar(
//             content: Text(
//               appLoca!.passRestablecida,
//             ),
//           ),
//         );
//       } else {
//         setState(() => _enableBt = true);
//         smState.showSnackBar(
//           SnackBar(
//             backgroundColor: td.colorScheme.error,
//             content: Text(
//               "Error",
//               style: td.textTheme.bodyMedium!.copyWith(
//                 color: td.colorScheme.onError,
//               ),
//             ),
//           ),
//         );
//       }
//     } catch (error) {
//       setState(() => _enableBt = true);
//       smState.showSnackBar(
//         SnackBar(
//           backgroundColor: td.colorScheme.error,
//           content: Text(
//             "Error",
//             style: td.textTheme.bodyMedium!.copyWith(
//               color: td.colorScheme.onError,
//             ),
//           ),
//         ),
//       );
//     }
//   }
// }

class NewUser extends StatefulWidget {
  const NewUser({super.key});

  @override
  State<NewUser> createState() => _NewUser();
}

class _NewUser extends State<NewUser> {
  late GlobalKey<FormState> _keyNewUser;
  late bool _enableBt,
      _boolTeacher,
      _polPri,
      _entiendoLOD,
      _entiendoAliasPublico;
  late String _alias, _comment, _codeTeacher, _confTeacherLOD, _confAliasLOD;

  @override
  void initState() {
    super.initState();
    _keyNewUser = GlobalKey<FormState>();
    _enableBt = true;
    _alias = '';
    _comment = '';
    _codeTeacher = '';
    _confTeacherLOD = '';
    _confAliasLOD = '';
    _boolTeacher = false;
    // aceptan la política de privacidad antes de llegar a esta pantalla
    _polPri = true;
    _entiendoLOD = false;
    _entiendoAliasPublico = false;
  }

  @override
  Widget build(BuildContext context) {
    double margenLateral =
        Auxiliar.getLateralMargin(MediaQuery.of(context).size.width);
    List<Widget> formNewUserLst = _formNewUser();
    List<Widget> btNewUserLst = _btNewUser();
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          title: Text(AppLocalizations.of(context)!.nuevoUsuario,
              overflow: TextOverflow.ellipsis, maxLines: 1),
          pinned: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.only(top: 20),
          sliver: SliverSafeArea(
            bottom: false,
            minimum: EdgeInsets.symmetric(horizontal: margenLateral),
            sliver: Form(
              key: _keyNewUser,
              child: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: Center(
                      child: Container(
                        constraints:
                            const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                        child: formNewUserLst.elementAt(index),
                      ),
                    ),
                  ),
                  childCount: formNewUserLst.length,
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(top: 20),
          sliver: SliverSafeArea(
            minimum: EdgeInsets.all(margenLateral),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Container(
                  constraints:
                      const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                  child: Wrap(
                    direction: Axis.horizontal,
                    alignment: WrapAlignment.center,
                    runAlignment: WrapAlignment.center,
                    spacing: margenLateral,
                    runSpacing: margenLateral,
                    children: btNewUserLst,
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  List<Widget> _formNewUser() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    return [
      TextFormField(
        onChanged: (String input) {
          // De esta forma si se destruye el widget ya lo tendría almacenado
          setState(() => _alias = input.trim());
        },
        maxLines: 1,
        decoration: inputDecoration(
            '${appLoca.alias}${_boolTeacher ? '*' : ''}',
            helperText: _boolTeacher ? appLoca.requerido : null),
        textCapitalization: TextCapitalization.none,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.next,
        enabled: _enableBt,
        autovalidateMode: _boolTeacher
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        validator: (v) => _boolTeacher
            ? (v == null || v.trim().isEmpty)
                ? appLoca.aliasError
                : null
            : null,
        initialValue: _alias,
      ),
      SwitchListTile.adaptive(
        value: _boolTeacher,
        onChanged: (value) => setState(() => _boolTeacher = value),
        title: Text(appLoca.quieroAnotar),
      ),
      Visibility(
        visible: _boolTeacher,
        child: TextFormField(
          onChanged: (String input) {
            _codeTeacher = input.trim();
          },
          maxLines: 1,
          decoration: inputDecoration(
            '${appLoca.codigoProporcionado}*',
            helperText: appLoca.requerido,
          ),
          textCapitalization: TextCapitalization.none,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
          enabled: _enableBt,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (v) => (_boolTeacher && (v == null || v.trim().isEmpty))
              ? appLoca.codigoProporcionadoError
              : null,
          initialValue: _codeTeacher,
        ),
      ),
      Visibility(
        visible: _boolTeacher,
        child: TextFormField(
          onChanged: (String input) {
            // De esta forma si se destruye el widget ya lo tendría almacenado
            _comment = input.trim();
          },
          decoration: inputDecoration(appLoca.descripcion,
              hintText: appLoca.descripcionHint),
          textCapitalization: TextCapitalization.sentences,
          keyboardType: TextInputType.text,
          enabled: _enableBt,
          textInputAction: TextInputAction.next,
          initialValue: _comment,
        ),
      ),
      Visibility(
        visible: _boolTeacher,
        child: CheckboxListTile.adaptive(
          value: _entiendoLOD,
          onChanged: (value) {
            if (value != null) {
              setState(() => _entiendoLOD = value);
              _confTeacherLOD = DateTime.now().toUtc().toString();
            }
          },
          title: Text(appLoca.entiendoLOD),
        ),
      ),
      CheckboxListTile.adaptive(
        value: _entiendoAliasPublico,
        onChanged: (value) {
          if (value != null) {
            setState(() => _entiendoAliasPublico = value);
            _confAliasLOD = DateTime.now().toUtc().toString();
          }
        },
        title: Text(appLoca.entiendoAliasPublico),
        enabled: _boolTeacher || _alias.isNotEmpty,
      ),
      // CheckboxListTile.adaptive(
      //   value: _polPri,
      //   onChanged: (value) {
      //     if (value != null) setState(() => _polPri = value);
      //   },
      //   title: Text(appLoca.aceptoPolPri),
      //   enabled: _boolTeacher || _alias.isNotEmpty,
      // ),
    ];
  }

  InputDecoration inputDecoration(
    String labelText, {
    String? hintText,
    String? helperText,
  }) {
    return InputDecoration(
      border: const OutlineInputBorder(),
      labelText: labelText,
      hintText: hintText ?? labelText,
      helperText: helperText,
      hintStyle: Theme.of(context)
          .textTheme
          .bodyLarge!
          .copyWith(overflow: TextOverflow.ellipsis),
    );
  }

  List<Widget> _btNewUser() {
    ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
    TextStyle bodyMedium = Theme.of(context).textTheme.bodyMedium!;
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    return [
      TextButton(
        onPressed: () async {
          http.get(Queries().signIn(), headers: {
            'Authorization': Template('Bearer {{{token}}}').renderString({
              'token': await FirebaseAuth.instance.currentUser!.getIdToken()
            })
          }).then((response) async {
            switch (response.statusCode) {
              case 200:
                Map<String, dynamic> data = json.decode(response.body);
                Auxiliar.userCHEST = UserCHEST(data);
                if (Auxiliar.userCHEST.alias != null) {
                  smState.clearSnackBars();
                  smState.showSnackBar(SnackBar(
                      content:
                          Text('${appLoca.hola} ${Auxiliar.userCHEST.alias}')));
                }
                Auxiliar.allowNewUser = false;
                if (!Config.development) {
                  FirebaseAnalytics.instance
                      .logLogin(loginMethod: "Google")
                      .then((a) {
                    GoRouter.of(context).go('/map');
                  });
                } else {
                  GoRouter.of(context).go('/map');
                }
                break;
              default:
                FirebaseAuth.instance.signOut();
                smState.clearSnackBars();
                smState.showSnackBar(SnackBar(
                    backgroundColor: colorScheme.error,
                    content: Text(
                        'Error in GET. Status code: ${response.statusCode}',
                        style:
                            bodyMedium.copyWith(color: colorScheme.onError))));
            }
          });
        },
        child: Text(_alias.isNotEmpty || _boolTeacher
            ? appLoca.posponer
            : appLoca.omitir),
      ),
      Visibility(
        visible: _alias.isNotEmpty || _boolTeacher,
        child: FilledButton(
          onPressed: _polPri &&
                  (_alias.isNotEmpty ? _entiendoAliasPublico : true) &&
                  (_boolTeacher ? _entiendoLOD : true)
              ? () async {
                  if (_keyNewUser.currentState!.validate()) {
                    Map<String, dynamic> obj = {};
                    if (_alias.trim().isNotEmpty && _entiendoAliasPublico) {
                      obj['alias'] = _alias.trim();
                      obj['confAliasLOD'] = _confAliasLOD;
                    }
                    if (_boolTeacher && _entiendoAliasPublico) {
                      if (_codeTeacher.trim().isNotEmpty) {
                        obj['code'] = _codeTeacher.trim();
                        obj['confTeacherLOD'] = _confTeacherLOD;
                      }
                      if (_comment.trim().isNotEmpty) {
                        obj['comment'] = _comment.trim();
                      }
                    }
                    if (obj.isNotEmpty) {
                      _enableBt = false;
                      try {
                        http
                            .put(Queries().putUser(),
                                headers: {
                                  'content-type': 'application/json',
                                  'Authorization':
                                      Template('Bearer {{{token}}}')
                                          .renderString({
                                    'token': await FirebaseAuth
                                        .instance.currentUser!
                                        .getIdToken()
                                  })
                                },
                                body: json.encode(obj))
                            .then((response) async {
                          switch (response.statusCode) {
                            case 201:
                              // Usuario creado en el servidor.
                              // Pido la info para registrarlo en el cliente
                              http.get(Queries().signIn(), headers: {
                                'Authorization': Template('Bearer {{{token}}}')
                                    .renderString({
                                  'token': await FirebaseAuth
                                      .instance.currentUser!
                                      .getIdToken()
                                })
                              }).then((response) async {
                                switch (response.statusCode) {
                                  case 200:
                                    Map<String, dynamic> data =
                                        json.decode(response.body);
                                    Auxiliar.userCHEST = UserCHEST(data);
                                    _enableBt = true;
                                    Auxiliar.allowNewUser = false;
                                    if (!Config.development) {
                                      FirebaseAnalytics.instance
                                          .logLogin(loginMethod: "Google")
                                          .then((a) {
                                        GoRouter.of(context).go('/map');
                                      });
                                    } else {
                                      GoRouter.of(context).go('/map');
                                    }
                                    break;
                                  default:
                                    _enableBt = true;
                                    FirebaseAuth.instance.signOut();
                                    smState.clearSnackBars();
                                    smState.showSnackBar(SnackBar(
                                        backgroundColor: colorScheme.error,
                                        content: Text(
                                            'Error in GET. Status code: ${response.statusCode}',
                                            style: bodyMedium.copyWith(
                                                color: colorScheme.onError))));
                                }
                              });
                              break;
                            default:
                              _enableBt = true;
                              FirebaseAuth.instance.signOut();
                              smState.clearSnackBars();
                              smState.showSnackBar(SnackBar(
                                  backgroundColor: colorScheme.error,
                                  content: Text(
                                      'Error in PUT. Status code: ${response.statusCode}',
                                      style: bodyMedium.copyWith(
                                          color: colorScheme.onError))));
                          }
                        });
                      } on FirebaseAuthException catch (e) {
                        _enableBt = true;
                        debugPrint(e.toString());
                        smState.clearSnackBars();
                        smState.showSnackBar(SnackBar(
                            backgroundColor: colorScheme.error,
                            content: Text('Error with Firebase Auth.',
                                style: bodyMedium.copyWith(
                                    color: colorScheme.onError))));
                      } catch (e) {
                        _enableBt = true;
                        debugPrint(e.toString());
                        smState.clearSnackBars();
                        smState.showSnackBar(SnackBar(
                            backgroundColor: colorScheme.error,
                            content: Text('Error.',
                                style: bodyMedium.copyWith(
                                    color: colorScheme.onError))));
                      }
                    } else {
                      _enableBt = true;
                      smState.clearSnackBars();
                      smState.showSnackBar(SnackBar(
                          backgroundColor: colorScheme.error,
                          content: Text('The object is empty.',
                              style: bodyMedium.copyWith(
                                  color: colorScheme.onError))));
                    }
                  }
                }
              : null,
          child: Text(appLoca.guardar),
        ),
      ),
    ];
  }
}

// class NewUser extends StatefulWidget {
//   const NewUser({super.key});

//   @override
//   State<NewUser> createState() => _NewUser();
// }

// class _NewUser extends State<NewUser> {
//   late GlobalKey<FormState> _keyNewUser;
//   late String _email, _pass;
//   late String? _firstname, _lastname;
//   late TextEditingController _textEditingControllerMail,
//       _textEditingControllerFirstname,
//       _textEditingControllerLastname;
//   late bool _enableBt, _allowNewUsers;
//   @override
//   void initState() {
//     _keyNewUser = GlobalKey<FormState>();
//     _textEditingControllerMail = TextEditingController();
//     _textEditingControllerFirstname = TextEditingController();
//     _textEditingControllerLastname = TextEditingController();
//     _enableBt = true;
//     _allowNewUsers = false;
//     super.initState();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final List<Widget> formNewUserList = formNewUser();
//     final List<Widget> buttonsNewUserList = buttonsNewUser();
//     return Scaffold(
//       body: CustomScrollView(
//         slivers: [
//           SliverAppBar.large(
//             title: Text(AppLocalizations.of(context)!.nuevoUsuario),
//             pinned: true,
//           ),
//           SliverVisibility(
//             visible: !_allowNewUsers,
//             sliver: SliverPadding(
//               padding: const EdgeInsets.only(top: 50, left: 10, right: 10),
//               sliver: SliverList(
//                 delegate: SliverChildListDelegate([
//                   Center(
//                     child: Container(
//                       constraints:
//                           const BoxConstraints(maxWidth: Auxiliar.maxWidth),
//                       alignment: Alignment.centerRight,
//                       child: SelectableText(
//                         AppLocalizations.of(context)!.registroDesactivado,
//                         style: Theme.of(context)
//                             .textTheme
//                             .bodyMedium!
//                             .copyWith(fontWeight: FontWeight.bold),
//                       ),
//                     ),
//                   ),
//                 ]),
//               ),
//             ),
//           ),
//           SliverPadding(
//             padding: const EdgeInsets.only(top: 50, left: 10, right: 10),
//             sliver: Form(
//               key: _keyNewUser,
//               child: SliverList(
//                 delegate: SliverChildBuilderDelegate(
//                   ((context, index) => Padding(
//                         padding: const EdgeInsets.only(bottom: 10),
//                         child: Center(
//                           child: Container(
//                               constraints: const BoxConstraints(
//                                   maxWidth: Auxiliar.maxWidth),
//                               child: formNewUserList[index]),
//                         ),
//                       )),
//                   childCount: formNewUserList.length,
//                 ),
//               ),
//             ),
//           ),
//           SliverPadding(
//             padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
//             sliver: SliverList(
//               delegate: SliverChildBuilderDelegate(
//                   (context, index) => Center(
//                         child: Container(
//                           constraints:
//                               const BoxConstraints(maxWidth: Auxiliar.maxWidth),
//                           alignment: Alignment.centerRight,
//                           child: buttonsNewUserList.elementAt(index),
//                         ),
//                       ),
//                   childCount: buttonsNewUserList.length),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   List<Widget> formNewUser() {
//     return [
//       TextFormField(
//         controller: _textEditingControllerMail,
//         onChanged: (String input) {
//           setState(() {
//             if (input.trim().isNotEmpty) {
//               Auxiliar.checkAccents(input, _textEditingControllerMail);
//             }
//           });
//         },
//         maxLines: 1,
//         decoration: InputDecoration(
//             border: const OutlineInputBorder(),
//             labelText: Template('{{{txt}}}*')
//                 .renderString({"txt": AppLocalizations.of(context)!.textLogin}),
//             hintText: AppLocalizations.of(context)!.textLogin,
//             hintMaxLines: 1,
//             helperText: AppLocalizations.of(context)!.requerido,
//             hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
//         textCapitalization: TextCapitalization.none,
//         keyboardType: TextInputType.emailAddress,
//         textInputAction: TextInputAction.next,
//         enabled: _allowNewUsers && _enableBt,
//         validator: (v) {
//           if (v == null ||
//                   v.trim().isEmpty // || !EmailValidator.validate(v.trim())
//               ) {
//             return AppLocalizations.of(context)!.textLoginError;
//           }
//           _email = v.trim();
//           return null;
//         },
//       ),
//       TextFormField(
//         obscureText: true,
//         maxLines: 1,
//         decoration: InputDecoration(
//             border: const OutlineInputBorder(),
//             labelText: Template('{{{txt}}}*')
//                 .renderString({"txt": AppLocalizations.of(context)!.passLogin}),
//             hintText: AppLocalizations.of(context)!.passLogin,
//             helperText: AppLocalizations.of(context)!.requerido,
//             hintMaxLines: 1,
//             hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
//         textCapitalization: TextCapitalization.none,
//         keyboardType: TextInputType.visiblePassword,
//         enabled: _allowNewUsers && _enableBt,
//         validator: (v) {
//           if (v == null || v.trim().isEmpty || v.trim().length < 6) {
//             return AppLocalizations.of(context)!.passTamaError;
//           }
//           _pass = v.trim();
//           return null;
//         },
//       ),
//       TextFormField(
//         obscureText: true,
//         maxLines: 1,
//         decoration: InputDecoration(
//             border: const OutlineInputBorder(),
//             labelText: Template('{{{txt}}}*').renderString(
//                 {"txt": AppLocalizations.of(context)!.passLoginAgain}),
//             hintText: AppLocalizations.of(context)!.passLoginAgain,
//             helperText: AppLocalizations.of(context)!.requerido,
//             hintMaxLines: 1,
//             hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
//         textCapitalization: TextCapitalization.none,
//         keyboardType: TextInputType.visiblePassword,
//         enabled: _allowNewUsers && _enableBt,
//         validator: (v) {
//           if (v == null || v.trim().isEmpty || v.trim() != _pass) {
//             return AppLocalizations.of(context)!.passLoginAgainError;
//           }
//           return null;
//         },
//       ),
//       TextFormField(
//         controller: _textEditingControllerFirstname,
//         onChanged: (String input) {
//           setState(() {
//             if (input.trim().isNotEmpty) {
//               Auxiliar.checkAccents(input, _textEditingControllerFirstname);
//             }
//           });
//         },
//         maxLines: 1,
//         decoration: InputDecoration(
//             border: const OutlineInputBorder(),
//             labelText: AppLocalizations.of(context)!.textName,
//             hintText: AppLocalizations.of(context)!.textName,
//             hintMaxLines: 1,
//             hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
//         textCapitalization: TextCapitalization.words,
//         textInputAction: TextInputAction.next,
//         keyboardType: TextInputType.name,
//         enabled: _allowNewUsers && _enableBt,
//         validator: (v) {
//           _firstname = (v != null && v.trim().isNotEmpty) ? v.trim() : null;
//           return null;
//         },
//       ),
//       TextFormField(
//         controller: _textEditingControllerLastname,
//         onChanged: (String input) {
//           setState(() {
//             if (input.trim().isNotEmpty) {
//               Auxiliar.checkAccents(input, _textEditingControllerLastname);
//             }
//           });
//         },
//         maxLines: 1,
//         decoration: InputDecoration(
//             border: const OutlineInputBorder(),
//             labelText: AppLocalizations.of(context)!.surname,
//             hintText: AppLocalizations.of(context)!.surname,
//             hintMaxLines: 1,
//             hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
//         textCapitalization: TextCapitalization.words,
//         keyboardType: TextInputType.name,
//         textInputAction: TextInputAction.done,
//         enabled: _allowNewUsers && _enableBt,
//         validator: (v) {
//           _lastname = (v != null && v.trim().isNotEmpty) ? v.trim() : null;
//           return null;
//         },
//       ),
//     ];
//   }

//   List<Widget> buttonsNewUser() {
//     return [
//       FilledButton(
//         onPressed: _allowNewUsers && _enableBt
//             ? () async {
//                 if (_keyNewUser.currentState!.validate()) {
//                   setState(() => _enableBt = false);
//                   //Intento el registro en Firebase
//                   try {
//                     FirebaseAuth.instance.setLanguageCode(MyApp.currentLang);
//                     await FirebaseAuth.instance.createUserWithEmailAndPassword(
//                       email: _email,
//                       password: _pass,
//                     );
//                     await FirebaseAuth.instance.currentUser!
//                         .sendEmailVerification();
//                     Map<String, dynamic> objSend = {};
//                     objSend["email"] = _email;
//                     if (_firstname != null) {
//                       objSend["firstname"] = _firstname;
//                     }
//                     if (_lastname != null) {
//                       objSend["lastname"] = _lastname;
//                     }
//                     http
//                         .put(Queries().putUser(),
//                             headers: {
//                               'content-type': 'application/json',
//                               'Authorization': Template('Bearer {{{token}}}')
//                                   .renderString({
//                                 'token': await FirebaseAuth
//                                     .instance.currentUser!
//                                     .getIdToken()
//                               })
//                             },
//                             body: json.encode(objSend))
//                         .then((value) async {
//                       ScaffoldMessengerState smState =
//                           ScaffoldMessenger.of(context);
//                       switch (value.statusCode) {
//                         case 201:
//                           FirebaseAuth.instance.signOut();
//                           if (!Config.development) {
//                             await FirebaseAnalytics.instance
//                                 .logSignUp(signUpMethod: "emailPass")
//                                 .then(
//                               (value) {
//                                 smState.clearSnackBars();
//                                 smState.showSnackBar(SnackBar(
//                                     content: Text(AppLocalizations.of(context)!
//                                         .validarCorreo)));
//                                 Navigator.pop(context);
//                               },
//                             ).onError((error, stackTrace) {
//                               debugPrint(error.toString());
//                               smState.clearSnackBars();
//                               smState.showSnackBar(SnackBar(
//                                   content: Text(AppLocalizations.of(context)!
//                                       .validarCorreo)));
//                               Navigator.pop(context);
//                             });
//                           } else {
//                             smState.clearSnackBars();
//                             smState.showSnackBar(SnackBar(
//                                 content: Text(AppLocalizations.of(context)!
//                                     .validarCorreo)));
//                             Navigator.pop(context);
//                           }
//                           break;
//                         default:
//                           setState(() => _enableBt = true);
//                           break;
//                       }
//                     }).onError((error, stackTrace) {
//                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//                           backgroundColor: Colors.red, content: Text("Error")));
//                       setState(() => _enableBt = true);
//                     });
//                   } on FirebaseAuthException catch (e) {
//                     if (e.code == 'weak-password') {
//                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//                           backgroundColor: Colors.red,
//                           content: Text(
//                               AppLocalizations.of(context)!.errorPassDebil)));
//                       setState(() => _enableBt = true);
//                     } else if (e.code == 'email-already-in-use') {
//                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//                           backgroundColor: Colors.red,
//                           content: Text(
//                               AppLocalizations.of(context)!.errorMailEnUso)));
//                       setState(() => _enableBt = true);
//                     }
//                   } catch (e) {
//                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//                         backgroundColor: Colors.red, content: Text("Error")));
//                     setState(() => _enableBt = true);
//                     //print(e);
//                   }
//                 }
//               }
//             : null,
//         child: Text(AppLocalizations.of(context)!.registrarUsuario),
//       ),
//     ];
//   }
// }

// class InfoUser extends StatefulWidget {
//   const InfoUser({super.key});

//   @override
//   State<StatefulWidget> createState() => _InfoUser();
// }

// class _InfoUser extends State<InfoUser> {
//   late bool _enableBt;
//   String? _firstname, _lastname;
//   late GlobalKey<FormState> _thisKey;

//   @override
//   void initState() {
//     _thisKey = GlobalKey<FormState>();
//     _enableBt = true;
//     super.initState();
//   }

//   @override
//   void dispose() {
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (Auxiliar.userCHEST.rol == Rol.guest) {
//       Navigator.pop(context);
//       return const Scaffold();
//     } else {
//       List<Widget> lstForms = lstFormsW();
//       List<Widget> lstInfo = lstInfoW();
//       return Scaffold(
//         body: CustomScrollView(
//           slivers: [
//             SliverPadding(
//               padding: const EdgeInsets.only(bottom: 20),
//               sliver: SliverAppBar(
//                 floating: true,
//                 title: Text(AppLocalizations.of(context)!.infoCuenta),
//               ),
//             ),
//             Form(
//               key: _thisKey,
//               child: SliverPadding(
//                 padding: const EdgeInsets.only(bottom: 15, right: 10, left: 10),
//                 sliver: SliverList(
//                   delegate: SliverChildBuilderDelegate(
//                       (context, index) => Center(
//                             child: Container(
//                               constraints: const BoxConstraints(
//                                   maxWidth: Auxiliar.maxWidth),
//                               child: Padding(
//                                 padding: const EdgeInsets.only(top: 15),
//                                 child: lstForms.elementAt(index),
//                               ),
//                             ),
//                           ),
//                       childCount: lstForms.length),
//                 ),
//               ),
//             ),
//             SliverPadding(
//               padding: const EdgeInsets.only(bottom: 15, right: 10, left: 10),
//               sliver: SliverList(
//                 delegate: SliverChildBuilderDelegate(
//                     (context, index) => Center(
//                           child: Container(
//                             constraints: const BoxConstraints(
//                                 maxWidth: Auxiliar.maxWidth),
//                             child: Align(
//                                 alignment: Alignment.centerLeft,
//                                 child: Padding(
//                                   padding: const EdgeInsets.only(top: 15),
//                                   child: lstInfo.elementAt(index),
//                                 )),
//                           ),
//                         ),
//                     childCount: lstInfo.length),
//               ),
//             ),
//           ],
//         ),
//       );
//     }
//   }

//   List<Widget> lstFormsW() {
//     return [
//       Align(
//         alignment: Alignment.centerLeft,
//         child: Text(
//           AppLocalizations.of(context)!.nombreApellidos,
//           style: Theme.of(context).textTheme.titleLarge,
//         ),
//       ),
//       TextFormField(
//         maxLines: 1,
//         decoration: InputDecoration(
//             border: const OutlineInputBorder(),
//             labelText: AppLocalizations.of(context)!.textName,
//             hintText: AppLocalizations.of(context)!.textName,
//             hintMaxLines: 1,
//             hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
//         textCapitalization: TextCapitalization.words,
//         textInputAction: TextInputAction.next,
//         keyboardType: TextInputType.name,
//         enabled: _enableBt,
//         // TODO
//         // initialValue: Auxiliar.userCHEST.firstname.isEmpty
//         //     ? null
//         //     : Auxiliar.userCHEST.firstname,
//         validator: (v) {
//           _firstname = (v != null && v.trim().isNotEmpty) ? v.trim() : null;
//           return null;
//         },
//       ),
//       TextFormField(
//         maxLines: 1,
//         decoration: InputDecoration(
//             border: const OutlineInputBorder(),
//             labelText: AppLocalizations.of(context)!.surname,
//             hintText: AppLocalizations.of(context)!.surname,
//             hintMaxLines: 1,
//             hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
//         textCapitalization: TextCapitalization.words,
//         keyboardType: TextInputType.name,
//         textInputAction: TextInputAction.next,
//         enabled: _enableBt,
//         // TODO
//         // initialValue: Auxiliar.userCHEST.lastname.isEmpty
//         //     ? null
//         //     : Auxiliar.userCHEST.lastname,
//         validator: (v) {
//           _lastname = (v != null && v.trim().isNotEmpty) ? v.trim() : null;
//           return null;
//         },
//       ),
//       Align(
//         alignment: Alignment.centerRight,
//         child: FilledButton.icon(
//           label: Text(AppLocalizations.of(context)!.guardar),
//           icon: const Icon(Icons.save),
//           onPressed: _enableBt
//               ? () async {
//                   // TODO
//                   // _enableBt = false;
//                   // if (_thisKey.currentState!.validate() &&
//                   //     (((_firstname ?? '') != Auxiliar.userCHEST.firstname) ||
//                   //         ((_lastname ?? '') != Auxiliar.userCHEST.lastname))) {
//                   //   Map<String, String> bodyRequest = {
//                   //     'firstname': _firstname ?? '',
//                   //     'lastname': _lastname ?? ''
//                   //   };
//                   //   if (bodyRequest.isNotEmpty) {
//                   //     http
//                   //         .put(
//                   //       Queries().putUser(),
//                   //       headers: {
//                   //         'Content-Type': 'application/json',
//                   //         'Authorization': Template('Bearer {{{token}}}')
//                   //             .renderString({
//                   //           'token': await FirebaseAuth.instance.currentUser!
//                   //               .getIdToken()
//                   //         }),
//                   //       },
//                   //       body: json.encode(bodyRequest),
//                   //     )
//                   //         .then((response) {
//                   //       ScaffoldMessengerState smState =
//                   //           ScaffoldMessenger.of(context);
//                   //       ThemeData td = Theme.of(context);
//                   //       smState.clearSnackBars();
//                   //       switch (response.statusCode) {
//                   //         case 200:
//                   //           Auxiliar.userCHEST.firstname = _firstname ?? '';
//                   //           Auxiliar.userCHEST.lastname = _lastname ?? '';
//                   //           smState.showSnackBar(SnackBar(
//                   //             content: Text(AppLocalizations.of(context)!
//                   //                 .perfilActualizado),
//                   //           ));
//                   //           break;
//                   //         default:
//                   //           smState.showSnackBar(SnackBar(
//                   //             backgroundColor: td.colorScheme.error,
//                   //             content: const Text("Error"),
//                   //           ));
//                   //       }
//                   //       _enableBt = true;
//                   //     }).onError((error, stackTrace) {
//                   //       debugPrint(error.toString());
//                   //       _enableBt = true;
//                   //     });
//                   //   } else {
//                   //     _enableBt = true;
//                   //   }
//                   // } else {
//                   //   _enableBt = true;
//                   // }
//                 }
//               : null,
//         ),
//       ),
//     ];
//   }

//   List<Widget> lstInfoW() {
//     AppLocalizations? appLoca = AppLocalizations.of(context);
//     ThemeData td = Theme.of(context);
//     return [
//       Text(
//         appLoca!.moreInfoAccount,
//         style: td.textTheme.titleLarge,
//       ),
//       SelectableText(
//         Template('{{{id}}}: {{{userId}}}').renderString(
//             {'id': "ID", 'userId': Auxiliar.userCHEST.id.split("/").last}),
//         style: td.textTheme.bodySmall,
//       ),
//       // TODO
//       // Text(
//       //   Template('{{{rol}}}: {{{userRol}}}').renderString(
//       //       {'rol': appLoca.rol, 'userRol': Auxiliar.userCHEST.rol.name}),
//       //   style: td.textTheme.bodySmall,
//       // )
//     ];
//   }
// }

class InfoUser extends StatefulWidget {
  const InfoUser({super.key});

  @override
  State<StatefulWidget> createState() => _InfoUser();
}

class _InfoUser extends State<InfoUser> {
  @override
  void initState() {
    Auxiliar.allowNewUser = false;
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double lateralMargin = Auxiliar.getLateralMargin(size.width);
    return Scaffold(
        body: CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: Text(AppLocalizations.of(context)!.infoCuenta),
          leading: BackButton(
            onPressed: () async {
              GoRouter.of(context).go('/map');
            },
          ),
        ),
        SliverPadding(
          padding:
              EdgeInsets.symmetric(horizontal: lateralMargin, vertical: 20),
          sliver: _body(lateralMargin),
        ),
        SliverPadding(
          padding:
              EdgeInsets.symmetric(horizontal: lateralMargin, vertical: 20),
          sliver: _buttons(lateralMargin),
        ),
      ],
    ));
  }

  Widget _body(double lateralMargin) {
    AppLocalizations? appLoca = AppLocalizations.of(context);
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    TextStyle titleStyle = Theme.of(context)
        .textTheme
        .titleLarge!
        .copyWith(color: colorScheme.onPrimaryContainer);
    TextStyle bodyStyle = Theme.of(context)
        .textTheme
        .bodyMedium!
        .copyWith(color: colorScheme.onPrimaryContainer);

    List<Widget> lista = [
      Text(
        appLoca!.datosUsuario,
        style: titleStyle,
      ),
      const SizedBox(height: 10),
      Text(
        '\t ID: ${Auxiliar.userCHEST.id}',
        style: bodyStyle,
      ),
      Text(
        '\t ${appLoca.aliasD}: ${Auxiliar.userCHEST.alias ?? appLoca.sinDefinir}',
        style: bodyStyle,
      ),
    ];
    String roles = '\t ${appLoca.rol}:';
    for (Rol r in Auxiliar.userCHEST.rol) {
      roles = '$roles ${r.name}';
    }
    lista.add(Text(
      roles,
      style: bodyStyle,
    ));
    return DecoratedSliver(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: const BorderRadius.all(Radius.circular(25)),
      ),
      sliver: SliverPadding(
        padding: EdgeInsets.all(lateralMargin),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                alignment: Alignment.centerLeft,
                child: lista.elementAt(index),
              ),
            ),
            childCount: lista.length,
          ),
        ),
      ),
    );
  }

  Widget _buttons(double lateralMargin) {
    AppLocalizations? appLoca = AppLocalizations.of(context);

    return SliverToBoxAdapter(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: Auxiliar.maxWidth),
          child: Wrap(
            spacing: lateralMargin,
            runSpacing: lateralMargin,
            runAlignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(onPressed: null, child: Text(appLoca!.borrarUsuario)),
              TextButton(
                onPressed: () {
                  Auxiliar.allowManageUser = true;
                  GoRouter.of(context)
                      .push('/users/${Auxiliar.userCHEST.id}/editUser');
                },
                child: Text(appLoca.editarUsuario),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EditUser extends StatefulWidget {
  const EditUser({super.key});

  @override
  State<EditUser> createState() => _EditUser();
}

class _EditUser extends State<EditUser> {
  late GlobalKey<FormState> _keyEditUser;
  late bool _enableBt,
      _boolTeacher,
      _polPri,
      _entiendoLOD,
      _entiendoAliasPublico,
      _bloqueaEntiendoLOD,
      _bloqueaEntiendoAliasPublico;
  late String _alias, _comment, _codeTeacher, _confTeacherLOD, _confAliasLOD;

  @override
  void initState() {
    super.initState();
    _keyEditUser = GlobalKey<FormState>();
    _enableBt = true;
    _alias = Auxiliar.userCHEST.alias ?? '';
    _comment = Auxiliar.userCHEST.getComment(MyApp.currentLang) != null
        ? Auxiliar.userCHEST.getComment(MyApp.currentLang)!
        : Auxiliar.userCHEST.comment != null
            ? Auxiliar.userCHEST.comment!.first.value
            : '';
    _codeTeacher = '';
    _confTeacherLOD = '';
    _confAliasLOD = '';
    _boolTeacher = Auxiliar.userCHEST.rol.contains(Rol.teacher);
    _polPri = true;
    _entiendoLOD = Auxiliar.userCHEST.rol.contains(Rol.teacher);
    _bloqueaEntiendoLOD = _entiendoLOD;
    _entiendoAliasPublico = _alias.isNotEmpty;
    _bloqueaEntiendoAliasPublico = _entiendoAliasPublico;
  }

  @override
  Widget build(BuildContext context) {
    double margenLateral =
        Auxiliar.getLateralMargin(MediaQuery.of(context).size.width);
    List<Widget> formEditUserLst = _formEditUser();
    List<Widget> btEditUserLst = _btEditUser();
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          title: Text(
            AppLocalizations.of(context)!.editarUsuario,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          pinned: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.only(top: 20),
          sliver: SliverSafeArea(
            bottom: false,
            minimum: EdgeInsets.symmetric(horizontal: margenLateral),
            sliver: Form(
              key: _keyEditUser,
              child: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: Center(
                      child: Container(
                        constraints:
                            const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                        child: formEditUserLst.elementAt(index),
                      ),
                    ),
                  ),
                  childCount: formEditUserLst.length,
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(top: 20),
          sliver: SliverSafeArea(
            minimum: EdgeInsets.all(margenLateral),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: Container(
                  constraints:
                      const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                  child: Wrap(
                    direction: Axis.horizontal,
                    alignment: WrapAlignment.center,
                    runAlignment: WrapAlignment.center,
                    spacing: margenLateral,
                    runSpacing: margenLateral,
                    children: btEditUserLst,
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  List<Widget> _formEditUser() {
    AppLocalizations appLoca = AppLocalizations.of(context)!;
    return [
      TextFormField(
        onChanged: (String input) {
          // De esta forma si se destruye el widget ya lo tendría almacenado
          setState(() => _alias = input.trim());
        },
        maxLines: 1,
        decoration: inputDecoration(
            '${appLoca.alias}${_boolTeacher ? '*' : ''}',
            helperText: _boolTeacher ? appLoca.requerido : null),
        textCapitalization: TextCapitalization.none,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.next,
        enabled: _enableBt,
        autovalidateMode: _boolTeacher
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        validator: (v) => _boolTeacher
            ? (v == null || v.trim().isEmpty)
                ? appLoca.aliasError
                : null
            : null,
        initialValue: _alias,
      ),
      SwitchListTile.adaptive(
        value: _boolTeacher,
        onChanged: Auxiliar.userCHEST.rol.contains(Rol.teacher)
            ? null
            : (value) => setState(() => _boolTeacher = value),
        title: Text(appLoca.quieroAnotar),
      ),
      Visibility(
        visible: _boolTeacher,
        child: TextFormField(
          onChanged: (String input) {
            _codeTeacher = input.trim();
          },
          maxLines: 1,
          decoration: inputDecoration(
            '${appLoca.codigoProporcionado}*',
            helperText: appLoca.requerido,
          ),
          textCapitalization: TextCapitalization.none,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
          enabled: _enableBt,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (v) => _bloqueaEntiendoLOD
              ? null
              : (_boolTeacher && (v == null || v.trim().isEmpty))
                  ? appLoca.codigoProporcionadoError
                  : null,
          initialValue: _codeTeacher,
          readOnly: _bloqueaEntiendoLOD,
        ),
      ),
      Visibility(
        visible: _boolTeacher,
        child: TextFormField(
          onChanged: (String input) {
            // De esta forma si se destruye el widget ya lo tendría almacenado
            _comment = input.trim();
          },
          decoration: inputDecoration(appLoca.descripcion,
              hintText: appLoca.descripcionHint),
          textCapitalization: TextCapitalization.sentences,
          keyboardType: TextInputType.text,
          enabled: _enableBt,
          textInputAction: TextInputAction.next,
          initialValue: _comment,
        ),
      ),
      Visibility(
        visible: _boolTeacher,
        child: CheckboxListTile.adaptive(
          value: _entiendoLOD,
          onChanged: _bloqueaEntiendoLOD
              ? null
              : (value) {
                  if (value != null) {
                    setState(() => _entiendoLOD = value);
                    _confTeacherLOD = DateTime.now().toUtc().toString();
                  }
                },
          title: Text(appLoca.entiendoLOD),
        ),
      ),
      CheckboxListTile.adaptive(
        value: _entiendoAliasPublico,
        onChanged: _bloqueaEntiendoAliasPublico
            ? null
            : (value) {
                if (value != null) {
                  setState(() => _entiendoAliasPublico = value);
                  _confAliasLOD = DateTime.now().toUtc().toString();
                }
              },
        title: Text(appLoca.entiendoAliasPublico),
        enabled: _boolTeacher || _alias.isNotEmpty,
      ),
    ];
  }

  InputDecoration inputDecoration(
    String labelText, {
    String? hintText,
    String? helperText,
  }) {
    return InputDecoration(
      border: const OutlineInputBorder(),
      labelText: labelText,
      hintText: hintText ?? labelText,
      helperText: helperText,
      hintStyle: Theme.of(context)
          .textTheme
          .bodyLarge!
          .copyWith(overflow: TextOverflow.ellipsis),
    );
  }

  List<Widget> _btEditUser() {
    ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
    TextStyle bodyMedium = Theme.of(context).textTheme.bodyMedium!;
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    AppLocalizations appLoca = AppLocalizations.of(context)!;

    return [
      TextButton(
        onPressed: () async {
          Auxiliar.allowManageUser = false;
          GoRouter.of(context).pop();
        },
        child: Text(_alias.isNotEmpty || _boolTeacher
            ? appLoca.posponer
            : appLoca.omitir),
      ),
      Visibility(
        visible: _alias.isNotEmpty || _boolTeacher,
        child: FilledButton(
          onPressed: _polPri &&
                  (_alias.isNotEmpty ? _entiendoAliasPublico : true) &&
                  (_boolTeacher ? _entiendoLOD : true)
              ? () async {
                  if (_keyEditUser.currentState!.validate()) {
                    Map<String, dynamic> obj = {};
                    if (_alias.trim() != Auxiliar.userCHEST.alias &&
                        _entiendoAliasPublico) {
                      obj['alias'] = _alias.trim();
                      obj['confAliasLOD'] = _confAliasLOD.isEmpty
                          ? DateTime.now().toUtc().toString()
                          : _confAliasLOD;
                    }
                    if (_boolTeacher && _entiendoAliasPublico) {
                      if (!Auxiliar.userCHEST.rol.contains(Rol.teacher) &&
                          _codeTeacher.trim().isNotEmpty) {
                        obj['code'] = _codeTeacher.trim();
                        obj['confTeacherLOD'] = _confTeacherLOD.isNotEmpty
                            ? _confTeacherLOD
                            : DateTime.now().toUtc().toString();
                      }
                      String c = Auxiliar.userCHEST
                                  .getComment(MyApp.currentLang) !=
                              null
                          ? Auxiliar.userCHEST.getComment(MyApp.currentLang)!
                          : Auxiliar.userCHEST.comment != null
                              ? Auxiliar.userCHEST.comment!.first.value
                              : '';
                      if (_comment.trim() != c) {
                        obj['comment'] = _comment.trim();
                      }
                    }
                    if (obj.isNotEmpty) {
                      _enableBt = false;
                      try {
                        http
                            .put(Queries().putUser(),
                                headers: {
                                  'content-type': 'application/json',
                                  'Authorization':
                                      Template('Bearer {{{token}}}')
                                          .renderString({
                                    'token': await FirebaseAuth
                                        .instance.currentUser!
                                        .getIdToken()
                                  })
                                },
                                body: json.encode(obj))
                            .then((response) async {
                          switch (response.statusCode) {
                            case 200:
                            case 204:
                              // Usuario creado en el servidor.
                              // Pido la info para registrarlo en el cliente
                              http.get(Queries().signIn(), headers: {
                                'Authorization': Template('Bearer {{{token}}}')
                                    .renderString({
                                  'token': await FirebaseAuth
                                      .instance.currentUser!
                                      .getIdToken()
                                })
                              }).then((response) async {
                                switch (response.statusCode) {
                                  case 200:
                                    _enableBt = true;
                                    Map<String, dynamic> data =
                                        json.decode(response.body);
                                    Auxiliar.userCHEST = UserCHEST(data);
                                    Auxiliar.allowManageUser = false;
                                    if (!Config.development) {
                                      FirebaseAnalytics.instance
                                          .logEvent(name: 'EditUser')
                                          .then((a) {
                                        GoRouter.of(context).go('/map');
                                      });
                                    } else {
                                      GoRouter.of(context).go('/map');
                                    }
                                    break;
                                  default:
                                    _enableBt = true;
                                    FirebaseAuth.instance.signOut();
                                    smState.clearSnackBars();
                                    smState.showSnackBar(SnackBar(
                                        backgroundColor: colorScheme.error,
                                        content: Text(
                                            'Error in GET. Status code: ${response.statusCode}',
                                            style: bodyMedium.copyWith(
                                                color: colorScheme.onError))));
                                    GoRouter.of(context).go('/map');
                                }
                              });
                              break;
                            default:
                              _enableBt = true;

                              FirebaseAuth.instance.signOut();
                              smState.clearSnackBars();
                              smState.showSnackBar(SnackBar(
                                  backgroundColor: colorScheme.error,
                                  content: Text(
                                      'Error in PUT. Status code: ${response.statusCode}',
                                      style: bodyMedium.copyWith(
                                          color: colorScheme.onError))));
                              GoRouter.of(context).go('/map');
                          }
                        });
                      } on FirebaseAuthException catch (e) {
                        _enableBt = true;

                        debugPrint(e.toString());
                        smState.clearSnackBars();
                        smState.showSnackBar(SnackBar(
                            backgroundColor: colorScheme.error,
                            content: Text('Error with Firebase Auth.',
                                style: bodyMedium.copyWith(
                                    color: colorScheme.onError))));
                      } catch (e) {
                        _enableBt = true;

                        debugPrint(e.toString());
                        smState.clearSnackBars();
                        smState.showSnackBar(SnackBar(
                            backgroundColor: colorScheme.error,
                            content: Text('Error.',
                                style: bodyMedium.copyWith(
                                    color: colorScheme.onError))));
                      }
                    } else {
                      _enableBt = true;
                      smState.clearSnackBars();
                      smState.showSnackBar(SnackBar(
                          backgroundColor: colorScheme.error,
                          content: Text('The object is empty.',
                              style: bodyMedium.copyWith(
                                  color: colorScheme.onError))));
                    }
                  }
                }
              : null,
          child: Text(appLoca.guardar),
        ),
      ),
    ];
  }
}
