import 'dart:convert';

import 'package:chest/main.dart';
import 'package:chest/util/auth/firebase.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:mustache_template/mustache.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:chest/util/auxiliar.dart';
import 'package:chest/util/queries.dart';
import 'package:chest/util/helpers/user.dart';
import 'package:chest/util/config.dart';

class NewUser extends StatefulWidget {
  final double? lat, long, zoom;

  const NewUser({
    super.key,
    this.lat,
    this.long,
    this.zoom,
  });

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
          automaticallyImplyLeading: false,
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
          try {
            setState(() => _enableBt = false);
            Auxiliar.allowNewUser = false;
            if (Auxiliar.userCHEST.isNotGuest &&
                Auxiliar.userCHEST.lastMapView.init) {
              GoRouter.of(context).go(
                  '/map?center=${Auxiliar.userCHEST.lastMapView.lat!},${Auxiliar.userCHEST.lastMapView.long!}&zoom=${Auxiliar.userCHEST.lastMapView.zoom!}');
            } else {
              GoRouter.of(context).go('/map');
            }
            // http
            //     .put(Queries.putUser(),
            //         headers: {
            //           'content-type': 'application/json',
            //           'Authorization': Template('Bearer {{{token}}}')
            //               .renderString({
            //             'token': await FirebaseAuth.instance.currentUser!
            //                 .getIdToken()
            //           })
            //         },
            //         body: json.encode({}))
            //     .then((response) async {
            //   switch (response.statusCode) {
            //     case 201:
            //       http.get(Queries.signIn(), headers: {
            //         'Authorization': Template('Bearer {{{token}}}')
            //             .renderString({
            //           'token':
            //               await FirebaseAuth.instance.currentUser!.getIdToken()
            //         })
            //       }).then((response) async {
            //         switch (response.statusCode) {
            //           case 200:
            //             Map<String, dynamic> data = json.decode(response.body);
            //             Auxiliar.userCHEST = UserCHEST(data);
            //             if (Auxiliar.userCHEST.alias != null) {
            //               smState.clearSnackBars();
            //               smState.showSnackBar(SnackBar(
            //                   content: Text(
            //                       '${appLoca.hola} ${Auxiliar.userCHEST.alias}')));
            //             }
            //             Auxiliar.allowNewUser = false;
            //             if (widget.lat != null &&
            //                 widget.long != null &&
            //                 widget.zoom != null) {
            //               Auxiliar.userCHEST.lastMapView = LastPosition(
            //                   widget.lat!, widget.long!, widget.zoom!);
            //               http
            //                   .put(Queries.preferences(),
            //                       headers: {
            //                         'content-type': 'application/json',
            //                         'Authorization':
            //                             Template('Bearer {{{token}}}')
            //                                 .renderString({
            //                           'token': await FirebaseAuth
            //                               .instance.currentUser!
            //                               .getIdToken()
            //                         })
            //                       },
            //                       body: json.encode({
            //                         'lastPointView':
            //                             Auxiliar.userCHEST.lastMapView.toJSON()
            //                       }))
            //                   .then((response) {
            //                 GoRouter.of(context).go(
            //                     '/map?center=${Auxiliar.userCHEST.lastMapView.lat!},${Auxiliar.userCHEST.lastMapView.long!}&zoom=${Auxiliar.userCHEST.lastMapView.zoom!}');
            //               }).onError((error, stackTrace) {
            //                 GoRouter.of(context).go(
            //                     '/map?center=${Auxiliar.userCHEST.lastMapView.lat!},${Auxiliar.userCHEST.lastMapView.long!}&zoom=${Auxiliar.userCHEST.lastMapView.zoom!}');
            //               });
            //             } else {
            //               if (!Config.development) {
            //                 FirebaseAnalytics.instance
            //                     .logLogin(loginMethod: "Google")
            //                     .then((a) {
            //                   GoRouter.of(context).go(Auxiliar
            //                           .userCHEST.lastMapView.init
            //                       ? '/map?center=${Auxiliar.userCHEST.lastMapView.lat!},${Auxiliar.userCHEST.lastMapView.long!}&zoom=${Auxiliar.userCHEST.lastMapView.zoom!}'
            //                       : '/map');
            //                 });
            //               } else {
            //                 GoRouter.of(context).go(Auxiliar
            //                         .userCHEST.lastMapView.init
            //                     ? '/map?center=${Auxiliar.userCHEST.lastMapView.lat!},${Auxiliar.userCHEST.lastMapView.long!}&zoom=${Auxiliar.userCHEST.lastMapView.zoom!}'
            //                     : '/map');
            //               }
            //             }
            //             break;
            //           default:
            //             FirebaseAuth.instance.signOut();
            //             smState.clearSnackBars();
            //             smState.showSnackBar(SnackBar(
            //                 backgroundColor: colorScheme.error,
            //                 content: Text(
            //                     'Error in GET. Status code: ${response.statusCode}',
            //                     style: bodyMedium.copyWith(
            //                         color: colorScheme.onError))));
            //         }
            //       });
            //       break;
            //     default:
            //   }
            // });
          } catch (e, stackTrace) {
            setState(() => _enableBt = true);
            if (Config.development) {
              debugPrint(e.toString());
            } else {
              await FirebaseCrashlytics.instance.recordError(e, stackTrace);
            }
            smState.clearSnackBars();
            smState.showSnackBar(SnackBar(
                backgroundColor: colorScheme.error,
                content: Text('Error.',
                    style: bodyMedium.copyWith(color: colorScheme.onError))));
          }
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
                      setState(() => _enableBt = false);
                      try {
                        http
                            .put(Queries.putUser(),
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
                            case 204:
                              // Usuario creado en el servidor.
                              // Pido la info para registrarlo en el cliente
                              http.get(Queries.signIn(), headers: {
                                'Authorization': Template('Bearer {{{token}}}')
                                    .renderString({
                                  'token': await FirebaseAuth
                                      .instance.currentUser!
                                      .getIdToken()
                                })
                              }).then((response) async {
                                switch (response.statusCode) {
                                  case 200:
                                  case 204:
                                    Map<String, dynamic> data =
                                        json.decode(response.body);
                                    Auxiliar.userCHEST = UserCHEST(data);
                                    setState(() => _enableBt = true);
                                    Auxiliar.allowNewUser = false;
                                    if (widget.lat != null &&
                                        widget.long != null &&
                                        widget.zoom != null) {
                                      Auxiliar.userCHEST.lastMapView =
                                          LastPosition(widget.lat!,
                                              widget.long!, widget.zoom!);
                                      http
                                          .put(Queries.preferences(),
                                              headers: {
                                                'content-type':
                                                    'application/json',
                                                'Authorization': Template(
                                                        'Bearer {{{token}}}')
                                                    .renderString({
                                                  'token': await FirebaseAuth
                                                      .instance.currentUser!
                                                      .getIdToken()
                                                })
                                              },
                                              body: json.encode({
                                                'lastPointView': Auxiliar
                                                    .userCHEST.lastMapView
                                                    .toJSON()
                                              }))
                                          .then((response) {
                                        if (mounted) {
                                          GoRouter.of(context).go(
                                              '/map?center=${Auxiliar.userCHEST.lastMapView.lat!},${Auxiliar.userCHEST.lastMapView.long!}&zoom=${Auxiliar.userCHEST.lastMapView.zoom!}');
                                        }
                                      }).onError((error, stackTrace) {
                                        if (mounted) {
                                          GoRouter.of(context).go(
                                              '/map?center=${Auxiliar.userCHEST.lastMapView.lat!},${Auxiliar.userCHEST.lastMapView.long!}&zoom=${Auxiliar.userCHEST.lastMapView.zoom!}');
                                        }
                                      });
                                    } else {
                                      if (!Config.development) {
                                        FirebaseAnalytics.instance
                                            .logLogin(loginMethod: "Google")
                                            .then((a) {
                                          if (mounted) {
                                            GoRouter.of(context).go(Auxiliar
                                                    .userCHEST.lastMapView.init
                                                ? '/map?center=${Auxiliar.userCHEST.lastMapView.lat!},${Auxiliar.userCHEST.lastMapView.long!}&zoom=${Auxiliar.userCHEST.lastMapView.zoom!}'
                                                : '/map');
                                          }
                                        });
                                      } else {
                                        GoRouter.of(context).go(Auxiliar
                                                .userCHEST.lastMapView.init
                                            ? '/map?center=${Auxiliar.userCHEST.lastMapView.lat!},${Auxiliar.userCHEST.lastMapView.long!}&zoom=${Auxiliar.userCHEST.lastMapView.zoom!}'
                                            : '/map');
                                      }
                                    }
                                    break;
                                  default:
                                    setState(() => _enableBt = true);
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
                              setState(() => _enableBt = true);
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
                      } on FirebaseAuthException catch (e, stackTrace) {
                        setState(() => _enableBt = true);
                        if (Config.development) {
                          debugPrint(e.toString());
                        } else {
                          await FirebaseCrashlytics.instance
                              .recordError(e, stackTrace);
                        }
                        smState.clearSnackBars();
                        smState.showSnackBar(SnackBar(
                            backgroundColor: colorScheme.error,
                            content: Text('Error with Firebase Auth.',
                                style: bodyMedium.copyWith(
                                    color: colorScheme.onError))));
                      } catch (e, stackTrace) {
                        setState(() => _enableBt = true);
                        if (Config.development) {
                          debugPrint(e.toString());
                        } else {
                          await FirebaseCrashlytics.instance
                              .recordError(e, stackTrace);
                        }
                        smState.clearSnackBars();
                        smState.showSnackBar(SnackBar(
                            backgroundColor: colorScheme.error,
                            content: Text('Error.',
                                style: bodyMedium.copyWith(
                                    color: colorScheme.onError))));
                      }
                    } else {
                      setState(() => _enableBt = true);
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
    double lateralMargin =
        Auxiliar.getLateralMargin(MediaQuery.of(context).size.width);
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
        color: colorScheme.primaryContainer,
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
    ScaffoldMessengerState sMState = ScaffoldMessenger.of(context);
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
              TextButton(
                  onPressed: () async {
                    bool? delete = await Auxiliar.deleteDialog(
                      context,
                      appLoca!.borrarUsuario,
                      appLoca.confirmaBorrarUsuario,
                    );
                    if (delete is bool &&
                        delete &&
                        FirebaseAuth.instance.currentUser != null) {
                      // Petición al servidor para borrar la cuenta
                      http
                          .delete(
                        Queries.deleteUser(),
                        headers: {
                          'Content-Type': 'application/json',
                          'Authorization':
                              Template('Bearer {{{token}}}').renderString({
                            'token': await FirebaseAuth.instance.currentUser!
                                .getIdToken(),
                          })
                        },
                        body: json.encode({}),
                      )
                          .then((v) async {
                        if (v.statusCode == 200 ||
                            v.statusCode == 204 ||
                            v.statusCode == 202) {
                          List<UserInfo> providerData =
                              FirebaseAuth.instance.currentUser!.providerData;
                          for (UserInfo userInfo in providerData) {
                            if (userInfo.providerId
                                .contains(AuthProviders.google.name)) {
                              await AuthFirebase.signOut(AuthProviders.google);
                            } else {
                              if (userInfo.providerId
                                  .contains(AuthProviders.apple.name)) {
                                await AuthFirebase.signOut(AuthProviders.apple);
                              }
                            }
                          }
                          if (mounted) GoRouter.of(context).go('/');
                          sMState.clearSnackBars();
                          sMState.showSnackBar(SnackBar(
                              content: Text(
                            appLoca.cuentaBorrada,
                          )));
                        } else {
                          sMState.clearSnackBars();
                          sMState.showSnackBar(SnackBar(
                              content: Text(
                            'Error. StatusCode: ${v.statusCode}',
                          )));
                        }
                      }).catchError((error, stackTrace) async {
                        if (Config.development) {
                          debugPrint(error.toString());
                        } else {
                          await FirebaseCrashlytics.instance
                              .recordError(error, stackTrace);
                        }

                        sMState.clearSnackBars();
                        sMState.showSnackBar(const SnackBar(
                            content: Text(
                          'Error',
                        )));
                      });
                    }
                  },
                  child: Text(appLoca!.borrarUsuario)),
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
                      setState(() => _enableBt = false);
                      try {
                        http
                            .put(Queries.putUser(),
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
                              http.get(Queries.signIn(), headers: {
                                'Authorization': Template('Bearer {{{token}}}')
                                    .renderString({
                                  'token': await FirebaseAuth
                                      .instance.currentUser!
                                      .getIdToken()
                                })
                              }).then((response) async {
                                switch (response.statusCode) {
                                  case 200:
                                    setState(() => _enableBt = true);
                                    Map<String, dynamic> data =
                                        json.decode(response.body);
                                    Auxiliar.userCHEST = UserCHEST(data);
                                    Auxiliar.allowManageUser = false;
                                    if (!Config.development) {
                                      FirebaseAnalytics.instance
                                          .logEvent(name: 'EditUser')
                                          .then((a) {
                                        if (mounted) {
                                          GoRouter.of(context).go('/map');
                                        }
                                      });
                                    } else {
                                      GoRouter.of(context).go('/map');
                                    }
                                    break;
                                  default:
                                    setState(() => _enableBt = true);
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
                              setState(() => _enableBt = true);

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
                      } on FirebaseAuthException catch (e, stackTrace) {
                        setState(() => _enableBt = true);

                        if (Config.development) {
                          debugPrint(e.toString());
                        } else {
                          await FirebaseCrashlytics.instance
                              .recordError(e, stackTrace);
                        }
                        smState.clearSnackBars();
                        smState.showSnackBar(SnackBar(
                            backgroundColor: colorScheme.error,
                            content: Text('Error with Firebase Auth.',
                                style: bodyMedium.copyWith(
                                    color: colorScheme.onError))));
                      } catch (e, stackTrace) {
                        setState(() => _enableBt = true);

                        if (Config.development) {
                          debugPrint(e.toString());
                        } else {
                          await FirebaseCrashlytics.instance
                              .recordError(e, stackTrace);
                        }
                        smState.clearSnackBars();
                        smState.showSnackBar(SnackBar(
                            backgroundColor: colorScheme.error,
                            content: Text('Error.',
                                style: bodyMedium.copyWith(
                                    color: colorScheme.onError))));
                      }
                    } else {
                      setState(() => _enableBt = true);
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
