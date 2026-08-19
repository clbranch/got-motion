// Generates Supabase Auth email HTML templates with embedded logo.
//
//   dart run tool/generate_auth_email_templates.dart
//
// Paste each file from web/email-templates/ into Supabase → Authentication → Email Templates.

import 'dart:convert';
import 'dart:io';

const _logoPath = 'web/assets/email_logo.png';
const _outDir = 'web/email-templates';

void main() {
  final logoB64 = base64Encode(File(_logoPath).readAsBytesSync());
  Directory(_outDir).createSync(recursive: true);

  final templates = <_Template>[
    _Template(
      file: 'confirm-signup.html',
      supabaseName: 'Confirm signup',
      subject: 'Confirm your Got Motion account',
      heading: 'Confirm your email',
      body:
          'Thanks for signing up for Got Motion. Tap below to confirm your account and start competing with your crew.',
      button: 'Confirm email',
      steps: '''
Step 1: Tap <strong style="color:#f4f7fb;">Confirm email</strong><br>
Step 2: Tap <strong style="color:#f4f7fb;">Allow</strong> when your phone asks to open Got Motion''',
      footer: 'Didn&apos;t create an account? You can ignore this email.',
    ),
    _Template(
      file: 'magic-link.html',
      supabaseName: 'Magic Link',
      subject: 'Sign in to Got Motion',
      heading: 'Sign in to Got Motion',
      body: 'Tap below to sign in to your account. This link expires soon.',
      button: 'Sign in',
      steps: '''
Step 1: Tap <strong style="color:#f4f7fb;">Sign in</strong><br>
Step 2: Tap <strong style="color:#f4f7fb;">Allow</strong> when your phone asks to open Got Motion''',
      footer: 'Didn&apos;t request this? You can ignore this email.',
    ),
    _Template(
      file: 'change-email.html',
      supabaseName: 'Change Email Address',
      subject: 'Confirm your new email — Got Motion',
      heading: 'Confirm your new email',
      body:
          'You requested to change the email on your Got Motion account. Tap below to confirm this address.',
      button: 'Confirm new email',
      steps: '''
Step 1: Tap <strong style="color:#f4f7fb;">Confirm new email</strong><br>
Step 2: Tap <strong style="color:#f4f7fb;">Allow</strong> when your phone asks to open Got Motion''',
      footer: 'Didn&apos;t request this change? You can ignore this email.',
    ),
    _Template(
      file: 'invite-user.html',
      supabaseName: 'Invite user',
      subject: 'You&apos;re invited to Got Motion',
      heading: 'You&apos;re invited',
      body:
          'You&apos;ve been invited to join Got Motion. Tap below to accept and set up your account.',
      button: 'Accept invite',
      steps: '''
Step 1: Tap <strong style="color:#f4f7fb;">Accept invite</strong><br>
Step 2: Tap <strong style="color:#f4f7fb;">Allow</strong> when your phone asks to open Got Motion''',
      footer: 'Didn&apos;t expect this invite? You can ignore this email.',
    ),
    _Template(
      file: 'reset-password.html',
      supabaseName: 'Reset password',
      subject: 'Reset your Got Motion password',
      heading: 'Reset your password',
      body:
          'We received a request to reset your password. Tap below to choose a new one in the app.',
      button: 'Reset password',
      steps: '''
Step 1: Tap <strong style="color:#f4f7fb;">Reset password</strong><br>
Step 2: Tap <strong style="color:#f4f7fb;">Allow</strong> when your phone asks to open Got Motion''',
      footer: 'Didn&apos;t request this? You can ignore this email.',
    ),
  ];

  final notifications = <_NotificationTemplate>[
    _NotificationTemplate(
      file: 'password-changed.html',
      supabaseName: 'Password changed (Security)',
      subject: 'Your Got Motion password was changed',
      heading: 'Password changed',
      body: '''
This is a confirmation that the password for your Got Motion account
<strong style="color:#f4f7fb;">{{ .Email }}</strong> was just changed.
If you made this change, you&apos;re all set — no action needed.''',
      footer:
          'If you didn&apos;t change your password, reset it in the app immediately and contact us at <a href="https://www.gotmotion.app/support" style="color:#238bff;">gotmotion.app/support</a>.',
    ),
    _NotificationTemplate(
      file: 'email-address-changed.html',
      supabaseName: 'Email address changed (Security)',
      subject: 'Your Got Motion email was changed',
      heading: 'Email address changed',
      body: '''
The email address for your Got Motion account was changed from
<strong style="color:#f4f7fb;">{{ .OldEmail }}</strong> to
<strong style="color:#f4f7fb;">{{ .Email }}</strong>.
If you made this change, you&apos;re all set — no action needed.''',
      footer:
          'If you didn&apos;t make this change, contact us immediately at <a href="https://www.gotmotion.app/support" style="color:#238bff;">gotmotion.app/support</a>.',
    ),
  ];

  for (final t in templates) {
    final html = _buildHtml(logoB64: logoB64, template: t);
    final path = '$_outDir/${t.file}';
    File(path).writeAsStringSync(html);
    stdout.writeln('wrote $path');
  }

  for (final t in notifications) {
    final html = _buildNotificationHtml(logoB64: logoB64, template: t);
    final path = '$_outDir/${t.file}';
    File(path).writeAsStringSync(html);
    stdout.writeln('wrote $path');
  }

  File('$_outDir/README.md').writeAsStringSync('''
# Got Motion — Supabase Auth email templates

Paste each HTML file into **Supabase → Authentication → Email Templates**.

| File | Supabase template | Suggested subject |
|------|-------------------|-------------------|
| `confirm-signup.html` | Confirm signup | Confirm your Got Motion account |
| `magic-link.html` | Magic Link | Sign in to Got Motion |
| `change-email.html` | Change Email Address | Confirm your new email — Got Motion |
| `invite-user.html` | Invite user | You're invited to Got Motion |
| `reset-password.html` | Reset password | Reset your Got Motion password |
| `password-changed.html` | Security → Password changed | Your Got Motion password was changed |
| `email-address-changed.html` | Security → Email address changed | Your Got Motion email was changed |

For each template: open **Source**, select all, paste the file contents, set the subject, **Save**.

Security notifications: **Authentication → Emails → Security** — enable the toggle, click the row, paste HTML, set subject.

Logo is embedded (base64) so it renders without external image hosting.
Regenerate after logo changes: `dart run tool/generate_auth_email_templates.dart`
''');
  stdout.writeln('wrote $_outDir/README.md');
}

