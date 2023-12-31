import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:connectycube_sdk/connectycube_sdk.dart';
import 'package:universal_io/io.dart';

import 'firebase_options.dart';
import 'src/chat_details_screen.dart';
import 'src/chat_dialog_screen.dart';
import 'src/chat_dialog_resizable_screen.dart';
import 'src/login_screen.dart';
import 'src/managers/push_notifications_manager.dart';
import 'src/select_dialog_screen.dart';
import 'src/settings_screen.dart';
import 'src/utils/auth_utils.dart';
import 'src/utils/configs.dart' as config;
import 'src/utils/consts.dart';
import 'src/utils/platform_utils.dart' as platformUtils;
import 'src/utils/pref_util.dart';
import 'src/utils/route_utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  log('[main]');

  if (kIsWeb || !(Platform.isLinux && Platform.isWindows)) {
    log('[main] init Firebase');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
      name: "DemoChatSdk",
      // options: FirebaseOptions(
      //   apiKey: 'AIzaSyCWMwKKR6r-9eS_N2EUl_x4gg1EkW6ly34',
      //   appId: '1:697503742825:android:7814077f092ba4245fdbf8',
      //   messagingSenderId: '697503742825',
      //   projectId: 'connnectycubesamples',
      //   databaseURL: 'https://connnectycubesamples-default-rtdb.firebaseio.com',
      //   storageBucket: 'connnectycubesamples.appspot.com',
      // ),
    );

    FirebaseMessaging.onBackgroundMessage(onBackgroundMessage);
  }

  runApp(App());
}

class App extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _AppState();
  }
}

class _AppState extends State<App> with WidgetsBindingObserver {
  late StreamSubscription<ConnectivityResult> connectivityStateSubscription;
  AppLifecycleState? appState;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: LoginScreen(),
      navigatorKey: Navigation.mainNavigation,
      onGenerateRoute: (settings) {
        String? name = settings.name;
        Map<String, dynamic>? args =
            settings.arguments as Map<String, dynamic>?;

        MaterialPageRoute pageRout;

        switch (name) {
          case 'chat_dialog':
            pageRout = MaterialPageRoute(
                builder: (context) => platformUtils.isDesktop()
                    ? ChatDialogResizableScreen(
                        args![USER_ARG_NAME], args[DIALOG_ARG_NAME])
                    : ChatDialogScreen(
                        args![USER_ARG_NAME], args[DIALOG_ARG_NAME]));
            break;

          case 'chat_dialog_resizable':
            pageRout = MaterialPageRoute<bool>(
              builder: (context) => ChatDialogResizableScreen(
                  args![USER_ARG_NAME], args[DIALOG_ARG_NAME]),
            );

            break;

          case 'chat_details':
            pageRout = MaterialPageRoute(
                builder: (context) => ChatDetailsScreen(
                    args![USER_ARG_NAME], args[DIALOG_ARG_NAME]));
            break;

          case 'select_dialog':
            pageRout = MaterialPageRoute<bool>(
                builder: (context) => platformUtils.isDesktop()
                    ? ChatDialogResizableScreen(
                        args![USER_ARG_NAME], args[DIALOG_ARG_NAME])
                    : SelectDialogScreen(args![USER_ARG_NAME], null, null));

            break;

          case 'login':
            pageRout = MaterialPageRoute(builder: (context) => LoginScreen());
            break;

          case 'settings':
            pageRout = MaterialPageRoute(
                builder: (context) => SettingsScreen(args![USER_ARG_NAME]));
            break;

          default:
            pageRout = MaterialPageRoute(builder: (context) => LoginScreen());

            break;
        }

        PushNotificationsManager.instance.onNotificationClicked = (payload) {
          return onNotificationSelected(payload, pageRout.subtreeContext);
        };

        return pageRout;
      },
    );
  }

  @override
  void initState() {
    super.initState();

    init(config.APP_ID, config.AUTH_KEY, config.AUTH_SECRET,
        onSessionRestore: () async {
      SharedPrefs sharedPrefs = await SharedPrefs.instance.init();
      log('onSessionRestore richa  = ${sharedPrefs.getUser()})');

      if (LoginType.phone == sharedPrefs.getLoginType()) {
        return createPhoneAuthSession();
      }

      return createSession(sharedPrefs.getUser());
    });

    // setEndpoints("", ""); // set custom API and Char server domains

    connectivityStateSubscription =
        Connectivity().onConnectivityChanged.listen((connectivityType) {
      if (AppLifecycleState.resumed != appState) return;

      if (connectivityType != ConnectivityResult.none) {
        log("chatConnectionState = ${CubeChatConnection.instance.chatConnectionState}");
        bool isChatDisconnected =
            CubeChatConnection.instance.chatConnectionState ==
                    CubeChatConnectionState.Closed ||
                CubeChatConnection.instance.chatConnectionState ==
                    CubeChatConnectionState.ForceClosed;

        if (isChatDisconnected &&
            CubeChatConnection.instance.currentUser != null) {
          CubeChatConnection.instance.relogin();
        }
      }
    });

    appState = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    connectivityStateSubscription.cancel();

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    log("Current app state: $state");
    appState = state;

    if (AppLifecycleState.paused == state) {
      if (CubeChatConnection.instance.isAuthenticated()) {
        CubeChatConnection.instance.markInactive();
      }
    } else if (AppLifecycleState.resumed == state) {
      // just for an example user was saved in the local storage
      SharedPrefs.instance.init().then((sharedPrefs) async {
        CubeUser? user = sharedPrefs.getUser();

        if (user != null) {
          if (!CubeChatConnection.instance.isAuthenticated()) {
            if (LoginType.phone == sharedPrefs.getLoginType()) {
              if(CubeSessionManager.instance.isActiveSessionValid()){
                user.password = CubeSessionManager.instance.activeSession?.token;
              } else {
                var phoneAuthSession = await createPhoneAuthSession();
                user.password = phoneAuthSession.token;
                log('phoneAuthSession.token = ${phoneAuthSession.token}');
              }
            }
            log('login richa = $user');
            CubeChatConnection.instance.login(user);
          } else {
            log('markActive richa  = $user');
            CubeChatConnection.instance.markActive();
          }
        }
      });
    }
  }
}
