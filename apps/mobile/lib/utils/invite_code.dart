String extractInviteCode(String input) {
  final trimmed = input.trim();
  final parts = trimmed.split("/");
  return parts.isNotEmpty ? parts.last : trimmed;
}

const String profileQrPrefix = "syrixuser:";

bool isProfileQrCode(String input) => input.trim().startsWith(profileQrPrefix);

String extractUserIdFromProfileQr(String input) => input.trim().substring(profileQrPrefix.length);
