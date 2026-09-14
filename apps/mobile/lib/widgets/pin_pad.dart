import "package:flutter/material.dart";
import "../theme/app_theme.dart";

class PinPad extends StatelessWidget {
  final int enteredLength;
  final int pinLength;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final String? errorText;

  const PinPad({
    super.key,
    required this.enteredLength,
    required this.onDigit,
    required this.onBackspace,
    this.pinLength = 6,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(pinLength, (index) {
            final filled = index < enteredLength;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? SyrixColors.primary : Colors.transparent,
                border: Border.all(color: SyrixColors.primary),
              ),
            );
          }),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 10),
          Text(errorText!, style: const TextStyle(color: SyrixColors.danger, fontSize: 13)),
        ],
        const SizedBox(height: 28),
        _buildRow(["1", "2", "3"]),
        const SizedBox(height: 14),
        _buildRow(["4", "5", "6"]),
        const SizedBox(height: 14),
        _buildRow(["7", "8", "9"]),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 72, height: 60),
            _buildKey("0"),
            SizedBox(
              width: 72,
              height: 60,
              child: IconButton(
                icon: const Icon(Icons.backspace_outlined, color: SyrixColors.textMuted),
                onPressed: onBackspace,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits.map(_buildKey).toList(),
    );
  }

  Widget _buildKey(String digit) {
    return SizedBox(
      width: 72,
      height: 60,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: () => onDigit(digit),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(color: SyrixColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
