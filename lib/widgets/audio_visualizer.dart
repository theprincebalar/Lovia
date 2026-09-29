import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AudioVisualizer extends StatelessWidget {
  final List<double> frequencies;
  final Color barColor;
  final double height;
  final double width;
  final bool isSpeaking;
  final bool isUserSpeaking;

  const AudioVisualizer({
    super.key,
    required this.frequencies,
    this.barColor = AppColors.primary,
    this.height = 70,
    this.width = double.infinity,
    this.isSpeaking = true,
    this.isUserSpeaking = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: frequencies.asMap().entries.map((entry) {
          final val = entry.value;
          final barHeight = isSpeaking ? (height * val).clamp(6.0, height) : 4.0;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOutQuad,
            width: 4,
            height: barHeight,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: isSpeaking ? null : Colors.white.withOpacity(0.18),
              gradient: isSpeaking
                  ? LinearGradient(
                      colors: isUserSpeaking
                          ? const [Color(0xFF00D2FF), Color(0xFF0077B6)]
                          : [barColor, AppColors.secondary],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    )
                  : null,
              boxShadow: isSpeaking
                  ? [
                      BoxShadow(
                        color: (isUserSpeaking ? const Color(0xFF00D2FF) : barColor).withOpacity(0.45),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}
