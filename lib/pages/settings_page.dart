import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_chat_app/constants/constants.dart';
import 'package:flutter_chat_app/models/models.dart';
import 'package:flutter_chat_app/providers/providers.dart';
import 'package:flutter_chat_app/widgets/loading_view.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _controllerNickname;
  late final TextEditingController _controllerAboutMe;

  String _userId = '';
  String _nickname = '';
  String _aboutMe = '';
  String _avatarUrl = '';

  bool _isLoading = false;
  File? _avatarFile;
  late final _settingProvider = context.read<SettingProvider>();

  final _focusNodeNickname = FocusNode();
  final _focusNodeAboutMe = FocusNode();

  @override
  void initState() {
    super.initState();
    _readLocal();
  }

  void _readLocal() {
    setState(() {
      _userId = _settingProvider.getPref(FirestoreConstants.id) ?? "";
      _nickname = _settingProvider.getPref(FirestoreConstants.nickname) ?? "";
      _aboutMe = _settingProvider.getPref(FirestoreConstants.aboutMe) ?? "";
      _avatarUrl = _settingProvider.getPref(FirestoreConstants.photoUrl) ?? "";
    });

    _controllerNickname = TextEditingController(text: _nickname);
    _controllerAboutMe = TextEditingController(text: _aboutMe);
  }

  void _handleUpdateData() {
    _focusNodeNickname.unfocus();
    _focusNodeAboutMe.unfocus();

    setState(() {
      _isLoading = true;
    });
    UserChat updateInfo = UserChat(
      id: _userId,
      photoUrl: _avatarUrl,
      nickname: _nickname,
      aboutMe: _aboutMe,
    );
    _settingProvider
        .updateDataFirestore(
            FirestoreConstants.pathUserCollection, _userId, updateInfo.toJson())
        .then((_) async {
      await _settingProvider.setPref(FirestoreConstants.nickname, _nickname);
      await _settingProvider.setPref(FirestoreConstants.aboutMe, _aboutMe);
      await _settingProvider.setPref(FirestoreConstants.photoUrl, _avatarUrl);

      setState(() {
        _isLoading = false;
      });

      Fluttertoast.showToast(msg: "Update success");
    }).catchError((err) {
      setState(() {
        _isLoading = false;
      });

      Fluttertoast.showToast(msg: err.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          AppConstants.settingsTitle,
          style: TextStyle(color: ColorConstants.primaryColor),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(left: 15, right: 15),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Avatar
                Container(
                  margin: const EdgeInsets.all(20),
                  child: _avatarFile == null
                      ? _avatarUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(45),
                              child: Image.network(
                                _avatarUrl,
                                fit: BoxFit.cover,
                                width: 90,
                                height: 90,
                                errorBuilder: (_, __, ___) {
                                  return const Icon(
                                    Icons.account_circle,
                                    size: 90,
                                    color: ColorConstants.greyColor,
                                  );
                                },
                                loadingBuilder: (_, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return SizedBox(
                                    width: 90,
                                    height: 90,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: ColorConstants.themeColor,
                                        value: loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                          : const Icon(
                              Icons.account_circle,
                              size: 90,
                              color: ColorConstants.greyColor,
                            )
                      : ClipOval(
                          child: Image.file(
                            _avatarFile!,
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                          ),
                        ),
                ),

                // Input
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Username
                    Container(
                      margin:
                          const EdgeInsets.only(left: 10, bottom: 5, top: 10),
                      child: const Text(
                        'Nickname',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.bold,
                          color: ColorConstants.primaryColor,
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(left: 30, right: 30),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                            primaryColor: ColorConstants.primaryColor),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Sweetie',
                            contentPadding: EdgeInsets.all(5),
                            hintStyle:
                                TextStyle(color: ColorConstants.greyColor),
                          ),
                          controller: _controllerNickname,
                          onChanged: (value) {
                            _nickname = value;
                          },
                          focusNode: _focusNodeNickname,
                        ),
                      ),
                    ),

                    // About me
                    Container(
                      margin:
                          const EdgeInsets.only(left: 10, top: 30, bottom: 5),
                      child: const Text(
                        'About me',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.bold,
                          color: ColorConstants.primaryColor,
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(left: 30, right: 30),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                            primaryColor: ColorConstants.primaryColor),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Eg. Fun and Traveller',
                            contentPadding: EdgeInsets.all(5),
                            hintStyle:
                                TextStyle(color: ColorConstants.greyColor),
                          ),
                          controller: _controllerAboutMe,
                          onChanged: (value) {
                            _aboutMe = value;
                          },
                          focusNode: _focusNodeAboutMe,
                        ),
                      ),
                    ),
                  ],
                ),

                // Button
                Container(
                  margin: const EdgeInsets.only(top: 50, bottom: 50),
                  child: TextButton(
                    onPressed: _handleUpdateData,
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(
                          ColorConstants.primaryColor),
                      padding: MaterialStateProperty.all<EdgeInsets>(
                        const EdgeInsets.fromLTRB(30, 10, 30, 10),
                      ),
                    ),
                    child: const Text(
                      'Update',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Loading
          Positioned(
              child:
                  _isLoading ? const LoadingView() : const SizedBox.shrink()),
        ],
      ),
    );
  }
}
