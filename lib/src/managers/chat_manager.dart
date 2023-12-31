import 'dart:async';

import 'package:connectycube_sdk/connectycube_sdk.dart';

class ChatManager {
  static ChatManager? _instance;

  ChatManager._();

  static ChatManager get instance => _instance ??= ChatManager._();

  StreamController<CubeMessage> sentMessagesController =
      StreamController.broadcast();

  Stream<CubeMessage> get sentMessagesStream {
    return sentMessagesController.stream;
  }

  StreamController<CubeMessage> isOnlineController =
  StreamController.broadcast();

  Stream<CubeMessage> get isOnlineStream {
    return isOnlineController.stream;
  }


  StreamController<MessageStatus> readMessagesController =
      StreamController.broadcast();

  Stream<MessageStatus> get readMessagesStream {
    return readMessagesController.stream;
  }
}
