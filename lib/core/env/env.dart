import 'package:envied/envied.dart';

part 'env.g.dart';

@envied
abstract class Env {
  @EnviedField(varName: 'APP_URL')
  static const String appUrl = _Env.appUrl;
  @EnviedField(varName: 'USER_ID_ENDPOINT')
  static const String userIdEndpoint = _Env.userIdEndpoint;
  @EnviedField(varName: 'LOGIN_ENDPOINT')
  static const String loginEndpoint = _Env.loginEndpoint;
  @EnviedField(varName: 'FCM_POST_ENDPOINT')
  static const String fcmPostEndpoint = _Env.fcmPostEndpoint;
}
