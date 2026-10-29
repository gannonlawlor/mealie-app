# Cookbook support

Cookbook - Mealie Companion is an independent app, not the official Mealie project.

## Choose how to use the app

- **Use Without Server:** save recipes on this device. iOS optionally supports
  iCloud sync. Keep a separate copy of recipes that you cannot afford to lose;
  the app currently has no general-purpose export/restore workflow.
- **Connect to Server:** enter the address of your own Mealie installation and
  sign in with its email/password credentials. Recipe management, meal planning,
  and shopping lists use that server. A Mealie account is separate from your Apple
  or Google account. SSO-only authentication is not currently provided by this app.

The client implements Mealie v2-style API endpoints. Check your server version
when reporting a problem; compatibility with every Mealie release has not been
verified. Prefer an HTTPS server address. HTTP transmits credentials and other
traffic without encryption.

## Troubleshooting

1. Confirm that your server opens in a browser on the same device and network.
2. Check that your server address and credentials are correct. For a private server,
   you may need your home network or VPN.
3. If a recipe import fails, verify the page opens and contains structured recipe
   data. Not every recipe website supports this. Try a different recipe page.
4. For iCloud, confirm you are signed in to iCloud and have enabled sync. For
   Reminders, check the app's permission in your device settings.
5. Avoid uninstalling the app as a first troubleshooting step: local recipes and
   queued changes may be lost.

## Report a problem

[Open an issue](https://github.com/gannonlawlor/mealie-app/issues) with the app
version, device/OS version, Mealie server version if applicable, and steps to
reproduce the problem. Say whether you use local or server mode. A public recipe
URL is useful for import problems.

The issue tracker is public. Redact credentials, private server addresses,
account details, and personal content from screenshots and logs. The app's
[privacy policy](PRIVACY.md) explains how its features handle data.
