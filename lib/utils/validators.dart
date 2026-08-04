// Practical email shape check (local@domain.tld) — not full RFC 5322, since
// that grammar accepts addresses no real mail provider issues and only
// confuses users when it rejects fine ones.
final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isValidEmail(String email) => _emailPattern.hasMatch(email.trim());
