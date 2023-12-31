import 'dart:async';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:connectycube_sdk/src/chat/realtime/managers/last_activity_manager.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';

import 'create_dialog_flow.dart';
import 'managers/chat_manager.dart';
import 'settings_screen.dart';
import 'utils/api_utils.dart';
import 'utils/consts.dart';
import 'utils/platform_utils.dart';
import 'widgets/common.dart';

class SelectDialogScreen extends StatelessWidget {
  static const String TAG = "SelectDialogScreen";
  final CubeUser currentUser;
  final Function(CubeDialog)? onDialogSelectedCallback;
  final CubeDialog? selectedDialog;

  SelectDialogScreen(
      this.currentUser, this.selectedDialog, this.onDialogSelectedCallback);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _onBackPressed(),
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            'Logged in as ${currentUser.fullName ?? currentUser.login ?? currentUser.email}',
          ),
          actions: <Widget>[
            IconButton(
              onPressed: () => _openSettings(context),
              icon: Icon(
                Icons.settings,
                color: Colors.white,
              ),
            ),
          ],
        ),
        body: BodyLayout(currentUser, selectedDialog, onDialogSelectedCallback),
      ),
    );
  }

  Future<bool> _onBackPressed() {
    return Future.value(true);
  }

  _openSettings(BuildContext context) {
    showModal(context: context, child: SettingsScreen(currentUser));
  }
}

class BodyLayout extends StatefulWidget {
  final CubeUser currentUser;
  final Function(CubeDialog)? onDialogSelectedCallback;
  final CubeDialog? selectedDialog;

  BodyLayout(
      this.currentUser, this.selectedDialog, this.onDialogSelectedCallback);

  @override
  State<StatefulWidget> createState() {
    return _BodyLayoutState(
        currentUser, selectedDialog, onDialogSelectedCallback);
  }
}

class _BodyLayoutState extends State<BodyLayout> {
  static const String TAG = "_BodyLayoutState";

  final CubeUser currentUser;
  List<ListItem<CubeDialog>> dialogList = [];
  var _isDialogContinues = true;

  StreamSubscription<CubeMessage>? msgSubscription;
  StreamSubscription<MessageStatus>? msgDeliveringSubscription;
  StreamSubscription<MessageStatus>? msgReadingSubscription;
  StreamSubscription<MessageStatus>? msgLocalReadingSubscription;
  StreamSubscription<CubeMessage>? msgSendingSubscription;
  StreamSubscription<LastActivitySubscriptionEvent>? lastActSubscription;
  final ChatMessagesManager? chatMessagesManager =
      CubeChatConnection.instance.chatMessagesManager;
  Function(CubeDialog)? onDialogSelectedCallback;
  CubeDialog? selectedDialog;

  Map<String, Set<String>> unreadMessages = {};

