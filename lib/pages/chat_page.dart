import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_app/constants/constants.dart';
import 'package:flutter_chat_app/models/models.dart';
import 'package:flutter_chat_app/pages/pages.dart';
import 'package:flutter_chat_app/providers/providers.dart';
import 'package:flutter_chat_app/widgets/widgets.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.arguments});

  final ChatPageArguments arguments;

  @override
  ChatPageState createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> {
  late final String _currentUserId;

  List<QueryDocumentSnapshot> _listMessage = [];
  int _limit = 20;
  final _limitIncrement = 20;
  String _groupChatId = "";

  final bool _isLoading = false;

  final _chatInputController = TextEditingController();
  final _listScrollController = ScrollController();
  final _focusNode = FocusNode();

  late final _chatProvider = context.read<ChatProvider>();
  late final _authProvider = context.read<AuthProvider>();

  @override
  void initState() {
    super.initState();
    _listScrollController.addListener(_scrollListener);
    _readLocal();
  }

  @override
  void dispose() {
    _chatInputController.dispose();
    _listScrollController
      ..removeListener(_scrollListener)
      ..dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (!_listScrollController.hasClients) return;
    if (_listScrollController.offset >=
            _listScrollController.position.maxScrollExtent &&
        !_listScrollController.position.outOfRange &&
        _limit <= _listMessage.length) {
      setState(() {
        _limit += _limitIncrement;
      });
    }
  }

  void _readLocal() {
    if (_authProvider.userFirebaseId?.isNotEmpty == true) {
      _currentUserId = _authProvider.userFirebaseId!;
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    }
    String peerId = widget.arguments.peerId;
    if (_currentUserId.compareTo(peerId) > 0) {
      _groupChatId = '$_currentUserId-$peerId';
    } else {
      _groupChatId = '$peerId-$_currentUserId';
    }

    _chatProvider.updateDataFirestore(
      FirestoreConstants.pathUserCollection,
      _currentUserId,
      {FirestoreConstants.chattingWith: peerId},
    );
  }

  void _onSendMessage(String content, int type) {
    if (content.trim().isNotEmpty) {
      _chatInputController.clear();
      _chatProvider.sendMessage(
          content, type, _groupChatId, _currentUserId, widget.arguments.peerId);
      if (_listScrollController.hasClients) {
        _listScrollController.animateTo(0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } else {
      Fluttertoast.showToast(
          msg: 'Nothing to send', backgroundColor: ColorConstants.greyColor);
    }
  }

  Widget _buildItemMessage(int index, DocumentSnapshot? document) {
    if (document == null) return const SizedBox.shrink();
    final messageChat = MessageChat.fromDocument(document);
    if (messageChat.idFrom == _currentUserId) {
      // Right (my message)
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          messageChat.type == TypeMessage.text
              // Text
              ? Container(
                  padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
                  width: 200,
                  decoration: BoxDecoration(
                      color: ColorConstants.greyColor2,
                      borderRadius: BorderRadius.circular(8)),
                  margin: EdgeInsets.only(
                      bottom: _isLastMessageRight(index) ? 20 : 10, right: 10),
                  child: Text(
                    messageChat.content,
                    style: const TextStyle(color: ColorConstants.primaryColor),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
                  width: 200,
                  decoration:
                      BoxDecoration(borderRadius: BorderRadius.circular(8)),
                  margin: EdgeInsets.only(
                      bottom: _isLastMessageRight(index) ? 20 : 10, right: 10),
                  child: const Text(
                    "Unable to show message!",
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                )
        ],
      );
    } else {
      // Left (peer message)
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipOval(
                  child: _isLastMessageLeft(index)
                      ? Image.network(
                          widget.arguments.peerAvatar,
                          loadingBuilder: (_, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                color: ColorConstants.themeColor,
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) {
                            return const Icon(
                              Icons.account_circle,
                              size: 35,
                              color: ColorConstants.greyColor,
                            );
                          },
                          width: 35,
                          height: 35,
                          fit: BoxFit.cover,
                        )
                      : Container(width: 35),
                ),
                messageChat.type == TypeMessage.text
                    ? Container(
                        padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
                        width: 200,
                        decoration: BoxDecoration(
                            color: ColorConstants.primaryColor,
                            borderRadius: BorderRadius.circular(8)),
                        margin: const EdgeInsets.only(left: 10),
                        child: Text(
                          messageChat.content,
                          style: const TextStyle(color: Colors.white),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
                        width: 200,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8)),
                        margin: const EdgeInsets.only(left: 10),
                        child: const Text(
                          "Unable to show message!",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
              ],
            ),

            // Time
            _isLastMessageLeft(index)
                ? Container(
                    margin: const EdgeInsets.only(left: 50, top: 5, bottom: 5),
                    child: Text(
                      DateFormat('dd MMM kk:mm').format(
                          DateTime.fromMillisecondsSinceEpoch(
                              int.parse(messageChat.timestamp))),
                      style: const TextStyle(
                          color: ColorConstants.greyColor,
                          fontSize: 12,
                          fontStyle: FontStyle.italic),
                    ),
                  )
                : const SizedBox.shrink()
          ],
        ),
      );
    }
  }

  bool _isLastMessageLeft(int index) {
    if ((index > 0 &&
            _listMessage[index - 1].get(FirestoreConstants.idFrom) ==
                _currentUserId) ||
        index == 0) {
      return true;
    } else {
      return false;
    }
  }

  bool _isLastMessageRight(int index) {
    if ((index > 0 &&
            _listMessage[index - 1].get(FirestoreConstants.idFrom) !=
                _currentUserId) ||
        index == 0) {
      return true;
    } else {
      return false;
    }
  }

  void _onBackPress() {
    _chatProvider.updateDataFirestore(
      FirestoreConstants.pathUserCollection,
      _currentUserId,
      {FirestoreConstants.chattingWith: null},
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.arguments.peerNickname,
          style: const TextStyle(color: ColorConstants.primaryColor),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: PopScope(
          canPop: false,
          onPopInvoked: (didPop) {
            if (didPop) return;
            _onBackPress();
          },
          child: Stack(
            children: [
              Column(
                children: [
                  _buildListMessage(),
                  _buildInput(),
                ],
              ),
              Positioned(
                child:
                    _isLoading ? const LoadingView() : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: const BoxDecoration(
          border: Border(
              top: BorderSide(color: ColorConstants.greyColor2, width: 0.5)),
          color: Colors.white),
      child: Row(
        children: [
          // chat input
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: TextField(
                onSubmitted: (_) {
                  _onSendMessage(_chatInputController.text, TypeMessage.text);
                },
                style: const TextStyle(
                    color: ColorConstants.primaryColor, fontSize: 15),
                controller: _chatInputController,
                decoration: const InputDecoration.collapsed(
                  hintText: 'Type your message...',
                  hintStyle: TextStyle(color: ColorConstants.greyColor),
                ),
                focusNode: _focusNode,
              ),
            ),
          ),

          // Button send message
          Material(
            color: Colors.white,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: IconButton(
                icon: const Icon(Icons.send),
                onPressed: () =>
                    _onSendMessage(_chatInputController.text, TypeMessage.text),
                color: ColorConstants.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListMessage() {
    return Flexible(
      child: _groupChatId.isNotEmpty
          ? StreamBuilder<QuerySnapshot>(
              stream: _chatProvider.getChatStream(_groupChatId, _limit),
              builder: (_, snapshot) {
                if (snapshot.hasData) {
                  _listMessage = snapshot.data!.docs;
                  if (_listMessage.isNotEmpty) {
                    return ListView.builder(
                      padding: const EdgeInsets.all(10),
                      itemBuilder: (_, index) =>
                          _buildItemMessage(index, snapshot.data?.docs[index]),
                      itemCount: snapshot.data?.docs.length,
                      reverse: true,
                      controller: _listScrollController,
                    );
                  } else {
                    return const Center(child: Text("No message here yet..."));
                  }
                } else {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: ColorConstants.themeColor,
                    ),
                  );
                }
              },
            )
          : const Center(
              child: CircularProgressIndicator(
                color: ColorConstants.themeColor,
              ),
            ),
    );
  }
}

class ChatPageArguments {
  final String peerId;
  final String peerAvatar;
  final String peerNickname;

  ChatPageArguments(
      {required this.peerId,
      required this.peerAvatar,
      required this.peerNickname});
}
