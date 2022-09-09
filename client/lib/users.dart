import 'dart:convert';

import 'package:email_validator/email_validator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mustache_template/mustache.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'helpers/auxiliar.dart';
import 'helpers/queries.dart';
import 'helpers/user.dart';

class LoginUsers extends StatefulWidget {
  const LoginUsers({Key? key}) : super(key: key);

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
    const double bh = 40, cmw = 400;
    final String mMailSinVerificar =
        AppLocalizations.of(context)!.errorEmailSinVerificar;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColorDark,
        leading: const BackButton(color: Colors.white),
        title: Text(AppLocalizations.of(context)!.iniciarSes),
      ),
      body: Center(
        child: SafeArea(
          minimum: const EdgeInsets.all(10),
          child: SingleChildScrollView(
            child: Column(children: [
              Form(
                key: _keyLoginForm,
                child: Column(
                  children: [
                    Container(
                      constraints: const BoxConstraints(
                          maxWidth: Auxiliar.MAX_WIDTH, minWidth: cmw),
                      child: TextFormField(
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
                            hintStyle: const TextStyle(
                                overflow: TextOverflow.ellipsis)),
                        textCapitalization: TextCapitalization.none,
                        keyboardType: TextInputType.emailAddress,
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
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    Container(
                      constraints: const BoxConstraints(
                          maxWidth: Auxiliar.MAX_WIDTH, minWidth: cmw),
                      child: TextFormField(
                        obscureText: true,
                        maxLines: 1,
                        decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            labelText: AppLocalizations.of(context)!.passLogin,
                            hintText: AppLocalizations.of(context)!.passLogin,
                            hintMaxLines: 1,
                            hintStyle: const TextStyle(
                                overflow: TextOverflow.ellipsis)),
                        textCapitalization: TextCapitalization.none,
                        validator: (v) {
                          if (v == null ||
                              v.trim().isEmpty ||
                              v.trim().length < 6) {
                            return AppLocalizations.of(context)!.passLogin;
                          }
                          _pass = v.trim();
                          return null;
                        },
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              Container(
                constraints: const BoxConstraints(
                    maxWidth: Auxiliar.MAX_WIDTH, maxHeight: bh),
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, double.infinity),
                    ),
                    onPressed: !_enableBt
                        ? null
                        : () async {
                            if (_keyLoginForm.currentState!.validate()) {
                              try {
                                _enableBt = false;
                                await FirebaseAuth.instance
                                    .signInWithEmailAndPassword(
                                        email: _email, password: _pass);
                                if (FirebaseAuth
                                    .instance.currentUser!.emailVerified) {
                                  http.get(Queries().signIn(), headers: {
                                    'Authorization':
                                        Template('Bearer {{{token}}}')
                                            .renderString({
                                      'token': await FirebaseAuth
                                          .instance.currentUser!
                                          .getIdToken()
                                    })
                                  }).then((data) {
                                    switch (data.statusCode) {
                                      case 200:
                                        Map<String, dynamic> j =
                                            json.decode(data.body);
                                        _enableBt = true;
                                        Auxiliar.userCHEST =
                                            UserCHEST(j["id"], j["rol"]);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                          duration: const Duration(seconds: 1),
                                          content: Text(
                                              AppLocalizations.of(context)!
                                                  .hola),
                                        ));
                                        Navigator.pop(context);
                                        break;
                                      default:
                                        _enableBt = true;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                          backgroundColor: Colors.red,
                                          content: Text("Error"),
                                        ));
                                    }
                                  }).onError((error, stackTrace) {
                                    _enableBt = true;
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(
                                      backgroundColor: Colors.red,
                                      content: Text("Error"),
                                    ));
                                  });
                                } else {
                                  _enableBt = true;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          backgroundColor: Colors.red,
                                          content: Text(mMailSinVerificar)));
                                }
                              } on FirebaseAuthException catch (e) {
                                _enableBt = true;
                                if (e.code == 'user-not-found' ||
                                    e.code == 'wrong-password') {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    backgroundColor: Colors.red,
                                    content: Text(AppLocalizations.of(context)!
                                        .errorUserPass),
                                  ));
                                }
                              } catch (e) {
                                _enableBt = true;
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        backgroundColor: Colors.red,
                                        content: Text("Error")));
                              }
                            }
                          },
                    child: Text(AppLocalizations.of(context)!.iniciarSes)),
              ),
              const SizedBox(
                height: 10,
              ),
              Container(
                constraints: const BoxConstraints(
                    maxWidth: Auxiliar.MAX_WIDTH, maxHeight: bh),
                child: TextButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, double.infinity),
                    ),
                    onPressed: !_enableBt
                        ? null
                        : () {
                            Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (BuildContext context) =>
                                      const ForgotPass(),
                                  fullscreenDialog: false,
                                ));
                          },
                    child: Text(AppLocalizations.of(context)!.olvidePass)),
              ),
              const SizedBox(
                height: 10,
              ),
              Container(
                  constraints: const BoxConstraints(
                      maxWidth: Auxiliar.MAX_WIDTH, maxHeight: bh),
                  child: TextButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize:
                            const Size(double.infinity, double.infinity),
                      ),
                      onPressed: !_enableBt
                          ? null
                          : () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (BuildContext context) =>
                                        const NewUser(),
                                    fullscreenDialog: false,
                                  ));
                            },
                      child: Text(AppLocalizations.of(context)!.nuevoUsuario))),
            ]),
          ),
        ),
      ),
    );
  }
}