  _BodyLayoutState(
      this.currentUser, this.selectedDialog, this.onDialogSelectedCallback);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: EdgeInsets.only(top: 2),
        child: Column(
          children: [
            Visibility(
              visible: _isDialogContinues && dialogList.isEmpty,
              child: Container(
                margin: EdgeInsets.all(40),
                alignment: FractionalOffset.center,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
            Expanded(
              child: _getDialogsList(context),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "New dialog",
        child: Icon(
          Icons.add_comment,
          color: Colors.white,
        ),
        backgroundColor: Colors.blue,
        onPressed: () => _createNewDialog(context),
      ),
    );
  }

  void _createNewDialog(BuildContext context) async {
    showModal(context: context, child: CreateDialog(currentUser));
  }

  void _processGetDialogError(exception) {
    log("GetDialog error $exception", TAG);
    setState(() {
      _isDialogContinues = false;
    });
    showDialogError(exception, context);
  }

  Widget _getDialogsList(BuildContext context) {
    if (_isDialogContinues) {
      getDialogs().then((dialogs) {
        _isDialogContinues = false;
        log("getDialogs: $dialogs", TAG);
        setState(() {
          dialogList.clear();
          dialogList.addAll(
              dialogs?.items.map((dialog) => ListItem(dialog)).toList() ?? []);
        });
      }).catchError((exception) {
        _processGetDialogError(exception);
      });
    }
    if (_isDialogContinues && dialogList.isEmpty)
      return SizedBox.shrink();
    else if (dialogList.isEmpty)
      return Center(
        child: Text(
          'No dialogs yet',
          style: TextStyle(fontSize: 20),
        ),
      );
    else
      return ListView.separated(
        itemCount: dialogList.length,
        itemBuilder: _getListItemTile,
        separatorBuilder: (context, index) {
          return Divider(
            thickness: 1,
            indent: 68,
            height: 1,
          );
        },
      );
  }

  Widget _getListItemTile(BuildContext context, int index) {
    Widget getDialogIcon() {
      var dialog = dialogList[index].data;
      if (dialog.type == CubeDialogType.PRIVATE)
        return Icon(
          Icons.person,
          size: 40.0,
          color: greyColor,
        );
      else {
        return Icon(
          Icons.group,
          size: 40.0,
          color: greyColor,
        );
      }
    }

    getDialogAvatar() {
      var dialog = dialogList[index].data;

      return getDialogAvatarWidget(dialog, 25,
          placeholder: getDialogIcon(), errorWidget: getDialogIcon());
    }

    return Container(
      color: selectedDialog != null &&
          selectedDialog!.dialogId == dialogList[index].data.dialogId
          ? Color.fromARGB(100, 168, 228, 160)
          : null,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        child: Row(
          children: <Widget>[
            getDialogAvatar(),
            Flexible(
              child: Container(
                child: Column(
                  children: <Widget>[
                    Container(
                      child: Text(
                        '${dialogList[index].data.name ?? 'Unknown dialog'}',
                        style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16.0,
                            overflow: TextOverflow.ellipsis),
                        maxLines: 1,
                      ),
                      alignment: Alignment.centerLeft,
                    ),
                    Container(
                      child: Text(
                        '${dialogList[index].data.lastMessage ?? ''}',
                        style: TextStyle(
                            color: primaryColor,
                            overflow: TextOverflow.ellipsis),
                        maxLines: 2,
                      ),
                      alignment: Alignment.centerLeft,
                    ),
                  ],
                ),
                margin: EdgeInsets.only(left: 8.0),
              ),
            ),
            Visibility(
              child: IconButton(
                iconSize: 25.0,
                icon: Icon(
                  Icons.delete,
                  color: themeColor,
                ),
                onPressed: () {
                  _deleteDialog(context, dialogList[index].data);
                },
              ),
              maintainAnimation: true,
              maintainState: true,
              visible: dialogList[index].isSelected,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    getMessageStateWidget(
                        dialogList[index].data.lastMessageState),
                    Text(
                      '${DateFormat('MMM dd').format(dialogList[index].data.lastMessageDateSent != null ? DateTime.fromMillisecondsSinceEpoch(dialogList[index].data.lastMessageDateSent! * 1000) : dialogList[index].data.updatedAt!)}',
                      style: TextStyle(color: primaryColor),
                    ),
                  ],
                ),
                if (dialogList[index].data.unreadMessageCount != null &&
                    dialogList[index].data.unreadMessageCount != 0)
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                      decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(10.0)),
                      child: Text(
                        dialogList[index].data.unreadMessageCount.toString(),
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        onLongPress: () {
          setState(() {
            dialogList[index].isSelected = !dialogList[index].isSelected;
          });
        },
        onTap: () {
          _selectDialog(context, dialogList[index].data);
        },
      ),
      padding: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
    );
  }

  void _deleteDialog(BuildContext context, CubeDialog dialog) async {
    log("_deleteDialog= $dialog");
    Fluttertoast.showToast(msg: 'Coming soon');
  }

  void _selectDialog(BuildContext context, CubeDialog dialog) async {
    if (onDialogSelectedCallback != null) {
      onDialogSelectedCallback?.call(dialog);
      setState(() {
        selectedDialog = dialog;
      });
    } else {
      Navigator.pushNamed(context, 'chat_dialog',
          arguments: {USER_ARG_NAME: currentUser, DIALOG_ARG_NAME: dialog});
    }
  }

  void refresh() {
    setState(() {
      _isDialogContinues = true;
    });
  }

  @override
  void initState() {
    super.initState();
    refreshBadgeCount();
    msgSubscription =
        chatMessagesManager!.chatMessagesStream.listen(onReceiveMessage);
    msgDeliveringSubscription = CubeChatConnection
        .instance.messagesStatusesManager?.deliveredStream
        .listen(onMessageDelivered);
    msgReadingSubscription = CubeChatConnection
        .instance.messagesStatusesManager?.readStream
        .listen(onMessageRead);
    msgLocalReadingSubscription =
        ChatManager.instance.readMessagesStream.listen(onMessageRead);
    msgSendingSubscription =
        ChatManager.instance.sentMessagesStream.listen(onReceiveMessage);


  }

  @override
  void dispose() {
    super.dispose();
    log("dispose", TAG);
    msgSubscription?.cancel();
    msgDeliveringSubscription?.cancel();
    msgReadingSubscription?.cancel();
    msgLocalReadingSubscription?.cancel();
    msgSendingSubscription?.cancel();
  }

  void onReceiveMessage(CubeMessage message) {
    log("onReceiveMessage global message= $message");
    updateDialog(message);
  }

  updateDialog(CubeMessage msg) {
    refreshBadgeCount();

    ListItem<CubeDialog>? dialogItem =
    dialogList.firstWhereOrNull((dlg) => dlg.data.dialogId == msg.dialogId);
    if (dialogItem == null) return;

    setState(() {
      dialogItem.data.lastMessage = msg.body;
      dialogItem.data.lastMessageId = msg.messageId;

      if (msg.senderId != currentUser.id) {
        dialogItem.data.unreadMessageCount =
        dialogItem.data.unreadMessageCount == null
            ? 1
            : dialogItem.data.unreadMessageCount! + 1;

        unreadMessages[msg.dialogId!] = <String>[
          ...unreadMessages[msg.dialogId] ?? [],
          msg.messageId!
        ].toSet();

        dialogItem.data.lastMessageState = null;
      } else {
        dialogItem.data.lastMessageState = MessageState.sent;
      }

      dialogItem.data.lastMessageDateSent = msg.dateSent;
      dialogList.sort((a, b) {
        DateTime dateA;
        if (a.data.lastMessageDateSent != null) {
          dateA = DateTime.fromMillisecondsSinceEpoch(
              a.data.lastMessageDateSent! * 1000);
        } else {
          dateA = a.data.updatedAt!;
        }

        DateTime dateB;
        if (b.data.lastMessageDateSent != null) {
          dateB = DateTime.fromMillisecondsSinceEpoch(
              b.data.lastMessageDateSent! * 1000);
        } else {
          dateB = b.data.updatedAt!;
        }

        if (dateA.isAfter(dateB)) {
          return -1;
        } else if (dateA.isBefore(dateB)) {
          return 1;
        } else {
          return 0;
        }
      });
    });
  }

  void onMessageDelivered(MessageStatus messageStatus) {
    _updateLastMessageState(messageStatus, MessageState.delivered);
  }

  void onMessageRead(MessageStatus messageStatus) {
    _updateLastMessageState(messageStatus, MessageState.read);

    if (messageStatus.userId == currentUser.id &&
        unreadMessages.containsKey(messageStatus.dialogId)) {
      if (unreadMessages[messageStatus.dialogId]
          ?.remove(messageStatus.messageId) ??
          false) {
        setState(() {
          var dialog = dialogList
              .firstWhereOrNull(
                  (dlg) => dlg.data.dialogId == messageStatus.dialogId)
              ?.data;

          if (dialog == null) return;

          dialog.unreadMessageCount = dialog.unreadMessageCount == null ||
              dialog.unreadMessageCount == 0
              ? 0
              : dialog.unreadMessageCount! - 1;
        });
      }
    }
  }

  void _updateLastMessageState(
      MessageStatus messageStatus, MessageState state) {
    var dialog = dialogList
        .firstWhereOrNull((dlg) => dlg.data.dialogId == messageStatus.dialogId)
        ?.data;

    if (dialog == null) return;

    if (messageStatus.messageId == dialog.lastMessageId &&
        messageStatus.userId != currentUser.id) {
      if (dialog.lastMessageState != state) {
        setState(() {
          dialog.lastMessageState = state;
        });
      }
    }
  }


}
