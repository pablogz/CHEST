import 'dart:convert';

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
    const double bh = 40, cMw = 600, cmw = 400;

    return Scaffold(
        appBar: AppBar(
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
                                maxWidth: cMw, minWidth: cmw),
                            child: TextFormField(
                              controller: _textController,
                              onChanged: (String input) {
                                setState(() {
                                  if (input.trim().isNotEmpty) {
                                    Auxiliar.checkAccents(
                                        input, _textController);
                                  }
                                });
                              },
                              maxLines: 1,
                              decoration: InputDecoration(
                                  border: const OutlineInputBorder(),
                                  hintText:
                                      AppLocalizations.of(context)!.textLogin,
                                  hintMaxLines: 1,
                                  hintStyle: const TextStyle(
                                      overflow: TextOverflow.ellipsis)),
                              textCapitalization: TextCapitalization.none,
                              validator: (v) {
                                if (v == null ||
                                    v.trim().isEmpty ||
                                    !Auxiliar.validMail(v.trim())) {
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
                                maxWidth: cMw, minWidth: cmw),
                            child: TextFormField(
                              obscureText: true,
                              maxLines: 1,
                              decoration: InputDecoration(
                                  border: const OutlineInputBorder(),
                                  hintText:
                                      AppLocalizations.of(context)!.passLogin,
                                  hintMaxLines: 1,
                                  hintStyle: const TextStyle(
                                      overflow: TextOverflow.ellipsis)),
                              textCapitalization: TextCapitalization.none,
                              validator: (v) {
                                if (v == null ||
                                    v.trim().isEmpty ||
                                    v.trim().length < 6) {
                                  return AppLocalizations.of(context)!
                                      .passLogin;
                                }
                                _pass = v.trim();
                                return null;
                              },
                            ),
                          )
                        ],
                      )),
                  const SizedBox(
                    height: 10,
                  ),
                  Container(
                      constraints:
                          const BoxConstraints(maxWidth: cMw, maxHeight: bh),
                      child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize:
                                const Size(double.infinity, double.infinity),
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
                                      if (FirebaseAuth.instance.currentUser!
                                          .emailVerified) {
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
                                              Navigator.pop(context,
                                                  UserCHEST(j["id"], j["rol"]));
                                              break;
                                            default:
                                              _enableBt = true;
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                      backgroundColor:
                                                          Colors.red,
                                                      content: Text("Error")));
                                          }
                                        }).onError((error, stackTrace) {
                                          _enableBt = true;
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  backgroundColor: Colors.red,
                                                  content: Text("Error")));
                                        });
                                      } else {
                                        _enableBt = true;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                backgroundColor: Colors.red,
                                                content: Text(AppLocalizations
                                                        .of(context)!
                                                    .errorEmailSinVerificar)));
                                      }
                                    } on FirebaseAuthException catch (e) {
                                      _enableBt = true;
                                      if (e.code == 'user-not-found' ||
                                          e.code == 'wrong-password') {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                backgroundColor: Colors.red,
                                                content: Text(
                                                    AppLocalizations.of(
                                                            context)!
                                                        .errorUserPass)));
                                      }
                                    } catch (e) {
                                      _enableBt = true;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              backgroundColor: Colors.red,
                                              content: Text("Error")));
                                    }
                                  }
                                },
                          child:
                              Text(AppLocalizations.of(context)!.iniciarSes))),
                  const SizedBox(
                    height: 10,
                  ),
                  Container(
                      constraints:
                          const BoxConstraints(maxWidth: cMw, maxHeight: bh),
                      child: TextButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize:
                                const Size(double.infinity, double.infinity),
                          ),
                          onPressed: () {},
                          child:
                              Text(AppLocalizations.of(context)!.olvidePass))),
                  const SizedBox(
                    height: 10,
                  ),
                  Container(
                      constraints:
                          const BoxConstraints(maxWidth: cMw, maxHeight: bh),
                      child: TextButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize:
                                const Size(double.infinity, double.infinity),
                          ),
                          onPressed: () {},
                          child: Text(
                              AppLocalizations.of(context)!.nuevoUsuario))),
                ])))));
  }
}
