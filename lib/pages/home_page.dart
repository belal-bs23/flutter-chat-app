import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_app/constants/constants.dart';
import 'package:flutter_chat_app/models/models.dart';
import 'package:flutter_chat_app/pages/pages.dart';
import 'package:flutter_chat_app/providers/providers.dart';
import 'package:flutter_chat_app/utils/utils.dart';
import 'package:flutter_chat_app/widgets/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final _firebaseMessaging = FirebaseMessaging.instance;
  final _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final _listScrollController = ScrollController();

  int _limit = 20;
  final _limitIncrement = 20;
  String _textSearch = "";
  final bool _isLoading = false;

  late final _authProvider = context.read<AuthProvider>();
  late final _homeProvider = context.read<HomeProvider>();
  late final String _currentUserId;

  final _searchDebouncer = Debouncer(milliseconds: 300);
  final _btnClearController = StreamController<bool>();
  final _searchBarController = TextEditingController();

  final _menus = <MenuSetting>[
    const MenuSetting(title: 'Settings', icon: Icons.settings),
    const MenuSetting(title: 'Log out', icon: Icons.exit_to_app),
  ];

  @override
  void initState() {
    super.initState();
    if (_authProvider.userFirebaseId?.isNotEmpty == true) {
      _currentUserId = _authProvider.userFirebaseId!;
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    }
    _registerNotification();
    _configLocalNotification();
    _listScrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _btnClearController.close();
    _searchBarController.dispose();
    _listScrollController
      ..removeListener(_scrollListener)
      ..dispose();
    super.dispose();
  }

  void _registerNotification() {
    _firebaseMessaging.requestPermission();

    FirebaseMessaging.onMessage.listen((message) {
      // print('onMessage: $message');
      if (message.notification != null) {
        _showNotification(message.notification!);
      }
      return;
    });

    _firebaseMessaging.getToken().then((token) {
      // print('push token: $token');
      if (token != null) {
        _homeProvider.updateDataFirestore(FirestoreConstants.pathUserCollection,
            _currentUserId, {'pushToken': token});
      }
    }).catchError((err) {
      Fluttertoast.showToast(msg: err.message.toString());
    });
  }

  void _configLocalNotification() {
    const initializationSettingsAndroid =
        AndroidInitializationSettings('app_icon');
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  void _scrollListener() {
    if (_listScrollController.offset >=
            _listScrollController.position.maxScrollExtent &&
        !_listScrollController.position.outOfRange) {
      setState(() {
        _limit += _limitIncrement;
      });
    }
  }

  void _onItemMenuPress(MenuSetting choice) {
    if (choice.title == 'Log out') {
      _handleSignOut();
    } else {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const SettingsPage()));
    }
  }

  void _showNotification(RemoteNotification remoteNotification) async {
    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      Platform.isAndroid
          ? 'com.dfa.flutterchatdemo'
          : 'com.duytq.flutterchatdemo',
      'Flutter chat demo',
      playSound: true,
      enableVibration: true,
      importance: Importance.max,
      priority: Priority.high,
    );
    // ignore: prefer_const_constructors
    final iOSPlatformChannelSpecifics = DarwinNotificationDetails();
    final platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    // print(remoteNotification);

    await _flutterLocalNotificationsPlugin.show(
      0,
      remoteNotification.title,
      remoteNotification.body,
      platformChannelSpecifics,
      payload: null,
    );
  }

  Future<void> _handleSignOut() async {
    await _authProvider.handleSignOut();
    // ignore: use_build_context_synchronously
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          AppConstants.homeTitle,
          style: TextStyle(color: ColorConstants.primaryColor),
        ),
        centerTitle: true,
        actions: [_buildPopupMenu()],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _homeProvider.getStreamFireStore(
                      FirestoreConstants.pathUserCollection,
                      _limit,
                      _textSearch,
                    ),
                    builder: (_, snapshot) {
                      if (snapshot.hasData) {
                        if ((snapshot.data?.docs.length ?? 0) > 0) {
                          return ListView.builder(
                            padding: const EdgeInsets.all(10),
                            itemBuilder: (_, index) =>
                                _buildItem(snapshot.data?.docs[index]),
                            itemCount: snapshot.data?.docs.length,
                            controller: _listScrollController,
                          );
                        } else {
                          return const Center(
                            child: Text("No users"),
                          );
                        }
                      } else {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: ColorConstants.themeColor,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              child: _isLoading ? const LoadingView() : const SizedBox.shrink(),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: ColorConstants.greyColor2,
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.search, color: ColorConstants.greyColor, size: 20),
          const SizedBox(width: 5),
          Expanded(
            child: TextFormField(
              textInputAction: TextInputAction.search,
              controller: _searchBarController,
              onChanged: (value) {
                _searchDebouncer.run(
                  () {
                    if (value.isNotEmpty) {
                      _btnClearController.add(true);
                      setState(() {
                        _textSearch = value;
                      });
                    } else {
                      _btnClearController.add(false);
                      setState(() {
                        _textSearch = "";
                      });
                    }
                  },
                );
              },
              decoration: const InputDecoration.collapsed(
                hintText: 'Search by name (Exact match)',
                hintStyle:
                    TextStyle(fontSize: 13, color: ColorConstants.greyColor),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          StreamBuilder<bool>(
            stream: _btnClearController.stream,
            builder: (_, snapshot) {
              return snapshot.data == true
                  ? GestureDetector(
                      onTap: () {
                        _searchBarController.clear();
                        _btnClearController.add(false);
                        setState(() {
                          _textSearch = "";
                        });
                      },
                      child: const Icon(Icons.clear_rounded,
                          color: ColorConstants.greyColor, size: 20))
                  : const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPopupMenu() {
    return PopupMenuButton<MenuSetting>(
      onSelected: _onItemMenuPress,
      itemBuilder: (_) {
        return _menus.map(
          (choice) {
            return PopupMenuItem<MenuSetting>(
                value: choice,
                child: Row(
                  children: [
                    Icon(
                      choice.icon,
                      color: ColorConstants.primaryColor,
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Text(
                      choice.title,
                      style:
                          const TextStyle(color: ColorConstants.primaryColor),
                    ),
                  ],
                ));
          },
        ).toList();
      },
    );
  }

  Widget _buildItem(DocumentSnapshot? document) {
    if (document != null) {
      final userChat = UserChat.fromDocument(document);
      if (userChat.id == _currentUserId) {
        return const SizedBox.shrink();
      } else {
        return Container(
          margin: const EdgeInsets.only(bottom: 10, left: 5, right: 5),
          child: TextButton(
            onPressed: () {
              if (Utilities.isKeyboardShowing(context)) {
                Utilities.closeKeyboard();
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatPage(
                    arguments: ChatPageArguments(
                      peerId: userChat.id,
                      peerAvatar: userChat.photoUrl,
                      peerNickname: userChat.nickname,
                    ),
                  ),
                ),
              );
            },
            style: ButtonStyle(
              backgroundColor:
                  MaterialStateProperty.all<Color>(ColorConstants.cardColor),
              shape: MaterialStateProperty.all<OutlinedBorder>(
                const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
            ),
            child: Row(
              children: [
                ClipOval(
                  child: userChat.photoUrl.isNotEmpty
                      ? Image.network(
                          userChat.photoUrl,
                          fit: BoxFit.cover,
                          width: 50,
                          height: 50,
                          loadingBuilder: (_, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return SizedBox(
                              width: 50,
                              height: 50,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: ColorConstants.themeColor,
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, object, stackTrace) {
                            return const Icon(
                              Icons.account_circle,
                              size: 50,
                              color: ColorConstants.greyColor,
                            );
                          },
                        )
                      : const Icon(
                          Icons.account_circle,
                          size: 50,
                          color: ColorConstants.greyColor,
                        ),
                ),
                Flexible(
                  child: Container(
                    margin: const EdgeInsets.only(left: 20),
                    child: Column(
                      children: [
                        Container(
                          alignment: Alignment.centerLeft,
                          margin: const EdgeInsets.fromLTRB(10, 0, 0, 5),
                          child: Text(
                            userChat.nickname,
                            maxLines: 1,
                            style: const TextStyle(
                                color: ColorConstants.primaryColor,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          alignment: Alignment.centerLeft,
                          margin: const EdgeInsets.fromLTRB(10, 0, 0, 0),
                          child: Text(
                            userChat.aboutMe == ""
                                ? "Hi, I am using ${AppConstants.appTitle}!"
                                : userChat.aboutMe,
                            maxLines: 1,
                            style: const TextStyle(
                              color: ColorConstants.primaryColor,
                              fontSize: 14,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } else {
      return const SizedBox.shrink();
    }
  }
}