class ForgotPass extends StatefulWidget {
  const ForgotPass({Key? key}) : super(key: key);

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
    const double bh = 40, cmw = 400;
    final String mPassReset = AppLocalizations.of(context)!.passRestablecida;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColorDark,
        leading: const BackButton(color: Colors.white),
        title: Text(AppLocalizations.of(context)!.olvidePass),
      ),
      body: Center(
        child: SafeArea(
          minimum: const EdgeInsets.all(10),
          child: SingleChildScrollView(
            child: Column(children: [
              Form(
                key: _keyPass,
                child: Column(
                  children: [
                    Container(
                      constraints: const BoxConstraints(
                          maxWidth: Auxiliar.MAX_WIDTH, minWidth: cmw),
                      child: TextFormField(
                        controller: _textEditingControllerMail,
                        onChanged: (String input) {
                          setState(() {
                            if (input.trim().isNotEmpty) {
                              Auxiliar.checkAccents(
                                  input, _textEditingControllerMail);
                            }
                          });
                        },
                        maxLines: 1,
                        decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            labelText: Template('{{{txt}}} *').renderString({
                              "txt": AppLocalizations.of(context)!.textLogin
                            }),
                            hintText: AppLocalizations.of(context)!.textLogin,
                            hintMaxLines: 1,
                            hintStyle: const TextStyle(
                                overflow: TextOverflow.ellipsis)),
                        textCapitalization: TextCapitalization.none,
                        keyboardType: TextInputType.emailAddress,
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
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              Container(
                constraints: const BoxConstraints(
                    maxWidth: Auxiliar.MAX_WIDTH, maxHeight: bh),
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, double.infinity),
                    ),
                    onPressed: !_enableBt
                        ? null
                        : () async {
                            if (_keyPass.currentState!.validate()) {
                              _enableBt = false;
                              try {
                                await FirebaseAuth.instance
                                    .sendPasswordResetEmail(email: _email);
                                _enableBt = true;
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(mPassReset)));
                                Navigator.pop(context);
                              } catch (error) {
                                _enableBt = true;
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        backgroundColor: Colors.red,
                                        content: Text("Error")));
                              }
                            }
                          },
                    child: Text(AppLocalizations.of(context)!.restablecerPass)),
              ),
            ]),
          ),
        ),
      ),
    );
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
  late bool _enableBt;
  @override
  void initState() {
    _keyNewUser = GlobalKey<FormState>();
    _textEditingControllerMail = TextEditingController();
    _textEditingControllerFirstname = TextEditingController();
    _textEditingControllerLastname = TextEditingController();
    _enableBt = true;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    const double bh = 40, cmw = 400;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColorDark,
        leading: const BackButton(color: Colors.white),
        title: Text(AppLocalizations.of(context)!.nuevoUsuario),
      ),
      body: Center(
        child: SafeArea(
          minimum: const EdgeInsets.all(10),
          child: SingleChildScrollView(
            child: Column(
              children: [
                Form(
                    key: _keyNewUser,
                    child: Column(
                      children: [
                        Container(
                          constraints: const BoxConstraints(
                              maxWidth: Auxiliar.MAX_WIDTH, minWidth: cmw),
                          child: TextFormField(
                            controller: _textEditingControllerMail,
                            onChanged: (String input) {
                              setState(() {
                                if (input.trim().isNotEmpty) {
                                  Auxiliar.checkAccents(
                                      input, _textEditingControllerMail);
                                }
                              });
                            },
                            maxLines: 1,
                            decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: Template('{{{txt}}} *')
                                    .renderString({
                                  "txt": AppLocalizations.of(context)!.textLogin
                                }),
                                hintText:
                                    AppLocalizations.of(context)!.textLogin,
                                hintMaxLines: 1,
                                hintStyle: const TextStyle(
                                    overflow: TextOverflow.ellipsis)),
                            textCapitalization: TextCapitalization.none,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null ||
                                  v.trim().isEmpty ||
                                  !EmailValidator.validate(v.trim())) {
                                return AppLocalizations.of(context)!
                                    .textLoginError;
                              }
                              _email = v.trim();
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        Container(
                          constraints: const BoxConstraints(
                              maxWidth: Auxiliar.MAX_WIDTH, minWidth: cmw),
                          child: TextFormField(
                            obscureText: true,
                            maxLines: 1,
                            decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: Template('{{{txt}}} *')
                                    .renderString({
                                  "txt": AppLocalizations.of(context)!.passLogin
                                }),
                                hintText:
                                    AppLocalizations.of(context)!.passLogin,
                                hintMaxLines: 1,
                                hintStyle: const TextStyle(
                                    overflow: TextOverflow.ellipsis)),
                            textCapitalization: TextCapitalization.none,
                            keyboardType: TextInputType.visiblePassword,
                            validator: (v) {
                              if (v == null ||
                                  v.trim().isEmpty ||
                                  v.trim().length < 6) {
                                return AppLocalizations.of(context)!
                                    .passTamaError;
                              }
                              _pass = v.trim();
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        Container(
                          constraints: const BoxConstraints(
                              maxWidth: Auxiliar.MAX_WIDTH, minWidth: cmw),
                          child: TextFormField(
                            controller: _textEditingControllerFirstname,
                            onChanged: (String input) {
                              setState(() {
                                if (input.trim().isNotEmpty) {
                                  Auxiliar.checkAccents(
                                      input, _textEditingControllerFirstname);
                                }
                              });
                            },
                            maxLines: 1,
                            decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText:
                                    AppLocalizations.of(context)!.textName,
                                hintText:
                                    AppLocalizations.of(context)!.textName,
                                hintMaxLines: 1,
                                hintStyle: const TextStyle(
                                    overflow: TextOverflow.ellipsis)),
                            textCapitalization: TextCapitalization.words,
                            keyboardType: TextInputType.name,
                            validator: (v) {
                              _firstname = (v != null && v.trim().isNotEmpty)
                                  ? v.trim()
                                  : null;
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(
                          height: 5,
                        ),
                        Container(
                          constraints: const BoxConstraints(
                              maxWidth: Auxiliar.MAX_WIDTH, minWidth: cmw),
                          child: TextFormField(
                            controller: _textEditingControllerLastname,
                            onChanged: (String input) {
                              setState(() {
                                if (input.trim().isNotEmpty) {
                                  Auxiliar.checkAccents(
                                      input, _textEditingControllerLastname);
                                }
                              });
                            },
                            maxLines: 1,
                            decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText:
                                    AppLocalizations.of(context)!.surname,
                                hintText: AppLocalizations.of(context)!.surname,
                                hintMaxLines: 1,
                                hintStyle: const TextStyle(
                                    overflow: TextOverflow.ellipsis)),
                            textCapitalization: TextCapitalization.words,
                            keyboardType: TextInputType.name,
                            validator: (v) {
                              _lastname = (v != null && v.trim().isNotEmpty)
                                  ? v.trim()
                                  : null;
                              return null;
                            },
                          ),
                        ),
                      ],
                    )),
                const SizedBox(
                  height: 10,
                ),
                Container(
                  constraints: const BoxConstraints(
                      maxWidth: Auxiliar.MAX_WIDTH, maxHeight: bh),
                  child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize:
                            const Size(double.infinity, double.infinity),
                      ),
                      onPressed: _enableBt
                          ? () async {
                              if (_keyNewUser.currentState!.validate()) {
                                setState(() => _enableBt = false);
                                //Intento el registro en Firebase
                                try {
                                  await FirebaseAuth.instance
                                      .createUserWithEmailAndPassword(
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
                                            'Authorization':
                                                Template('Bearer {{{token}}}')
                                                    .renderString({
                                              'token': await FirebaseAuth
                                                  .instance.currentUser!
                                                  .getIdToken()
                                            })
                                          },
                                          body: json.encode(objSend))
                                      .then((value) async {
                                    switch (value.statusCode) {
                                      case 201:
                                        FirebaseAuth.instance.signOut();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text(
                                                    AppLocalizations.of(
                                                            context)!
                                                        .validarCorreo)));
                                        Navigator.pop(context);
                                        break;
                                      default:
                                        setState(() => _enableBt = true);
                                        break;
                                    }
                                  }).onError((error, stackTrace) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            backgroundColor: Colors.red,
                                            content: Text("Error")));
                                    setState(() => _enableBt = true);
                                  });
                                } on FirebaseAuthException catch (e) {
                                  if (e.code == 'weak-password') {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            backgroundColor: Colors.red,
                                            content: Text(
                                                AppLocalizations.of(context)!
                                                    .errorPassDebil)));
                                    setState(() => _enableBt = true);
                                  } else if (e.code == 'email-already-in-use') {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            backgroundColor: Colors.red,
                                            content: Text(
                                                AppLocalizations.of(context)!
                                                    .errorMailEnUso)));
                                    setState(() => _enableBt = true);
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          backgroundColor: Colors.red,
                                          content: Text("Error")));
                                  setState(() => _enableBt = true);
                                  //print(e);
                                }
                              }
                            }
                          : null,
                      child:
                          Text(AppLocalizations.of(context)!.registrarUsuario)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
