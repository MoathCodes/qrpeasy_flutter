import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class MobileGettingUserData extends StatelessWidget {
  const MobileGettingUserData({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Lottie.asset('assets/lotties/userdata.json'),
    );
  }
}