class _Template {
  const _Template({
    required this.file,
    required this.supabaseName,
    required this.subject,
    required this.heading,
    required this.body,
    required this.button,
    required this.steps,
    required this.footer,
  });

  final String file;
  final String supabaseName;
  final String subject;
  final String heading;
  final String body;
  final String button;
  final String steps;
  final String footer;
}

String _buildHtml({required String logoB64, required _Template template}) {
  return '''
<!DOCTYPE html>
<html>
<body style="margin:0;padding:0;background:#07090d;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#07090d;padding:40px 16px;">
    <tr>
      <td align="center">
        <table width="100%" style="max-width:520px;background:#11161d;border:1px solid #222b37;border-radius:16px;padding:32px 28px;">
          <tr>
            <td align="center" style="padding-bottom:24px;background:#11161d;">
              <img src="data:image/png;base64,$logoB64" alt="Got Motion" width="80" height="80" style="display:block;margin:0 auto 12px;border:0;outline:none;text-decoration:none;" />
              <div style="font-size:13px;color:#8d98aa;margin-top:4px;">Stay in motion together</div>
            </td>
          </tr>
          <tr>
            <td style="color:#f4f7fb;font-size:22px;font-weight:700;padding-bottom:12px;">${template.heading}</td>
          </tr>
          <tr>
            <td style="color:#8d98aa;font-size:15px;line-height:1.6;padding-bottom:24px;">
              ${template.body}
            </td>
          </tr>
          <tr>
            <td align="center" style="padding-bottom:24px;">
              <a href="{{ .ConfirmationURL }}"
                 style="display:inline-block;background:#238bff;color:#ffffff;text-decoration:none;font-weight:700;font-size:16px;padding:14px 28px;border-radius:12px;">
                ${template.button}
              </a>
            </td>
          </tr>
          <tr>
            <td style="color:#8d98aa;font-size:13px;line-height:1.5;padding-bottom:8px;">
              ${template.steps}
            </td>
          </tr>
          <tr>
            <td style="color:#8d98aa;font-size:12px;line-height:1.5;padding-top:16px;border-top:1px solid #222b37;">
              If the button doesn&apos;t work, copy this link:<br>
              <a href="{{ .ConfirmationURL }}" style="color:#238bff;word-break:break-all;">{{ .ConfirmationURL }}</a>
            </td>
          </tr>
          <tr>
            <td style="color:#8d98aa;font-size:12px;padding-top:20px;">
              ${template.footer}
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>''';
}

class _NotificationTemplate {
  const _NotificationTemplate({
    required this.file,
    required this.supabaseName,
    required this.subject,
    required this.heading,
    required this.body,
    required this.footer,
  });

  final String file;
  final String supabaseName;
  final String subject;
  final String heading;
  final String body;
  final String footer;
}

String _buildNotificationHtml({
  required String logoB64,
  required _NotificationTemplate template,
}) {
  return '''
<!DOCTYPE html>
<html>
<body style="margin:0;padding:0;background:#07090d;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#07090d;padding:40px 16px;">
    <tr>
      <td align="center">
        <table width="100%" style="max-width:520px;background:#11161d;border:1px solid #222b37;border-radius:16px;padding:32px 28px;">
          <tr>
            <td align="center" style="padding-bottom:24px;background:#11161d;">
              <img src="data:image/png;base64,$logoB64" alt="Got Motion" width="80" height="80" style="display:block;margin:0 auto 12px;border:0;outline:none;text-decoration:none;" />
              <div style="font-size:13px;color:#8d98aa;margin-top:4px;">Stay in motion together</div>
            </td>
          </tr>
          <tr>
            <td style="color:#f4f7fb;font-size:22px;font-weight:700;padding-bottom:12px;">${template.heading}</td>
          </tr>
          <tr>
            <td style="color:#8d98aa;font-size:15px;line-height:1.6;padding-bottom:24px;">
              ${template.body}
            </td>
          </tr>
          <tr>
            <td style="color:#8d98aa;font-size:12px;line-height:1.5;padding-top:16px;border-top:1px solid #222b37;">
              ${template.footer}
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>''';
}
