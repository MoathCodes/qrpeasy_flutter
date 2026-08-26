import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:qrpeasy_flutter/core/enums/page_status.dart';
import 'package:qrpeasy_flutter/core/env/env.dart';
import 'package:qrpeasy_flutter/widgets/mobile_error.dart';
import 'package:qrpeasy_flutter/widgets/mobile_loading.dart';
import 'package:qrpeasy_flutter/widgets/mobile_userdata.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class MobileView extends StatefulWidget {
  const MobileView({super.key});

  @override
  _MobileViewState createState() => _MobileViewState();
}

class _MobileViewState extends State<MobileView> {
  final WebViewController _webViewController = WebViewController();

  final _loadingProgress = Signal<double>(0.0);
  final _currentPageTitle = Signal<String>("Login");
  final _pageStatus = Signal<PageStatus>(PageStatus.ready);
  late Resource<String> titleResourse;

  bool didPostToken = false;

  void addFileSelectionListener() async {
    print('[DEBUG] added file selection');
    if (Platform.isAndroid) {
      final androidController =
          _webViewController.platform as AndroidWebViewController;
      await androidController.setOnShowFileSelector(_androidFilePicker);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        title: ResourceBuilder(
          resource: titleResourse,
          builder: (context, resourceState) {
            String title = resourceState.map(
              ready: (ready) => ready.value,
              error: (error) => "Page 404",
              loading: (loading) => "Loading",
            );
            return Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            );
          },
        ),
      ),
      body: SafeArea(
        child: SignalBuilder(
          signal: _loadingProgress,
          child: WebViewWidget(controller: _webViewController),
          builder: (context, value, child) {
            (bool isFinishedLoading, PageStatus pageStatus) state =
                (value > 0.7, _pageStatus.value);
            return switch (state) {
              (true, PageStatus.ready) => child ?? const SizedBox.shrink(),
              (false, PageStatus.notfound) =>
                MobileError(onRefreshButtonPressed: _refreshButton),
              (true, PageStatus.notfound) =>
                MobileError(onRefreshButtonPressed: _refreshButton),
              (false, PageStatus.gettingUserData) =>
                const MobileGettingUserData(),
              (true, PageStatus.gettingUserData) =>
                const MobileGettingUserData(),
              (_, _) => const MobileLoading(),
            };
          },
        ),
      ),
    );
  }

  Future<String> getPageTitle() async {
    final title = await _webViewController.getTitle();
    return title?.substring(10 + 1) ?? "";
  }

  Future<int?> getUserId(String url) async {
    print('[DEBUG] $url');
    if (url == '${Env.appUrl}${Env.userIdEndpoint}') {
      _pageStatus.set(PageStatus.gettingUserData);
      final jsOutput = await _webViewController
          .runJavaScriptReturningResult('document.body.innerText');

      print('[DEBUG] $jsOutput');
      // I had to decode it twice because JavaScript returns an encoded
      // Json and then webview returns it after casting it to String.
      final jsonObject = json.decode(json.decode(jsOutput.toString()));
      final userId = jsonObject['id'];
      print("[DEBUG] $userId");

      return userId;
    }
    return null;
  }

  /// This method will load the `Env.appUrl` to the webview
  ///
  /// It's currently only used in `_getUserId` method to return the user to the
  /// app after getting the id from `Env.getUserId` endpoint.
  void goToMainPage() {
    _webViewController.loadRequest(Uri.parse(Env.appUrl));
    _pageStatus.set(PageStatus.ready);
  }

  Future<void> goToUserIdEndpoint() async {
    _pageStatus.set(PageStatus.gettingUserData);
    await _webViewController
        .loadRequest(Uri.parse('${Env.appUrl}${Env.userIdEndpoint}'));
  }

  @override
  void initState() {
    super.initState();
    titleResourse =
        Resource<String>(fetcher: getPageTitle, source: _currentPageTitle);

    addFileSelectionListener();

    _webViewController
      // Allowing JavaScript, It's important to get the ID later when we inject
      // the JavaScript code to the webview.
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Set background color to transparent
      ..setBackgroundColor(const Color(0x00000000))
      // These are event that will take place during the life of the webview,
      // These handle navigations, error, 404 pages, etc.
      ..setNavigationDelegate(
        NavigationDelegate(
          // This method handles the loading state of the app, it sends the
          // AppBar title via a `Resource` and update the `_loadingProgress`
          // signal with the current progress (starts at 0 ends at 1)
          onProgress: (int progress) {
            titleResourse.set(const ResourceReady("يرجى الإنتظار..."));
            _loadingProgress.set(progress / 100);
          },
          onPageStarted: (String url) async {
            final value = await _loadingProgress.until(
              (value) => value == 1,
            );

            print("[DEBUG] We have waited for the value and it's: $value");

            // Getting the local storage
            // final SharedPreferences sharedPreferences = await SharedPreferences
            //     .getInstance(); //TODO: remove the clear method it's for debug only

            // Checks if we have sent the fcm token before, using a local
            // variable stored in `SharedPrefrences`.
            // final bool? didPostToken =
            //     sharedPreferences.getBool('post-fcm-token');

            // Here a couple of checks must happen before we send the fcm_token
            // 1. Is the user signed in, we check this by making sure that the
            // user is not in the login page (The endpoint is configured to
            // redirect the user nomatter where he is if he isn't logged in)

            // 2. We make sure that we didn't token previosly via `didPostToken`
            if (url != "${Env.appUrl}${Env.loginEndpoint}" &&
                didPostToken == false) {
              // 3. We check that we are in the endpoint that allows us to get
              // the user id, in order to send it to the backend with the token.
              await goToUserIdEndpoint();
              // We get the user id from reading the page.
              final userId = await getUserId(url);
              if (userId != null) {
                // await sharedPreferences.setBool("post-fcm-token", true);
                await postFCMToken(url, userId);
                _pageStatus.set(PageStatus.ready);
                didPostToken = true;
                goToMainPage();
              }
              //TODO: need to handle if the user is null
            }
          },
          onPageFinished: (String url) async {
            // Once a page has fully loaded we make sure that the title
            // of the page is currect
            titleResourse.refresh();
          },
          onHttpError: (HttpResponseError error) {
            if (kDebugMode) {
              print("An Http Error Occured: ${error.response?.statusCode}");
            }
            if (kDebugMode) {
              print("An Http Error Occured: ${error.request?.uri}");
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (kDebugMode) {
              print("A Web Resourse Error Occured: ${error.errorType}");
              print("A Web Resourse Error Occured: ${error.errorCode}");
              print("A Web Resourse Error Occured: ${error.description}");
            }

            _pageStatus.set(PageStatus.notfound);
          },
          onHttpAuthRequest: (request) => print("The request is $request"),
          onNavigationRequest: (NavigationRequest request) {
            if (!request.url.startsWith(Env.appUrl)) {
              return NavigationDecision.prevent;
            }
            if (request.url.contains('register')) _webViewController.goBack();
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(Env.appUrl))
      ..clearCache()
      ..reload();
  }

  // TODO: This needs refactoring & error handling.
  Future<void> postFCMToken(String url, int id) async {
    final String? fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken == null) {
      throw "Token was not found";
    }

    final uri = Uri.https(Env.appUrl.substring(8).replaceAll(r'/', ''),
        Env.fcmPostEndpoint, {'fcm_token': fcmToken, 'user_id': id.toString()});
    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode != 200) {
      print("[Debug] Request: ${response.request}");
      throw Exception(
          "Status code error - Status code: ${response.statusCode}");
    }

    print("[Debug] Token is sent");
  }

  Future<List<String>> _androidFilePicker(FileSelectorParams params) async {
    print('[DEBUG] files doing');
    final picker = ImagePicker();

    final result = await picker.pickImage(source: ImageSource.gallery);
    if (result != null) {
      final file = File(result.path);
      return [file.uri.toString()];
    }
    return [];
  }

  /// This functions is passed to the error screen `MobileError` to provide
  /// functionality to the refresh button in the `MobileError` Page.
  void _refreshButton() {
    _webViewController.reload();
    _pageStatus.set(PageStatus.ready);
  }
}
