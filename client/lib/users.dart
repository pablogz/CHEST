import 'dart:convert';

import 'package:chest/util/config.dart';
import 'package:chest/main.dart';
import 'package:email_validator/email_validator.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mustache_template/mustache.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:chest/util/auxiliar.dart';
import 'package:chest/util/helpers/queries.dart';
import 'package:chest/util/helpers/user.dart';

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
              v.trim().isEmpty ||
              !EmailValidator.validate(v.trim())) {
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
      TextButton(
          onPressed: !_enableBt
              ? null
              : () {
                  Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => const ForgotPass(),
                        fullscreenDialog: false,
                      ));
                },
          child: Text(AppLocalizations.of(context)!.olvidePass)),
      TextButton(
          onPressed: !_enableBt
              ? null
              : () {
                  Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => const NewUser(),
                        fullscreenDialog: false,
                      ));
                },
          child: Text(AppLocalizations.of(context)!.nuevoUsuario)),
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
              Auxiliar.userCHEST = UserCHEST(j["id"], j["rol"]);
              if (j.keys.contains("firstname") &&
                  j["firstname"] != null &&
                  j["firstname"].trim().isNotEmpty) {
                Auxiliar.userCHEST.firstname = j["firstname"];
              }
              if (j.keys.contains("lastname") &&
                  j["lastname"] != null &&
                  j["lastname"].trim().isNotEmpty) {
                Auxiliar.userCHEST.lastname = j["lastname"];
              }
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

class ForgotPass extends StatefulWidget {
  const ForgotPass({super.key});

  @override
  State<ForgotPass> createState() => _ForgotPass();
}

class _ForgotPass extends State<ForgotPass> {
  late GlobalKey<FormState> _keyPass;
  late String _email;
  late TextEditingController _textEditingControllerMail;
  late bool _enableBt;
  @override
  void initState() {
    _keyPass = GlobalKey<FormState>();
    _textEditingControllerMail = TextEditingController();
    _enableBt = true;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> formFormPassList = formFormPass();
    final List<Widget> buttonForgotPassList = buttonForgotPass();
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(AppLocalizations.of(context)!.olvidePass),
          ),
          Form(
            key: _keyPass,
            child: SliverPadding(
              padding: const EdgeInsets.only(top: 50, left: 10, right: 10),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Center(
                            child: Container(
                                constraints: const BoxConstraints(
                                    maxWidth: Auxiliar.maxWidth),
                                child: formFormPassList.elementAt(index)),
                          ),
                        ),
                    childCount: formFormPassList.length),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 10, left: 10, right: 10),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Center(
                  child: Container(
                    constraints:
                        const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: buttonForgotPassList.elementAt(index),
                    ),
                  ),
                ),
                childCount: buttonForgotPassList.length,
              ),
            ),
          )
        ],
      ),
    );
  }

  List<Widget> formFormPass() {
    return [
      TextFormField(
        controller: _textEditingControllerMail,
        onChanged: (String input) {
          setState(() {
            if (input.trim().isNotEmpty) {
              Auxiliar.checkAccents(input, _textEditingControllerMail);
            }
          });
        },
        autovalidateMode: AutovalidateMode.disabled,
        maxLines: 1,
        decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: Template('{{{txt}}} *')
                .renderString({"txt": AppLocalizations.of(context)!.textLogin}),
            hintText: AppLocalizations.of(context)!.textLogin,
            hintMaxLines: 1,
            hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
        textCapitalization: TextCapitalization.none,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        enabled: _enableBt,
        validator: (v) {
          if (v == null ||
              v.trim().isEmpty ||
              !EmailValidator.validate(v.trim())) {
            return AppLocalizations.of(context)!.textLoginError;
          }
          _email = v.trim();
          return null;
        },
        onFieldSubmitted: (v) async {
          if (_enableBt && _keyPass.currentState!.validate()) {
            forgotPass();
          }
        },
      ),
    ];
  }

  List<Widget> buttonForgotPass() {
    return [
      FilledButton(
        onPressed: !_enableBt
            ? null
            : () async {
                if (_keyPass.currentState!.validate()) {
                  forgotPass();
                }
              },
        child: Text(AppLocalizations.of(context)!.restablecerPass),
      ),
    ];
  }

  void forgotPass() async {
    AppLocalizations? appLoca = AppLocalizations.of(context);
    ThemeData td = Theme.of(context);
    ScaffoldMessengerState smState = ScaffoldMessenger.of(context);
    setState(() => _enableBt = false);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _email).then(
        (value) {
          setState(() {
            _enableBt = true;
          });
          Navigator.pop(context);
          smState.showSnackBar(
            SnackBar(
              content: Text(
                appLoca!.passRestablecida,
              ),
            ),
          );
        },
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        Navigator.pop(context);
        smState.showSnackBar(
          SnackBar(
            content: Text(
              appLoca!.passRestablecida,
            ),
          ),
        );
      } else {
        setState(() => _enableBt = true);
        smState.showSnackBar(
          SnackBar(
            backgroundColor: td.colorScheme.error,
            content: Text(
              "Error",
              style: td.textTheme.bodyMedium!.copyWith(
                color: td.colorScheme.onError,
              ),
            ),
          ),
        );
      }
    } catch (error) {
      setState(() => _enableBt = true);
      smState.showSnackBar(
        SnackBar(
          backgroundColor: td.colorScheme.error,
          content: Text(
            "Error",
            style: td.textTheme.bodyMedium!.copyWith(
              color: td.colorScheme.onError,
            ),
          ),
        ),
      );
    }
  }
}

