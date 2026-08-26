import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class MobileError extends StatelessWidget {
  final VoidCallback onRefreshButtonPressed;
  const MobileError({super.key, required this.onRefreshButtonPressed});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Lottie.asset('assets/lotties/404Page.json'),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            "حدثت مشكلة أثناء محاولة الوصول للموقع، نرجوا التحقق من اتصالك بالإنترنت.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
            onPressed: onRefreshButtonPressed, child: const Text("حدث الصفحة"))
      ],
    );
  }
  
}