class NewUser extends StatefulWidget {
  const NewUser({Key? key}) : super(key: key);

  @override
  State<NewUser> createState() => _NewUser();
}

class _NewUser extends State<NewUser> {
  late GlobalKey<FormState> _keyNewUser;
  late String _email, _pass;
  late String? _firstname, _lastname;
  late TextEditingController _textEditingControllerMail,
      _textEditingControllerFirstname,
      _textEditingControllerLastname;
  late bool _enableBt, _allowNewUsers;
  @override
  void initState() {
    _keyNewUser = GlobalKey<FormState>();
    _textEditingControllerMail = TextEditingController();
    _textEditingControllerFirstname = TextEditingController();
    _textEditingControllerLastname = TextEditingController();
    _enableBt = true;
    _allowNewUsers = false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> formNewUserList = formNewUser();
    final List<Widget> buttonsNewUserList = buttonsNewUser();
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(AppLocalizations.of(context)!.nuevoUsuario),
            pinned: true,
          ),
          SliverVisibility(
            visible: !_allowNewUsers,
            sliver: SliverPadding(
              padding: const EdgeInsets.only(top: 50, left: 10, right: 10),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Center(
                    child: Container(
                      constraints:
                          const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                      alignment: Alignment.centerRight,
                      child: SelectableText(
                        AppLocalizations.of(context)!.registroDesactivado,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium!
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(top: 50, left: 10, right: 10),
            sliver: Form(
              key: _keyNewUser,
              child: SliverList(
                delegate: SliverChildBuilderDelegate(
                  ((context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Center(
                          child: Container(
                              constraints: const BoxConstraints(
                                  maxWidth: Auxiliar.maxWidth),
                              child: formNewUserList[index]),
                        ),
                      )),
                  childCount: formNewUserList.length,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                  (context, index) => Center(
                        child: Container(
                          constraints:
                              const BoxConstraints(maxWidth: Auxiliar.maxWidth),
                          alignment: Alignment.centerRight,
                          child: buttonsNewUserList.elementAt(index),
                        ),
                      ),
                  childCount: buttonsNewUserList.length),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> formNewUser() {
    return [
      TextFormField(
        controller: _textEditingControllerMail,
        onChanged: (String input) {
          setState(() {
            if (input.trim().isNotEmpty) {
              Auxiliar.checkAccents(input, _textEditingControllerMail);
            }
          });
        },
        maxLines: 1,
        decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: Template('{{{txt}}}*')
                .renderString({"txt": AppLocalizations.of(context)!.textLogin}),
            hintText: AppLocalizations.of(context)!.textLogin,
            hintMaxLines: 1,
            helperText: AppLocalizations.of(context)!.requerido,
            hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
        textCapitalization: TextCapitalization.none,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        enabled: _allowNewUsers && _enableBt,
        validator: (v) {
          if (v == null ||
              v.trim().isEmpty ||
              !EmailValidator.validate(v.trim())) {
            return AppLocalizations.of(context)!.textLoginError;
          }
          _email = v.trim();
          return null;
        },
      ),
      TextFormField(
        obscureText: true,
        maxLines: 1,
        decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: Template('{{{txt}}}*')
                .renderString({"txt": AppLocalizations.of(context)!.passLogin}),
            hintText: AppLocalizations.of(context)!.passLogin,
            helperText: AppLocalizations.of(context)!.requerido,
            hintMaxLines: 1,
            hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
        textCapitalization: TextCapitalization.none,
        keyboardType: TextInputType.visiblePassword,
        enabled: _allowNewUsers && _enableBt,
        validator: (v) {
          if (v == null || v.trim().isEmpty || v.trim().length < 6) {
            return AppLocalizations.of(context)!.passTamaError;
          }
          _pass = v.trim();
          return null;
        },
      ),
      TextFormField(
        obscureText: true,
        maxLines: 1,
        decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: Template('{{{txt}}}*').renderString(
                {"txt": AppLocalizations.of(context)!.passLoginAgain}),
            hintText: AppLocalizations.of(context)!.passLoginAgain,
            helperText: AppLocalizations.of(context)!.requerido,
            hintMaxLines: 1,
            hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
        textCapitalization: TextCapitalization.none,
        keyboardType: TextInputType.visiblePassword,
        enabled: _allowNewUsers && _enableBt,
        validator: (v) {
          if (v == null || v.trim().isEmpty || v.trim() != _pass) {
            return AppLocalizations.of(context)!.passLoginAgainError;
          }
          return null;
        },
      ),
      TextFormField(
        controller: _textEditingControllerFirstname,
        onChanged: (String input) {
          setState(() {
            if (input.trim().isNotEmpty) {
              Auxiliar.checkAccents(input, _textEditingControllerFirstname);
            }
          });
        },
        maxLines: 1,
        decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: AppLocalizations.of(context)!.textName,
            hintText: AppLocalizations.of(context)!.textName,
            hintMaxLines: 1,
            hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        keyboardType: TextInputType.name,
        enabled: _allowNewUsers && _enableBt,
        validator: (v) {
          _firstname = (v != null && v.trim().isNotEmpty) ? v.trim() : null;
          return null;
        },
      ),
      TextFormField(
        controller: _textEditingControllerLastname,
        onChanged: (String input) {
          setState(() {
            if (input.trim().isNotEmpty) {
              Auxiliar.checkAccents(input, _textEditingControllerLastname);
            }
          });
        },
        maxLines: 1,
        decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: AppLocalizations.of(context)!.surname,
            hintText: AppLocalizations.of(context)!.surname,
            hintMaxLines: 1,
            hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
        textCapitalization: TextCapitalization.words,
        keyboardType: TextInputType.name,
        textInputAction: TextInputAction.done,
        enabled: _allowNewUsers && _enableBt,
        validator: (v) {
          _lastname = (v != null && v.trim().isNotEmpty) ? v.trim() : null;
          return null;
        },
      ),
    ];
  }

  List<Widget> buttonsNewUser() {
    return [
      FilledButton(
        onPressed: _allowNewUsers && _enableBt
            ? () async {
                if (_keyNewUser.currentState!.validate()) {
                  setState(() => _enableBt = false);
                  //Intento el registro en Firebase
                  try {
                    FirebaseAuth.instance.setLanguageCode(MyApp.currentLang);
                    await FirebaseAuth.instance.createUserWithEmailAndPassword(
                      email: _email,
                      password: _pass,
                    );
                    await FirebaseAuth.instance.currentUser!
                        .sendEmailVerification();
                    Map<String, dynamic> objSend = {};
                    objSend["email"] = _email;
                    if (_firstname != null) {
                      objSend["firstname"] = _firstname;
                    }
                    if (_lastname != null) {
                      objSend["lastname"] = _lastname;
                    }
                    http
                        .put(Queries().putUser(),
                            headers: {
                              'content-type': 'application/json',
                              'Authorization': Template('Bearer {{{token}}}')
                                  .renderString({
                                'token': await FirebaseAuth
                                    .instance.currentUser!
                                    .getIdToken()
                              })
                            },
                            body: json.encode(objSend))
                        .then((value) async {
                      ScaffoldMessengerState smState =
                          ScaffoldMessenger.of(context);
                      switch (value.statusCode) {
                        case 201:
                          FirebaseAuth.instance.signOut();
                          if (!Config.development) {
                            await FirebaseAnalytics.instance
                                .logSignUp(signUpMethod: "emailPass")
                                .then(
                              (value) {
                                smState.clearSnackBars();
                                smState.showSnackBar(SnackBar(
                                    content: Text(AppLocalizations.of(context)!
                                        .validarCorreo)));
                                Navigator.pop(context);
                              },
                            ).onError((error, stackTrace) {
                              debugPrint(error.toString());
                              smState.clearSnackBars();
                              smState.showSnackBar(SnackBar(
                                  content: Text(AppLocalizations.of(context)!
                                      .validarCorreo)));
                              Navigator.pop(context);
                            });
                          } else {
                            smState.clearSnackBars();
                            smState.showSnackBar(SnackBar(
                                content: Text(AppLocalizations.of(context)!
                                    .validarCorreo)));
                            Navigator.pop(context);
                          }
                          break;
                        default:
                          setState(() => _enableBt = true);
                          break;
                      }
                    }).onError((error, stackTrace) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          backgroundColor: Colors.red, content: Text("Error")));
                      setState(() => _enableBt = true);
                    });
                  } on FirebaseAuthException catch (e) {
                    if (e.code == 'weak-password') {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          backgroundColor: Colors.red,
                          content: Text(
                              AppLocalizations.of(context)!.errorPassDebil)));
                      setState(() => _enableBt = true);
                    } else if (e.code == 'email-already-in-use') {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          backgroundColor: Colors.red,
                          content: Text(
                              AppLocalizations.of(context)!.errorMailEnUso)));
                      setState(() => _enableBt = true);
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        backgroundColor: Colors.red, content: Text("Error")));
                    setState(() => _enableBt = true);
                    //print(e);
                  }
                }
              }
            : null,
        child: Text(AppLocalizations.of(context)!.registrarUsuario),
      ),
    ];
  }
}

class InfoUser extends StatefulWidget {
  const InfoUser({super.key});

  @override
  State<StatefulWidget> createState() => _InfoUser();
}

class _InfoUser extends State<InfoUser> {
  late bool _enableBt;
  String? _firstname, _lastname;
  late GlobalKey<FormState> _thisKey;

  @override
  void initState() {
    _thisKey = GlobalKey<FormState>();
    _enableBt = true;
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Auxiliar.userCHEST.rol == Rol.guest) {
      Navigator.pop(context);
      return const Scaffold();
    } else {
      List<Widget> lstForms = lstFormsW();
      List<Widget> lstInfo = lstInfoW();
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 20),
              sliver: SliverAppBar(
                floating: true,
                title: Text(AppLocalizations.of(context)!.infoCuenta),
              ),
            ),
            Form(
              key: _thisKey,
              child: SliverPadding(
                padding: const EdgeInsets.only(bottom: 15, right: 10, left: 10),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                      (context, index) => Center(
                            child: Container(
                              constraints: const BoxConstraints(
                                  maxWidth: Auxiliar.maxWidth),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 15),
                                child: lstForms.elementAt(index),
                              ),
                            ),
                          ),
                      childCount: lstForms.length),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 15, right: 10, left: 10),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                    (context, index) => Center(
                          child: Container(
                            constraints: const BoxConstraints(
                                maxWidth: Auxiliar.maxWidth),
                            child: Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 15),
                                  child: lstInfo.elementAt(index),
                                )),
                          ),
                        ),
                    childCount: lstInfo.length),
              ),
            ),
          ],
        ),
      );
    }
  }

  List<Widget> lstFormsW() {
    return [
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          AppLocalizations.of(context)!.nombreApellidos,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      TextFormField(
        maxLines: 1,
        decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: AppLocalizations.of(context)!.textName,
            hintText: AppLocalizations.of(context)!.textName,
            hintMaxLines: 1,
            hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        keyboardType: TextInputType.name,
        enabled: _enableBt,
        initialValue: Auxiliar.userCHEST.firstname.isEmpty
            ? null
            : Auxiliar.userCHEST.firstname,
        validator: (v) {
          _firstname = (v != null && v.trim().isNotEmpty) ? v.trim() : null;
          return null;
        },
      ),
      TextFormField(
        maxLines: 1,
        decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: AppLocalizations.of(context)!.surname,
            hintText: AppLocalizations.of(context)!.surname,
            hintMaxLines: 1,
            hintStyle: const TextStyle(overflow: TextOverflow.ellipsis)),
        textCapitalization: TextCapitalization.words,
        keyboardType: TextInputType.name,
        textInputAction: TextInputAction.next,
        enabled: _enableBt,
        initialValue: Auxiliar.userCHEST.lastname.isEmpty
            ? null
            : Auxiliar.userCHEST.lastname,
        validator: (v) {
          _lastname = (v != null && v.trim().isNotEmpty) ? v.trim() : null;
          return null;
        },
      ),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          label: Text(AppLocalizations.of(context)!.guardar),
          icon: const Icon(Icons.save),
          onPressed: _enableBt
              ? () async {
                  _enableBt = false;
                  if (_thisKey.currentState!.validate() &&
                      (((_firstname ?? '') != Auxiliar.userCHEST.firstname) ||
                          ((_lastname ?? '') != Auxiliar.userCHEST.lastname))) {
                    Map<String, String> bodyRequest = {
                      'firstname': _firstname ?? '',
                      'lastname': _lastname ?? ''
                    };
                    if (bodyRequest.isNotEmpty) {
                      http
                          .put(
                        Queries().putUser(),
                        headers: {
                          'Content-Type': 'application/json',
                          'Authorization': Template('Bearer {{{token}}}')
                              .renderString({
                            'token': await FirebaseAuth.instance.currentUser!
                                .getIdToken()
                          }),
                        },
                        body: json.encode(bodyRequest),
                      )
                          .then((response) {
                        ScaffoldMessengerState smState =
                            ScaffoldMessenger.of(context);
                        ThemeData td = Theme.of(context);
                        smState.clearSnackBars();
                        switch (response.statusCode) {
                          case 200:
                            Auxiliar.userCHEST.firstname = _firstname ?? '';
                            Auxiliar.userCHEST.lastname = _lastname ?? '';
                            smState.showSnackBar(SnackBar(
                              content: Text(AppLocalizations.of(context)!
                                  .perfilActualizado),
                            ));
                            break;
                          default:
                            smState.showSnackBar(SnackBar(
                              backgroundColor: td.colorScheme.error,
                              content: const Text("Error"),
                            ));
                        }
                        _enableBt = true;
                      }).onError((error, stackTrace) {
                        debugPrint(error.toString());
                        _enableBt = true;
                      });
                    } else {
                      _enableBt = true;
                    }
                  } else {
                    _enableBt = true;
                  }
                }
              : null,
        ),
      ),
    ];
  }

  List<Widget> lstInfoW() {
    AppLocalizations? appLoca = AppLocalizations.of(context);
    ThemeData td = Theme.of(context);
    return [
      Text(
        appLoca!.moreInfoAccount,
        style: td.textTheme.titleLarge,
      ),
      SelectableText(
        Template('{{{id}}}: {{{userId}}}').renderString(
            {'id': "ID", 'userId': Auxiliar.userCHEST.id.split("/").last}),
        style: td.textTheme.bodySmall,
      ),
      Text(
        Template('{{{rol}}}: {{{userRol}}}').renderString(
            {'rol': appLoca.rol, 'userRol': Auxiliar.userCHEST.rol.name}),
        style: td.textTheme.bodySmall,
      )
    ];
  }
}
